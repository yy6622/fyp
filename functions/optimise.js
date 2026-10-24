const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { parseOptimiseAnswer, resolveOptimiseAnswer } = require("./optimise_prompt");
const { optimisePlan } = require("./optimise_engine");
const { computeLogisticsWindow, withinWindow } = require("./logistics");

if (getApps().length === 0) initializeApp();

// No AI model and no external service here: Voya's own scheduling algorithm (optimise_engine.js)
// reworks the plan with Voya's place knowledge base - visit lengths, best time of day, districts,
// meal times, full-day places, booked flights and hotel stays - and says why for every change.

const oneLine = (v) => String(v || "").replace(/[|\s]+/g, " ").trim();

/**
 * Belt-and-braces: a hotel check-in must be the earliest thing on its day. Only vetoes a change THIS run is making (drops that one update,
 * leaving the item at its original day/time) — an item this run didn't
 * touch is left alone even if it was already before check-in, since a
 * pre-existing conflict isn't this run's to fix.
 */
function enforceHotelCheckinFirst(updates, plan) {
  const updateByItemId = new Map(updates.map((u) => [u.itemId, u]));
  const finalOf = (item, originalDay) => {
    const u = updateByItemId.get(item.id);
    return u ? { day: u.toDay, time: u.newTime } : { day: Number(originalDay), time: item.time };
  };

  // Every item, tagged with its day/time *after* applying every update —
  // just enough to find each day's check-in and compare times against it.
  const finalByDay = {};
  for (const [day, items] of Object.entries(plan)) {
    for (const item of items) {
      const f = finalOf(item, day);
      (finalByDay[f.day] ||= []).push({ ...item, finalTime: f.time });
    }
  }

  const dropped = new Set();
  for (const items of Object.values(finalByDay)) {
    const checkin = items.find((it) => it.icon === "hotel" && /check.?in/i.test(it.label));
    if (!checkin) continue;
    for (const it of items) {
      if (it.id === checkin.id || it.finalTime >= checkin.finalTime) continue;
      const u = updateByItemId.get(it.id);
      if (u) dropped.add(u.itemId); // only something this run moved counts as "making it worse"
    }
  }
  return updates.filter((u) => !dropped.has(u.itemId));
}


/**
 * Reworks a trip's existing plan — one day, or the whole trip — into a
 * better-flowing schedule. Unlike generateItinerary this never reads the
 * chat and never adds/removes anything: it only reorders/re-times what's
 * already there. Nothing is written to the trip; the app shows the result
 * and the user chooses what to apply (same pattern as generateItinerary).
 *
 * request.data: { tripId: string, mode: 'day' | 'whole', dayIndex?: number, groupByArea?: boolean (default true) }
 *   dayIndex is the `trips/{tripId}.days` key (required when mode === 'day').
 * returns: {
 *   update: [{ itemId, label, location, icon, fromDay, fromDayIndex, toDay, toDayIndex, oldTime, newTime, reason }],
 *   itemCount: number,
 * }
 */
exports.optimiseItinerary = onCall({ timeoutSeconds: 60, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const tripId = request.data && request.data.tripId;
  if (typeof tripId !== "string" || !tripId) throw new HttpsError("invalid-argument", "tripId is required.");
  const mode = request.data && request.data.mode;
  if (mode !== "day" && mode !== "whole") throw new HttpsError("invalid-argument", "mode must be 'day' or 'whole'.");
  let onlyDayIndex = null;
  if (mode === "day") {
    const di = request.data && request.data.dayIndex;
    if (typeof di !== "number" || !Number.isInteger(di)) {
      throw new HttpsError("invalid-argument", "dayIndex is required for mode 'day'.");
    }
    onlyDayIndex = di;
  }

  // Loaded here, not at the top of the file: same reason as itinerary.js —
  // `firebase deploy` gives the whole codebase only 10 seconds to load.
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
  if (mode === "day" && !dayKeys.includes(String(onlyDayIndex))) {
    throw new HttpsError("invalid-argument", "That day does not exist on this trip.");
  }

  // Current plan, by 1-based day number — same shape/ordering as
  // itinerary.js builds, so optimise_prompt.js's resolver can reuse
  // itinerary_prompt.js's name-matching helpers unchanged.
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

  const onlyDay = mode === "day" ? dayKeys.indexOf(String(onlyDayIndex)) + 1 : null;
  const itemCount =
    mode === "day" ? (plan[onlyDay] || []).length : Object.values(plan).reduce((n, list) => n + list.length, 0);
  if (itemCount < 2) {
    throw new HttpsError(
      "failed-precondition",
      mode === "day"
        ? "This day doesn't have enough activities to optimise yet."
        : "This trip doesn't have enough activities to optimise yet.",
    );
  }

  const window = computeLogisticsWindow(trip, dayKeys.length);
  const days = dayKeys.map((k, i) => ({ day: i + 1, weekday: daysRaw[k].weekday || "", date: daysRaw[k].date || "" }));
  // the group's saved places: their visit length and kind help the optimiser (never fails the run)
  const { loadSavedPlaces, loadCatalogPlaces } = require("./itinerary");
  const [saved, catalog] = await Promise.all([
    loadSavedPlaces(db, tripId, trip.memberIds).catch(() => []),
    // the app's places for this city: their district / coordinates tell which activities are in one area
    loadCatalogPlaces(db, trip.destination).catch(() => []),
  ]);
  // the group's choice in the Optimise sheet: keep places of one area on one day (default yes)
  const groupByArea = !(request.data && request.data.groupByArea === false);
  const result = optimisePlan(plan, {
    mode, onlyDay, window, days, saved, catalog, groupByArea,
    destination: trip.destination || "",
    flights: Array.isArray(trip.flights) ? trip.flights : [],
    hotelStays: Array.isArray(trip.hotelStays) ? trip.hotelStays : [],
  });
  const answer = parseOptimiseAnswer(JSON.stringify({ update: result.update }), dayKeys.length);
  if (!answer) throw new HttpsError("internal", "Optimise could not finish right now. Please try again.");

  // Belt-and-braces: mode "day" must never touch another day.
  if (mode === "day") {
    answer.update = answer.update.filter((u) => u.from_day === onlyDay && u.day === onlyDay);
  }

  const resolved = resolveOptimiseAnswer(answer, plan);

  // More belt-and-braces: check-in first, and nothing outside the flight window (booked in
  // Explore or typed in) - whatever the optimiser returned.
  resolved.update = enforceHotelCheckinFirst(resolved.update, plan);
  const win = result.window || window;
  resolved.update = resolved.update.filter((u) => withinWindow(win, u.toDay, u.newTime));

  const dayIndexOf = (day) => Number(dayKeys[day - 1]);
  return {
    update: resolved.update.map((u) => ({ ...u, fromDayIndex: dayIndexOf(u.fromDay), toDayIndex: dayIndexOf(u.toDay) })),
    itemCount,
    // what could not be fixed in this run ("Day 2 is very full: ... try Optimise Whole Trip")
    notes: result.notes || [],
    engine: "voya-optimiser",
  };
});
