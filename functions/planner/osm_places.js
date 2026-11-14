
const USER_AGENT = "Voya-FYP/1.0 (group trip planner; contact via app)";
const OVERPASS = "https://overpass-api.de/api/interpreter";
const NOMINATIM = "https://nominatim.openstreetmap.org/search";
const RADIUS_M = 12000;              // around the city centre
const KEEP = 5;
const TIMEOUT_MS = 9000;

const OSM_QUERY = {
  "night market": ['["amenity"="marketplace"]["name"~"night|夜市|pasar malam|ตลาดนัด|야시장|chợ đêm|jodd|ratchada",i]',
    '["amenity"="marketplace"]["opening_hours"~"(1[7-9]|2[0-3]):[0-9]{2}-(2[0-3]|0[0-2]):"]'],
  "street food": ['["amenity"="food_court"]', '["amenity"="marketplace"]["name"~"food|小吃|hawker",i]'],
  massage: ['["shop"="massage"]', '["leisure"="spa"]', '["amenity"="spa"]'],
  cafe: ['["amenity"="cafe"]'],
  brunch: ['["amenity"="cafe"]["cuisine"~"breakfast|brunch|coffee_shop",i]', '["amenity"="restaurant"]["cuisine"~"breakfast|brunch",i]'],
  dessert: ['["amenity"="ice_cream"]', '["shop"="pastry"]', '["amenity"="cafe"]["cuisine"~"dessert|cake|ice_cream|bubble_tea",i]'],
  dumplings: ['["amenity"="restaurant"]["cuisine"~"dumpling",i]', '["amenity"="restaurant"]["name"~"dumpling|小笼|饺子|包子",i]'],
  "local food": [],                    // filled per country below
  museum: ['["tourism"="museum"]'],
  mall: ['["shop"="mall"]', '["shop"="department_store"]'],
  park: ['["leisure"="park"]["wikidata"]', '["leisure"="park"]["tourism"]'],
  temple: ['["amenity"="place_of_worship"]["religion"~"buddhist|hindu|taoist|shinto|chinese_folk"]["tourism"]',
    '["amenity"="place_of_worship"]["religion"~"buddhist|hindu|taoist|shinto|chinese_folk"]["wikidata"]'],
  beach: ['["natural"="beach"]'],
  "rooftop bar": ['["amenity"="bar"]["rooftop"="yes"]', '["amenity"="bar"]["name"~"rooftop|sky",i]'],
  "floating market": ['["amenity"="marketplace"]["name"~"floating|ตลาดน้ำ|水上",i]'],
};
const LOCAL_CUISINE_TAG = { TH: "thai", MY: "malaysian|malay", SG: "singaporean|hawker", ID: "indonesian|balinese", JP: "japanese|ramen|sushi",
  KR: "korean", TW: "taiwanese", HK: "cantonese|dim_sum", VN: "vietnamese", CN: "chinese|shanghai|cantonese" };

const isFood = (kind) => ["street food", "cafe", "brunch", "dessert", "dumplings", "local food"].includes(kind);
const norm = (s) => String(s || "").trim().toLowerCase();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const titleCase = (s) => String(s || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

function km(aLat, aLon, bLat, bLon) {
  const r = Math.PI / 180;
  const x = (bLon - aLon) * r * Math.cos(((aLat + bLat) / 2) * r);
  const y = (bLat - aLat) * r;
  return Math.sqrt(x * x + y * y) * 6371;
}

async function getJson(url, init = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(url, { ...init, signal: ctrl.signal, headers: { "User-Agent": USER_AGENT, ...(init.headers || {}) } });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  } finally {
    clearTimeout(t);
  }
}

function overpassQuery(kind, lat, lon, country) {
  let sel = OSM_QUERY[kind] || [];
  if (kind === "local food") {
    const c = LOCAL_CUISINE_TAG[country] || "regional";
    sel = [`["amenity"="restaurant"]["cuisine"~"${c}",i]`];
  }
  if (!sel.length) return null;
  const parts = sel.map((s) => `nwr${s}["name"](around:${RADIUS_M},${lat},${lon});`).join("");
  return `[out:json][timeout:8];(${parts});out center tags 40;`;
}

// Raw OSM rows, straight off Overpass -- not yet in the catalog_attractions /
// catalog_restaurants display schema. toCatalogDoc() below converts one of
// these into the same shape the app's own live refresh writes, so a place
// found here and a place found by a traveller browsing Explore converge on
// one document (same id scheme: "osm_<n|w|r><id>") instead of two.
function rowsFromOverpass(elements, kind, { lat, lon, country, city }) {
  const seen = new Set();
  const rows = [];
  for (const e of elements || []) {
    const tags = e.tags || {};
    const plat = e.lat ?? (e.center && e.center.lat);
    const plon = e.lon ?? (e.center && e.center.lon);
    const name = tags["name:en"] || tags.int_name || tags.name;
    if (!name || plat == null || plon == null || seen.has(norm(name))) continue;
    seen.add(norm(name));
    const fame = (tags.wikidata ? 3 : 0) + (tags.wikipedia ? 2 : 0) + (tags.website || tags["contact:website"] ? 1 : 0) +
      (tags.opening_hours ? 0.5 : 0) + (tags["name:en"] ? 0.5 : 0);
    rows.push({
      id: `osm_${e.type[0]}${e.id}`,
      fame,
      dist: km(lat, lon, plat, plon),
      data: {
        name: tags.name || name,
        nameEn: tags["name:en"] || tags.int_name || "",
        category: kind.replace(/ /g, "_"),
        type: isFood(kind) ? "restaurant" : "attraction",
        country, city,
        district: tags["addr:suburb"] || tags["addr:district"] || tags["addr:city_district"] || tags["addr:quarter"] || "",
        lat: plat, lng: plon,
        website: tags.website || tags["contact:website"] || "",
        wikipedia: tags.wikipedia || "",
        openingHours: tags.opening_hours || "",
        cuisine: tags.cuisine || "",
      },
    });
  }
  rows.sort((a, b) => b.fame - a.fame || a.dist - b.dist);
  return rows.slice(0, KEEP);
}

// Builds the exact document that gets written to (and later read back from)
// catalog_attractions / catalog_restaurants -- the one and only collection
// this feature keeps data in. "needKey" is this specific need (e.g.
// "TH:museum") so a future trip to the same country can reuse the same
// document without a fresh Overpass call; "destinationKey" tags it for the
// current trip's own Explore-style display lookup.
function toCatalogDoc(d, kind, destinationKey, needKey) {
  const name = (d.nameEn && d.nameEn.trim()) || d.name;
  const nameLocal = d.name && d.name.trim() && d.name.trim() !== name ? d.name.trim() : null;
  const food = d.type === "restaurant" || isFood(kind);
  const { FieldValue } = require("firebase-admin/firestore");
  const common = {
    name,
    ...(nameLocal ? { nameLocal } : {}),
    location: d.city || "",
    address: d.district || "",
    lat: d.lat, lng: d.lng,
    website: d.website || "",
    openingHours: d.openingHours || "",
    phone: "",
    description: "",
    rating: "New",
    reviews: "0",
    destinationQuery: destinationKey,
    ...(d.country ? { country: d.country } : {}),
    ...(needKey ? { needKeys: FieldValue.arrayUnion(needKey) } : {}),
    source: "voya-summarise",
  };
  if (food) {
    const cuisineTags = d.cuisine ? String(d.cuisine).split(/[;,]/).map(titleCase) : [titleCase(kind)];
    return { collection: "catalog_restaurants", doc: { ...common, priceRange: "", cuisineTags } };
  }
  const cat = titleCase(d.category || kind);
  return { collection: "catalog_attractions", doc: { ...common, category: cat, categories: [cat], price: "" } };
}

// Shape handed to the itinerary builder -- unchanged regardless of whether
// the place came from an existing catalog doc or a fresh OSM find, so
// needs.js/schedule.js don't need to know which.
function toPlace(d, kind) {
  const food = d.collectionHint === "catalog_restaurants" || (d.cuisineTags !== undefined) || isFood(kind);
  return {
    name: d.name,
    type: food ? "restaurant" : "attraction",
    location: d.location || "",
    district: d.address || d.district || "",
    lat: d.lat, lng: d.lng,
    category: String((Array.isArray(d.categories) && d.categories[0]) || d.category || kind).replace(/_/g, " "),
    categories: [kind],
    cuisineTags: Array.isArray(d.cuisineTags) ? d.cuisineTags : (d.cuisine ? String(d.cuisine).split(/[;,]/) : []),
  };
}

function makeNeedLookup({ db, destination, fetchJson = getJson, maxLookups = 4, now = () => new Date() }) {
  const tripDestination = String(destination || "").trim();
  const destinationKey = tripDestination.toLowerCase();
  let cityP = null;
  let osmCalls = 0;
  // One lazily-loaded, per-country cache per collection -- loaded at most
  // once each per lookupNeed() run, same cost as the old catalog_places
  // query, just split across the two real display collections instead of
  // a separate reference one.
  const countryRowsByCollection = {};
  const city = async (name) => {
    if (!cityP) {
      const where = String(name || destination || "").trim();
      cityP = (async () => {
        const q = encodeURIComponent(where);
        if (!q) return null;
        const r = await fetchJson(`${NOMINATIM}?q=${q}&format=json&limit=1&addressdetails=1`);
        const hit = Array.isArray(r) && r[0];
        if (!hit) return null;
        return { lat: Number(hit.lat), lon: Number(hit.lon), country: String((hit.address && hit.address.country_code) || "").toUpperCase(),
          city: where.split(",")[0].trim() };
      })();
    }
    return cityP;
  };

  const loadCountryRows = (collectionName, country) => {
    const cacheKey = `${collectionName}:${country}`;
    if (!countryRowsByCollection[cacheKey]) {
      countryRowsByCollection[cacheKey] = db.collection(collectionName).where("country", "==", country).limit(800).get()
        .then((s) => s.docs.map((d) => ({ ...d.data(), _id: d.id, _collection: collectionName }))).catch(() => []);
    }
    return countryRowsByCollection[cacheKey];
  };

  return async function lookupNeed(need, cityName) {
    try {
      const c = await city(cityName);
      if (!c || !c.country) return [];
      const key = `${c.country}:${need.kind}`;
      const collectionName = isFood(need.kind) ? "catalog_restaurants" : "catalog_attractions";
      const rows = await loadCountryRows(collectionName, c.country);
      const near = rows.filter((d) => d.lat != null && d.lng != null && km(c.lat, c.lon, d.lat, d.lng) <= RADIUS_M / 1000 + 3);
      const known = near.filter((d) => (Array.isArray(d.needKeys) && d.needKeys.includes(key)) ||
        need.fits.test(`${d.name || ""} ${d.nameLocal || ""} ${String((Array.isArray(d.categories) && d.categories[0]) || d.category || "").replace(/_/g, " ")}`));
      if (known.length) {
        const top = known.slice(0, KEEP);
        const { FieldValue } = require("firebase-admin/firestore");
        const batch = db.batch();
        for (const d of top) {
          // Already live in the one display collection -- just stamp this
          // trip's destination on it (and remember the need-match for next
          // time) instead of writing a second copy anywhere.
          batch.set(db.collection(d._collection).doc(d._id),
            { destinationQuery: destinationKey, needKeys: FieldValue.arrayUnion(key) }, { merge: true });
        }
        await batch.commit().catch((err) => console.error("catalog stamp failed", err.message));
        return top.map((d) => toPlace(d, need.kind));
      }

      if (osmCalls >= maxLookups) return [];
      const q = overpassQuery(need.kind, c.lat, c.lon, c.country);
      if (!q) return [];
      osmCalls++;
      if (osmCalls > 1) await sleep(300);
      const r = await fetchJson(OVERPASS, { method: "POST", body: `data=${encodeURIComponent(q)}`,
        headers: { "Content-Type": "application/x-www-form-urlencoded" } });
      const found = rowsFromOverpass(r && r.elements, need.kind, c);
      if (!found.length) return [];
      const batch = db.batch();
      const builtDocs = [];
      for (const row of found) {
        const { collection, doc } = toCatalogDoc(row.data, need.kind, destinationKey, key);
        batch.set(db.collection(collection).doc(row.id), { ...doc, fetchedAt: now() }, { merge: true });
        builtDocs.push(doc);
      }
      await batch.commit().catch((err) => console.error("catalog write failed", err.message));
      return builtDocs.map((d) => toPlace(d, need.kind));
    } catch (err) {
      console.error("lookupNeed failed", need && need.kind, err && err.message);
      return [];
    }
  };
}

module.exports = { makeNeedLookup, overpassQuery, rowsFromOverpass, toCatalogDoc, toPlace, OSM_QUERY };
