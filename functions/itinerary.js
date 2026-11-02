const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { parseItineraryAnswer, resolveItineraryAnswer } = require("./itinerary_prompt");
const { computeLogisticsWindow, withinWindow } = require("./logistics");

if (getApps().length === 0) initializeApp();

const MAX_MESSAGES = 300;
const MAX_SAVED = 60;


const oneLine = (v) => String(v || "").replace(/[|\s]+/g, " ").trim();

async function loadSavedPlaces(db, tripId, memberIds) {
  const keys = memberIds.map((uid) => `${uid}#${tripId}`);
  const sources = [
    ["catalog_attractions", "attraction"],
    ["catalog_restaurants", "restaurant"],
  ];
  const queries = [];
  for (const [collection, type] of sources) {
    for (let i = 0; i < keys.length; i += 30) {
      queries.push(
        db.collection(collection).where("favoritedBy", "array-contains-any", keys.slice(i, i + 30)).get()
          .then((snap) => snap.docs.map((d) => ({
            name: oneLine(d.get("name")), location: oneLine(d.get("location")), type,
            category: oneLine(d.get("category")),
            categories: (d.get("categories") || []).map(oneLine),
            cuisineTags: (d.get("cuisineTags") || []).map(oneLine),
            recommendedDuration: oneLine(d.get("recommendedDuration")),
            rating: oneLine(d.get("rating")),
            price: oneLine(d.get("price") || d.get("priceRange")),
          }))),
      );
    }
  }
  const seen = new Set();
  const saved = [];
  for (const place of (await Promise.all(queries)).flat()) {
    const key = place.name.toLowerCase();
    if (!place.name || seen.has(key)) continue;
    seen.add(key);
    saved.push(place);
  }
  return saved.sort((a, b) => a.name.localeCompare(b.name)).slice(0, MAX_SAVED);
}

async function loadSavedHotels(db, tripId, memberIds) {
  const keys = memberIds.map((uid) => `${uid}#${tripId}`);
  const queries = [];
  for (let i = 0; i < keys.length; i += 30) {
    queries.push(db.collection("catalog_hotels").where("favoritedBy", "array-contains-any", keys.slice(i, i + 30)).get()
      .then((snap) => snap.docs.map((d) => ({ name: oneLine(d.get("name")), location: oneLine(d.get("location") || d.get("address")) }))));
  }
  const seen = new Set();
  return (await Promise.all(queries)).flat().filter((h) => h.name && !seen.has(h.name.toLowerCase()) && seen.add(h.name.toLowerCase()));
}

async function loadCatalogPlaces(db, destination) {
  const key = String(destination || "").trim().toLowerCase();
  if (!key) return [];
  const sources = [["catalog_attractions", "attraction"], ["catalog_restaurants", "restaurant"]];
  const lists = await Promise.all(sources.map(async ([collection, type]) => {
    try {
      const snap = await db.collection(collection).where("destinationQuery", "==", key).limit(150).get();
      const text = (v) => (typeof v === "string" ? oneLine(v) : "");
      const geo = (d) => { const l = d.get("location"); return l && typeof l === "object" && "latitude" in l ? l : null; };
      return snap.docs.map((d) => ({ name: oneLine(d.get("name")), location: text(d.get("address")) || text(d.get("location")), type,
        category: oneLine(d.get("category")),
        categories: (d.get("categories") || []).map(oneLine),
        cuisineTags: (d.get("cuisineTags") || []).map(oneLine),
        district: oneLine(d.get("district")),
        lat: d.get("lat") ?? (geo(d) && geo(d).latitude), lng: d.get("lng") ?? (geo(d) && geo(d).longitude),
        rating: oneLine(d.get("rating")), price: oneLine(d.get("price") || d.get("priceRange")) }));
    } catch (err) {
      return [];
    }
  }));
  return lists.flat().filter((p) => p.name);
}

exports.loadSavedPlaces = loadSavedPlaces;
exports.loadCatalogPlaces = loadCatalogPlaces;


function buildPrompt({ messages, members, days, plan, saved, catalog, model, destination, window,
  hasHotel, flights, hotelStays, savedHotels, lookupNeed, decisions, foodPreference, accommodation }) {
  return { messages, members, days, plan, saved, catalog, model, destination, window,
    hasHotel, flights, hotelStays, savedHotels, lookupNeed, decisions, foodPreference, accommodation };
}

async function submitAndParse(prompt, dayCount) {
  const { buildItinerary } = require("./itinerary_engine");
  const built = await buildItinerary(prompt);
  const answer = parseItineraryAnswer(JSON.stringify(built.answer), dayCount);
  return { built, answer };
}

exports.generateItinerary = onCall({ timeoutSeconds: 120, memory: "512MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const tripId = request.data && request.data.tripId;
  if (typeof tripId !== "string" || !tripId) throw new HttpsError("invalid-argument", "tripId is required.");
  if (request.data.consent !== true) {
    throw new HttpsError("failed-precondition", "AI Summarise needs your consent to read this group's chat first.");
  }

  const { getFirestore } = require("firebase-admin/firestore");
  const db = getFirestore();
  const tripRef = db.collection("trips").doc(tripId);
  const snap = await tripRef.get();
  const trip = snap.data();
  if (!snap.exists || !Array.isArray(trip.memberIds) || !trip.memberIds.includes(request.auth.uid)) {
    throw new HttpsError("permission-denied", "You are not a member of this trip.");
  }

  const daysRaw = trip.days || {};
  const dayKeys = Object.keys(daysRaw).sort((a, b) => Number(a) - Number(b));
  if (dayKeys.length === 0) throw new HttpsError("failed-precondition", "This trip has no days yet.");

  // Step 2: retrieve.
  const [msgSnap, saved, catalog, savedHotels] = await Promise.all([
    tripRef.collection("messages").orderBy("createdAt", "desc").limit(MAX_MESSAGES).get(),
    loadSavedPlaces(db, tripId, trip.memberIds).catch((err) => {
      console.error("generateItinerary could not read saved places", err);
      return [];
    }),
    loadCatalogPlaces(db, trip.destination),
    loadSavedHotels(db, tripId, trip.memberIds).catch(() => []),
  ]);
  const messages = msgSnap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .reverse()
    .filter((m) => typeof m.text === "string" && m.text.trim())
    .map((m) => ({ id: m.id, speaker: String(m.senderName || "Member").trim() || "Member", text: m.text }));
  if (messages.length === 0) {
    throw new HttpsError("failed-precondition", "There is no discussion in this group yet.");
  }

  const plan = {};
  dayKeys.forEach((key, i) => {
    plan[i + 1] = Object.entries((daysRaw[key] && daysRaw[key].items) || {})
      .map(([id, it]) => ({
        id,
        time: oneLine(it.time),
        label: oneLine(it.label),
        location: oneLine(it.location),
        icon: oneLine(it.icon) || "activity",
      }))
      .filter((it) => it.label)
      .sort((a, b) => a.time.localeCompare(b.time) || a.label.localeCompare(b.label));
  });

  const days = dayKeys.map((k, i) => ({ day: i + 1, weekday: daysRaw[k].weekday || "", date: daysRaw[k].date || "" }));
  const window = computeLogisticsWindow(trip, dayKeys.length);
  const basePromptArgs = {
    members: trip.memberIds, days, plan, saved, catalog,
    model: require("./discussion_summary/load_model").loadModel().model,
    destination: trip.destination || "", window,
    hasHotel: Array.isArray(trip.hotelStays) && trip.hotelStays.length > 0,
    flights: Array.isArray(trip.flights) ? trip.flights : [],
    hotelStays: Array.isArray(trip.hotelStays) ? trip.hotelStays : [],
    savedHotels,
    lookupNeed: require("./planner/osm_places").makeNeedLookup({ db, destination: trip.destination || "" }),
    decisions: trip.discussionDecisions || null,
    foodPreference: trip.foodPreference || "",
    accommodation: trip.accommodation || "",
  };

  let built;
  let answer;
  let lastErr = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    const messagesThisAttempt = attempt === 0 ? messages : messages.slice(Math.ceil(messages.length / 2));
    const prompt = buildPrompt({ ...basePromptArgs, messages: messagesThisAttempt });
    try {
      const result = await submitAndParse(prompt, dayKeys.length);
      built = result.built;
      answer = result.answer;
      lastErr = null;
    } catch (err) {
      lastErr = err;
      built = null;
      answer = null;
    }
    if (answer !== null || attempt === 1 || messagesThisAttempt.length < 2) break;
  }
  if (lastErr) console.error("generateItinerary failed", lastErr);
  if (!answer) throw new HttpsError("internal", "AI Summarise could not finish right now. Please try again.");

  const resolved = resolveItineraryAnswer(answer, saved, plan);

  const win = built.window || window;
  resolved.add = resolved.add.filter((a) => a.icon === "hotel" || withinWindow(win, a.day, a.time));
  resolved.update = resolved.update.filter((u) => withinWindow(win, u.day, u.time));

  const dayIndex = (day) => Number(dayKeys[day - 1]);
  return {
    add: resolved.add.map((a) => ({ ...a, dayIndex: dayIndex(a.day) })),
    update: resolved.update.map((u) => ({ ...u, fromDayIndex: dayIndex(u.fromDay), toDayIndex: dayIndex(u.toDay) })),
    remove: resolved.remove.map((r) => ({ ...r, dayIndex: dayIndex(r.day) })),
    unresolved: resolved.unresolved,
    ideas: (built.ideas || []).slice(0, 8),
    logistics: {
      fixed: ((built.logistics && built.logistics.fixed) || []).map((f) => ({ ...f, dayIndex: dayIndex(f.day) })),
      flightsBooked: Boolean(built.logistics && built.logistics.flightsBooked),
      hotelsBooked: Boolean(built.logistics && built.logistics.stays.length),
    },
    messageCount: messages.length,
    savedCount: saved.length,
    engine: "voya-planner",
    openai: built.stats.openai,
    relaxed: built.stats.relaxed,
  };
});
