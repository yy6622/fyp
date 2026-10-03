// Talks to Geoapify's Places API (https://api.geoapify.com) — built on
// OpenStreetMap data — to search for real-world attractions and map results
// onto Voya's own catalog_attractions schema (see js/data.js).
//
// Chosen over Google Places API specifically because of storage rights:
// Google's terms only allow keeping the bare Place ID indefinitely — every
// other field (name, address, photos...) must be dropped or re-fetched
// within 30 days, which rules out "import once, keep forever in Firestore".
// Geoapify's terms explicitly allow permanently caching/storing results in
// your own database, as long as you keep attribution to OpenStreetMap (and,
// on the free plan, to Geoapify) — see the notice in the import modal in
// admin/attractions.html. Docs: https://apidocs.geoapify.com/docs/places/
import { GEOAPIFY_API_KEY } from "./places-config.js";

const GEOCODE_URL = "https://api.geoapify.com/v1/geocode/search";
const PLACES_URL = "https://api.geoapify.com/v2/places";
const PLACE_DETAILS_URL = "https://api.geoapify.com/v2/place-details";

export function hasApiKey() {
  return !!GEOAPIFY_API_KEY && GEOAPIFY_API_KEY !== "PASTE_YOUR_GEOAPIFY_API_KEY_HERE";
}

/**
 * Friendly category groups shown as chips in the sweep UI, mapped to the
 * real (dotted) Geoapify category codes their Places API expects. A value
 * can be a comma-separated list — Geoapify treats that as OR. If an admin
 * types a category that isn't in this dictionary, it's passed straight
 * through as a raw category code (see categoriesForLabel below), so a
 * specific code from Geoapify's own category list still works even though
 * it isn't one of these friendly presets.
 */
const CATEGORY_GROUPS = {
  "Tourist attractions": "tourism.attraction",
  "Landmarks & sights": "tourism.sights",
  "Museums": "entertainment.museum",
  "Art & culture": "entertainment.culture",
  "Zoos & aquariums": "entertainment.zoo,entertainment.aquarium",
  "Theme parks": "entertainment.theme_park",
  "Parks & gardens": "leisure.park",
  "Nature reserves": "natural.protected_area,natural.forest",
  "Mountains & caves": "natural.mountain",
  "Water & coast": "natural.water,natural.coastal",
  "Heritage sites": "heritage",
  "Shopping": "commercial.shopping_mall,commercial.marketplace",
};
export const DEFAULT_SWEEP_KEYWORDS = Object.keys(CATEGORY_GROUPS);

function categoriesForLabel(label) {
  return CATEGORY_GROUPS[label] || label;
}

/** Resolves a free-text location ("Penang, Malaysia") to a Geoapify boundary place_id. */
export async function geocodeLocation(text) {
  if (!hasApiKey()) {
    throw new Error("Geoapify API key isn't set — open js/places-config.js and paste your key in.");
  }
  const url = `${GEOCODE_URL}?text=${encodeURIComponent(text)}&limit=1&format=json&apiKey=${GEOAPIFY_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Geocoding failed (HTTP ${res.status})`);
  const body = await res.json();
  const hit = body.results?.[0];
  if (!hit) throw new Error(`Couldn't find "${text}" — try a more specific name.`);
  return { placeId: hit.place_id, lat: hit.lat, lon: hit.lon, formatted: hit.formatted || text };
}

/** One Places search: everything matching `categoriesCsv` within boundary `placeId`. */
export async function searchGeoapifyPlaces(categoriesCsv, placeId, { limit = 50 } = {}) {
  if (!hasApiKey()) {
    throw new Error("Geoapify API key isn't set — open js/places-config.js and paste your key in.");
  }
  const url = `${PLACES_URL}?categories=${encodeURIComponent(categoriesCsv)}&filter=place:${placeId}&limit=${limit}&apiKey=${GEOAPIFY_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) {
    const errBody = await res.json().catch(() => ({}));
    throw new Error(errBody?.message || `Places API error (HTTP ${res.status})`);
  }
  const body = await res.json();
  return body.features || [];
}

/**
 * Runs one Places search per (location × category) combination, merges the
 * results into a single deduped list (by place_id — the same real place
 * can match more than one category), then fetches full Place Details
 * (website, phone, opening hours, an image if one exists) for EVERY unique
 * place found — not just ones the admin later selects — so the review
 * list already shows complete info before anything is imported. Each
 * location is geocoded once (cached per sweep) to resolve its search
 * boundary. This is the closest practical approximation of "get every
 * attraction": broad category coverage across every location given, not a
 * literal full-database export — no Places provider (Geoapify included)
 * offers that.
 *
 * Because every unique result gets its own Place Details call, API usage
 * scales with how many distinct places the sweep finds, not with how many
 * the admin ends up importing — keep the location/category lists to what
 * you actually need swept if you're watching the daily credit budget.
 *
 * `onProgress(phase, done, total, label)` fires after each step so the
 * caller can show real progress instead of a frozen button. `phase` is
 * "search" during the location×category sweep and "details" while
 * enriching the deduped results. A small delay between calls in both
 * phases avoids firing the whole batch at once.
 */
export async function sweepGeoapifyPlaces(locations, categoryLabels, { onProgress } = {}) {
  const combos = [];
  for (const location of locations) for (const label of categoryLabels) combos.push({ location, label });

  const geocodeCache = new Map();
  const byId = new Map();

  for (let i = 0; i < combos.length; i++) {
    const { location, label } = combos[i];
    try {
      let geo = geocodeCache.get(location);
      if (!geo) {
        geo = await geocodeLocation(location);
        geocodeCache.set(location, geo);
      }
      const features = await searchGeoapifyPlaces(categoriesForLabel(label), geo.placeId);
      for (const feature of features) {
        const placeId = feature.properties?.place_id;
        if (placeId && !byId.has(placeId)) {
          byId.set(placeId, mapPlaceToAttraction(feature, { location: geo.formatted }));
        }
      }
    } catch (err) {
      // One bad combo (typo'd location, empty category match) shouldn't
      // abort the whole sweep — note it in the progress label and continue.
      onProgress?.("search", i + 1, combos.length, `"${label}" in "${location}" failed: ${err.message}`);
      continue;
    }
    onProgress?.("search", i + 1, combos.length, `"${label}" in "${location}"`);
    if (i < combos.length - 1) await new Promise((r) => setTimeout(r, 180));
  }

  const results = Array.from(byId.values());
  for (let i = 0; i < results.length; i++) {
    const details = await enrichPlaceDetails(results[i].sourcePlaceId);
    results[i].website = details.website || results[i].website;
    results[i].phone = details.phone || results[i].phone;
    results[i].openingHours = details.openingHours || results[i].openingHours;
    results[i].highlights = details.highlights?.length ? details.highlights : results[i].highlights;
    results[i].image = details.image || results[i].image;
    results[i].images = details.image ? [details.image] : results[i].images;
    onProgress?.("details", i + 1, results.length, results[i].name || "");
    if (i < results.length - 1) await new Promise((r) => setTimeout(r, 150));
  }
  return results;
}

// Geoapify's category taxonomy is much finer-grained than Voya's category
// chips — this maps a result's categories (most specific first) onto one of
// the labels already used by the seeded/hand-added attractions (see
// catalog_repository.dart's _seedAttractions). Order matters: more specific
// prefixes are checked before generic ones.
const CATEGORY_BY_PREFIX = [
  ["entertainment.museum", "Museum"],
  ["entertainment.culture", "Art & Culture"],
  ["entertainment.zoo", "Adventure"],
  ["entertainment.aquarium", "Adventure"],
  ["entertainment.theme_park", "Adventure"],
  ["leisure.park", "Nature"],
  ["natural.", "Nature"],
  ["heritage", "Historic Site"],
  ["tourism.sights", "Historic Site"],
  ["commercial.shopping_mall", "Shopping"],
  ["commercial.marketplace", "Shopping"],
  ["tourism.attraction", "Landmark"],
  ["tourism.information", "Landmark"],
];

export function categoryFromGeoapifyCategories(categories = []) {
  for (const cat of categories) {
    const hit = CATEGORY_BY_PREFIX.find(([prefix]) => cat.startsWith(prefix));
    if (hit) return hit[1];
  }
  return "Attraction";
}

/**
 * Maps one Places search result onto Voya's catalog_attractions field
 * shape. Only basic search fields are available at this point (no
 * website/phone/hours/image yet — sweepGeoapifyPlaces fills those in for
 * every result via enrichPlaceDetails right after this runs). Geoapify/OSM
 * has no star-rating or review-count data, so those fields are left at
 * "0" — same placeholder convention already used for "no data yet" fields
 * elsewhere in this form.
 */
export function mapPlaceToAttraction(feature, { location = "" } = {}) {
  const p = feature.properties || {};
  const category = categoryFromGeoapifyCategories(p.categories);
  return {
    name: p.name || p.address_line1 || "",
    category,
    categories: [category],
    rating: "0",
    reviews: "0",
    price: "Free entry",
    fees: {},
    image: "",
    images: [],
    location: location || p.city || p.state || "",
    address: p.formatted || "",
    phone: "",
    website: "",
    recommendedDuration: "",
    openingHours: "",
    openingHoursByDay: {},
    facilities: [],
    highlights: [],
    // Imported rows start as "pending" purely as an admin-side reminder to
    // review/fill in fees + photos before treating them as real listings —
    // the mobile app doesn't read `status` at all, so this doesn't hide
    // them from Explore on its own (see the note in js/data.js).
    status: "pending",
    sourcePlaceId: p.place_id,
    source: "Geoapify",
  };
}

/**
 * Fetches the richer Place Details fields (website, phone, an OSM-format
 * opening-hours string, a short description, an image if OSM/Wikidata has
 * one) for ONE place. Called by sweepGeoapifyPlaces for every unique result
 * it finds. Best-effort: a failed lookup returns {} rather than throwing,
 * so one bad detail fetch doesn't block enriching/importing the rest.
 * Geoapify's opening_hours is a single raw OSM-syntax string (e.g.
 * "Mo-Fr 09:00-18:00; Sa 09:00-13:00"), not split per day the way Google's
 * response was — parsing that syntax reliably is its own project, so it's
 * stored as-is in `openingHours` and left for the admin to split into
 * `openingHoursByDay` from the Edit form if they want that detail.
 */
export async function enrichPlaceDetails(placeId) {
  if (!hasApiKey() || !placeId) return {};
  try {
    const url = `${PLACE_DETAILS_URL}?id=${encodeURIComponent(placeId)}&apiKey=${GEOAPIFY_API_KEY}`;
    const res = await fetch(url);
    if (!res.ok) return {};
    const body = await res.json().catch(() => null);
    const p = body?.features?.[0]?.properties;
    if (!p) return {};
    return {
      website: p.website || p.website_other || "",
      phone: p.contact?.phone || "",
      openingHours: p.opening_hours || "",
      highlights: p.description ? [p.description] : [],
      image: p.wiki_and_media?.image || "",
    };
  } catch {
    return {};
  }
}
