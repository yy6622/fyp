// Exports real group-chat messages from Firestore to data/raw/firestore_messages.csv
//
// Uses the firebase-admin package already installed in ../../functions.
// One-time login (opens a browser):   gcloud auth application-default login
// Then, from this folder:
//   node export_firestore_chats.js                 -> every trip with at least 5 text messages
//   node export_firestore_chats.js --trip <tripId> -> one trip only
//
// Only text messages are exported (no images / locations). Sender names are
// kept because the summary reports who prefers / agreed to what.

const path = require("path");
const fs = require("fs");
// Resolve packages as if we were inside functions/, so its node_modules is used.
const fnRequire = require("module").createRequire(path.join(__dirname, "..", "..", "functions", "index.js"));
const { initializeApp } = fnRequire("firebase-admin/app");
const { getFirestore } = fnRequire("firebase-admin/firestore");

const PROJECT_ID = "voya-f69f0";
const MIN_MESSAGES = 5;

function csvCell(v) {
  const s = String(v == null ? "" : v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

async function main() {
  const tripArg = process.argv.indexOf("--trip");
  const onlyTrip = tripArg > 0 ? process.argv[tripArg + 1] : null;
  initializeApp({ projectId: PROJECT_ID });
  const db = getFirestore();
  const trips = onlyTrip ? [await db.collection("trips").doc(onlyTrip).get()] : (await db.collection("trips").get()).docs;
  const rows = [["message_id", "conv_id", "speaker", "message", "created_at", "destination"]];
  let kept = 0;
  for (const trip of trips) {
    if (!trip.exists) continue;
    const snap = await trip.ref.collection("messages").orderBy("createdAt").get();
    const msgs = snap.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((m) => typeof m.text === "string" && m.text.trim());
    if (msgs.length < MIN_MESSAGES) continue;
    kept += 1;
    const dest = trip.get("destination") || trip.get("name") || "";
    for (const m of msgs) {
      const at = m.createdAt && m.createdAt.toDate ? m.createdAt.toDate().toISOString() : "";
      rows.push([m.id, trip.id, (m.senderName || "Member").trim(), m.text.replace(/\r?\n/g, " ").trim(), at, dest]);
    }
    console.log(`${trip.id}: ${msgs.length} messages`);
  }
  const out = path.join(__dirname, "data", "raw", "firestore_messages.csv");
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, "﻿" + rows.map((r) => r.map(csvCell).join(",")).join("\n"), "utf8");
  console.log(`\n${rows.length - 1} messages from ${kept} chats -> ${out}`);
}

main().catch((e) => {
  console.error(e.message || e);
  if (String(e).includes("credentials")) console.error("Run: gcloud auth application-default login");
  process.exit(1);
});
