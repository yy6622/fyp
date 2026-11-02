
const toMin = (t) => { const [h, m] = String(t).split(":").map(Number); return h * 60 + (m || 0); };
const toHHMM = (n) => `${String(Math.floor(n / 60) % 24).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;
const round15 = (n) => Math.ceil(n / 15) * 15;

const DAY_START = 9 * 60 + 30;
const LUNCH = 12 * 60;
const DINNER = 18 * 60;
const EVENING = 19 * 60 + 30;
const DAY_END = 22 * 60;
const BUFFER = 30;

const isFood = (p) => p.icon === "food";
const eveningOnly = (p) => /[EN]/.test(p.slots || "") && !/[MA]/.test(p.slots || "") && !isFood(p);
const fullDay = (p) => (p.hours || 0) >= 6;
const snack = (p) => isFood(p) && /A/.test(p.slots || "") && !/D/.test(p.slots || "");
const visitMinutes = (p) => Math.round(60 * (eveningOnly(p) ? Math.min(p.hours || 1.5, 1.5) : (p.hours || 2)));

const normArea = (s) => String(s || "").normalize("NFKC").toLowerCase().replace(/\s+/g, " ").trim();
function km(a, b) {
  const r = Math.PI / 180;
  const x = (b.lng - a.lng) * r * Math.cos(((a.lat + b.lat) / 2) * r);
  const y = (b.lat - a.lat) * r;
  return Math.sqrt(x * x + y * y) * 6371;
}
const NEAR_KM = 2.5;
function areaKeys(places) {
  const out = new Map();
  const withGeo = places.filter((p) => Number.isFinite(p.place.lat) && Number.isFinite(p.place.lng));
  for (const p of places) out.set(p.key, normArea(p.place.district));
  for (const p of withGeo) {
    if (out.get(p.key)) continue;
    const near = withGeo.find((q) => q !== p && out.get(q.key) && km(p.place, q.place) <= NEAR_KM);
    out.set(p.key, near ? out.get(near.key) : `near:${p.key}`);
  }
  return out;
}

function schedule(places, days, plan, window, { relaxed = false, checkIn = null, planAreas = {} } = {}) {
  const n = days.length;
  const areaOf = areaKeys(places);
  const maxSights = relaxed ? 2 : 3;
  const dayInfo = new Map(days.map((d) => {
    let start = DAY_START;
    let end = DAY_END;
    if (d.day === 1 && n > 1) start = 14 * 60;
    if (d.day === n && n > 1) end = 12 * 60 + 30;               // last day: home time
    if (checkIn && checkIn.day === d.day) start = Math.max(start, toMin(checkIn.time) + 60);
    if (window && window.floor && window.floor.day === d.day) start = Math.max(start, window.floor.minMinutes);
    if (window && window.ceil && window.ceil.day === d.day) end = Math.min(end, window.ceil.maxMinutes);
    const busy = (plan[d.day] || []).filter((it) => /^\d{2}:\d{2}$/.test(it.time || ""))
      .map((it) => [toMin(it.time), toMin(it.time) + (it.icon === "hotel" || it.icon === "flight" ? 60 : 120)]);
    if (checkIn && checkIn.day === d.day) busy.push([toMin(checkIn.time), toMin(checkIn.time) + 60]);
    const existing = (plan[d.day] || []).filter((it) => !["hotel", "flight"].includes(it.icon)).length;
    const districts = new Map();
    for (const a of planAreas[d.day] || []) districts.set(a, (districts.get(a) || 0) + 1);
    return [d.day, { start, end, busy, sights: existing, items: [], fullDay: false, districts }];
  }));

  const byKey = new Map(places.map((p) => [p.key, p]));
  const parent = new Map(places.map((p) => [p.key, p.key]));
  const find = (k) => (parent.get(k) === k ? k : find(parent.get(k)));
  for (const p of places) for (const q of p.partners || []) if (byKey.has(q)) parent.set(find(q), find(p.key));
  const named = new Set(places.filter((p) => p.day).map((p) => find(p.key)));
  const firstInArea = new Map();
  for (const p of places) {
    const a = areaOf.get(p.key);
    const root = find(p.key);
    if (!a || named.has(root) || fullDay(p.place)) continue;
    if (!firstInArea.has(a)) firstInArea.set(a, root);
    else if (find(firstInArea.get(a)) !== root && !named.has(find(firstInArea.get(a)))) parent.set(root, find(firstInArea.get(a)));
  }
  const groups = new Map();
  for (const p of places) (groups.get(find(p.key)) || groups.set(find(p.key), []).get(find(p.key))).push(p);

  const sightsOf = (g) => g.filter((p) => !isFood(p.place) && !eveningOnly(p.place)).length;
  const canTake = (d, g) => {
    const info = dayInfo.get(d);
    if (!info || info.fullDay) return false;
    if (g.some((p) => fullDay(p.place))) return info.items.length === 0 && info.sights === 0 && d !== 1 && (d !== n || n === 1);
    const daytime = Math.max(0, Math.min(info.end, DINNER) - info.start);
    const need = g.filter((p) => !isFood(p.place) && !eveningOnly(p.place)).reduce((a, p) => a + visitMinutes(p.place) + BUFFER, 0);
    const used = info.items.filter((p) => !isFood(p.place) && !eveningOnly(p.place)).reduce((a, p) => a + visitMinutes(p.place) + BUFFER, 0);
    const evening = g.filter((p) => eveningOnly(p.place)).length;
    const eveningUsed = info.items.filter((p) => eveningOnly(p.place)).length;
    if (evening && (info.end < EVENING + 60 || eveningUsed + evening > 2)) return false;
    if (g.every((p) => isFood(p.place))) {
      const food = info.items.filter((p) => isFood(p.place));
      if (food.length + g.length > 3) return false;
      if (g.some((p) => snack(p.place)) && food.some((p) => snack(p.place))) return false;
    }
    const cap = n > 1 && d === 1 ? (relaxed ? 0 : 1) : n > 1 && d === n ? 1 : maxSights;
    return info.sights + sightsOf(g) <= cap && used + need <= daytime + 30;
  };
  const put = (d, g) => {
    const info = dayInfo.get(d);
    for (const p of g) {
      info.items.push(p);
      const dist = areaOf.get(p.key);
      if (dist) info.districts.set(dist, (info.districts.get(dist) || 0) + 1);
      if (fullDay(p.place)) info.fullDay = true;
    }
    info.sights += sightsOf(g);
  };
  const score = (d, g) => {
    const info = dayInfo.get(d);
    const same = g.reduce((a, p) => a + (info.districts.get(areaOf.get(p.key)) || 0), 0);
    const edge = (d === 1 || d === n) && n > 2 ? 1.5 : 0;
    let food = 0;
    if (g.every((p) => isFood(p.place))) {
      const meals = info.items.filter((p) => isFood(p.place));
      food = (info.sights > 0 || info.items.length > 0 ? 2.5 : -3) - meals.length * 2 -
        meals.filter((m) => g.some((p) => snack(p.place) === snack(m.place))).length * 2;
    }
    return same * 5 + food - info.sights * 1.2 - info.items.length * 0.3 - edge - d * 0.01;
  };

  const free = [];
  for (const g of groups.values()) {
    const named = g.find((p) => p.day);
    if (named) {
      const rest = g.filter((p) => !p.day || p.day === named.day);
      put(named.day, rest);
      for (const p of g) if (p.day && p.day !== named.day) put(p.day, [p]);
    } else {
      free.push(g);
    }
  }
  free.sort((a, b) => Number(b.some((p) => fullDay(p.place))) - Number(a.some((p) => fullDay(p.place))) ||
    b.length - a.length || sightsOf(b) - sightsOf(a));
  const unplaced = [];
  for (const g of free) {
    let options = days.map((d) => d.day).filter((d) => canTake(d, g));
    if (!options.length && g.length > 1) {
      for (const p of g) {
        const o = days.map((d) => d.day).filter((d) => canTake(d, [p]));
        if (o.length) put(o.sort((a, b) => score(b, [p]) - score(a, [p]))[0], [p]);
        else unplaced.push(p);
      }
      continue;
    }
    if (!options.length) { unplaced.push(...g); continue; }
    options.sort((a, b) => score(b, g) - score(a, g));
    put(options[0], g);
  }
  for (const p of unplaced) {
    const d = days.map((x) => x.day).filter((x) => !dayInfo.get(x).fullDay)
      .sort((a, b) => dayInfo.get(a).items.length - dayInfo.get(b).items.length)[0] || 1;
    put(d, [p]);
  }

  const out = [];
  for (const [day, info] of dayInfo) {
    const busy = info.busy.slice();
    const freeAt = (t, dur) => {
      let s = round15(t);
      for (let guard = 0; guard < 60; guard++) {
        const clash = busy.find(([a, b]) => s < b && a < s + dur);
        if (!clash) return s;
        s = round15(clash[1]);
      }
      return s;
    };
    const place = (p, t) => {
      const dur = visitMinutes(p.place);
      const s = freeAt(t, dur);
      busy.push([s, s + dur]);
      out.push({ key: p.key, day, time: toHHMM(Math.min(s, 23 * 60 + 30)) });
      return s + dur;
    };
    const timed = info.items.filter((p) => p.time);
    for (const p of timed) place(p, toMin(p.time));
    const rest = info.items.filter((p) => !p.time);
    const food = rest.filter((p) => isFood(p.place));
    const evening = rest.filter((p) => eveningOnly(p.place));
    const sights = rest.filter((p) => !isFood(p.place) && !eveningOnly(p.place))
      .sort((a, b) => Number(/M/.test(b.place.slots || "")) - Number(/M/.test(a.place.slots || "")));
    const snacks = food.filter((p) => snack(p.place));
    const meals = food.filter((p) => !snack(p.place));
    const lunchFood = meals.filter((p, i) => (/L/.test(p.place.slots || "") || !/[BD]/.test(p.place.slots || "")) &&
      !(i > 0 && /D/.test(p.place.slots || "")));
    const dinnerFood = meals.filter((p) => !lunchFood.includes(p));
    let cursor = info.start;
    for (const p of sights) {
      if (fullDay(p.place)) { cursor = place(p, Math.max(cursor, 9 * 60)) + BUFFER; continue; }
      if (cursor + visitMinutes(p.place) > LUNCH + 30 && cursor < LUNCH + 60) {
        const lunch = lunchFood.shift();
        if (lunch) cursor = place(lunch, Math.max(cursor, LUNCH)) + BUFFER;
        else cursor = Math.max(cursor, LUNCH + 60);
      }
      let at = /M/.test(p.place.slots || "") ? cursor : Math.max(cursor, LUNCH + 90);
      const dur = visitMinutes(p.place);
      const first = freeAt(at, dur);
      if (first < LUNCH + 60 && first + dur > LUNCH + 30 && first > LUNCH - 60) at = LUNCH + 60;   // not across lunch
      cursor = place(p, at) + BUFFER;
    }
    const hadLunch = () => out.some((o) => o.day === day && byKey.get(o.key) && isFood(byKey.get(o.key).place) &&
      toMin(o.time) >= 10 * 60 && toMin(o.time) < 14 * 60);
    for (const p of lunchFood) place(p, info.start > LUNCH + 60 || hadLunch() ? DINNER : LUNCH);
    for (const p of snacks) place(p, Math.max(cursor, 15 * 60));
    for (const p of dinnerFood) place(p, /B/.test(p.place.slots || "") && !/D/.test(p.place.slots || "") ? 8 * 60 + 30 : DINNER);
    let night = Math.max(EVENING, info.start);
    for (const p of evening) night = place(p, night) + BUFFER;
  }
  return out;
}

module.exports = { schedule, toMin, toHHMM };
