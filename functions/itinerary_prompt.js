// Pure helpers for generateItinerary (see itinerary.js) - no Firebase imports,
// so they can be unit-tested with plain `node`.
//
// buildItineraryPrompt MUST produce exactly what
// ml/itinerary_model/prompt_format.py build_user_prompt() produces: the
// tuned model was trained on that format. ml/itinerary_model/test_prompt_parity.py
// checks the two stay identical.
//
// Format v2: the model also sees the group's saved places and the current
// plan, and answers with changes (add / update / remove).

const ICONS = ["flight", "hotel", "shopping", "food", "place", "activity"];
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

/**
 * trip: { destination,
 *         days:    [{day, weekday, date}],
 *         members: [name],
 *         saved:   [{name, location, type}],          type: attraction | restaurant
 *         plan:    {day: [{time, label, location, icon}]},
 *         flightArrival: string,                      real booked flight's arrival date+time, '' if none
 *         hotelCheckIn: string,                        real booked hotel's check-in date+time, '' if none
 *         hotelCheckOut: string }                      real booked hotel's check-out date+time, '' if none
 * messages: [{ sender, text }] oldest first
 */
function buildItineraryPrompt(trip, messages) {
  const lines = ["TRIP", `destination: ${trip.destination}`, `days: ${trip.days.length}`];
  for (const d of trip.days) lines.push(`day ${d.day}: ${d.weekday} ${d.date}`);
  lines.push("members: " + trip.members.join(", "));

  // The real booked flight/hotel times (see TripFlight.arrivalTime,
  // TripHotelStay.checkIn/checkOut) — so the model can avoid scheduling
  // day-1 activities before the flight actually lands or before check-in,
  // and last-day activities after check-out, instead of only guessing
  // from the generic "day 1 / last day" rule it already has.
  lines.push("", "LOGISTICS");
  const logistics = [];
  if (trip.flightArrival) logistics.push(`flight arrival: ${trip.flightArrival}`);
  if (trip.hotelCheckIn) logistics.push(`hotel check-in: ${trip.hotelCheckIn}`);
  if (trip.hotelCheckOut) logistics.push(`hotel check-out: ${trip.hotelCheckOut}`);
  if (logistics.length) lines.push(...logistics);
  else lines.push("(none booked yet)");

  lines.push("", "SAVED PLACES");
  if (trip.saved && trip.saved.length) {
    for (const s of trip.saved) lines.push(`- ${s.name} | ${s.location} | ${s.type}`);
  } else {
    lines.push("(none)");
  }

  lines.push("", "CURRENT PLAN");
  for (const d of trip.days) {
    const items = (trip.plan && trip.plan[d.day]) || [];
    if (!items.length) {
      lines.push(`day ${d.day}: (nothing yet)`);
      continue;
    }
    lines.push(`day ${d.day}:`);
    for (const it of items) lines.push(`- ${it.time} | ${it.label} | ${it.location} | ${it.icon}`);
  }

  lines.push("", "DISCUSSION");
  for (const m of messages) {
    const text = String(m.text).split(/\s+/).filter(Boolean).join(" ");
    lines.push(`${m.sender}: ${text}`);
  }
  return lines.join("\n");
}

/** The first balanced {...} in the text (string-aware), or null. */
function firstJsonObject(text) {
  const start = text.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === '"') inString = false;
    } else if (ch === '"') inString = true;
    else if (ch === "{") depth++;
    else if (ch === "}" && --depth === 0) return text.slice(start, i + 1);
  }
  return null;
}

const cleanText = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const validDay = (d, dayCount) => Number.isInteger(d) && d >= 1 && d <= dayCount;

/**
 * Never trust model output: keep only well-formed entries on days that exist.
 * Returns { add, update, remove, unresolved } in the model's own field names,
 * or null if the text isn't the expected JSON at all.
 */
function parseItineraryAnswer(text, dayCount) {
  // Use the first complete JSON object only: the tuned model occasionally
  // repeats its answer, or wraps it in a code fence.
  const raw = firstJsonObject(String(text || ""));
  if (raw === null) return null;
  let obj;
  try {
    obj = JSON.parse(raw);
  } catch (_) {
    return null;
  }
  if (!obj || !Array.isArray(obj.add)) return null;
  const list = (v) => (Array.isArray(v) ? v.filter((x) => x && typeof x === "object") : []);

  const add = [];
  for (const it of list(obj.add)) {
    const label = cleanText(it.label, 80);
    const time = cleanText(it.time, 5);
    if (!label || !TIME_RE.test(time) || !validDay(it.day, dayCount)) continue;
    add.push({
      day: it.day,
      time,
      label,
      location: cleanText(it.location, 120),
      icon: ICONS.includes(it.icon) ? it.icon : "activity",
      saved: it.saved === true,
    });
  }
  add.sort((a, b) => a.day - b.day || a.time.localeCompare(b.time) || a.label.localeCompare(b.label));

  const update = [];
  for (const it of list(obj.update)) {
    const label = cleanText(it.label, 80);
    const time = cleanText(it.time, 5);
    if (!label || !TIME_RE.test(time) || !validDay(it.from_day, dayCount) || !validDay(it.day, dayCount)) continue;
    update.push({ label, from_day: it.from_day, day: it.day, time });
  }

  const remove = [];
  for (const it of list(obj.remove)) {
    const label = cleanText(it.label, 80);
    if (!label || !validDay(it.day, dayCount)) continue;
    remove.push({ day: it.day, label });
  }

  const unresolved = Array.isArray(obj.unresolved)
    ? obj.unresolved.filter((u) => typeof u === "string" && u.trim()).map((u) => u.trim().slice(0, 80))
    : [];
  return { add, update, remove, unresolved };
}

const norm = (s) => String(s || "").toLowerCase().replace(/[^a-z0-9一-鿿]+/g, " ").trim();

/** Same place, allowing a shorter/longer form of the name ("Tim Ho Wan" / "Tim Ho Wan (Sham Shui Po)"). */
function samePlace(a, b) {
  const na = norm(a);
  const nb = norm(b);
  if (!na || !nb) return false;
  if (na === nb) return true;
  const ta = new Set(na.split(" "));
  const tb = new Set(nb.split(" "));
  const [small, big] = ta.size <= tb.size ? [ta, tb] : [tb, ta];
  return [...small].every((t) => big.has(t));
}

/** Exact (normalised) name first, then the looser match - but only if exactly one candidate fits. */
function findOne(candidates, label, nameOf) {
  const exact = candidates.filter((c) => norm(nameOf(c)) === norm(label));
  if (exact.length >= 1) return exact[0];
  const loose = candidates.filter((c) => samePlace(nameOf(c), label));
  return loose.length === 1 ? loose[0] : null;
}

/**
 * Turns the model's answer into things the app can apply, checking every
 * claim against the real data instead of trusting the model:
 *  - "saved" is decided by actually finding the place in the saved list
 *    (and then the saved name/location are used verbatim)
 *  - update / remove must point at an item that really is in the plan,
 *    otherwise they are dropped - a wrong one would damage the user's plan
 *
 * saved: [{name, location, type}]
 * plan:  {day: [{id, time, label, location, icon}]}
 */
function resolveItineraryAnswer(answer, saved, plan) {
  const dayItems = (day) => (plan && plan[day]) || [];
  const allItems = Object.keys(plan || {}).flatMap((d) => dayItems(d).map((it) => ({ ...it, day: Number(d) })));
  const locate = (label, day) => {
    const onDay = findOne(dayItems(day), label, (it) => it.label);
    if (onDay) return { ...onDay, day };
    return findOne(allItems, label, (it) => it.label); // the model named the wrong day
  };

  const touched = new Set(); // plan item ids already used by an update/remove
  const update = [];
  for (const u of answer.update) {
    const item = locate(u.label, u.from_day);
    if (!item || touched.has(item.id)) continue;
    if (item.day === u.day && item.time === u.time) continue; // nothing would change
    touched.add(item.id);
    update.push({
      itemId: item.id,
      label: item.label,
      location: item.location,
      icon: item.icon,
      fromDay: item.day,
      toDay: u.day,
      oldTime: item.time,
      newTime: u.time,
    });
  }

  const remove = [];
  for (const r of answer.remove) {
    const item = locate(r.label, r.day);
    if (!item || touched.has(item.id)) continue;
    touched.add(item.id);
    remove.push({ itemId: item.id, label: item.label, day: item.day, time: item.time });
  }

  const add = [];
  for (const a of answer.add) {
    const match = findOne(saved || [], a.label, (s) => s.name);
    const label = match ? match.name : a.label;
    const logistics = a.icon === "hotel" || a.icon === "flight";
    add.push({
      day: a.day,
      time: a.time,
      label,
      location: match && match.location ? match.location : a.location,
      icon: match && match.type === "restaurant" ? "food" : a.icon,
      inSavedList: Boolean(match),
      // hotel check-in / airport runs are never "saved places", so no warning for them
      warnNotSaved: !match && !logistics,
      alreadyInPlan: dayItems(a.day).some((it) => samePlace(it.label, label)),
    });
  }

  return { add, update, remove, unresolved: answer.unresolved };
}

module.exports = { buildItineraryPrompt, parseItineraryAnswer, resolveItineraryAnswer, samePlace, ICONS };
