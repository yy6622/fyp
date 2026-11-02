
const AVERAGE_SPEED_KMH = 25;
const MIN_TRAVEL_MINUTES = 10;
const SAME_AREA_MINUTES = 15;
const DIFFERENT_AREA_MINUTES = 30;
const UNKNOWN_MINUTES = 20;

function hasCoords(p) {
  return Boolean(p) && Number.isFinite(p.lat) && Number.isFinite(p.lng);
}

function kmBetween(a, b) {
  const r = Math.PI / 180;
  const x = (b.lng - a.lng) * r * Math.cos(((a.lat + b.lat) / 2) * r);
  const y = (b.lat - a.lat) * r;
  return Math.sqrt(x * x + y * y) * 6371;
}

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
