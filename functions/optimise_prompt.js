
const { findOne, firstJsonObject } = require("./itinerary_prompt");

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

const cleanText = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const validDay = (d, dayCount) => Number.isInteger(d) && d >= 1 && d <= dayCount;

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

function resolveOptimiseAnswer(answer, plan) {
  const dayItems = (day) => (plan && plan[day]) || [];
  const allItems = Object.keys(plan || {}).flatMap((d) => dayItems(d).map((it) => ({ ...it, day: Number(d) })));
  const locate = (label, day) => {
    const onDay = findOne(dayItems(day), label, (it) => it.label);
    if (onDay) return { ...onDay, day };
    return findOne(allItems, label, (it) => it.label); // named on another day
  };

  const touched = new Set();
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
