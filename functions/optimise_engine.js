
const SLOT = { breakfast: 8 * 60, morning: 9 * 60 + 30, lunch: 12 * 60 + 30, afternoon: 14 * 60 + 30, snack: 15 * 60 + 30,
  sunset: 17 * 60 + 30, dinner: 19 * 60, night: 20 * 60 + 30, sunrise: 5 * 60 + 45 };
const DURATION = { food: 60, place: 90, activity: 120, shopping: 90, hotel: 45, flight: 60 };
const DAY_START = 9 * 60;
const DAY_END = 23 * 60;
const SAME_AREA_GAP = 15;
const OTHER_AREA_GAP = 30;
const MAX_SIGHTS = 3;

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

// Mirrors lib/models/day_plan_models.dart's isLikelyIndoor word lists exactly,
// so an activity is "outdoor" here iff the Dart side would call it confidently
// outdoor (not ambiguous, not indoor) -- used to avoid scheduling it inside a
// forecast rain window.
const INDOOR_WORDS = /(museum|gallery|mall|shopping (centre|center)|department store|supermarket|cinema|movie|theatre|theater|aquarium|planetarium|arcade|bowling|karaoke|spa|massage|indoor|casino|ice rink|restaurant|cafe|café|food court|博物馆|美术馆|商场|购物中心|百货|电影院|水族馆|按摩|室内|咖啡|餐厅)/i;
const OUTDOOR_WORDS = /(beach|hiking?|trail|park|garden|zoo|safari|mountain|lake|river|waterfall|outdoor|night market|street food|market|viewpoint|cruise|boat|island|cycling|bike|trekking|climbing|ski|surfing|rooftop|walking tour|picnic|sunrise|sunset|海滩|沙滩|爬山|登山|公园|花园|动物园|夜市|海岛|骑车|徒步|日出|日落)/i;
function isLikelyOutdoor(label) {
  const text = String(label || "");
  return OUTDOOR_WORDS.test(text) && !INDOOR_WORDS.test(text);
}

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
    const c = cur ?? SLOT.lunch;
    const pref = c < 10 * 60 + 30 ? SLOT.breakfast : c < 16 * 60 ? SLOT.lunch : c < 21 * 60 + 30 ? SLOT.dinner : SLOT.night;
    return { kind: "food", pref, meal: true };
  }
  if (has(t, ["night market", "夜市", "pasar malam", "night view", "夜景", "bar", "pub", "club", "show", "表演", "light show"])) {
    return { kind: icon, pref: SLOT.night, why: "evening" };
  }
  if (icon === "shopping") return { kind: "shopping", pref: cur !== null && cur >= 17 * 60 ? SLOT.night - 60 : SLOT.afternoon };
  return { kind: icon, pref: cur !== null && cur >= 13 * 60 ? SLOT.afternoon : SLOT.morning };
}

const locKey = (it) => lower(it.location).replace(/[^a-z0-9一-鿿]+/g, " ").trim();
const MEAL_WORD = /breakfast|brunch|lunch|dinner|supper|早餐|早点|午餐|午饭|晚餐|晚饭|宵夜|sarapan|makan/;

function profile(item, known) {
  const c = classify(item);
  const { districtOf } = require("./planner/places");
  const p = { ...c, dur: DURATION[c.kind] || 90, group: lower(districtOf({ location: item.location })), place: null };
  p.outdoor = !p.fixed && !p.meal && isLikelyOutdoor(item.label);
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
  p.daytimeOnly = !p.meal && !p.fixed && !p.timeBound && !p.fullDay && (p.place
    ? !/[EN]/.test(p.place.slots || "")
    : /museum|temple|garden|zoo|aquarium|palace|博物馆|美术馆|寺|庙|园|宫|muzium|kuil|taman/.test(lower(item.label)));
  return p;
}

function travelTimePenaltyOf(minutes) {
  if (minutes == null) return 0.3;
  return Math.max(0, Math.min(1, minutes / 60));
}
function waitingTimePenaltyOf(minutes) {
  return Math.max(0, Math.min(1, Math.max(0, minutes) / 120));
}

function pointOf(block, info) {
  for (const it of block) {
    const inf = info.get(it.id);
    if (inf.place && Number.isFinite(inf.place.lat) && Number.isFinite(inf.place.lng)) {
      return { lat: inf.place.lat, lng: inf.place.lng, district: inf.group || "" };
    }
  }
  return { district: info.get(block[0].id).group || "" };
}

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

function twoOptReorder(ordered, info, extraFor = () => 0) {
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

  // 2-opt only considers travel time and live traffic delay.
  // Rating, recommendation scores and attraction costs do not affect order.
  const totalUtility = (seq) => {
    let sum = 0;
    for (let i = 1; i < seq.length; i++) {
      const minutes = estimateTravelMinutes(pointOf(seq[i - 1], info), pointOf(seq[i], info));
      sum -= travelTimePenaltyOf(minutes);
      const prevBlock = seq[i - 1];
      const extra = extraFor(prevBlock[prevBlock.length - 1].id, seq[i][0].id);
      if (extra > 0) sum -= Math.max(0, Math.min(1, extra / 60));
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

  const flatOptimised = optimisedRuns.flat();
  let ri = 0;
  const final = [];
  for (const b of blocks) {
    if (isAnchorBlock(b, info)) final.push(b);
    else { final.push(flatOptimised[ri]); ri++; }
  }
  return final.flat();
}

function scheduleDay(items, { start = DAY_START, end = DAY_END, prof = null, busy: extraBusy = [], rainWindows = [], extraFor = () => 0 } = {}) {
  const info = prof || new Map(items.map((it) => [it.id, profile(it, null)]));
  const fixed = items.filter((it) => info.get(it.id).fixed);
  const flex = items.filter((it) => !info.get(it.id).fixed);
  for (const it of fixed) if (info.get(it.id).checkin) start = Math.max(start, toMin(it.time) + DURATION.hotel);
  const fullDayHere = flex.some((it) => info.get(it.id).fullDay);

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

  const travelOrdered = twoOptReorder(ordered, info, extraFor);

  const busy = [...fixed.map((it) => [toMin(it.time), toMin(it.time) + (DURATION[info.get(it.id).kind] || 60)]), ...extraBusy];
  const clashes = (s, e) => busy.some(([a, b]) => s < b && a < e);
  const rainAt = (s, e) => rainWindows.find(([a, b]) => s < b && a < e) || null;
  const out = new Map(fixed.map((it) => [it.id, toMin(it.time)]));
  // id -> [windowStart, windowEnd] for every outdoor item actually moved to
  // dodge a forecast rain window, so the caller can say exactly why.
  const rainShifted = new Map();
  // id -> {withId, extraMinutes} for every item scheduled with extra buffer
  // because the leg right before it was measured as congested right now, so
  // the caller can tell the user exactly why (or that it's still tight even
  // with the extra time).
  const congestionNoted = new Map();
  let cursor = start;
  let lastGroup = null;
  let prevId = null;
  const place = (it) => {
    const inf = info.get(it.id);
    const dur = inf.dur;
    const inPark = fullDayHere && inf.meal;
    const congestionExtra = !inPark && prevId ? extraFor(prevId, it.id) : 0;
    const gap = (lastGroup && inf.group && inf.group === lastGroup ? 0 : (lastGroup ? OTHER_AREA_GAP - SAME_AREA_GAP : 0)) + congestionExtra;
    if (congestionExtra > 0) congestionNoted.set(it.id, { withId: prevId, extraMinutes: congestionExtra });
    let s0;
    if (inf.fullDay) s0 = start;
    else if (inf.pref === SLOT.sunrise) s0 = inf.pref;
    else if (inf.timeBound) s0 = Math.max(inf.pref, inPark ? start : cursor + gap);
    else s0 = Math.max(cursor + gap, start);
    s0 = round15(s0);

    let s = s0;
    if (!inPark) {
      // Where it would land dodging only busy clashes (no weather) ...
      let sNoRain = s0;
      while (clashes(sNoRain, sNoRain + dur) && sNoRain < end) sNoRain += 15;
      // ... vs. where it lands once a forecast rain window is dodged too
      // (outdoor items only -- an indoor one has no reason to move for rain).
      s = s0;
      while ((clashes(s, s + dur) || (inf.outdoor && rainAt(s, s + dur))) && s < end) s += 15;
      if (inf.outdoor && s > sNoRain) {
        const hit = rainAt(sNoRain, sNoRain + dur);
        if (hit) rainShifted.set(it.id, hit);
      }
    }
    if (s + 15 > end) s = Math.max(start, end - dur);
    out.set(it.id, s);
    if (!inPark) {
      busy.push([s, s + dur]);
      if (inf.pref !== SLOT.sunrise || s >= cursor) cursor = s + dur + SAME_AREA_GAP;
      lastGroup = inf.group || null;
      prevId = it.id;
    }
  };
  const queue = [...travelOrdered];
  while (queue.length) {
    const it = queue.shift();
    const inf = info.get(it.id);
    if (!inf.timeBound && !inf.fullDay && !fullDayHere) {
      const meal = queue.find((o) => info.get(o.id).meal && info.get(o.id).pref !== SLOT.snack);
      if (meal && Math.max(cursor, start) + inf.dur > info.get(meal.id).pref + 30 && cursor < info.get(meal.id).pref + 30) {
        queue.splice(queue.indexOf(meal), 1);
        place(meal);
      }
    }
    place(it);
  }
  return { times: out, rainShifted, congestionNoted };
}

function mealName(pref) {
  return pref === SLOT.breakfast ? "Breakfast time" : pref === SLOT.lunch ? "Lunch time" : pref === SLOT.snack ? "Afternoon café break"
    : pref === SLOT.dinner ? "Dinner time" : "Supper time";
}

const { kmBetween } = require("./maps_service");

// When a congested leg can't be fixed by reordering/retiming (a simple
// activity+meal day often has nothing to swap), the next best thing is to
// suggest swapping the destination itself: a different restaurant for a
// meal, or a different attraction for anything else -- picked by actual
// proximity to the *previous* stop (the one the jam is coming from), so
// the suggestion itself doesn't just recreate the same traffic.
function findAlternativePlace(targetProf, anchorProf, places) {
  if (!Array.isArray(places) || !places.length) return null;
  const anchor = anchorProf && anchorProf.place;
  if (!anchor || !Number.isFinite(anchor.lat) || !Number.isFinite(anchor.lng)) return null;
  const { norm } = require("./planner/places");
  const wantFood = Boolean(targetProf && targetProf.meal);
  const currentName = targetProf && targetProf.place ? norm(targetProf.place.name) : null;
  const candidates = places
    .filter((q) => Number.isFinite(q.lat) && Number.isFinite(q.lng)
      && (wantFood ? q.icon === "food" : q.icon !== "food")
      && (!currentName || norm(q.name) !== currentName))
    .map((q) => ({ q, km: kmBetween(anchor, q) }))
    .filter((c) => Number.isFinite(c.km) && c.km <= 8)
    .sort((a, b) => a.km - b.km);
  if (!candidates.length) return null;
  return { name: candidates[0].q.name, km: candidates[0].km };
}

function optimisePlan(plan, { mode, onlyDay = null, window = { floor: null, ceil: null }, destination = "", saved = [],
  catalog = [], flights = [], hotelStays = [], days: dayList = null, groupByArea = true, votes = [], rainWindows = {},
  congestedLegs = [] } = {}) {
  const { knownPlaces, norm } = require("./planner/places");
  const { tripLogistics } = require("./planner/logistics_plan");
  const days = Object.keys(plan).map(Number).sort((a, b) => a - b);
  const known = knownPlaces({ destination, saved, catalog });
  const { voteDayAssignments } = require("./planner/vote_days");
  const voteDayByPlace = voteDayAssignments({ votes, known, days: dayList || days.map((d) => ({ day: d, date: "" })) });
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
  const why = new Map();
  // votedDayById marks items the whole-trip rebalancer below must never
  // move to a different day (see the `movable` check further down).
  const votedDayById = new Map();
  for (const it of byId.values()) {
    const p = prof.get(it.id);
    const votedDay = p.place && voteDayByPlace.get(norm(p.place.name));
    if (votedDay && days.includes(votedDay)) {
      votedDayById.set(it.id, votedDay);
      if (where.get(it.id) !== votedDay) {
        why.set(it.id, "Day " + votedDay + " — the group voted for this");
        where.set(it.id, votedDay);
      }
    }
  }
  const geo = [...byId.values()].filter((it) => prof.get(it.id).place && Number.isFinite(prof.get(it.id).place.lat));
  for (const it of geo) {
    const p = prof.get(it.id);
    if (p.group) continue;
    const near = geo.find((o) => o.id !== it.id && prof.get(o.id).group && kmBetween(p.place, prof.get(o.id).place) <= 2.5);
    p.group = near ? prof.get(near.id).group : `near:${it.id}`;
  }

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

  const rainWindowsForDay = (d) => {
    const raw = rainWindows && rainWindows[String(d)];
    return Array.isArray(raw)
      ? raw.filter((w) => Array.isArray(w) && w.length === 2 && Number.isFinite(w[0]) && Number.isFinite(w[1]))
      : [];
  };

  // Minutes of *measured* extra delay between two specific plan items right
  // now (keyed either direction) -- from the client's live traffic check,
  // today only (there's no hour-by-hour traffic forecast the way there is
  // for rain). Lets the scheduler add a realistic buffer instead of the
  // generic 15/30 min area gap, and lets 2-opt prefer not to keep them
  // adjacent when a reorder can avoid it. Zero for everything when none
  // were sent.
  const congestionExtraById = new Map();
  for (const leg of Array.isArray(congestedLegs) ? congestedLegs : []) {
    if (!leg || typeof leg.fromItemId !== "string" || typeof leg.toItemId !== "string") continue;
    const mins = Math.max(0, Math.min(90, Math.round(Number(leg.extraMinutes) || 0)));
    if (mins <= 0) continue;
    congestionExtraById.set([leg.fromItemId, leg.toItemId].sort().join("|"), mins);
  }
  const extraFor = (idA, idB) => (idA && idB ? congestionExtraById.get([idA, idB].sort().join("|")) || 0 : 0);

  const lateOn = (d) => {
    const items = [...byId.values()].filter((it) => where.get(it.id) === d);
    if (!items.length) return [];
    const b = bounds(d);
    const { times } = scheduleDay(items, { start: b.start, end: b.end, prof, busy: b.busy, rainWindows: rainWindowsForDay(d), extraFor });
    return items.filter((it) => {
      const p = prof.get(it.id);
      const t = times.get(it.id);
      return !p.fixed && !p.meal && ((p.daytimeOnly && t >= 17 * 60 + 30) || t + p.dur > b.end + 15);
    }).map((it) => ({ it, time: times.get(it.id) }));
  };

  if (mode === "whole" && days.length > 1) {
    const onDay = (d) => [...byId.values()].filter((it) => where.get(it.id) === d);
    const movable = (it) => { const p = prof.get(it.id); return !p.fixed && !p.meal && it.icon !== "hotel" && it.icon !== "flight" && !votedDayById.has(it.id); };
    const sights = (d) => onDay(d).filter(movable);
    const isFullDay = (d) => sights(d).some((it) => prof.get(it.id).fullDay);
    const freeMinutes = (d) => {
      const b = bounds(d);
      const used = onDay(d).reduce((n, it) => n + (prof.get(it.id).fixed ? 0 : prof.get(it.id).dur + SAME_AREA_GAP), 0);
      return b.end - b.start - b.busy.reduce((n, [a, e]) => n + e - a, 0) - used;
    };
    const bestDay = (it, exclude) => {
      const p = prof.get(it.id);
      const cands = days.filter((d) => !exclude.includes(d) && !isFullDay(d) && freeMinutes(d) >= p.dur);
      const pool = cands.length ? cands : days.filter((d) => !exclude.includes(d) && !isFullDay(d));
      if (!pool.length) return null;
      const score = (d) => (p.group ? sights(d).filter((o) => prof.get(o.id).group === p.group).length * 1000 : 0) + freeMinutes(d);
      return pool.sort((a, b) => score(b) - score(a) || a - b)[0];
    };

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
          if (lateOn(d).length) {
            for (const it of moving) where.set(it.id, was.get(it.id));
            continue;
          }
          for (const it of moving) why.set(it.id, anchor ? `Same area as ${anchor.label}` : `Keeps ${list.length} places of one area together`);
          break;
        }
      }
    }
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
    const { times, rainShifted, congestionNoted } = scheduleDay(items, { start: b.start, end: b.end, prof, busy: b.busy, rainWindows: rainWindowsForDay(d), extraFor });
    for (const { it, time } of lateOn(d)) {
      notes.push(mode === "day"
        ? `Day ${d} is very full: ${it.label} ends up at ${toHHMM(time)}. Try Optimise Whole Trip to move it to another day.`
        : `Day ${d} is very full: ${it.label} ends up at ${toHHMM(time)}. Consider moving it to another day.`);
    }
    if (congestionNoted.size) {
      for (const [id, { withId, extraMinutes }] of congestionNoted) {
        const it = items.find((o) => o.id === id);
        const withItem = items.find((o) => o.id === withId);
        if (!it) continue;
        const alt = findAlternativePlace(prof.get(id), withId ? prof.get(withId) : null, known.places);
        const altPhrase = alt ? ` Consider ${alt.name} instead \u2014 it's closer to ${withItem ? withItem.label : "your previous stop"} and skips that jam.` : "";
        notes.push(`Heads up: traffic from ${withItem ? withItem.label : "the previous stop"} to ${it.label} was running ~${extraMinutes} min over usual \u00b7 extra time added.${altPhrase}`);
      }
    }
    // A long stretch of nothing planned isn't itself a problem, but leaving
    // it completely silent isn't helpful either -- suggest something
    // concrete to fill it (same 180-minute threshold as the client's
    // _maxTrafficGapMinutes, since that's the same "too far apart for
    // anything specific to be worth saying" cutoff in spirit). Mirrors
    // scheduleDay's own sequencing: a big gap only ever shows up between
    // two items that aren't both sitting inside the same full-day block.
    const GAP_FILL_MINUTES = 180;
    const byTime = items.slice().sort((x, y) => times.get(x.id) - times.get(y.id));
    for (let i = 0; i < byTime.length - 1; i++) {
      const a = byTime[i];
      const b = byTime[i + 1];
      const aProf = prof.get(a.id);
      const bProf = prof.get(b.id);
      const aEnd = times.get(a.id) + aProf.dur;
      const gapMinutes = times.get(b.id) - aEnd;
      if (gapMinutes < GAP_FILL_MINUTES) continue;
      const alt = findAlternativePlace({ meal: false }, aProf, known.places);
      const h = Math.floor(gapMinutes / 60);
      const m = gapMinutes % 60;
      const gapLabel = h > 0 ? `${h}h${m > 0 ? ` ${m}m` : ""}` : `${m}m`;
      const suggestion = alt
        ? `maybe head back to your hotel to rest, or visit ${alt.name} nearby`
        : "maybe head back to your hotel to rest, or explore nearby";
      notes.push(`There's a ${gapLabel} gap between ${a.label} and ${b.label} \u2014 ${suggestion}.`);
    }
    for (const it of items) {
      const p = prof.get(it.id);
      const min = times.get(it.id);
      const time = p.fixed ? it.time : toHHMM(min);
      if (it.day === d && time === it.time) continue;
      let reason;
      if (it.day !== d) reason = why.get(it.id) || `Fits better on Day ${d}`;
      else if (rainShifted.has(it.id)) {
        const [rs, re] = rainShifted.get(it.id);
        reason = `Rain forecast ${toHHMM(rs)}\u2013${toHHMM(re)} \u00b7 moved to avoid it`;
      }
      else if (congestionNoted.has(it.id)) {
        const { withId, extraMinutes } = congestionNoted.get(it.id);
        const withItem = items.find((o) => o.id === withId);
        const alt = findAlternativePlace(p, withId ? prof.get(withId) : null, known.places);
        const altPhrase = alt ? ` \u2014 consider ${alt.name} instead` : "";
        reason = withItem
          ? `Traffic from ${withItem.label} was running ~${extraMinutes} min over usual \u00b7 extra time added${altPhrase}`
          : `Traffic was running ~${extraMinutes} min over usual \u00b7 extra time added${altPhrase}`;
      }
      else if (p.fullDay) reason = "Starts early: it takes most of the day";
      else if (p.why === "evening") reason = "Best in the evening";
      else if (p.why === "sunrise") reason = "In time for sunrise";
      else if (p.why === "sunset") reason = "In time for sunset";
      else if (p.meal && Math.abs(min - p.pref) <= 60) reason = mealName(p.pref);
      else if (min === round15(b.start) && b.startWhy === "flight") reason = "After your flight lands";
      else if (min === round15(b.start) && b.startWhy === "checkin") reason = "After hotel check-in";
      else if (p.why === "morning") reason = "Best in the morning";
      else {
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
