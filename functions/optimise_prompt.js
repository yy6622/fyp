// Pure helpers for optimiseItinerary (see optimise.js) - no Firebase imports,
// so they can be unit-tested with plain `node`, same convention as
// itinerary_prompt.js.
//
// Optimise only reorders / re-times what is already in the plan, so its answer
// only has an "update" array, never add / remove. These helpers check the
// optimiser's answer and match it back to the real plan items.

const { findOne, firstJsonObject } = require("./itinerary_prompt");

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

const cleanText = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const validDay = (d, dayCount) => Number.isInteger(d) && d >= 1 && d <= dayCount;

/**
 * Keep only well-formed entries on days that exist. Returns { update }, or
 * null if the text isn't the expected JSON at all.
 */
function parseOptimiseAnswer(text, dayCount) {
  const raw = firstJsonObject(String(text || ""));
  if (raw === null) return null;
  let obj;
  try {
    obj = JSON.parse(raw);
  } catch (_) {
    return null;
  }
  if (!obj || !Array.isArray(obj.update)) return null;

  const update = [];
  for (const it of obj.update) {
    if (!it || typeof it !== "object") continue;
    const label = cleanText(it.label, 80);
    const time = cleanText(it.time, 5);
    if (!label || !TIME_RE.test(time) || !validDay(it.from_day, dayCount) || !validDay(it.day, dayCount)) continue;
    update.push({ label, from_day: it.from_day, day: it.day, time, reason: cleanText(it.reason, 120) });
  }
  return { update };
}

/**
 * Turns the optimiser's answer into things the app can apply, matching every
 * entry against the real plan by name — same find-by-name approach
 * resolveItineraryAnswer uses.
 *
 * plan: {day: [{id, time, label, location, icon}]}
 */
function resolveOptimiseAnswer(answer, plan) {
  const dayItems = (day) => (plan && plan[day]) || [];
  const allItems = Object.keys(plan || {}).flatMap((d) => dayItems(d).map((it) => ({ ...it, day: Number(d) })));
  const locate = (label, day) => {
    const onDay = findOne(dayItems(day), label, (it) => it.label);
    if (onDay) return { ...onDay, day };
    return findOne(allItems, label, (it) => it.label); // named on another day
  };

  const touched = new Set(); // plan item ids already used by an update in this answer
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
      reason: u.reason || "",
    });
  }
  return { update };
}

module.exports = { parseOptimiseAnswer, resolveOptimiseAnswer };
