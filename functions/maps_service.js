// ---------------------------------------------------------------------
// "Maps service" (FYP documentation's Optimised Itinerary Generation
// Algorithm): one place to ask "how far / how long between these two
// points" — used by optimise_engine.js's two-opt pass and its utility
// formula's travelTimePenalty term. Deliberately a thin, swappable
// module: today it estimates from whatever location data a place
// actually has (lat/lng when the Explore catalog scrape found them, a
// named district otherwise), with no billing account or API key to
// configure — that's this FYP's own scope decision (no external paid
// Maps API), not a limitation of the formula itself. Swapping this for
// a real paid API (Google Distance Matrix/Directions) later only means
// rewriting the body of estimateTravelMinutes; every caller (and the
// utility formula that consumes its output) stays exactly the same.
// ---------------------------------------------------------------------

const AVERAGE_SPEED_KMH = 25; // a city-traffic + walking blend; this app has no live traffic feed to do better
const MIN_TRAVEL_MINUTES = 10; // never "0 minutes" between two distinct places
const SAME_AREA_MINUTES = 15; // optimise_engine.js's existing SAME_AREA_GAP, reused as this tier's estimate
const DIFFERENT_AREA_MINUTES = 30; // optimise_engine.js's existing OTHER_AREA_GAP
const UNKNOWN_MINUTES = 20; // neither coordinates nor a district on either side — a conservative middle guess

function hasCoords(p) {
  return Boolean(p) && Number.isFinite(p.lat) && Number.isFinite(p.lng);
}

/**
 * Straight-line km between two {lat, lng} points — an equirectangular
 * approximation, accurate enough at city scale (the same approximation
 * this engine's own area-grouping already relied on before this module
 * existed).
 */
function kmBetween(a, b) {
  const r = Math.PI / 180;
  const x = (b.lng - a.lng) * r * Math.cos(((a.lat + b.lat) / 2) * r);
  const y = (b.lat - a.lat) * r;
  return Math.sqrt(x * x + y * y) * 6371;
}

/**
 * Minutes to travel from [a] to [b] — each a {lat, lng, district}-
 * shaped point (any field may be missing, since it's only as complete
 * as whatever CatalogRepository/planner/places.js resolved for that
 * activity):
 *  - both have coordinates -> a real distance / average-speed estimate.
 *  - no coordinates, but both name a district -> the coarse same-
 *    district / different-district estimate this engine always used.
 *  - otherwise -> a fixed, conservative estimate.
 */
function estimateTravelMinutes(a, b) {
  if (hasCoords(a) && hasCoords(b)) {
    const km = kmBetween(a, b);
    return Math.max(MIN_TRAVEL_MINUTES, Math.round((km / AVERAGE_SPEED_KMH) * 60));
  }
  const districtA = a && a.district ? String(a.district).toLowerCase() : "";
  const districtB = b && b.district ? String(b.district).toLowerCase() : "";
  if (districtA && districtB) return districtA === districtB ? SAME_AREA_MINUTES : DIFFERENT_AREA_MINUTES;
  return UNKNOWN_MINUTES;
}

module.exports = {
  kmBetween,
  estimateTravelMinutes,
  AVERAGE_SPEED_KMH,
  MIN_TRAVEL_MINUTES,
  SAME_AREA_MINUTES,
  DIFFERENT_AREA_MINUTES,
  UNKNOWN_MINUTES,
};
