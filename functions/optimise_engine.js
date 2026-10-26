// Voya's own schedule optimiser. No AI model and no external service: fixed rules plus Voya's
// place knowledge base (planner/gazetteer.json and the group's saved places). Pure functions,
// testable with node (ml/discussion_summary/test_optimise.js).
//
// Input : plan {day: [{id, time, label, location, icon}]}, mode "day" | "whole", onlyDay,
//         logistics window from logistics.js, and optionally the trip's destination, saved places,
//         flights, hotel stays and days (for typed-in flights and hotel check-in / check-out).
// Output: { update: [{label, from_day, day, time, reason}], window, notes: [string] }
//
// Algorithm
//  1. Profile every activity. Flights and timed hotel check-ins / check-outs are FIXED.
//     A place Voya knows (gazetteer or saved list) brings its visit length, its district and when it
//     is best (morning / afternoon / evening only, full day); otherwise words in the label decide
//     (breakfast / lunch / dinner / supper, sunrise / sunset / night market ...).
//  2. Booked flights and hotel stays (planner/logistics_plan.js) give each day its start and end
//     (landing + 90 min, 3 h before the flight home) and busy slots (check-in 15:00, check-out 11:00).
//  3. mode "whole" only, in this order:
//     a. a full-day place (theme park) gets the day to itself; the other sights go to other days;
//     b. a day that is too short for its activities (arrival / departure day) hands the extra ones
//        to the day with the most free time, and a museum / garden that would only get an evening
//        slot moves to a day where it fits in daylight;
//     c. same district: an activity moves to the day that already has places in its district;
//     d. balancing: while the busiest day has 2+ more sights than the lightest, a whole same-district
//        group moves to the lightest day (a group is only split when its day has more than 3 sights).
//  4. Every touched day is re-timed: fixed items and busy slots stay; meals at meal times, evening
//     places in the evening; others in order of their best time, places in the same district next to
//     each other; each activity lasts its visit length, 15 min to walk to a place in the same
//     district, 30 min to another district; nothing overlaps; nothing before the day starts or after
//     it ends.
//  5. Only items whose day or time changed are returned, each with the reason; what still does not
//     fit (a full day in mode "day") comes back as a note.

const SLOT = { breakfast: 8 * 60, morning: 9 * 60 + 30, lunch: 12 * 60 + 30, afternoon: 14 * 60 + 30, snack: 15 * 60 + 30,
  sunset: 17 * 60 + 30, dinner: 19 * 60, night: 20 * 60 + 30, sunrise: 5 * 60 + 45 };
const DURATION = { food: 60, place: 90, activity: 120, shopping: 90, hotel: 45, flight: 60 };
const DAY_START = 9 * 60;
const DAY_END = 23 * 60;
const SAME_AREA_GAP = 15;
const OTHER_AREA_GAP = 30;
const MAX_SIGHTS = 3;           // a day with more sights than this is split even if they share a district

const { estimateTravelMinutes } = require("./maps_service");

const has = (text, words) => words.some((w) => text.includes(w));
const lower = (s) => String(s || "").toLowerCase();

function toMin(hhmm) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm || "").trim());
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}
function toHHMM(min) {
  const m = Math.max(0, Math.min(23 * 60 + 45, Math.round(min / 15) * 15));
  return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
}
const round15 = (n) => Math.ceil(n / 15) * 15;

/** kind, preferred minute of the day, and whether the item may move at all - from the icon and label words. */
function classify(item) {
  const t = lower(item.label);
  const icon = item.icon || "activity";
  const cur = toMin(item.time);
  if (icon === "flight") return { kind: "flight", pref: cur ?? SLOT.morning, fixed: true };
  if (icon === "hotel") {
    const checkin = /check.?in|入住|daftar masuk/.test(t);
    const checkout = /check.?out|退房|daftar keluar/.test(t);
    return { kind: "hotel", pref: cur ?? (checkout ? 11 * 60 : 15 * 60), fixed: cur !== null && (checkin || checkout), checkin };
  }
  if (has(t, ["sunrise", "日出", "matahari terbit"])) return { kind: icon, pref: SLOT.sunrise, why: "sunrise" };
  if (has(t, ["sunset", "日落", "matahari terbenam"])) return { kind: icon, pref: SLOT.sunset, why: "sunset" };
  if (icon === "food") {
    if (has(t, ["breakfast", "早餐", "早点", "sarapan", "brunch", "dim sum", "点心", "kopitiam", "roti canai"])) return { kind: "food", pref: SLOT.breakfast, meal: true };
    if (has(t, ["lunch", "午餐", "午饭", "makan tengah hari"])) return { kind: "food", pref: SLOT.lunch, meal: true };
    if (has(t, ["supper", "宵夜", "night market", "夜市", "pasar malam"])) return { kind: "food", pref: SLOT.night, meal: true };
    if (has(t, ["dinner", "晚餐", "晚饭", "makan malam", "bbq", "steamboat", "火锅", "hotpot"])) return { kind: "food", pref: SLOT.dinner, meal: true };
    if (has(t, ["cafe", "café", "coffee", "咖啡", "dessert", "甜品", "bakery", "tea house", "茶"])) return { kind: "food", pref: SLOT.snack, meal: true };
    // otherwise the meal closest to when the group put it
    const c = cur ?? SLOT.lunch;
    const pref = c < 10 * 60 + 30 ? SLOT.breakfast : c < 16 * 60 ? SLOT.lunch : c < 21 * 60 + 30 ? SLOT.dinner : SLOT.night;
    return { kind: "food", pref, meal: true };
  }
  if (has(t, ["night market", "夜市", "pasar malam", "night view", "夜景", "bar", "pub", "club", "show", "表演", "light show"])) {
    return { kind: icon, pref: SLOT.night, why: "evening" };
  }
  if (icon === "shopping") return { kind: "shopping", pref: cur !== null && cur >= 17 * 60 ? SLOT.night - 60 : SLOT.afternoon };
  // places / activities: keep morning vs afternoon as the group had it
  return { kind: icon, pref: cur !== null && cur >= 13 * 60 ? SLOT.afternoon : SLOT.morning };
}

const locKey = (it) => lower(it.location).replace(/[^a-z0-9一-鿿]+/g, " ").trim();
const MEAL_WORD = /breakfast|brunch|lunch|dinner|supper|早餐|早点|午餐|午饭|晚餐|晚饭|宵夜|sarapan|makan/;

/** classify() plus what Voya knows about the place: visit length, district, best time of day. */
function profile(item, known) {
  const c = classify(item);
  // the area it is in: the item's own location if that names an area (not a street address, not the city)
  const { districtOf } = require("./planner/places");
  const p = { ...c, dur: DURATION[c.kind] || 90, group: lower(districtOf({ location: item.location })), place: null };
  if (!c.fixed && item.icon !== "hotel" && item.icon !== "flight" && known && known.places.length) {
    const { aliasHits } = require("./planner/places");
    const hits = aliasHits(item.label, known.places).sort((a, b) => (b.end - b.start) - (a.end - a.start));
    const place = hits.length ? hits[0].place : null;
    if (place) {
      p.place = place;
      p.group = lower(place.district || "") || p.group;
      const slots = place.slots || "";
      const hours = Number(place.hours) || 0;
      const t = lower(item.label);
      if (item.icon === "food" || place.icon === "food") {
        p.dur = Math.round(Math.min(Math.max((hours || 1) * 60, 45), 90));
        if (!MEAL_WORD.test(t)) {
          if (/A/.test(slots) && !/[LD]/.test(slots)) p.pref = SLOT.snack;
          else if (/B/.test(slots) && !/[LD]/.test(slots)) p.pref = SLOT.breakfast;
          else if (/D/.test(slots) && !/[BL]/.test(slots)) p.pref = SLOT.dinner;
        }
        p.meal = true;
      } else {
        if (hours) p.dur = Math.round(Math.min(Math.max(hours, 0.75), 10) * 60);
        if (hours >= 6) {
          p.fullDay = true;
          p.pref = SLOT.morning;
          p.why = "fullDay";
        } else if (/[EN]/.test(slots) && !/[MA]/.test(slots)) {
          p.pref = /sunset|日落/.test(t) ? SLOT.sunset : SLOT.night;
          p.dur = Math.min(p.dur, 90);
          p.why = "evening";
        } else if (/M/.test(slots) && !/[AEN]/.test(slots)) {
          p.pref = SLOT.morning;
          p.why = "morning";
        } else if (/A/.test(slots) && !/[MEN]/.test(slots)) {
          p.pref = SLOT.afternoon;
        }
      }
    }
  }
  p.timeBound = Boolean(p.meal) || [SLOT.sunrise, SLOT.sunset, SLOT.night].includes(p.pref);
  // a museum / garden / temple closes in the evening: it should start by 17:00
  p.daytimeOnly = !p.meal && !p.fixed && !p.timeBound && !p.fullDay && (p.place
    ? !/[EN]/.test(p.place.slots || "")
    : /museum|temple|garden|zoo|aquarium|palace|博物馆|美术馆|寺|庙|园|宫|muzium|kuil|taman/.test(lower(item.label)));
  return p;
}

// ---------------------------------------------------------------------
// Utility formula (FYP documentation's Optimised Itinerary Generation
// Algorithm): utility = recommendationScore - travelTimePenalty -
// waitingTimePenalty - costPenalty. Every term is normalised to
// roughly [0, 1] so the subtraction means something regardless of the
// raw rating/minutes/price scale it came from.
//
// recommendationScore and costPenalty are a property of the PLACE
// itself, not of the order it's visited in — so between two orderings
// of the very same set of places, both terms add up to the same total
// either way and cancel out of the comparison. Only travelTimePenalty
// and waitingTimePenalty, which genuinely depend on sequence, actually
// decide which ordering the two-opt pass below prefers. That's the
// correct, intended behaviour of a utility-based objective (constant
// terms don't change an argmax), not a shortcut around the formula —
// and the moment a factor varies by position (a time-of-day price
// change, say), the formula is already there to react to it.
// ---------------------------------------------------------------------
function recommendationScoreOf(inf) {
  const r = inf.place && inf.place.rating != null ? parseFloat(inf.place.rating) : NaN;
  if (!Number.isFinite(r)) return 0.5; // unrated / unknown place - neutral, not punished
  return Math.max(0, Math.min(1, r / 5));
}
function costPenaltyOf(inf) {
  const price = inf.place && inf.place.price != null ? String(inf.place.price) : "";
  if (!price || /free/i.test(price)) return 0;
  const n = parseFloat(price.replace(/[^0-9.]/g, ""));
  if (!Number.isFinite(n)) return 0.2; // priced but unparseable - a small default, not free
  return Math.max(0, Math.min(1, n / 200));
}
function travelTimePenaltyOf(minutes) {
  if (minutes == null) return 0.3; // transition this run couldn't estimate at all
  return Math.max(0, Math.min(1, minutes / 60));
}
function waitingTimePenaltyOf(minutes) {
  return Math.max(0, Math.min(1, Math.max(0, minutes) / 120));
}

/** The {lat, lng, district} point for a block (see toBlocks below) — the first member that
 * actually has coordinates, falling back to the block's own group name as a district. */
function pointOf(block, info) {
  for (const it of block) {
    const inf = info.get(it.id);
    if (inf.place && Number.isFinite(inf.place.lat) && Number.isFinite(inf.place.lng)) {
      return { lat: inf.place.lat, lng: inf.place.lng, district: inf.group || "" };
    }
  }
  return { district: info.get(block[0].id).group || "" };
}

/** Splits `ordered` into blocks: a maximal run of consecutive items sharing one non-empty,
 * non-time-bound, non-full-day group (the grouping loop above already keeps a group's items
 * consecutive), or a lone item otherwise (fixed-feeling anchors: meals, sunrise/sunset, a
 * full-day place, or anything ungrouped). */
function toBlocks(ordered, info) {
  const blocks = [];
  for (const it of ordered) {
    const inf = info.get(it.id);
    const last = blocks[blocks.length - 1];
    const movable = !inf.timeBound && !inf.fullDay;
    const lastMovable = last && !info.get(last[0].id).timeBound && !info.get(last[0].id).fullDay;
    if (last && lastMovable && movable && inf.group && info.get(last[0].id).group === inf.group) last.push(it);
    else blocks.push([it]);
  }
  return blocks;
}

const isAnchorBlock = (block, info) => {
  const inf = info.get(block[0].id);
  return inf.timeBound || inf.fullDay;
};

/**
 * Two-opt local-improvement pass: reorders the movable blocks between
 * each pair of anchors (a meal/sunrise/sunset slot, or a full-day
 * place — none of which this ever moves) to maximise the utility
 * formula above. In practice this means minimising total estimated
 * travel time between consecutive blocks (see that formula's own doc
 * comment for why recommendationScore/costPenalty don't change the
 * winner). Runs each maximal anchor-to-anchor run of movable blocks
 * independently, bounded (200 passes) so a busy day can never make
 * this expensive.
 */
function twoOptReorder(ordered, info) {
  const blocks = toBlocks(ordered, info);
  if (blocks.length < 3) return ordered;

  const runs = [];
  let current = [];
  for (const b of blocks) {
    if (isAnchorBlock(b, info)) {
      if (current.length) runs.push(current);
      current = [];
    } else {
      current.push(b);
    }
  }
  if (current.length) runs.push(current);

  const totalUtility = (seq) => {
    let sum = 0;
    for (let i = 0; i < seq.length; i++) {
      const inf0 = info.get(seq[i][0].id);
      sum += recommendationScoreOf(inf0) - costPenaltyOf(inf0);
      if (i > 0) {
        const minutes = estimateTravelMinutes(pointOf(seq[i - 1], info), pointOf(seq[i], info));
        sum -= travelTimePenaltyOf(minutes);
      }
    }
    return sum;
  };

  const optimisedRuns = runs.map((run) => {
    if (run.length < 3) return run;
    let order = run.slice();
    let best = totalUtility(order);
    let changed = true;
    let guard = 0;
    while (changed && guard < 200) {
      changed = false;
      guard++;
      for (let i = 0; i < order.length - 1; i++) {
        for (let j = i + 1; j < order.length; j++) {
          const next = order.slice(0, i).concat(order.slice(i, j + 1).reverse(), order.slice(j + 1));
          const u = totalUtility(next);
          if (u > best + 1e-9) {
            order = next;
            best = u;
            changed = true;
          }
        }
      }
    }
    return order;
  });

  // Re-stitch: walk `blocks` again, pulling each run's (possibly
  // reordered) blocks back out left to right; anchors are untouched.
  const flatOptimised = optimisedRuns.flat();
  let ri = 0;
  const final = [];
  for (const b of blocks) {
    if (isAnchorBlock(b, info)) final.push(b);
    else { final.push(flatOptimised[ri]); ri++; }
  }
  return final.flat();
}

/**
 * Lay out one day's items. Returns Map(id -> minute).
 * prof: Map(id -> profile)   busy: extra [start, end] minutes that must stay free (booked check-in ...)
 */
function scheduleDay(items, { start = DAY_START, end = DAY_END, prof = null, busy: extraBusy = [] } = {}) {
  const info = prof || new Map(items.map((it) => [it.id, profile(it, null)]));
  const fixed = items.filter((it) => info.get(it.id).fixed);
  const flex = items.filter((it) => !info.get(it.id).fixed);
  // a timed hotel check-in starts the day
  for (const it of fixed) if (info.get(it.id).checkin) start = Math.max(start, toMin(it.time) + DURATION.hotel);
  const fullDayHere = flex.some((it) => info.get(it.id).fullDay);

  // order: by preferred slot; items in the same district are pulled next to the first of them
  flex.sort((a, b) => info.get(a.id).pref - info.get(b.id).pref || a.label.localeCompare(b.label));
  const ordered = [];
  const used = new Set();
  for (const it of flex) {
    if (used.has(it.id)) continue;
    ordered.push(it);
    used.add(it.id);
    const key = info.get(it.id).group;
    if (!key || info.get(it.id).timeBound) continue;
    for (const other of flex) {
      if (!used.has(other.id) && !info.get(other.id).timeBound && info.get(other.id).group === key) {
        ordered.push(other);
        used.add(other.id);
      }
    }
  }

  // Optimised Itinerary Generation Algorithm (FYP documentation) — the
  // two-opt pass can only improve on the district-pulling order above,
  // never move an anchor, so it's always safe to apply here before the
  // time-placement loop below consumes `ordered`.
  const travelOrdered = twoOptReorder(ordered, info);

  const busy = [...fixed.map((it) => [toMin(it.time), toMin(it.time) + (DURATION[info.get(it.id).kind] || 60)]), ...extraBusy];
  const clashes = (s, e) => busy.some(([a, b]) => s < b && a < e);
  const out = new Map(fixed.map((it) => [it.id, toMin(it.time)]));
  let cursor = start;
  let lastGroup = null;
  const place = (it) => {
    const inf = info.get(it.id);
    const dur = inf.dur;
    // a meal on a theme-park day is eaten in the park: it keeps its meal time and blocks nothing
    const inPark = fullDayHere && inf.meal;
    const gap = lastGroup && inf.group && inf.group === lastGroup ? 0 : (lastGroup ? OTHER_AREA_GAP - SAME_AREA_GAP : 0);
    let s;
    if (inf.fullDay) s = start;
    else if (inf.pref === SLOT.sunrise) s = inf.pref;
    else if (inf.timeBound) s = Math.max(inf.pref, inPark ? start : cursor + gap);
    else s = Math.max(cursor + gap, start);
    s = round15(s);
    if (!inPark) while (clashes(s, s + dur) && s < end) s += 15;
    if (s + 15 > end) s = Math.max(start, end - dur);   // squeezed: keep it inside the day
    out.set(it.id, s);
    if (!inPark) {
      busy.push([s, s + dur]);
      if (inf.pref !== SLOT.sunrise || s >= cursor) cursor = s + dur + SAME_AREA_GAP;
      lastGroup = inf.group || null;
    }
  };
  const queue = [...travelOrdered];
  while (queue.length) {
    const it = queue.shift();
    const inf = info.get(it.id);
    // a sight that would run more than 30 min into the next meal waits until after that meal
    if (!inf.timeBound && !inf.fullDay && !fullDayHere) {
      const meal = queue.find((o) => info.get(o.id).meal && info.get(o.id).pref !== SLOT.snack);
      if (meal && Math.max(cursor, start) + inf.dur > info.get(meal.id).pref + 30 && cursor < info.get(meal.id).pref + 30) {
        queue.splice(queue.indexOf(meal), 1);
        place(meal);
      }
    }
    place(it);
  }
  return out;
}

function mealName(pref) {
  return pref === SLOT.breakfast ? "Breakfast time" : pref === SLOT.lunch ? "Lunch time" : pref === SLOT.snack ? "Afternoon café break"
    : pref === SLOT.dinner ? "Dinner time" : "Supper time";
}

/**
 * plan, { mode, onlyDay, window, destination, saved, catalog, flights, hotelStays, days }
 * days: [{day, date}] (only needed for typed-in flights / hotel stays)
 */
// kmBetween now lives in maps_service.js (the "Maps service" abstraction) — re-exported
// locally under its old name so every existing call site below needed no further changes.
const { kmBetween } = require("./maps_service");

/**
 * groupByArea: the group's choice in the app (Optimise sheet). true = keep places of one area on one day.
 */
function optimisePlan(plan, { mode, onlyDay = null, window = { floor: null, ceil: null }, destination = "", saved = [],
  catalog = [], flights = [], hotelStays = [], days: dayList = null, groupByArea = true } = {}) {
  const { knownPlaces } = require("./planner/places");
  const { tripLogistics } = require("./planner/logistics_plan");
  const days = Object.keys(plan).map(Number).sort((a, b) => a - b);
  const known = knownPlaces({ destination, saved, catalog });
  const where = new Map();                    // id -> day after moves
  const byId = new Map();
  const prof = new Map();
  for (const d of days) {
    for (const it of plan[d] || []) {
      where.set(it.id, d);
      byId.set(it.id, { ...it, day: d });
      prof.set(it.id, profile(it, known));
    }
  }
  const why = new Map();                      // id -> reason for a day move
  // places with only coordinates (from the catalog): one within 2.5 km of another shares its area
  const geo = [...byId.values()].filter((it) => prof.get(it.id).place && Number.isFinite(prof.get(it.id).place.lat));
  for (const it of geo) {
    const p = prof.get(it.id);
    if (p.group) continue;
    const near = geo.find((o) => o.id !== it.id && prof.get(o.id).group && kmBetween(p.place, prof.get(o.id).place) <= 2.5);
    p.group = near ? prof.get(near.id).group : `near:${it.id}`;
  }

  // booked flights / hotel stays: each day's start, end and busy slots
  const lp = tripLogistics({ flights, hotelStays, days: dayList || days.map((d) => ({ day: d, date: "" })),
    window: window || { floor: null, ceil: null } });
  const win = lp.window;
  const bounds = (d) => {
    let start = DAY_START;
    let end = DAY_END;
    let startWhy = null;
    if (win.floor && win.floor.day === d && win.floor.minMinutes > start) { start = win.floor.minMinutes; startWhy = "flight"; }
    if (win.ceil && win.ceil.day === d) end = Math.min(end, win.ceil.maxMinutes);
    const busy = [];
    for (const f of lp.fixed) {
      if (f.day !== d || f.kind !== "hotel") continue;
      // already in the plan as an item: that item is the fixed one
      const inPlan = [...byId.values()].some((it) => where.get(it.id) === d && it.icon === "hotel" &&
        Math.abs((toMin(it.time) ?? -999) - toMin(f.time)) < 60);
      if (!inPlan) busy.push([toMin(f.time), toMin(f.time) + DURATION.hotel]);
    }
    for (const it of byId.values()) {
      const p = prof.get(it.id);
      if (where.get(it.id) === d && p.checkin && toMin(it.time) + DURATION.hotel > start) {
        start = toMin(it.time) + DURATION.hotel;
        startWhy = "checkin";
      }
    }
    return { start, end, busy, startWhy };
  };

  // what does not fit the day once it is laid out: a daytime place pushed past 17:30, or past the day's end
  const lateOn = (d) => {
    const items = [...byId.values()].filter((it) => where.get(it.id) === d);
    if (!items.length) return [];
    const b = bounds(d);
    const times = scheduleDay(items, { start: b.start, end: b.end, prof, busy: b.busy });
    return items.filter((it) => {
      const p = prof.get(it.id);
      const t = times.get(it.id);
      return !p.fixed && !p.meal && ((p.daytimeOnly && t >= 17 * 60 + 30) || t + p.dur > b.end + 15);
    }).map((it) => ({ it, time: times.get(it.id) }));
  };

  if (mode === "whole" && days.length > 1) {
    const onDay = (d) => [...byId.values()].filter((it) => where.get(it.id) === d);
    const movable = (it) => { const p = prof.get(it.id); return !p.fixed && !p.meal && it.icon !== "hotel" && it.icon !== "flight"; };
    const sights = (d) => onDay(d).filter(movable);
    const isFullDay = (d) => sights(d).some((it) => prof.get(it.id).fullDay);
    const freeMinutes = (d) => {
      const b = bounds(d);
      const used = onDay(d).reduce((n, it) => n + (prof.get(it.id).fixed ? 0 : prof.get(it.id).dur + SAME_AREA_GAP), 0);
      return b.end - b.start - b.busy.reduce((n, [a, e]) => n + e - a, 0) - used;
    };
    // the best other day for an activity: no theme park there, then its district, then the most free time
    const bestDay = (it, exclude) => {
      const p = prof.get(it.id);
      const cands = days.filter((d) => !exclude.includes(d) && !isFullDay(d) && freeMinutes(d) >= p.dur);
      const pool = cands.length ? cands : days.filter((d) => !exclude.includes(d) && !isFullDay(d));
      if (!pool.length) return null;
      const score = (d) => (p.group ? sights(d).filter((o) => prof.get(o.id).group === p.group).length * 1000 : 0) + freeMinutes(d);
      return pool.sort((a, b) => score(b) - score(a) || a - b)[0];
    };

    // a. a full-day place gets its day to itself
    for (const d of days) {
      const parks = sights(d).filter((it) => prof.get(it.id).fullDay);
      for (const it of parks.slice(1)) {
        const to = days.filter((x) => x !== d && !isFullDay(x)).sort((a, b) => sights(a).length - sights(b).length || freeMinutes(b) - freeMinutes(a))[0];
        if (to) { where.set(it.id, to); why.set(it.id, `${parks[0].label} already takes up Day ${d}`); }
      }
      if (!parks.length) continue;
      for (const it of sights(d).filter((o) => !prof.get(o.id).fullDay)) {
        const to = bestDay(it, [d]);
        if (to) { where.set(it.id, to); why.set(it.id, `${parks[0].label} takes the whole of Day ${d}`); }
      }
    }
    // b. a day too short for what is on it (flight / check-in) hands activities to the freest day
    for (const d of days) {
      for (let guard = 0; guard < 20 && freeMinutes(d) < 0; guard++) {
        const extra = sights(d).filter((it) => !prof.get(it.id).fullDay).sort((a, b) => prof.get(b.id).pref - prof.get(a.id).pref)[0];
        if (!extra) break;
        const to = bestDay(extra, [d]);
        if (!to || freeMinutes(to) < prof.get(extra.id).dur) break;
        where.set(extra.id, to);
        why.set(extra.id, bounds(d).startWhy === "flight" || (win.ceil && win.ceil.day === d)
          ? `Day ${d} is short because of your flight` : `Not enough time on Day ${d}`);
      }
    }
    // b2. a museum / garden pushed into the evening (or past the end of the day) goes to a day with room
    const fixLate = () => {
      for (const d of days) {
        for (let guard = 0; guard < 10; guard++) {
          const late = lateOn(d).filter(({ it }) => movable(it) && !prof.get(it.id).fullDay);
          if (!late.length) break;
          const { it } = late[late.length - 1];
          const to = days.filter((x) => x !== d && !isFullDay(x) && freeMinutes(x) >= prof.get(it.id).dur)
            .map((x) => { where.set(it.id, x); const ok = !lateOn(x).some((l) => l.it.id === it.id); where.set(it.id, d); return ok ? x : null; })
            .filter((x) => x !== null)
            .sort((a, b) => (prof.get(it.id).group ? sights(b).filter((o) => prof.get(o.id).group === prof.get(it.id).group).length
              - sights(a).filter((o) => prof.get(o.id).group === prof.get(it.id).group).length : 0) || freeMinutes(b) - freeMinutes(a))[0];
          if (!to) break;
          where.set(it.id, to);
          why.set(it.id, prof.get(it.id).daytimeOnly ? `No daytime left on Day ${d}` : `Day ${d} is too full`);
        }
      }
    };
    fixLate();
    // c. one area on one day (when the group wants that): every area spread over several days is
    //    brought to one day - the day that already has most of it, else the one with the fewest places
    //    of other areas - if that day has the time; bigger areas first
    if (groupByArea) {
      const areas = new Map();
      for (const it of byId.values()) {
        const p = prof.get(it.id);
        if (!movable(it) || !p.group || p.fullDay) continue;
        if (!areas.has(p.group)) areas.set(p.group, []);
        areas.get(p.group).push(it);
      }
      const order = [...areas.entries()].filter(([, l]) => l.length >= 2 && new Set(l.map((it) => where.get(it.id))).size > 1)
        .sort((x, y) => y[1].length - x[1].length);
      for (const [area, list] of order) {
        const here = (d) => list.filter((it) => where.get(it.id) === d);
        const others = (d) => sights(d).filter((o) => prof.get(o.id).group !== area).length;
        const cands = days.filter((d) => !isFullDay(d)).sort((a, b) =>
          here(b).length - here(a).length || others(a) - others(b) || freeMinutes(b) - freeMinutes(a) || a - b);
        for (const d of cands) {
          const moving = list.filter((it) => where.get(it.id) !== d);
          const need = moving.reduce((n, it) => n + prof.get(it.id).dur + SAME_AREA_GAP, 0);
          if (sights(d).length + moving.length > MAX_SIGHTS + 1 || freeMinutes(d) < need) continue;
          const anchor = here(d)[0] || list.find((it) => !moving.includes(it)) || null;
          const was = new Map(moving.map((it) => [it.id, where.get(it.id)]));
          for (const it of moving) where.set(it.id, d);
          if (lateOn(d).length) {                       // does not really fit once laid out: undo
            for (const it of moving) where.set(it.id, was.get(it.id));
            continue;
          }
          for (const it of moving) why.set(it.id, anchor ? `Same area as ${anchor.label}` : `Keeps ${list.length} places of one area together`);
          break;
        }
      }
    }
    // d. balancing: move whole same-district groups (never split a group if a whole one fits)
    for (let guard = 0; guard < 50; guard++) {
      const open = days.filter((d) => !isFullDay(d));
      if (open.length < 2) break;
      const counts = open.map((d) => [d, sights(d).length]).sort((x, y) => y[1] - x[1] || x[0] - y[0]);
      const [heavy, hc] = counts[0];
      const lightRow = counts.slice().reverse().find(([d]) => freeMinutes(d) > 60) || counts[counts.length - 1];
      const [light, lc] = lightRow;
      if (hc - lc < 2 || heavy === light) break;
      const groups = new Map();
      for (const it of sights(heavy)) {
        const k = (groupByArea && prof.get(it.id).group) || `#${it.id}`;
        if (!groups.has(k)) groups.set(k, []);
        groups.get(k).push(it);
      }
      let best = null;
      for (const g of groups.values()) {
        const newDiff = Math.abs((hc - g.length) - (lc + g.length));
        if (newDiff >= hc - lc) continue;
        const need = g.reduce((n, it) => n + prof.get(it.id).dur + SAME_AREA_GAP, 0);
        if (need > freeMinutes(light)) continue;
        if (!best || newDiff < best.diff || (newDiff === best.diff && g.length < best.g.length)) best = { g, diff: newDiff };
      }
      if (!best) {
        // only big groups left: split one only when the day is really too full (more than 3 sights)
        const g = [...groups.values()].sort((x, y) => y.length - x.length)[0];
        if (!g || hc <= MAX_SIGHTS) break;
        const one = g.sort((x, y) => prof.get(y.id).pref - prof.get(x.id).pref)[0];
        if (prof.get(one.id).dur + SAME_AREA_GAP > freeMinutes(light)) break;
        best = { g: [one] };
      }
      for (const it of best.g) {
        where.set(it.id, light);
        why.set(it.id, `Day ${heavy} was much busier than Day ${light}`);
      }
    }
    fixLate();
  }

  const update = [];
  const notes = [];
  const target = mode === "day" ? [onlyDay] : days;
  for (const d of target) {
    const items = [...byId.values()].filter((it) => where.get(it.id) === d);
    if (!items.length) continue;
    const b = bounds(d);
    const times = scheduleDay(items, { start: b.start, end: b.end, prof, busy: b.busy });
    for (const { it, time } of lateOn(d)) {
      notes.push(mode === "day"
        ? `Day ${d} is very full: ${it.label} ends up at ${toHHMM(time)}. Try Optimise Whole Trip to move it to another day.`
        : `Day ${d} is very full: ${it.label} ends up at ${toHHMM(time)}. Consider moving it to another day.`);
    }
    for (const it of items) {
      const p = prof.get(it.id);
      const min = times.get(it.id);
      const time = p.fixed ? it.time : toHHMM(min);
      if (it.day === d && time === it.time) continue;
      let reason;
      if (it.day !== d) reason = why.get(it.id) || `Fits better on Day ${d}`;
      else if (p.fullDay) reason = "Starts early: it takes most of the day";
      else if (p.why === "evening") reason = "Best in the evening";
      else if (p.why === "sunrise") reason = "In time for sunrise";
      else if (p.why === "sunset") reason = "In time for sunset";
      else if (p.meal && Math.abs(min - p.pref) <= 60) reason = mealName(p.pref);
      else if (min === round15(b.start) && b.startWhy === "flight") reason = "After your flight lands";
      else if (min === round15(b.start) && b.startWhy === "checkin") reason = "After hotel check-in";
      else if (p.why === "morning") reason = "Best in the morning";
      else {
        // the stop just before it, if any
        const before = items.filter((o) => o.id !== it.id && times.get(o.id) < min)
          .sort((x, y) => times.get(y.id) - times.get(x.id))[0];
        if (!before) reason = `Starts the day (about ${Math.round(p.dur / 30) / 2} h there)`;
        else if (p.group && prof.get(before.id).group === p.group) reason = `Right after ${before.label}, same area`;
        else reason = `After ${before.label} (about ${Math.round(p.dur / 30) / 2} h there)`;
      }
      update.push({ label: it.label, from_day: it.day, day: d, time, reason });
    }
  }
  update.sort((a, b) => a.from_day - b.from_day || a.day - b.day || a.time.localeCompare(b.time));
  return { update, window: win, notes: notes.slice(0, 5) };
}

module.exports = { optimisePlan, scheduleDay, classify, profile, toMin, toHHMM };
