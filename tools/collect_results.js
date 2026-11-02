// Collects every test report in test_results/ into one table per test case.
//   node tools/collect_results.js
// Reads:  unit.json, integration.json          (flutter test --file-reporter json:...)
//         *-junit.xml                           (node --test junit, Playwright junit)
//         manual_results.csv                    (optional, your manual test results)
// Writes: test_results/summary.csv   one row per executed test
//         test_results/by_test_case.csv   one row per TCxx (paste into Table 5.x)
//         test_results/summary.md    readable overview
const fs = require("fs");
const path = require("path");

const dir = path.join(__dirname, "..", "test_results");
const rows = [];
const tcOf = (name) => (name.match(/\bTC\d+[a-z]?\b/) || [""])[0];

// Test cases that check a requirement the app does not meet yet (see Chapter 7.4).
const KNOWN_GAPS = {
  // Empty: every requirement with a test case is implemented. Add an entry here
  // when a test checks a requirement the app does not meet yet.
};

const unescape = (s) => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&");

function readJunit(file, layer) {
  const xml = fs.readFileSync(file, "utf8");
  const re = /<testcase\b([^>]*?)(\/>|>([\s\S]*?)<\/testcase>)/g;
  let m;
  while ((m = re.exec(xml))) {
    const name = unescape((m[1].match(/name="([^"]*)"/) || [, ""])[1]);
    const body = m[3] || "";
    let result = "PASS";
    let detail = "";
    if (/<skipped/.test(body)) {
      result = "SKIPPED";
      detail = unescape((body.match(/<skipped[^>]*message="([^"]*)"/) || [, ""])[1]);
    } else if (/<failure|<error/.test(body)) {
      result = "FAIL";
      detail = unescape((body.match(/<(?:failure|error)[^>]*message="([^"]*)"/) || [, ""])[1] ||
        body.replace(/<[^>]+>/g, " ").trim().split("\n")[0]);
    }
    rows.push({ tc: tcOf(name), name, layer, result, detail });
  }
}

function readFlutterJson(file, layer) {
  const tests = new Map();
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    if (!line.startsWith("{")) continue;
    let e;
    try { e = JSON.parse(line); } catch { continue; }
    if (e.type === "testStart") tests.set(e.test.id, { name: e.test.name, errors: [] });
    if (e.type === "error" && tests.has(e.testID)) tests.get(e.testID).errors.push(e.error);
    if (e.type === "testDone" && tests.has(e.testID)) {
      const t = tests.get(e.testID);
      if (e.hidden || !tcOf(t.name)) continue;
      const result = e.skipped ? "SKIPPED" : e.result === "success" ? "PASS" : "FAIL";
      rows.push({ tc: tcOf(t.name), name: t.name, layer, result, detail: (t.errors[0] || "").split("\n").slice(0, 3).join(" ") });
    }
  }
}

function readManual(file) {
  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/).slice(1).filter(Boolean);
  for (const line of lines) {
    const [tc, name, result, ...rest] = line.split(",");
    if (!tc) continue;
    rows.push({ tc: tc.trim(), name: (name || "").trim(), layer: "Manual", result: (result || "NOT RUN").trim().toUpperCase(), detail: rest.join(",").trim() });
  }
}

if (!fs.existsSync(dir)) {
  console.error("No test_results/ folder yet - run run_tests.ps1 first.");
  process.exit(1);
}
const layerOf = { "unit.json": "Dart unit", "integration.json": "Flutter integration (emulator)" };
for (const f of fs.readdirSync(dir)) {
  const p = path.join(dir, f);
  if (f.endsWith(".json") && layerOf[f]) readFlutterJson(p, layerOf[f]);
  if (f === "functions-junit.xml") readJunit(p, "Cloud Functions (Node)");
  if (f === "live-junit.xml") readJunit(p, "Live API (Stripe test mode)");
  if (f === "web-junit.xml") readJunit(p, "Web console (Playwright)");
  if (f === "manual_results.csv") readManual(p);
}

const csv = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
fs.writeFileSync(path.join(dir, "summary.csv"),
  ["Test case,Test,Layer,Result,Details", ...rows.map((r) => [r.tc, r.name, r.layer, r.result, r.detail].map(csv).join(","))].join("\n"));

const byTc = new Map();
for (const r of rows) {
  if (!r.tc) continue;
  if (!byTc.has(r.tc)) byTc.set(r.tc, []);
  byTc.get(r.tc).push(r);
}
const num = (tc) => Number(tc.match(/\d+/)[0]);
const order = [...byTc.keys()].sort((a, b) => num(a) - num(b) || a.localeCompare(b));
const tcRows = order.map((tc) => {
  const list = byTc.get(tc);
  const failed = list.filter((r) => r.result === "FAIL");
  const ran = list.filter((r) => r.result === "PASS" || r.result === "FAIL");
  const status = ran.length === 0 ? (list.some((r) => r.result === "NOT RUN") ? "Not run" : "Skipped") : failed.length ? "Fail" : "Pass";
  const gaps = failed.map((r) => KNOWN_GAPS[r.tc]).filter(Boolean);
  const actual = status === "Pass" ? "As expected"
    : status === "Fail" ? (gaps.length ? `Known gap: ${gaps.join("; ")}` : failed.map((r) => r.detail).join(" | ").slice(0, 300))
    : list.map((r) => r.detail).filter(Boolean).join(" | ");
  return { tc, status, tests: `${ran.length - failed.length}/${ran.length}`, layers: [...new Set(list.map((r) => r.layer))].join(" + "), actual };
});
fs.writeFileSync(path.join(dir, "by_test_case.csv"),
  ["Test case,Status,Tests passed,Executed by,Actual result", ...tcRows.map((r) => [r.tc, r.status, r.tests, r.layers, r.actual].map(csv).join(","))].join("\n"));

const count = (s) => tcRows.filter((r) => r.status === s).length;
const md = [
  `# Voya test results (${new Date().toISOString().slice(0, 16).replace("T", " ")})`,
  "",
  `Test cases: ${tcRows.length}  |  Pass: ${count("Pass")}  |  Fail: ${count("Fail")}  |  Skipped/not run: ${count("Skipped") + count("Not run")}`,
  `Individual tests: ${rows.length}  |  passed ${rows.filter((r) => r.result === "PASS").length}  |  failed ${rows.filter((r) => r.result === "FAIL").length}`,
  "",
  "| Test case | Status | Tests passed | Executed by | Actual result |",
  "| --- | --- | --- | --- | --- |",
  ...tcRows.map((r) => `| ${r.tc} | ${r.status} | ${r.tests} | ${r.layers} | ${r.actual.replace(/\|/g, "/")} |`),
].join("\n");
fs.writeFileSync(path.join(dir, "summary.md"), md);
console.log(md);
