const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { parseItineraryAnswer, resolveItineraryAnswer } = require("./itinerary_prompt");
const { computeLogisticsWindow, withinWindow } = require("./logistics");

if (getApps().length === 0) initializeApp();

// No Gemini / external model: Voya's own trained model (functions/discussion_summary/) reads
// who agreed / objected, and the planner (functions/planner/) only plans REAL places named in
// the chat (saved list, the app's catalog for this city, Voya's place database, name patterns),
// then organises them into days (itinerary_engine.js). No chat message is ever copied into the
// plan as an activity.
const MAX_MESSAGES = 300;
const MAX_SAVED = 60;


// One line of the prompt per field, "|" is the field separator.
const oneLine = (v) => String(v || "").replace(/[|\s]+/g, " ").trim();

/** Everything any member of the trip saved for this trip (attractions + restaurants). */
async function loadSavedPlaces(db, tripId, memberIds) {
  const keys = memberIds.map((uid) => `${uid}#${tripId}`);
  const sources = [
    ["catalog_attractions", "attraction"],
    ["catalog_restaurants", "restaurant"],
  ];
  const queries = [];
  for (const [collection, type] of sources) {
    for (let i = 0; i < keys.length; i += 30) { // array-contains-any takes at most 30 values
      queries.push(
        db.collection(collection).where("favoritedBy", "array-contains-any", keys.slice(i, i + 30)).get()
          .then((snap) => snap.docs.map((d) => ({
            name: oneLine(d.get("name")), location: oneLine(d.get("location")), type,
            // what kind of place it is - lets "a museum" / "本帮菜" in the chat find it (planner/needs.js)
            category: oneLine(d.get("category")),
            categories: (d.get("categories") || []).map(oneLine),
            cuisineTags: (d.get("cuisineTags") || []).map(oneLine),
            recommendedDuration: oneLine(d.get("recommendedDuration")),
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

/** Hotels any member saved for this trip (Explore): used when the chat agreed on an area but nothing is booked. */
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

/** The app's catalog places for the trip's city (not only the saved ones): more names the planner can recognise. */
async function loadCatalogPlaces(db, destination) {
  const key = String(destination || "").trim().toLowerCase();
  if (!key) return [];
  const sources = [["catalog_attractions", "attraction"], ["catalog_restaurants", "restaurant"]];
  const lists = await Promise.all(sources.map(async ([collection, type]) => {
    try {
      const snap = await db.collection(collection).where("destinationQuery", "==", key).limit(150).get();
      // the bulk restaurant import stores 'location' as a GeoPoint, not text
      const text = (v) => (typeof v === "string" ? oneLine(v) : "");
      const geo = (d) => { const l = d.get("location"); return l && typeof l === "object" && "latitude" in l ? l : null; };
      return snap.docs.map((d) => ({ name: oneLine(d.get("name")), location: text(d.get("address")) || text(d.get("location")), type,
        // what kind of place it is: lets "夜市" / "a café" find it when nobody saved one (planner/needs.js)
        category: oneLine(d.get("category")),
        categories: (d.get("categories") || []).map(oneLine),
        cuisineTags: (d.get("cuisineTags") || []).map(oneLine),
        // the area it is in, for keeping one area on one day (planner/schedule.js)
        district: oneLine(d.get("district")),
        lat: d.get("lat") ?? (geo(d) && geo(d).latitude), lng: d.get("lng") ?? (geo(d) && geo(d).longitude) }));
    } catch (err) {
      return [];      // the catalog only adds names; never fail AI Summarise over it
    }
  }));
  return lists.flat().filter((p) => p.name);
}

/**
 * Reads a trip's group chat together with the group's saved places and the
 * current plan, and returns the changes the group agreed on. It only
 * *suggests*: nothing is written to the trip, the app shows the result and
 * the user chooses what to apply.
 *
 * request.data: { tripId: string }
 * returns: {
 *   add:    [{ day, dayIndex, time, label, location, icon, inSavedList, warnNotSaved, alreadyInPlan }],
 *   update: [{ itemId, label, location, icon, fromDay, fromDayIndex, toDay, toDayIndex, oldTime, newTime }],
 *   remove: [{ itemId, label, day, dayIndex, time }],
 *   unresolved: [string],     // raised in chat but never decided
 *   messageCount: number,
 *   savedCount: number,
 * }
 */
exports.loadSavedPlaces = loadSavedPlaces;
exports.loadCatalogPlaces = loadCatalogPlaces;

exports.generateItinerary = onCall({ timeoutSeconds: 120, memory: "512MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const tripId = request.data && request.data.tripId;
  if (typeof tripId !== "string" || !tripId) throw new HttpsError("invalid-argument", "tripId is required.");

  // Loaded here, not at the top of the file: the Firestore client is slow to
  // import, and `firebase deploy` gives the whole codebase only 10 seconds to load.
  const { getFirestore } = require("firebase-admin/firestore");
  const db = getFirestore();
  const tripRef = db.collection("trips").doc(tripId);
  const snap = await tripRef.get();
  // Same wording for "missing" and "not yours", so trip ids can't be probed.
  const trip = snap.data();
  if (!snap.exists || !Array.isArray(trip.memberIds) || !trip.memberIds.includes(request.auth.uid)) {
    throw new HttpsError("permission-denied", "You are not a member of this trip.");
  }

  const daysRaw = trip.days || {};
  const dayKeys = Object.keys(daysRaw).sort((a, b) => Number(a) - Number(b));
  if (dayKeys.length === 0) throw new HttpsError("failed-precondition", "This trip has no days yet.");

  const [msgSnap, saved, catalog, savedHotels] = await Promise.all([
    tripRef.collection("messages").orderBy("createdAt", "desc").limit(MAX_MESSAGES).get(),
    // A saved-list failure must not block the whole feature: carry on without it.
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

  // The current plan, by 1-based day number. Ids stay server-side (the model
  // never sees them); they are used afterwards to pin update/remove to real items.
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
  let built;
  try {
    const { buildItinerary } = require("./itinerary_engine");
    const { loadModel } = require("./discussion_summary/load_model");
    built = await buildItinerary({
      messages, members: trip.memberIds, days, plan, saved, catalog, model: loadModel().model,
      destination: trip.destination || "", window,
      hasHotel: Array.isArray(trip.hotelStays) && trip.hotelStays.length > 0,
      // booked flights and hotel stays: the plan is built around them (planner/logistics_plan.js)
      flights: Array.isArray(trip.flights) ? trip.flights : [],
      hotelStays: Array.isArray(trip.hotelStays) ? trip.hotelStays : [],
      savedHotels,
      // a wish nobody named a place for ("夜市"): catalog_places, then OpenStreetMap (planner/osm_places.js)
      lookupNeed: require("./planner/osm_places").makeNeedLookup({ db, destination: trip.destination || "" }),
      decisions: trip.discussionDecisions || null,
    });
  } catch (err) {
    console.error("generateItinerary failed", err);
    throw new HttpsError("internal", "AI Summarise could not finish right now. Please try again.");
  }
  // Same validation as before: only well-formed entries on days that exist.
  const answer = parseItineraryAnswer(JSON.stringify(built.answer), dayKeys.length);
  if (!answer) throw new HttpsError("internal", "AI Summarise could not finish right now. Please try again.");

  const resolved = resolveItineraryAnswer(answer, saved, plan);

  // Belt-and-braces: the prompt *asks* the model to respect real flight/
  // hotel times (rule 9), but nothing stopped it from getting that wrong —
  // this is what actually enforces it, regardless of what the model said.
  // Only applies where a real flight timestamp exists at all (see
  // logistics.js's doc comment); otherwise it's a no-op, same behaviour as
  // before this existed.
  // the window now also has the typed-in flights and the chat's arrival time (planner/logistics_plan.js);
  // flight / hotel rows themselves are exempt (a check-out can be before the flight-home cut-off)
  const win = built.window || window;
  resolved.add = resolved.add.filter((a) => a.icon === "hotel" || withinWindow(win, a.day, a.time));
  resolved.update = resolved.update.filter((u) => withinWindow(win, u.day, u.time));

  const dayIndex = (day) => Number(dayKeys[day - 1]);
  return {
    add: resolved.add.map((a) => ({ ...a, dayIndex: dayIndex(a.day) })),
    update: resolved.update.map((u) => ({ ...u, fromDayIndex: dayIndex(u.fromDay), toDayIndex: dayIndex(u.toDay) })),
    remove: resolved.remove.map((r) => ({ ...r, dayIndex: dayIndex(r.day) })),
    unresolved: resolved.unresolved,
    // wishes without a place yet ("Dessert", "Shopping mall (if it rains)") - see planner/needs.js
    ideas: (built.ideas || []).slice(0, 8),
    // the booked flights / hotel stays the plan was built around, as {day, dayIndex, time, label, kind}
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
