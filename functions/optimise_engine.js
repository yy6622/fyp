
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

function recommendationScoreOf(inf) {
  const r = inf.place && inf.place.rating != null ? parseFloat(inf.place.rating) : NaN;
  if (!Number.isFinite(r)) return 0.5;
  return Math.max(0, Math.min(1, r / 5));
}
function costPenaltyOf(inf) {
  const price = inf.place && inf.place.price != null ? String(inf.place.price) : "";
  if (!price || /free/i.test(price)) return 0;
  const n = parseFloat(price.replace(/[^0-9.]/g, ""));
  if (!Number.isFinite(n)) return 0.2;
  return Math.max(0, Math.min(1, n / 200));
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

  const flatOptimised = optimisedRuns.flat();
  let ri = 0;
  const final = [];
  for (const b of blocks) {
    if (isAnchorBlock(b, info)) final.push(b);
    else { final.push(flatOptimised[ri]); ri++; }
  }
  return final.flat();
}

function scheduleDay(items, { start = DAY_START, end = DAY_END, prof = null, busy: extraBusy = [] } = {}) {
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

  const travelOrdered = twoOptReorder(ordered, info);

  const busy = [...fixed.map((it) => [toMin(it.time), toMin(it.time) + (DURATION[info.get(it.id).kind] || 60)]), ...extraBusy];
  const clashes = (s, e) => busy.some(([a, b]) => s < b && a < e);
  const out = new Map(fixed.map((it) => [it.id, toMin(it.time)]));
  let cursor = start;
  let lastGroup = null;
  const place = (it) => {
    const inf = info.get(it.id);
    const dur = inf.dur;
    const inPark = fullDayHere && inf.meal;
    const gap = lastGroup && inf.group && inf.group === lastGroup ? 0 : (lastGroup ? OTHER_AREA_GAP - SAME_AREA_GAP : 0);
    let s;
    if (inf.fullDay) s = start;
    else if (inf.pref === SLOT.sunrise) s = inf.pref;
    else if (inf.timeBound) s = Math.max(inf.pref, inPark ? start : cursor + gap);
    else s = Math.max(cursor + gap, start);
    s = round15(s);
    if (!inPark) while (clashes(s, s + dur) && s < end) s += 15;
    if (s + 15 > end) s = Math.max(start, end - dur);
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

const { kmBetween } = require("./maps_service");

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
  const why = new Map();
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
