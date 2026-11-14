// Talks to Geoapify's Geocoding + Place Details APIs (https://api.geoapify.com)
// — built on OpenStreetMap data — to look up ONE place by name or location
// and map it onto Voya's own catalog_attractions schema (see js/data.js), so
// the Add/Edit Attraction form (admin/attraction-form.html) can auto-fill
// itself from a single text search instead of the admin typing everything
// by hand.
//
// Chosen over Google Places API specifically because of storage rights:
// Google's terms only allow keeping the bare Place ID indefinitely — every
// other field (name, address, photos...) must be dropped or re-fetched
// within 30 days, which rules out "look it up once, keep the result forever
// in Firestore". Geoapify's terms explicitly allow permanently caching/
// storing results in your own database, as long as you keep attribution to
// OpenStreetMap (and, on the free plan, to Geoapify). Docs:
// https://apidocs.geoapify.com/docs/geocoding/ and
// https://apidocs.geoapify.com/docs/places/#place-details
import { GEOAPIFY_API_KEY } from "./places-config.js";

const GEOCODE_URL = "https://api.geoapify.com/v1/geocode/search";
const REVERSE_GEOCODE_URL = "https://api.geoapify.com/v1/geocode/reverse";
const PLACE_DETAILS_URL = "https://api.geoapify.com/v2/place-details";
const PLACES_URL = "https://api.geoapify.com/v2/places";
// Wikipedia's own public REST/API endpoints — free, no key, CORS-enabled
// (Wikimedia serves Access-Control-Allow-Origin: * on these), used only as
// a fallback image source when Geoapify's Place Details didn't return one.
const WIKI_SUMMARY_URL = "https://en.wikipedia.org/api/rest_v1/page/summary/";
const WIKI_SEARCH_URL = "https://en.wikipedia.org/w/api.php";

export function hasApiKey() {
  return !!GEOAPIFY_API_KEY && GEOAPIFY_API_KEY !== "PASTE_YOUR_GEOAPIFY_API_KEY_HERE";
}

// Geoapify's category taxonomy is much finer-grained than Voya's category
// chips — this maps a result's categories (most specific first) onto one of
// the labels already used by the seeded/hand-added attractions (see
// catalog_repository.dart's _seedAttractions). Order matters: more specific
// prefixes are checked before generic ones. Expanded (2026-11-12) to cover
// the real Geoapify tourism/entertainment taxonomy more fully — previously
// most of entertainment.* (cinema, arcade, escape game, water park, ...)
// and every tourism.attraction.* leaf had no entry and fell through to the
// generic "Attraction" bucket, which only ever matches the "Landmark"
// filter chip — so picking Museum/Nature/Adventure/Cultural/Shopping
// returned far fewer real results than the catalogue actually has, and
// "Landmark" became a catch-all for anything uncategorized, which is what
// made it feel unrelated to what was actually picked.
const CATEGORY_BY_PREFIX = [
  ["entertainment.museum", "Museum"],
  ["entertainment.planetarium", "Museum"],
  ["entertainment.culture", "Art & Culture"],
  ["entertainment.zoo", "Adventure"],
  ["entertainment.aquarium", "Adventure"],
  ["entertainment.theme_park", "Adventure"],
  ["entertainment.water_park", "Adventure"],
  ["entertainment.activity_park", "Adventure"],
  ["entertainment.amusement_arcade", "Adventure"],
  ["entertainment.bowling_alley", "Adventure"],
  ["entertainment.escape_game", "Adventure"],
  ["entertainment.flying_fox", "Adventure"],
  ["entertainment.miniature_golf", "Adventure"],
  // Checked before the broader "tourism.attraction" entry below, since
  // startsWith would otherwise match this too and it has its own, more
  // fitting bucket (a viewpoint is scenery, not really a landmark).
  ["tourism.attraction.viewpoint", "Nature"],
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

// Short, honest "About" text generated purely from fields the catalogue
// already has for this record (name/category/location) -- used whenever
// neither Geoapify's Place Details nor Wikipedia produced a real
// description. Deliberately never repeats address/phone/website/opening
// hours (detail_page_attraction.dart already shows those as their own
// fields -- restating them here would just be redundant padding, the same
// lesson learned writing catalog_restaurants' description generator).
const CATEGORY_DESCRIPTOR = {
  Museum: "museum",
  "Art & Culture": "cultural venue",
  Adventure: "attraction",
  Nature: "natural attraction",
  "Historic Site": "historic site",
  Shopping: "shopping destination",
  Landmark: "landmark",
};
export function generateFallbackDescription({ name = "", category = "", location = "", address = "" } = {}) {
  const n = name.trim() || "This place";
  const descriptor = CATEGORY_DESCRIPTOR[category] || "attraction";
  const article = /^[aeiou]/i.test(descriptor) ? "an" : "a";
  const place = location.trim() || address.split(",").slice(-2).join(",").trim();
  return place
    ? `${n} is ${article} ${descriptor} in ${place}, worth a visit if you're exploring the area.`
    : `${n} is ${article} ${descriptor} worth a visit if you're exploring the area.`;
}

// One verified, real, freely-licensed (Wikimedia Commons) photo per
// category -- used ONLY when a specific place has no real photo of its
// own (no Geoapify/Wikidata image, no matching Wikipedia article). This is
// an honest "generic photo of what a place in this category looks like",
// same accepted pattern already used for catalog_restaurants' cuisine
// stock fallbacks -- never presented as a photo of the specific place.
// Each URL was Image().onload-verified before being hardcoded here.
export const CATEGORY_FALLBACK_IMAGE = {
  Museum: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Moscow_MSU_Zoological_Museum_asv2021-07_img11.jpg/960px-Moscow_MSU_Zoological_Museum_asv2021-07_img11.jpg",
  "Art & Culture": "https://upload.wikimedia.org/wikipedia/commons/7/75/Exhibition_room%2C_Art_Gallery%2C_Montreal%2C_QC%2C_1879.jpg",
  Adventure: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fb/Makalali_Game_Reserve_%28ZA%29%2C_Mond_--_2024_--_1818.jpg/960px-Makalali_Game_Reserve_%28ZA%29%2C_Mond_--_2024_--_1818.jpg",
  Nature: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Blue_Mountains_National_Park_%28AU%29%2C_Jamison_Valley_--_2019_--_1903.jpg/960px-Blue_Mountains_National_Park_%28AU%29%2C_Jamison_Valley_--_2019_--_1903.jpg",
  "Historic Site": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/Ancient_Church_Ruins_-_geograph.org.uk_-_6905984.jpg/960px-Ancient_Church_Ruins_-_geograph.org.uk_-_6905984.jpg",
  Shopping: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Atrium_in_the_Myer_Centre_shopping_mall_Brisbane.jpg/960px-Atrium_in_the_Myer_Centre_shopping_mall_Brisbane.jpg",
  Landmark: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/The_Clock_Tower_of_Dobrich_%2823058674246%29.jpg/960px-The_Clock_Tower_of_Dobrich_%2823058674246%29.jpg",
  Attraction: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Mirador_de_la_Cruz_from_afar.jpg/960px-Mirador_de_la_Cruz_from_afar.jpg",
};
export function categoryFallbackImage(category = "") {
  return CATEGORY_FALLBACK_IMAGE[category] || CATEGORY_FALLBACK_IMAGE.Attraction;
}

/**
 * Maps one Geoapify result (a Places-search feature's `.properties`, or the
 * equivalent flat object the Geocoding API returns) onto Voya's
 * catalog_attractions field shape. Geoapify/OSM has no star-rating or
 * review-count data, so those are left out entirely here — the form keeps
 * whatever the admin already typed (or its own "0" placeholder) rather than
 * this function inventing a value.
 */
function mapPlaceToAttraction(p, { location = "" } = {}) {
  const category = categoryFromGeoapifyCategories(p.categories);
  return {
    name: p.name || p.address_line1 || "",
    category,
    categories: [category],
    location: location || p.city || p.state || "",
    address: p.formatted || "",
    phone: "",
    website: "",
    openingHours: "",
    description: "",
    highlights: [],
    image: "",
    sourcePlaceId: p.place_id || "",
    source: "Geoapify",
  };
}

/**
 * Fetches the richer Place Details fields (website, phone, an OSM-format
 * opening-hours string, a short description, an image if OSM/Wikidata has
 * one) for ONE place by its Geoapify place_id. Best-effort: a failed lookup
 * returns {} rather than throwing, so a missing detail doesn't block the
 * rest of the auto-fill. Geoapify's opening_hours is a single raw
 * OSM-syntax string (e.g. "Mo-Fr 09:00-18:00; Sa 09:00-13:00"), not split
 * per day — stored as-is and left for the admin to tidy up or split into
 * per-day hours on the form if they want that detail.
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
      description: p.description || "",
      image: p.wiki_and_media?.image || "",
    };
  } catch {
    return {};
  }
}

/**
 * Looks up a page image on Wikipedia for a place name, as a fallback for
 * when Geoapify's Place Details has no `wiki_and_media.image` — that field
 * only exists when OSM explicitly links the place to a Wikidata entry,
 * which plenty of real, well-known places are missing even though they
 * have a normal Wikipedia article. Tries the name as an exact article title
 * first (fast path via Wikipedia's REST summary endpoint), and if that
 * doesn't resolve, falls back to Wikipedia's own search API with
 * "name + location" to find the closest matching article and tries that
 * title instead. Best-effort and silent on failure (network blocked, no
 * match, ambiguous name) — returns "" rather than throwing, so a miss here
 * just leaves the Photos section empty for the admin to fill in by hand,
 * same as before this existed.
 */
async function fetchWikiSummaryImage(title) {
  try {
    const res = await fetch(`${WIKI_SUMMARY_URL}${encodeURIComponent(title)}`);
    if (!res.ok) return "";
    const body = await res.json().catch(() => null);
    return body?.thumbnail?.source || body?.originalimage?.source || "";
  } catch {
    return "";
  }
}

async function findWikipediaImage(name, location = "") {
  if (!name) return "";
  const direct = await fetchWikiSummaryImage(name);
  if (direct) return direct;
  try {
    const searchTerm = location ? `${name} ${location}` : name;
    const searchUrl = `${WIKI_SEARCH_URL}?action=query&list=search&srsearch=${encodeURIComponent(searchTerm)}&srlimit=1&format=json&origin=*`;
    const res = await fetch(searchUrl);
    if (!res.ok) return "";
    const body = await res.json().catch(() => null);
    const title = body?.query?.search?.[0]?.title;
    return title ? await fetchWikiSummaryImage(title) : "";
  } catch {
    return "";
  }
}

/**
 * Fills in a full address from coordinates when the forward geocode result
 * didn't come with one — happens for plenty of real OSM points of
 * interest (parks, landmarks, scenic spots) where whoever mapped it filled
 * in the name/category but never added street-address tags. The
 * coordinates themselves always exist (a geocoder result is a point on
 * the map by definition), so reverse-geocoding against OSM's broader
 * street/building data near that point can usually still produce a real
 * address even though the POI's own tags had none. Best-effort — returns
 * "" on any failure, same as every other optional enrichment here, so a
 * miss just leaves the admin to type the address in by hand (as it did
 * before this existed), not a blocked save.
 */
export async function reverseGeocodeAddress(lat, lon) {
  if (!hasApiKey() || lat == null || lon == null) return "";
  try {
    const url = `${REVERSE_GEOCODE_URL}?lat=${lat}&lon=${lon}&format=json&apiKey=${GEOAPIFY_API_KEY}`;
    const res = await fetch(url);
    if (!res.ok) return "";
    const body = await res.json().catch(() => null);
    return body?.results?.[0]?.formatted || "";
  } catch {
    return "";
  }
}

/**
 * Looks up JUST a full address for an existing record by its name +
 * location — used by the one-off "fill in missing addresses" backfill
 * tool, where every other field (category, phone, photo, etc.) is already
 * real admin-entered or previously-imported data that a full
 * findAndFillFromOsm() re-run shouldn't be allowed to overwrite. Same
 * forward-geocode-then-reverse-geocode-fallback pipeline as the address
 * part of findAndFillFromOsm(), just without touching anything else.
 * Returns "" (never throws) when nothing can be found, so the caller can
 * simply skip that record and move on to the next one.
 */
export async function findAddressOnly(name, location) {
  if (!hasApiKey()) return "";
  const text = [name, location].filter(Boolean).join(", ").trim();
  if (!text) return "";
  try {
    const url = `${GEOCODE_URL}?text=${encodeURIComponent(text)}&limit=1&format=json&apiKey=${GEOAPIFY_API_KEY}`;
    const res = await fetch(url);
    if (!res.ok) return "";
    const body = await res.json().catch(() => null);
    const hit = body?.results?.[0];
    if (!hit) return "";
    if (hit.formatted) return hit.formatted;
    if (hit.lat != null && hit.lon != null) return await reverseGeocodeAddress(hit.lat, hit.lon);
    return "";
  } catch {
    return "";
  }
}

/**
 * Looks up JUST a lat/lng for an existing record by its name + location
 * (and, when the record already has one, its own address text -- a full
 * street address geocodes far more precisely than "name + city" alone,
 * same reasoning as findAddressOnly() above but in the other direction).
 * Used by the one-off "fill in missing coordinates" backfill tool
 * (fill-missing-coordinates.html), where every other field is already
 * real data that tool shouldn't touch. Returns null (never throws) when
 * nothing can be found, so the caller can skip the record and move on.
 */
export async function findCoordinatesOnly(name, location, address) {
  if (!hasApiKey()) return null;
  const text = [address || null, !address ? name : null, !address ? location : null].filter(Boolean).join(", ").trim();
  if (!text) return null;
  try {
    const url = `${GEOCODE_URL}?text=${encodeURIComponent(text)}&limit=1&format=json&apiKey=${GEOAPIFY_API_KEY}`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const body = await res.json().catch(() => null);
    const hit = body?.results?.[0];
    if (!hit || hit.lat == null || hit.lon == null) return null;
    return { lat: hit.lat, lng: hit.lon };
  } catch {
    return null;
  }
}

/**
 * The single lookup behind the small "find on OpenStreetMap" button next to
 * the Name field on admin/attraction-form.html. Takes whatever the admin
 * typed — a specific name ("Senso-ji Temple") or just a location
 * ("Asakusa, Tokyo") — runs it through Geoapify's Geocoding API (the same
 * OSM-backed dataset the Places API uses, so a well-known POI's name
 * resolves straight to it), then fetches Place Details for the match to
 * fill in website/phone/hours/image — and if Geoapify didn't have an image,
 * tries Wikipedia directly as a fallback (see findWikipediaImage above).
 * Returns a plain object the caller applies onto the form; throws a
 * user-facing message if nothing matched.
 */
export async function findAndFillFromOsm(query) {
  if (!hasApiKey()) {
    throw new Error("Geoapify API key isn't set — open js/places-config.js and paste your key in.");
  }
  const text = (query || "").trim();
  if (!text) throw new Error("Type a name or location first.");

  const url = `${GEOCODE_URL}?text=${encodeURIComponent(text)}&limit=1&format=json&apiKey=${GEOAPIFY_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`OpenStreetMap search failed (HTTP ${res.status})`);
  const body = await res.json();
  const hit = body.results?.[0];
  if (!hit) throw new Error(`Couldn't find "${text}" on OpenStreetMap — try a different spelling, or add the city/country.`);

  const result = mapPlaceToAttraction(hit, { location: hit.city || hit.state || "" });

  if (hit.place_id) {
    const details = await enrichPlaceDetails(hit.place_id);
    result.website = details.website || result.website;
    result.phone = details.phone || result.phone;
    result.openingHours = details.openingHours || result.openingHours;
    result.description = details.description || result.description;
    result.image = details.image || result.image;
  }
  if (!result.address && hit.lat != null && hit.lon != null) {
    result.address = await reverseGeocodeAddress(hit.lat, hit.lon);
  }
  if (!result.image) {
    result.image = await findWikipediaImage(result.name, result.location);
  }
  if (!result.description) {
    result.description = generateFallbackDescription(result);
  }
  return result;
}

// ==================== Restaurant variant (admin/restaurant-form.html) ====================
// Same Geoapify lookup, mapped onto catalog_restaurants' schema instead of
// catalog_attractions' — cuisine tags (restricted to the same fixed preset
// list restaurant-form.html's picker uses, so an OSM match never produces a
// tag the admin couldn't also have picked by hand) instead of a category.
const CUISINE_BY_PREFIX = [
  ["catering.restaurant.japanese", "Japanese"],
  ["catering.restaurant.sushi", "Japanese"],
  ["catering.restaurant.chinese", "Chinese"],
  ["catering.restaurant.italian", "Italian"],
  ["catering.restaurant.pizza", "Italian"],
  ["catering.restaurant.indian", "Indian"],
  ["catering.restaurant.thai", "Thai"],
  ["catering.restaurant.korean", "Korean"],
  ["catering.restaurant.vietnamese", "Vietnamese"],
  ["catering.restaurant.seafood", "Seafood"],
  ["catering.restaurant.vegetarian", "Vegetarian"],
  ["catering.restaurant.vegan", "Vegetarian"],
  ["catering.restaurant.middle_eastern", "Middle Eastern"],
  ["catering.fast_food", "Fast Food"],
  ["catering.cafe", "Cafe & Dessert"],
  ["catering.ice_cream", "Cafe & Dessert"],
];

export function cuisineTagsFromGeoapifyCategories(categories = []) {
  const tags = new Set();
  for (const cat of categories) {
    const hit = CUISINE_BY_PREFIX.find(([prefix]) => cat.startsWith(prefix));
    if (hit) tags.add(hit[1]);
  }
  return [...tags];
}

function mapPlaceToRestaurant(p, { location = "" } = {}) {
  return {
    name: p.name || p.address_line1 || "",
    cuisineTags: cuisineTagsFromGeoapifyCategories(p.categories),
    location: location || p.city || p.state || "",
    address: p.formatted || "",
    priceRange: "",
    phone: "",
    website: "",
    openingHours: "",
    image: "",
    sourcePlaceId: p.place_id || "",
    source: "Geoapify",
  };
}

/** Restaurant-form equivalent of findAndFillFromOsm() above — same
 * Geocoding + Place Details + Wikipedia-image-fallback pipeline, mapped
 * onto catalog_restaurants' fields instead of catalog_attractions'. */
export async function findAndFillRestaurantFromOsm(query) {
  if (!hasApiKey()) {
    throw new Error("Geoapify API key isn't set — open js/places-config.js and paste your key in.");
  }
  const text = (query || "").trim();
  if (!text) throw new Error("Type a name or location first.");

  const url = `${GEOCODE_URL}?text=${encodeURIComponent(text)}&limit=1&format=json&apiKey=${GEOAPIFY_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`OpenStreetMap search failed (HTTP ${res.status})`);
  const body = await res.json();
  const hit = body.results?.[0];
  if (!hit) throw new Error(`Couldn't find "${text}" on OpenStreetMap — try a different spelling, or add the city/country.`);

  const result = mapPlaceToRestaurant(hit, { location: hit.city || hit.state || "" });

  if (hit.place_id) {
    const details = await enrichPlaceDetails(hit.place_id);
    result.website = details.website || result.website;
    result.phone = details.phone || result.phone;
    result.openingHours = details.openingHours || result.openingHours;
    result.image = details.image || result.image;
  }
  if (!result.address && hit.lat != null && hit.lon != null) {
    result.address = await reverseGeocodeAddress(hit.lat, hit.lon);
  }
  if (!result.image) {
    result.image = await findWikipediaImage(result.name, result.location);
  }
  return result;
}

// ==================== Bulk attraction import (admin/bulk-import-attractions.html) ====================
// Finds a batch of real, named tourist attractions near one destination's
// coordinates, mapped onto Voya's catalog_attractions schema (see
// mapPlaceToAttraction above) -- used to grow catalog_attractions'
// city coverage the same way catalog_restaurants already covers ~1,300
// cities, instead of staying limited to the handful of countries it's had
// so far.
//
// Categories are queried SEPARATELY, one category (group) per request,
// never combined into one big multi-category call. Investigated live for
// Singapore before writing this: a single combined request listing 10
// categories at limit=200 never once surfaced Gardens by the Bay,
// Singapore Zoo, or Marina Bay Sands -- all clearly real, famous,
// wikidata-tagged places. Querying leisure.park or entertainment.zoo on
// their own immediately found all three. The likely cause: Geoapify's
// Places API appears to split one shared result pool across however many
// categories a single call lists, so a handful of very high-volume
// categories (tourism.attraction's huge stock of public sculptures and
// war memorials, especially) crowd the genuinely famous but
// lower-volume-category places out of the response entirely. Separate
// calls cost more API quota but are the only way this actually works.
export const BULK_CATEGORY_GROUPS = [
  "entertainment.museum",
  "entertainment.culture",
  "entertainment.zoo,entertainment.aquarium,entertainment.theme_park",
  "leisure.park",
  "heritage",
  "tourism.attraction.viewpoint",
];

// Public sculptures/statues and war memorials are the dominant noise
// source in OSM's tourism.* tagging -- see the investigation note above.
// Excluded even from the narrower category list, in case one of these
// shows up tagged under e.g. heritage too.
function isLowValuePlace(categories = []) {
  return categories.some((c) => c.includes("artwork") || c.includes("memorial"));
}

// A rough "is this actually notable" score, used only to rank results
// within one city's combined pool -- Geoapify/OSM has no popularity metric
// of its own in this response, so a wikidata/wikipedia tag (mappers only
// add these to places with their own encyclopedia entry) is the strongest
// real signal available, backed up by which category group matched.
function scoreBulkPlace(props) {
  const raw = props.datasource?.raw || {};
  const cats = props.categories || [];
  let score = 0;
  if (raw.wikidata) score += 10;
  if (raw.wikipedia) score += 8;
  if (props.website) score += 2;
  if (cats.some((c) => c.startsWith("entertainment.museum"))) score += 6;
  if (cats.some((c) => c.startsWith("entertainment.zoo") || c.startsWith("entertainment.aquarium") || c.startsWith("entertainment.theme_park"))) score += 6;
  if (cats.some((c) => c.startsWith("heritage"))) score += 5;
  if (cats.some((c) => c.startsWith("tourism.attraction.viewpoint"))) score += 5;
  if (cats.some((c) => c.startsWith("leisure.park"))) score += 3;
  return score;
}

/**
 * Finds up to `limit` real attractions near (lat, lon), already mapped onto
 * catalog_attractions' field shape via mapPlaceToAttraction. `seenPlaceIds`
 * is a Set the caller keeps across the WHOLE bulk-import run (every city,
 * not just this one) -- a place already picked up by an earlier city's
 * search (two destinations' search circles can overlap) is skipped here so
 * the same real-world POI never gets written to Firestore twice. Returns
 * `{ attractions, categoryCallsFailed }` -- the admin tool uses the second
 * field to detect "the API key has run out of quota for today" (every
 * category call failing in a row) and pause the whole run rather than
 * silently writing nothing for hundreds of remaining cities.
 */
export async function findAttractionsNearCity({ lat, lon, location, limit = 15, radiusMeters = 20000, seenPlaceIds = new Set() }) {
  if (!hasApiKey() || lat == null || lon == null) return { attractions: [], categoryCallsFailed: 0 };
  const pool = [];
  let categoryCallsFailed = 0;
  for (const categories of BULK_CATEGORY_GROUPS) {
    try {
      const url = `${PLACES_URL}?categories=${encodeURIComponent(categories)}&filter=circle:${lon},${lat},${radiusMeters}&bias=proximity:${lon},${lat}&limit=15&apiKey=${GEOAPIFY_API_KEY}`;
      const res = await fetch(url);
      if (!res.ok) { categoryCallsFailed++; continue; } // one bad/quota-exhausted category shouldn't sink the whole city
      const body = await res.json().catch(() => null);
      for (const f of body?.features || []) {
        const props = f.properties;
        if (!props?.name) continue; // unnamed OSM nodes aren't useful in a traveller-facing catalogue
        if (isLowValuePlace(props.categories)) continue;
        if (seenPlaceIds.has(props.place_id)) continue;
        pool.push(props);
      }
    } catch {
      categoryCallsFailed++;
    }
    // a polite gap between the free-tier API's own category calls
    await new Promise((r) => setTimeout(r, 250));
  }
  // De-dup by place_id within this city's own combined pool -- a place can
  // legitimately match more than one of the category groups above (e.g. a
  // museum that's also tagged heritage).
  const byId = new Map();
  for (const props of pool) {
    if (!byId.has(props.place_id)) byId.set(props.place_id, props);
  }
  const ranked = [...byId.values()].sort((a, b) => scoreBulkPlace(b) - scoreBulkPlace(a));
  const picks = ranked.slice(0, limit).map((props) => {
    seenPlaceIds.add(props.place_id);
    return mapPlaceToAttraction(props, { location });
  });
  // Enrich each of the FINAL picks (never the whole candidate pool -- that
  // would multiply API calls many times over for nothing) with the same
  // Place Details + Wikipedia-image-fallback pipeline the single-place
  // "find on OpenStreetMap" flow already uses, so a bulk-imported
  // attraction isn't permanently stuck with a blank image/description the
  // way every earlier bulk-imported record was (see fill-geoapify-
  // attractions.html for the one-off catch-up on records imported before
  // this fix). Best-effort per place -- one slow/failed lookup never blocks
  // the rest of the city's picks or the overall import run.
  const attractions = [];
  for (const attraction of picks) {
    try {
      if (attraction.sourcePlaceId) {
        const details = await enrichPlaceDetails(attraction.sourcePlaceId);
        attraction.website = details.website || attraction.website;
        attraction.phone = details.phone || attraction.phone;
        attraction.openingHours = details.openingHours || attraction.openingHours;
        attraction.description = details.description || attraction.description;
        attraction.image = details.image || attraction.image;
      }
      if (!attraction.image) {
        attraction.image = await findWikipediaImage(attraction.name, attraction.location);
      }
      if (!attraction.image) {
        // Last resort so an automated bulk-import pick is never left with
        // literally no photo at all (that was the actual bug) -- an
        // honest, flagged category stock photo, same as the restaurant
        // cuisine fallback pattern.
        attraction.image = categoryFallbackImage(attraction.category);
        attraction.imageIsActualPlace = false;
      } else {
        attraction.imageIsActualPlace = true;
      }
      if (!attraction.description) {
        attraction.description = generateFallbackDescription(attraction);
      }
    } catch {
      // Enrichment is best-effort -- fall back to a local, honest
      // description so the record still isn't left completely blank.
      if (!attraction.description) attraction.description = generateFallbackDescription(attraction);
    }
    attractions.push(attraction);
    await new Promise((r) => setTimeout(r, 150));
  }
  return { attractions, categoryCallsFailed };
}
