// "Discussion summary" - Voya's own trained model (no external AI API).
//
// Reads a trip's group chat and returns a structured summary: destination,
// dates, budget, places, transport and accommodation with what the group
// agreed / is still undecided on / turned down, everyone's preferences, and
// the key messages. The classifier (TF-IDF + linear SVM) is trained in
// ml/discussion_summary/ and exported to model.json; summariser.js is a 1:1
// port of ml/discussion_summary/summariser.py (checked by test_parity.py).
//
// request.data: { tripId: string }
// returns: { facts, sections, preferences, pending, highlights, text, stats, model, messageCount }
//
// The summary comes only from the trained model and the rules here - OpenAI is NOT used to word it.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");

if (getApps().length === 0) initializeApp();

const MAX_MESSAGES = 300;
const TITLES = { DESTINATION: "Destination", DATE: "Dates", BUDGET: "Budget", ACCOMMODATION: "Accommodation",
  TRANSPORT: "Transport", ATTRACTION: "Places to visit" };
const TRANSPORT_WORDS = /(flight|fly|plane|airasia|airline|机票|飞机|航班|飞|train|高铁|火车|动车|mrt|lrt|metro|subway|地铁|bus|巴士|大巴|taxi|grab|uber|didi|滴滴|打车|出租|car|drive|自驾|租车|开车|ferry|轮渡|船|walk|走路|ktm|ets)/i;
const PREFERENCE_WORDS = /(prefer|don'?t like|dont like|cannot eat|can'?t eat|allerg|vegetarian|vegan|halal|no pork|不吃|不能吃|过敏|吃素|清真|怕|不喜欢|喜欢|不想|想要|希望|最好|wake up|early|晕车|motion sick|budget|省钱|tak suka|tak makan)/i;
const ORDER = { confirmed: 0, pending: 1, rejected: 2 };

/**
 * Pure part of the function (no Firestore) - also used by the smoke test.
 * Who agreed to what comes from the trained model (summariser.js); places and the hotel area are
 * then anchored on real names (planner/decide.js), so the card shows "The Bund", never a raw chat line.
 */
function buildResponse(messages, memberIds, decisions = null, { destination = "", saved = [], catalog = [], memberNames = [] } = {}) {
  const { summarise } = require("./summariser");
  const { model, name: modelName } = require("./load_model").loadModel();
  const { knownPlaces, findCity, placesFor } = require("../planner/places");
  const { decide } = require("../planner/decide");
  const { destinationOf } = require("../itinerary_engine");
  const s = summarise(messages, model, memberIds);
  const known = knownPlaces({ destination: destinationOf(destination, messages), saved, catalog });
  const d = decide({ messages, s, known, members: memberNames, decisions });

  const strip = (it) => ({
    category: it.category, status: it.status, text: it.text, value: it.value, proposer: it.proposer,
    support: it.support, against: it.against, messageId: it.messageId, decided: null,
  });
  const sections = [];
  const section = (category, items) => {
    if (items.length) sections.push({ category, title: TITLES[category], items: items.sort((a, b) => ORDER[a.status] - ORDER[b.status]) });
  };
  const modelItems = (cat) => s.sections.filter((x) => x.category === cat).flatMap((x) => x.items).map(strip);

  // destination: the city the chat names (never "hi" or a sentence)
  const city = d.destination || placesFor(destination).city;
  if (city) {
    const first = messages.find((m) => findCity(m.text || "", placesFor("")) === city);
    const name = city.split(",")[0];
    section("DESTINATION", [{ category: "DESTINATION", status: "confirmed", text: first ? first.text : name, value: name,
      proposer: first ? first.speaker : "", support: [], against: [], messageId: first ? first.id : "", decided: null }]);
  }
  section("DATE", modelItems("DATE").filter((it) => it.value));
  section("BUDGET", modelItems("BUDGET").filter((it) => it.value));
  const textOf = new Map(messages.map((m) => [m.id, m.text]));
  const fromDecision = (x, category, value) => ({
    category, status: x.status, text: textOf.get(x.sourceMessageId) || value, value, proposer: x.proposer,
    support: x.support, against: x.against, messageId: x.messageId, decided: x.decided,
  });
  section("ACCOMMODATION", d.hotels.map((h) => fromDecision(h, "ACCOMMODATION", `Hotel near ${h.name}`)));
  section("TRANSPORT", modelItems("TRANSPORT").filter((it) => TRANSPORT_WORDS.test(it.text || "") && Array.from(it.text || "").length <= 60));
  section("ATTRACTION", d.places.map((p) => fromDecision(p, "ATTRACTION", p.name)));

  const facts = { ...s.facts };
  if (city) facts.destination = city.split(",")[0];
  const preferences = (s.preferences || []).filter((p) => PREFERENCE_WORDS.test(p.text || ""));
  const all = sections.flatMap((x) => x.items);
  const word = { confirmed: "agreed", pending: "undecided", rejected: "turned down" };
  const lines = [];
  for (const sec of sections) {
    for (const st of ["confirmed", "pending", "rejected"]) {
      const vals = sec.items.filter((it) => it.status === st).map((it) => it.value || it.text);
      if (vals.length) lines.push(`${sec.title} - ${word[st]}: ${vals.join(", ")}.`);
    }
  }
  for (const p of preferences) lines.push(`Preferences - ${p.speaker}: ${p.text}.`);
  const response = {
    facts,
    sections,
    preferences,
    pending: [],
    highlights: s.highlights,
    text: lines.join("\n"),
    stats: { ...s.stats, topics: all.length, confirmed: all.filter((it) => it.status === "confirmed").length },
    model: modelName,
    messageCount: messages.length,
  };
  require("./decisions").applyToSummary(response, decisions);
  // pending = the same objects as in sections, so decisions applied to one show in both
  response.pending = response.sections.flatMap((sec) => sec.items).filter((it) => it.status === "pending");
  response.stats.pending = response.pending.length;
  return response;
}
exports.buildResponse = buildResponse;

exports.summariseDiscussion = onCall({ timeoutSeconds: 60, memory: "512MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const tripId = request.data && request.data.tripId;
  if (typeof tripId !== "string" || !tripId) throw new HttpsError("invalid-argument", "tripId is required.");

  // Loaded here, not at the top: `firebase deploy` gives the codebase only 10 s to load.
  const { getFirestore } = require("firebase-admin/firestore");
  const db = getFirestore();
  const tripRef = db.collection("trips").doc(tripId);
  const snap = await tripRef.get();
  const trip = snap.data();
  // Same wording for "missing" and "not yours", so trip ids can't be probed.
  if (!snap.exists || !Array.isArray(trip.memberIds) || !trip.memberIds.includes(request.auth.uid)) {
    throw new HttpsError("permission-denied", "You are not a member of this trip.");
  }

  const msgSnap = await tripRef.collection("messages").orderBy("createdAt", "desc").limit(MAX_MESSAGES).get();
  const messages = msgSnap.docs
    .reverse()
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((m) => typeof m.text === "string" && m.text.trim())
    .map((m) => ({ id: m.id, speaker: String(m.senderName || "Member").trim() || "Member", text: m.text }));
  if (messages.length === 0) {
    throw new HttpsError("failed-precondition", "There is no discussion in this group yet.");
  }

  let result;
  try {
    const memberNames = Object.values(trip.memberNames || {}).map(String);
    result = buildResponse(messages, trip.memberIds, trip.discussionDecisions || null,
      { destination: trip.destination || "", memberNames });
  } catch (err) {
    console.error("summariseDiscussion failed", err);
    throw new HttpsError("internal", "Could not summarise the discussion. Please try again.");
  }
  return result;
});
