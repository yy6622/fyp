// Offline smoke test of the three Cloud Functions that use Voya's own model
// (no network, no Firebase project, no tokens):
//   generateItinerary (AI Summarise), optimiseItinerary (Optimise), summariseDiscussion.
// Run from functions/ so its node_modules are used:   cd functions && node ../ml/discussion_summary/test_functions_mock.js
const path = require("path");
const assert = require("assert");
const Module = require("module");
const fnDir = path.join(__dirname, "..", "..", "functions");
const fnRequire = Module.createRequire(path.join(fnDir, "index.js"));
process.env.OPENAI_API_KEY = "";

// ---- fake Firestore --------------------------------------------------------
const trip = {
  memberIds: ["u1", "u2", "u3", "u4"],
  memberNames: { u1: "Wei Jie", u2: "Amanda", u3: "Hafiz", u4: "Mei" },
  destination: "Shanghai",
  days: {
    0: { weekday: "Fri", date: "18 Dec 2026", items: { h1: { time: "15:00", label: "Hotel check-in", location: "People's Square", icon: "hotel" } } },
    1: { weekday: "Sat", date: "19 Dec 2026", items: {
      a1: { time: "10:00", label: "Disneyland", location: "Pudong", icon: "activity" },
      a2: { time: "09:00", label: "Dinner at Jia Jia Tang Bao", location: "Huangpu", icon: "food" },
      a3: { time: "11:00", label: "Yu Garden", location: "Huangpu", icon: "place" },
      a4: { time: "13:00", label: "Oriental Pearl Tower", location: "Lujiazui", icon: "place" },
      a5: { time: "15:00", label: "Nanjing Road", location: "Huangpu", icon: "shopping" } } },
    2: { weekday: "Sun", date: "20 Dec 2026", items: {} },
  },
  flights: [], hotelStays: [],
};
const chat = [
  ["Wei Jie", "guys so are we confirmed going Shanghai in Dec?"], ["Amanda", "yes!! finally"],
  ["Mei", "外滩一定要去，晚上很漂亮"], ["Hafiz", "第二天晚上去外滩吧"], ["Amanda", "can we skip Disneyland? too expensive"],
  ["Wei Jie", "agree, no Disneyland"], ["Mei", "Tianzifang for shopping on Sunday"], ["Hafiz", "ok"],
  ["Amanda", "hotel near People's Square ok"], ["Hafiz", "I prefer not to wake up too early pls"],
];
const docs = (rows) => ({ docs: rows.map(([id, data]) => ({ id, data: () => data, get: (k) => data[k] })) });
const fakeDb = {
  collection: (name) => ({
    doc: (id) => ({
      get: async () => ({ exists: name === "trips", data: () => trip, get: (k) => trip[k] }),
      collection: (sub) => ({
        orderBy: () => ({ limit: () => ({ get: async () => docs(chat.map(([s, t], i) => [`m${i}`, { senderName: s, text: t }]).reverse()) }) }),
        doc: () => ({ get: async () => ({ exists: false }), set: async () => {} }),
      }),
    }),
    where: () => ({ limit: () => ({ get: async () => docs([]) }), get: async () => docs(name === "catalog_attractions"
      ? [["c1", { name: "The Bund", location: "Huangpu" }], ["c2", { name: "Tianzifang", location: "Taikang Road" }]] : []) }),
  }),
  doc: () => ({ get: async () => ({ exists: false }), set: async () => {} }),
  runTransaction: async () => false,
};
const fsPath = fnRequire.resolve("firebase-admin/firestore");
require.cache[fsPath] = { id: fsPath, filename: fsPath, loaded: true,
  exports: { getFirestore: () => fakeDb, FieldValue: { increment: (n) => n, serverTimestamp: () => 0 } } };

(async () => {
  const req = (data) => ({ auth: { uid: "u1" }, data });
  const itin = await require(path.join(fnDir, "itinerary.js")).generateItinerary.run(req({ tripId: "t1" }));
  console.log("generateItinerary:", JSON.stringify({ add: itin.add.map((a) => `${a.label} d${a.day} ${a.time}`),
    remove: itin.remove.map((r) => r.label), unresolved: itin.unresolved, engine: itin.engine, openai: itin.openai }));
  assert.strictEqual(itin.engine, "voya-planner");
  // The saved list has the English name; without OpenAI the Chinese name from the chat is kept.
  assert.ok(itin.add.some((a) => ["The Bund", "外滩"].includes(a.label) && a.day === 2 && a.time >= "17:00"), "the Bund on day 2, evening (第二天晚上)");
  assert.ok(itin.add.some((a) => a.label === "Tianzifang" && a.day === 3), "Tianzifang on Sunday = day 3");
  assert.ok(itin.remove.some((r) => r.label === "Disneyland"), "Disneyland removed (rejected in chat)");

  // a "Decide now" decision in the app overrides the chat: Tianzifang skipped
  trip.discussionDecisions = { m6: { status: "rejected", byName: "Amanda" } };
  const itin2 = await require(path.join(fnDir, "itinerary.js")).generateItinerary.run(req({ tripId: "t1" }));
  assert.ok(!itin2.add.some((a) => a.label === "Tianzifang"), "decided 'Skip' in the app removes the suggestion");
  const sum2 = await require(path.join(fnDir, "discussion_summary")).summariseDiscussion.run(req({ tripId: "t1" }));
  const tz = sum2.sections.flatMap((x) => x.items).find((it) => it.value === "Tianzifang");
  assert.ok(tz && tz.status === "rejected" && tz.decided.status === "rejected", "summary shows the app decision (old per-message id)");
  assert.strictEqual(tz.messageId, "d_place_tianzifang", "new decisions are stored per place, not per message");
  delete trip.discussionDecisions;
  console.log("decisions: Skip in the app overrides the chat in AI Summarise and in the summary");

  const opt = await require(path.join(fnDir, "optimise.js")).optimiseItinerary.run(req({ tripId: "t1", mode: "day", dayIndex: 1 }));
  console.log("optimiseItinerary day:", JSON.stringify(opt.update.map((u) => `${u.label} ${u.oldTime}->${u.newTime}`)));
  assert.ok(opt.update.some((u) => u.label.startsWith("Dinner") && u.newTime >= "18:00"), "dinner moved to the evening");
  assert.strictEqual(opt.engine, "voya-optimiser", "Optimise uses Voya's own scheduler, no AI");
  assert.ok(opt.update.every((u) => u.reason), "every Optimise change says why");
  assert.ok(opt.notes.length > 0, "a day with Disneyland and four more stops is flagged as too full");
  const whole = await require(path.join(fnDir, "optimise.js")).optimiseItinerary.run(req({ tripId: "t1", mode: "whole" }));
  console.log("optimiseItinerary whole:", JSON.stringify(whole.update.map((u) => `${u.label} d${u.fromDay}->d${u.toDay} ${u.newTime}`)));
  assert.ok(whole.update.some((u) => u.toDay !== u.fromDay), "whole trip rebalances an overloaded day");

  const sum = await require(path.join(fnDir, "discussion_summary")).summariseDiscussion.run(req({ tripId: "t1" }));
  assert.ok(sum.overview === undefined, "no OpenAI overview in the summary");
  console.log("summariseDiscussion:", sum.text.split("\n")[0]);
  console.log("all function smoke tests passed");
})().catch((e) => { console.error(e); process.exit(1); });
