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
            // Optimised Itinerary Generation Algorithm's utility formula (optimise_engine.js) —
            // recommendationScore reads this place's own rating, costPenalty its price/priceRange.
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
        lat: d.get("lat") ?? (geo(d) && geo(d).latitude), lng: d.get("lng") ?? (geo(d) && geo(d).longitude),
        // Optimised Itinerary Generation Algorithm's utility formula (optimise_engine.js).
        rating: oneLine(d.get("rating")), price: oneLine(d.get("price") || d.get("priceRange")) }));
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

// AI-Summarised Itinerary Algorithm (FYP documentation) — this function is that algorithm's
// steps 2-9, run in order every call:
//   2. retrieve      - the chat, the group's saved places, the app's catalog, booked flights/stays
//   3. filter        - drop empty/deleted messages, cap how much history is read at all
//   4. extract       - entities (places, who agreed/objected) come out of itinerary_engine.js's
//                       own planner/decide.js + planner/places.js, driven by the structured input below
//   5. build prompt  - assemble the structured input the AI service is asked to work from (a plain
//                       object, not literal text — see buildPrompt's own doc comment for why)
//   6. submit        - buildItinerary() IS the "AI service" here: Voya's own locally trained model
//                       (functions/discussion_summary/), never an external API/key (see header comment)
//   7. parse         - parseItineraryAnswer() (itinerary_prompt.js)
//   8. validate      - resolveItineraryAnswer() + the logistics-window filter below
//   9. regenerate    - on a genuine parse failure only, one retry with a trimmed prompt
// Steps 1 (consent) and 10-12 (display, review, confirm-to-save) are below / in the Flutter client
// (ai_itinerary_sheet.dart shows the result; nothing here is written to the trip - the person
// applies what they want from what's returned).

/** Step 5: the structured input the AI service (step 6) is asked to work from - an object, not a
 * free-text prompt, since the "AI service" standing in here is Voya's own local model, not an LLM
 * that takes a string. Keeping this as one explicit, named step (rather than inlining its fields
 * into the buildItinerary(...) call) is what makes this function's steps 2-9 match the documented
 * algorithm one for one, not just in spirit. */
function buildPrompt({ messages, members, days, plan, saved, catalog, model, destination, window,
  hasHotel, flights, hotelStays, savedHotels, lookupNeed, decisions, foodPreference, accommodation }) {
  return { messages, members, days, plan, saved, catalog, model, destination, window,
    hasHotel, flights, hotelStays, savedHotels, lookupNeed, decisions, foodPreference, accommodation };
}

/** Step 6: submits [prompt] to the AI service (Voya's local model) and step 7: parses its answer.
 * Returns null (never throws) when the answer isn't the well-formed JSON object step 7 expects,
 * so the caller can tell "nothing to suggest" apart from "that attempt didn't come back usable"
 * and decide whether step 9 (regenerate) is worth trying. */
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
  // Step 1: consent gate. The Flutter client (ai_itinerary_sheet.dart) only ever calls this
  // function after the person explicitly confirms a dialog explaining that AI Summarise reads
  // this group's chat; this is what actually enforces that, regardless of what called it - a
  // request missing the flag is refused outright, same wording either way so a caller can't
  // probe whether consent or trip membership is what's missing.
  if (request.data.consent !== true) {
    throw new HttpsError("failed-precondition", "AI Summarise needs your consent to read this group's chat first.");
  }

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

  // Step 2: retrieve.
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
  // Step 3: filter - drop anything with no real text (a deleted message, an image-only post the
  // model can't read) out of the capped window step 2 already limited to MAX_MESSAGES.
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
  // Step 4 (extract) happens inside itinerary_engine.js's buildItinerary, driven by step 5's
  // prompt below - findPlaces/decide there pull out the entities (which place, who agreed) this
  // function never has to see itself.
  const basePromptArgs = {
    members: trip.memberIds, days, plan, saved, catalog,
    model: require("./discussion_summary/load_model").loadModel().model,
    destination: trip.destination || "", window,
    hasHotel: Array.isArray(trip.hotelStays) && trip.hotelStays.length > 0,
    // booked flights and hotel stays: the plan is built around them (planner/logistics_plan.js)
    flights: Array.isArray(trip.flights) ? trip.flights : [],
    hotelStays: Array.isArray(trip.hotelStays) ? trip.hotelStays : [],
    savedHotels,
    // a wish nobody named a place for ("夜市"): catalog_places, then OpenStreetMap (planner/osm_places.js)
    lookupNeed: require("./planner/osm_places").makeNeedLookup({ db, destination: trip.destination || "" }),
    decisions: trip.discussionDecisions || null,
    // Group Setting > Travel Preferences - a soft tie-break among several equally-fitting
    // places/hotels (see itinerary_engine.js's buildItinerary doc comment on foodPreference).
    foodPreference: trip.foodPreference || "",
    accommodation: trip.accommodation || "",
  };

  // Steps 5-9: build the prompt, submit it, parse the answer - and on a genuine parse failure
  // (not "nothing to suggest", which is a valid answer, not a failure), regenerate once with a
  // trimmed prompt (the most recent half of the discussion only) before giving up. buildItinerary
  // is deterministic for identical input, so retrying unchanged would just fail the same way
  // again - trimming is what makes the second attempt a genuinely different one, the same way a
  // person re-asking would phrase it more narrowly rather than repeat themselves verbatim.
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
    // A real result (even an empty one - "nothing to suggest" is valid) ends the loop; only a
    // parse/throw failure, and only when a second, narrower attempt is still possible, retries.
    if (answer !== null || attempt === 1 || messagesThisAttempt.length < 2) break;
  }
  if (lastErr) console.error("generateItinerary failed", lastErr);
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
