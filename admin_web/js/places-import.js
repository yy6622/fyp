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
const PLACE_DETAILS_URL = "https://api.geoapify.com/v2/place-details";
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
      highlights: p.description ? [p.description] : [],
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
    result.highlights = details.highlights?.length ? details.highlights : result.highlights;
    result.image = details.image || result.image;
  }
  if (!result.image) {
    result.image = await findWikipediaImage(result.name, result.location);
  }
  return result;
}
