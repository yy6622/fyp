const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { parseOptimiseAnswer, resolveOptimiseAnswer } = require("./optimise_prompt");
const { optimisePlan } = require("./optimise_engine");
const { computeLogisticsWindow, withinWindow } = require("./logistics");

if (getApps().length === 0) initializeApp();


const oneLine = (v) => String(v || "").replace(/[|\s]+/g, " ").trim();

function enforceHotelCheckinFirst(updates, plan) {
  const updateByItemId = new Map(updates.map((u) => [u.itemId, u]));
  const finalOf = (item, originalDay) => {
    const u = updateByItemId.get(item.id);
    return u ? { day: u.toDay, time: u.newTime } : { day: Number(originalDay), time: item.time };
  };

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
      if (u) dropped.add(u.itemId);
    }
  }
  return updates.filter((u) => !dropped.has(u.itemId));
}


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
  if (mode === "day" && !dayKeys.includes(String(onlyDayIndex))) {
    throw new HttpsError("invalid-argument", "That day does not exist on this trip.");
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
  const { loadSavedPlaces, loadCatalogPlaces } = require("./itinerary");
  const [saved, catalog] = await Promise.all([
    loadSavedPlaces(db, tripId, trip.memberIds).catch(() => []),
    loadCatalogPlaces(db, trip.destination).catch(() => []),
  ]);
  const groupByArea = !(request.data && request.data.groupByArea === false);
  const result = optimisePlan(plan, {
    mode, onlyDay, window, days, saved, catalog, groupByArea,
    destination: trip.destination || "",
    flights: Array.isArray(trip.flights) ? trip.flights : [],
    hotelStays: Array.isArray(trip.hotelStays) ? trip.hotelStays : [],
  });
  const answer = parseOptimiseAnswer(JSON.stringify({ update: result.update }), dayKeys.length);
  if (!answer) throw new HttpsError("internal", "Optimise could not finish right now. Please try again.");

  if (mode === "day") {
    answer.update = answer.update.filter((u) => u.from_day === onlyDay && u.day === onlyDay);
  }

  const resolved = resolveOptimiseAnswer(answer, plan);

  resolved.update = enforceHotelCheckinFirst(resolved.update, plan);
  const win = result.window || window;
  resolved.update = resolved.update.filter((u) => withinWindow(win, u.toDay, u.newTime));

  const dayIndexOf = (day) => Number(dayKeys[day - 1]);
  return {
    update: resolved.update.map((u) => ({ ...u, fromDayIndex: dayIndexOf(u.fromDay), toDayIndex: dayIndexOf(u.toDay) })),
    itemCount,
    notes: result.notes || [],
    engine: "voya-optimiser",
  };
});
