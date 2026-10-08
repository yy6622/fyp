const fs = require("fs");
const path = require("path");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");
const { buildItineraryPrompt, parseItineraryAnswer, resolveItineraryAnswer } = require("./itinerary_prompt");

if (getApps().length === 0) initializeApp();

// Free-tier Gemini Developer API key (ai.google.dev / Google AI Studio) —
// NOT Vertex AI, a different product with no billing account attached at
// all. Set once with: firebase functions:secrets:set GEMINI_API_KEY
// (same key value as lib/config/secrets.dart's geminiApiKey — see that
// file's comment for where to get one free).
//
// This replaces the old Vertex AI call, which used a custom fine-tuned
// model (see ml/itinerary_model/). Vertex AI requires a billing account,
// and this project's billing account hit a "dunning" (payment-failed)
// hold that blocked it outright — moving here trades that away entirely.
// The real cost: a fine-tuned model can't be deployed on the free
// Developer API (tuning/serving a tuned model is Vertex-only and paid),
// so this now always calls the untuned base model below. Per
// ml/itinerary_model/'s own eval, the tuned model scored noticeably
// higher (decision_f1 ~95% tuned vs ~83-87% untuned) — the base model is
// still useful, just less precise about which chat messages represent a
// real decision vs. idle chatter.
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const BASE_MODEL = "gemini-3.5-flash";
const MAX_MESSAGES = 300;
const MAX_SAVED = 60;

// Same text the model was tuned with - a copy of ml/itinerary_model/system_prompt.txt.
const SYSTEM_PROMPT = fs.readFileSync(path.join(__dirname, "itinerary_system_prompt.txt"), "utf8").trim();

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
          .then((snap) => snap.docs.map((d) => ({ name: oneLine(d.get("name")), location: oneLine(d.get("location")), type }))),
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

/**
 * The free Gemini Developer API returns 503 ("model is overloaded, please
 * try again later") noticeably more often than the paid Vertex AI path did
 * — the free tier gets lower priority under load. That's normally gone a
 * few seconds later, so retrying a couple of times here (short, increasing
 * delays) turns a transient blip into a slightly-slower success instead of
 * a failed request the person has to notice and retry by hand. A
 * non-overload error (bad key, bad request, safety block, ...) isn't
 * transient, so it's thrown immediately instead of wasting the retries.
 */
async function callGeminiWithRetry(ai, prompt, attempts = 3) {
  for (let i = 0; i < attempts; i++) {
    try {
      const response = await ai.models.generateContent({
        model: BASE_MODEL,
        contents: prompt,
        config: {
          systemInstruction: SYSTEM_PROMPT,
          temperature: 0,
          responseMimeType: "application/json",
          maxOutputTokens: 8192,
        },
      });
      return response.text;
    } catch (err) {
      const message = String((err && err.message) || "");
      const overloaded = err && (err.status === 503 || /\b503\b|overloaded|UNAVAILABLE/i.test(message));
      if (!overloaded || i === attempts - 1) throw err;
      console.warn(`generateItinerary model overloaded, retrying (${i + 1}/${attempts})`, message);
      await new Promise((resolve) => setTimeout(resolve, 1500 * (i + 1)));
    }
  }
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
exports.generateItinerary = onCall({ timeoutSeconds: 120, memory: "512MiB", secrets: [geminiApiKey] }, async (request) => {
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

  const [msgSnap, saved] = await Promise.all([
    tripRef.collection("messages").orderBy("createdAt", "desc").limit(MAX_MESSAGES).get(),
    // A saved-list failure must not block the whole feature: carry on without it.
    loadSavedPlaces(db, tripId, trip.memberIds).catch((err) => {
      console.error("generateItinerary could not read saved places", err);
      return [];
    }),
  ]);
  const messages = msgSnap.docs
    .map((d) => d.data())
    .reverse()
    .filter((m) => typeof m.text === "string" && m.text.trim())
    .map((m) => ({ sender: (m.senderName || "Member").trim() || "Member", text: m.text }));
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

  // The real booked flight/hotel for this trip, if any — same Firestore
  // doc already fetched above (trip.flights / trip.hotelStays, written by
  // TripRepository.addFlight/addHotelStay), just not read until now. When
  // there's more than one, the first booked is used as the reference —
  // good enough for "when do we land / when can we check in", which is
  // the only thing this is for (see buildItineraryPrompt's LOGISTICS
  // section); it isn't trying to model a full multi-leg itinerary.
  const firstFlight = Array.isArray(trip.flights) && trip.flights.length ? trip.flights[0] : null;
  const firstHotel = Array.isArray(trip.hotelStays) && trip.hotelStays.length ? trip.hotelStays[0] : null;

  const prompt = buildItineraryPrompt(
    {
      destination: trip.destination || "",
      days: dayKeys.map((k, i) => ({ day: i + 1, weekday: daysRaw[k].weekday || "", date: daysRaw[k].date || "" })),
      members: Object.values(trip.memberNames || {}).map(String),
      saved,
      plan,
      flightArrival: firstFlight ? oneLine(firstFlight.arrivalTime || firstFlight.dateTime) : "",
      hotelCheckIn: firstHotel ? oneLine(firstHotel.checkIn) : "",
      hotelCheckOut: firstHotel ? oneLine(firstHotel.checkOut) : "",
    },
    messages,
  );

  let text;
  try {
    const { GoogleGenAI } = require("@google/genai");
    // Plain API-key auth against the free Gemini Developer API — no
    // `vertexai: true`, no project/location, nothing billed. See the
    // geminiApiKey comment above for why this is no longer Vertex AI.
    const ai = new GoogleGenAI({ apiKey: geminiApiKey.value() });
    text = await callGeminiWithRetry(ai, prompt);
  } catch (err) {
    // The raw SDK/HTTP error (status codes, JSON error bodies, stack
    // traces) is exactly what a programmer debugging this would want, and
    // exactly what a trip member tapping "AI Summarise" should never see.
    // It goes to the server log ONLY (`firebase functions:log`, or Cloud
    // Logging) — the HttpsError thrown below carries just a short, plain
    // sentence, which is all that reaches the app (see
    // ItineraryAiService._generate on the Flutter side).
    console.error("generateItinerary model call failed", err);
    const message = String((err && err.message) || "");
    const overloaded = err && (err.status === 503 || /\b503\b|overloaded|UNAVAILABLE/i.test(message));
    throw new HttpsError(
      "unavailable",
      overloaded
        ? "AI Summarise is getting a lot of requests right now. Please wait a moment and try again."
        : "AI Summarise could not finish right now. Please try again.",
    );
  }

  const answer = parseItineraryAnswer(text, dayKeys.length);
  if (!answer) {
    console.error("generateItinerary unparseable answer", text);
    throw new HttpsError("internal", "The itinerary model returned something unreadable. Try again.");
  }

  const resolved = resolveItineraryAnswer(answer, saved, plan);
  const dayIndex = (day) => Number(dayKeys[day - 1]);
  return {
    add: resolved.add.map((a) => ({ ...a, dayIndex: dayIndex(a.day) })),
    update: resolved.update.map((u) => ({ ...u, fromDayIndex: dayIndex(u.fromDay), toDayIndex: dayIndex(u.toDay) })),
    remove: resolved.remove.map((r) => ({ ...r, dayIndex: dayIndex(r.day) })),
    unresolved: resolved.unresolved,
    messageCount: messages.length,
    savedCount: saved.length,
  };
});
