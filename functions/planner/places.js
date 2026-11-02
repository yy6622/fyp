
const GAZ = require("./gazetteer.json");

const CJK = /[一-鿿]/;
const norm = (s) => String(s || "").normalize("NFKC").toLowerCase().replace(/\s+/g, " ").trim();

function placesFor(destination) {
  const d = norm(destination);
  const city = GAZ.cities.find((c) => c.aliases.some((a) => a.length >= 2 && d.includes(a)) || norm(c.city) === d);
  const name = city ? city.city : null;
  return {
    city: name,
    places: name ? GAZ.places.filter((p) => p.city === name) : [],
    areas: name ? GAZ.areas.filter((a) => a.city === name) : [],
    cities: GAZ.cities,
  };
}

const CITY_WORDS = new Set(GAZ.cities.flatMap((c) => [norm(c.city), ...c.aliases, norm(c.city.split(",")[0])]));
function districtOf(p) {
  const d = String(p.district || "").trim();
  if (d) return d;
  const loc = String(p.location || "").trim();
  const first = loc.split(",")[0].trim();
  if (!first || CITY_WORDS.has(norm(loc)) || CITY_WORDS.has(norm(first))) return "";
  if (/\d/.test(first) || first.split(/\s+/).length > 3 || /\b(jalan|jln|road|rd|street|st|soi|lorong|avenue|ave)\b|路|街|号/i.test(first)) return "";
  return first;
}

function fromCatalog(list, source) {
  return (list || []).filter((p) => p && p.name).map((p) => {
    const food = p.type === "restaurant";
    const tags = [p.category, ...(p.categories || []), ...(p.cuisineTags || [])].filter(Boolean).map((t) => norm(t));
    const hours = parseFloat(String(p.recommendedDuration || "").replace(/[^0-9.]/g, "")) || (food ? 1.0 : 2.0);
    return {
      name: String(p.name).trim(),
      area: String(p.location || "").trim(),
      district: districtOf(p),
      icon: food ? "food" : (p.icon || (tags.some((t) => /shop|mall|market/.test(t)) ? "shopping" : "place")),
      slots: food ? (tags.some((t) => /cafe|café|coffee|brunch|breakfast|dessert|bakery/.test(t)) ? "BLA" : "LD") : "MAE",
      hours: Math.min(Math.max(hours, 0.5), 8),
      tags,
      aliases: [norm(p.name), ...(p.aliases || []).map(norm)].filter((a) => a.length >= 2),
      saved: source === "saved" ? { name: String(p.name).trim(), type: p.type || "attraction", location: String(p.location || "") } : null,
      catalogName: source === "catalog" || source === "osm" ? String(p.name).trim() : undefined,
      lat: p.lat, lng: p.lng,
      rating: p.rating, price: p.price,
      source,
    };
  });
}

function samePlace(a, b) {
  if (a.aliases.some((x) => b.aliases.includes(x))) return true;
  const long = (p) => p.aliases.filter((x) => (CJK.test(x) ? x.length >= 2 : x.length >= 5));
  return long(a).some((x) => b.aliases.some((y) => y.includes(x))) || long(b).some((x) => a.aliases.some((y) => y.includes(x)));
}

// Generic plan labels that are not a place the group could talk about by name.
const GENERIC_PLAN_LABEL = /^(breakfast|brunch|lunch|dinner|supper|check[ -]?in|check[ -]?out|hotel|flight|arrive|arrival|depart|departure|free time|rest|transfer|早餐|午餐|晚餐|入住|退房)\b/i;

function knownPlaces({ destination, saved = [], catalog = [], planned = [] }) {
  const base = placesFor(destination);
  const out = [];
  const add = (p) => {
    const hit = out.find((q) => norm(q.name) === norm(p.name)) || out.find((q) => samePlace(q, p));
    if (hit) {
      hit.aliases = [...new Set([...hit.aliases, ...p.aliases])];
      hit.tags = [...new Set([...(hit.tags || []), ...(p.tags || [])])];
      if (p.saved) { hit.saved = p.saved; hit.source = "saved"; }
      else if (p.source === "catalog" && hit.source === "voya") hit.catalogName = p.name;
      return;
    }
    out.push({ ...p, aliases: [...p.aliases], tags: [...(p.tags || [])] });
  };
  for (const p of base.places) add({ ...p, source: "voya", saved: null });
  for (const p of fromCatalog(catalog, "catalog")) add(p);
  for (const p of fromCatalog(saved, "saved")) add(p);
  // Items already in the plan are places too, even when the place list does not
  // know them (a custom activity like "Disneyland"). Without this, "no
  // Disneyland" could not be matched and was counted against the place
  // discussed just before it (TC27b).
  const custom = (planned || []).filter((it) => it && it.name && String(it.name).trim().length >= 4
    && !GENERIC_PLAN_LABEL.test(String(it.name).trim()));
  for (const p of fromCatalog(custom, "plan")) {
    if (!out.some((q) => samePlace(q, p))) add(p);
  }
  return { city: base.city, places: out, areas: base.areas, cities: base.cities };
}

// ---------------------------------------------------------------- matching

function isWordAt(text, start, end) {
  const before = start === 0 ? " " : text[start - 1];
  const after = end >= text.length ? " " : text[end];
  const letter = /[a-z0-9]/;
  return !letter.test(before) && !letter.test(after);
}

function aliasHits(text, places) {
  const t = norm(text);
  const hits = [];
  for (const p of places) {
    for (const a of p.aliases) {
      let i = t.indexOf(a);
      while (i >= 0) {
        const end = i + a.length;
        if (CJK.test(a) || isWordAt(t, i, end)) hits.push({ place: p, start: i, end, alias: a });
        i = t.indexOf(a, i + 1);
      }
    }
  }
  hits.sort((x, y) => (y.end - y.start) - (x.end - x.start) || x.start - y.start);
  const taken = [];
  const out = [];
  for (const h of hits) {
    if (taken.some(([s, e]) => h.start < e && s < h.end)) continue;
    taken.push([h.start, h.end]);
    out.push(h);
  }
  return out.sort((a, b) => a.start - b.start);
}

const ZH_SUFFIX = "(?:路|街|巷|公园|花园|园|寺|庙|宫|塔|博物馆|美术馆|纪念馆|科技馆|水族馆|广场|古镇|古城|老街|乐园|夜市|市场|码头|海滩|沙滩|山|湖|岛|桥|大厦|天地|动物园)";
const ZH_SUFFIX_RE = new RegExp(ZH_SUFFIX, "g");
const ZH_STOP_CHARS = new Set(Array.from(
  "的了是在我你他她它们一二三四五六七八九十两几条个些座家间所这那哪就便走进去来到如例吧呢吗啊呀也都还很太想要会可能和跟或与及把被给让从往向对说看逛坐吃住玩找带先再又最多少好有没不而但比较像等之外内上下里边旁近每各该其某啦嘛哦喔着过得地着呗么啥怎么样什么"));
const ZH_NOT_PLACE = /(迷路|走路|马路|一路|上路|带路|问路|找路|认路|顺路|道路|公路|线路|铁路|水路|山路|出路|半路|网路|思路|套路|心路|门路|来路|去路|进路|退路|岔路|街上|逛街|上街|过桥|搭桥|下山|上山|爬山|游湖|中心点|市中心)$/;
const ZH_GENERIC = /^(小|大|老|新|旧|附近|旁边|这|那|一)$/;
const EN_PATTERN = /\b((?:[A-Z][A-Za-z'’-]+\s){1,4}(?:Road|Street|St|Temple|Museum|Park|Market|Tower|Garden|Gardens|Bridge|Beach|Mall|Square|Hill|Lake|Island|Bay|Palace|Castle|Shrine|Zoo|Aquarium|Falls|Village|Cave|Caves|Pagoda|Mosque|Cathedral|Church|Fort|Harbour|Harbor|Pier|Waterfront))\b/g;

function patternHits(text, taken, members) {
  const out = [];
  const raw = String(text || "").normalize("NFKC");
  const chars = Array.from(raw);
  const offsets = [];
  let pos = 0;
  for (const ch of chars) { offsets.push(pos); pos += ch.length; }
  for (const m of raw.matchAll(ZH_SUFFIX_RE)) {
    const at = offsets.indexOf(m.index);
    if (at < 0) continue;
    let k = at;
    while (k > 0 && at - k < 6 && /[\u4e00-\u9fffA-Za-z0-9]/.test(chars[k - 1]) && !ZH_STOP_CHARS.has(chars[k - 1]) &&
      (at - k < 4 || /[A-Za-z0-9]/.test(chars[k - 1]))) k--;
    const prefix = chars.slice(k, at).join("");
    if (Array.from(prefix).length < 2 || ZH_GENERIC.test(prefix)) continue;
    const start = offsets[k];
    const name = prefix + m[0];
    if (ZH_NOT_PLACE.test(name)) continue;
    out.push({ name, start, end: start + name.length });
  }
  for (const m of raw.matchAll(EN_PATTERN)) {
    const name = m[1].trim();
    if (members.some((x) => name.toLowerCase().startsWith(String(x).toLowerCase() + " "))) continue;
    out.push({ name, start: m.index, end: m.index + name.length });
  }
  return out.filter((h) => !taken.some(([s, e]) => h.start < e && s < h.end));
}

function findPlaces(text, known, members = []) {
  const hits = aliasHits(text, known.places);
  const t = norm(text);
  const blocked = hits.map((h) => [h.start, h.end]);
  for (const a of [...known.areas, ...known.cities]) {
    for (const x of a.aliases) {
      if (x.length < 2) continue;
      let i = t.indexOf(x);
      while (i >= 0) { blocked.push([i, i + x.length]); i = t.indexOf(x, i + 1); }
    }
  }
  for (const pat of patternHits(text, blocked, members)) {
    const key = norm(pat.name);
    if (known.areas.some((a) => a.aliases.includes(key))) continue;
    if (known.cities.some((c) => c.aliases.includes(key))) continue;
    hits.push({
      place: { name: pat.name, area: "", district: pat.name, icon: "place", slots: "MAE", hours: 2.0,
        aliases: [key], source: "pattern" },
      start: pat.start, end: pat.end, alias: key,
    });
  }
  for (const h of hits) {
    const before = t.slice(Math.max(0, h.start - 6), h.start);
    h.compare = /(跟|和|像|比|好像|一样|than|like|as|similar to)\s*$/.test(before) &&
      /^(差不多|一样|类似|那样)/.test(t.slice(h.end, h.end + 4)) || /(similar to|same as|like)\s*$/.test(before);
    h.negated = /(不去|不要去|不要|不想去|不用去|skip|no|not|cancel|算了|别去|跳过)\s*$/.test(before);
  }
  return hits.sort((a, b) => a.start - b.start);
}

function findAreas(text, known) {
  const t = norm(text);
  const out = known.areas.filter((a) => a.aliases.some((x) => t.includes(x))).map((a) => a.name);
  for (const p of known.places) if (p.aliases.some((x) => x.length >= 2 && t.includes(x))) out.push(p.name);
  return [...new Set(out)];
}

function findCity(text, known) {
  const t = norm(text);
  for (const c of known.cities) {
    for (const a of c.aliases) {
      if (a.length < 2) continue;
      const i = t.indexOf(a);
      if (i >= 0 && (CJK.test(a) || isWordAt(t, i, i + a.length)) && !/^(中心|博物馆|动物园|迪士尼|tower|museum|disney)/.test(t.slice(i + a.length).trim())) {
        return c.city;
      }
    }
  }
  return null;
}

module.exports = { knownPlaces, findPlaces, findAreas, findCity, placesFor, norm, aliasHits, fromCatalog, districtOf };
