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

export const BULK_CATEGORY_GROUPS = [
  "entertainment.museum",
  "entertainment.culture",
  "entertainment.zoo,entertainment.aquarium,entertainment.theme_park",
  "leisure.park",
  "heritage",
  "tourism.attraction.viewpoint",
];

function isLowValuePlace(categories = []) {
  return categories.some((c) => c.includes("artwork") || c.includes("memorial"));
}

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
