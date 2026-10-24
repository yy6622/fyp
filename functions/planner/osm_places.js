// Finding a real place for a wish nobody named ("夜市", "massage", "a café") when neither the group's
// saved list nor Voya's own place list (gazetteer + catalog_attractions / catalog_restaurants) has one:
//
//   1. catalog_places in Firestore: the OSM-derived place list the app already uses for Explore, plus
//      every place found by step 2 on an earlier run (`needKeys` = ["TH:night market", ...]).
//   2. OpenStreetMap (Nominatim to find the city, Overpass for places of that kind around it). What
//      is found is written to catalog_places, so the next trip to that city finds it in step 1.
// The place picked is also copied to catalog_attractions / catalog_restaurants for the trip's destination,
// so the plan shows it as a rich activity card, like a saved place.
//
// Never fails AI Summarise: any error, timeout or empty answer just returns [] and the planner falls
// back to a time block ("Night market - pick a place"). No AI model involved.

const USER_AGENT = "Voya-FYP/1.0 (group trip planner; contact via app)";
const OVERPASS = "https://overpass-api.de/api/interpreter";
const NOMINATIM = "https://nominatim.openstreetmap.org/search";
const RADIUS_M = 12000;              // around the city centre
const KEEP = 5;                      // places saved per wish per city
const TIMEOUT_MS = 9000;

// Overpass selectors per wish (needs.js `kind`). Every selector also needs a name.
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

/** Overpass QL for one wish around a point. */
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

/** Overpass elements -> catalog_places rows (best first: well-known, then close to the centre). */
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
        source: "voya-osm",
      },
    });
  }
  rows.sort((a, b) => b.fame - a.fame || a.dist - b.dist);
  return rows.slice(0, KEEP);
}

/** Planner place (planner/places.js shape) from a catalog_places row. */
function toPlace(d, kind) {
  const name = (d.nameEn && d.nameEn.trim()) || d.name;
  return {
    name, type: d.type === "restaurant" || isFood(kind) ? "restaurant" : "attraction",
    location: d.city || "", district: d.district || "", lat: d.lat, lng: d.lng,
    category: String(d.category || kind).replace(/_/g, " "),
    categories: [kind], cuisineTags: d.cuisine ? String(d.cuisine).split(/[;,]/) : [],
  };
}

const titleCase = (s) => String(s || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

/**
 * The app shows an activity as a rich card when its name matches a catalog_attractions /
 * catalog_restaurants document for the trip's destination (GroupTripController). So a place found in
 * catalog_places / OpenStreetMap is also written there, the same way the app's Explore tab copies
 * catalog_places rows (doc id "place_<catalog_places id>", destinationQuery = destination in lower case).
 */
async function mirrorToCatalog(db, rows, destination, kind) {
  const key = String(destination || "").trim().toLowerCase();
  if (!key || !rows.length) return;
  const batch = db.batch();
  for (const { id, data: d } of rows) {
    const name = (d.nameEn && d.nameEn.trim()) || d.name;
    const food = d.type === "restaurant" || isFood(kind);
    const common = { name, location: String(destination).trim(), destinationQuery: key, website: d.website || "",
      openingHours: d.openingHours || "", address: d.district || "", phone: "", description: "", rating: "New", reviews: "0",
      lat: d.lat, lng: d.lng, district: d.district || "", ...(d.imageUrl ? { image: d.imageUrl } : {}), source: "voya-summarise" };
    if (food) {
      batch.set(db.collection("catalog_restaurants").doc(`place_${id}`), { ...common, priceRange: "",
        cuisineTags: d.cuisine ? String(d.cuisine).split(/[;,]/).map(titleCase) : [titleCase(kind)] }, { merge: true });
    } else {
      const cat = titleCase(d.category || kind);
      batch.set(db.collection("catalog_attractions").doc(`place_${id}`), { ...common, category: cat, categories: [cat], price: "" },
        { merge: true });
    }
  }
  await batch.commit().catch((err) => console.error("catalog mirror failed", err.message));
}

/**
 * Makes the `lookupNeed(need)` function the planner calls (itinerary_engine.js). One per request:
 * the city is geocoded once, and at most `maxLookups` wishes go to OpenStreetMap.
 * db: Firestore (Admin SDK)   destination: "Bangkok"   fetchJson: injectable for tests
 */
function makeNeedLookup({ db, destination, fetchJson = getJson, maxLookups = 4, now = () => new Date() }) {
  const tripDestination = String(destination || "").trim();
  let cityP = null;
  let countryRows = null;
  let osmCalls = 0;
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

  /** need: an entry of needs.js NEEDS; cityName: the trip's city as the planner knows it ("Bangkok, Thailand") */
  return async function lookupNeed(need, cityName) {
    try {
      const c = await city(cityName);
      if (!c || !c.country) return [];
      const key = `${c.country}:${need.kind}`;
      // 1. catalog_places: rows found for this wish before, or OSM-scraped rows of that kind nearby
      if (!countryRows) {
        countryRows = db.collection("catalog_places").where("country", "==", c.country).limit(800).get()
          .then((s) => s.docs.map((d) => ({ ...d.data(), _id: d.id }))).catch(() => []);
      }
      const near = (await countryRows).filter((d) => d.lat != null && d.lng != null && km(c.lat, c.lon, d.lat, d.lng) <= RADIUS_M / 1000 + 3);
      const known = near.filter((d) => (Array.isArray(d.needKeys) && d.needKeys.includes(key)) ||
        need.fits.test(`${d.name} ${d.nameEn || ""} ${String(d.category || "").replace(/_/g, " ")}`));
      if (known.length) {
        const top = known.slice(0, KEEP);
        await mirrorToCatalog(db, top.map((d) => ({ id: d._id, data: d })), tripDestination || c.city, need.kind);
        return top.map((d) => toPlace(d, need.kind));
      }

      // 2. OpenStreetMap, then remember the result in catalog_places
      if (osmCalls >= maxLookups) return [];
      const q = overpassQuery(need.kind, c.lat, c.lon, c.country);
      if (!q) return [];
      osmCalls++;
      if (osmCalls > 1) await sleep(300);          // be polite to the public Overpass server
      const r = await fetchJson(OVERPASS, { method: "POST", body: `data=${encodeURIComponent(q)}`,
        headers: { "Content-Type": "application/x-www-form-urlencoded" } });
      const rows = rowsFromOverpass(r && r.elements, need.kind, c);
      if (!rows.length) return [];
      const { FieldValue } = require("firebase-admin/firestore");
      const batch = db.batch();
      for (const row of rows) {
        batch.set(db.collection("catalog_places").doc(row.id),
          { ...row.data, needKeys: FieldValue.arrayUnion(key), fetchedAt: now() }, { merge: true });
      }
      await batch.commit().catch((err) => console.error("catalog_places write failed", err.message));
      await mirrorToCatalog(db, rows, tripDestination || c.city, need.kind);
      return rows.map((row) => toPlace(row.data, need.kind));
    } catch (err) {
      console.error("lookupNeed failed", need && need.kind, err && err.message);
      return [];
    }
  };
}

module.exports = { makeNeedLookup, overpassQuery, rowsFromOverpass, toPlace, mirrorToCatalog, OSM_QUERY };
