
const HHMM_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;
const MINUTES_PER_DAY = 24 * 60;

function hhmmToMinutes(hhmm) {
  const m = HHMM_RE.exec(String(hhmm || ""));
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

function dayNumberForDate(tripStartDate, date, dayCount) {
  if (!tripStartDate || !date || Number.isNaN(date.getTime())) return null;
  const startMidnight = new Date(tripStartDate.getFullYear(), tripStartDate.getMonth(), tripStartDate.getDate());
  const dateMidnight = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diffDays = Math.round((dateMidnight - startMidnight) / 86400000);
  const day = diffDays + 1;
  return day >= 1 && day <= dayCount ? day : null;
}

function flightsWithRealTimes(flights) {
  return (Array.isArray(flights) ? flights : [])
    .filter((f) => f && typeof f.departureAtIso === "string" && f.departureAtIso)
    .map((f) => ({ ...f, _dep: new Date(f.departureAtIso) }))
    .filter((f) => !Number.isNaN(f._dep.getTime()))
    .sort((a, b) => a._dep - b._dep);
}

function computeLogisticsWindow(trip, dayCount, { arrivalBufferMinutes = 60, departureBufferMinutes = 180 } = {}) {
  const tripStartDate =
    trip.startDate && typeof trip.startDate.toDate === "function" ? trip.startDate.toDate() : null;
  const flights = flightsWithRealTimes(trip.flights);
  const window = { floor: null, ceil: null };

  if (flights.length) {
    const arrival = flights[0];
    const landedAt = arrival.arrivalAtIso ? new Date(arrival.arrivalAtIso) : arrival._dep;
    const day = dayNumberForDate(tripStartDate, landedAt, dayCount);
    if (day && !Number.isNaN(landedAt.getTime())) {
      window.floor = { day, minMinutes: landedAt.getHours() * 60 + landedAt.getMinutes() + arrivalBufferMinutes };
    }
  }
  if (flights.length >= 2) {
    const departure = flights[flights.length - 1];
    const day = dayNumberForDate(tripStartDate, departure._dep, dayCount);
    if (day) {
      window.ceil = {
        day,
        maxMinutes: departure._dep.getHours() * 60 + departure._dep.getMinutes() - departureBufferMinutes,
      };
    }
  }
  return window;
}

function withinWindow(window, day, time) {
  const mins = hhmmToMinutes(time);
  if (mins === null) return true;
  if (window.floor && day === window.floor.day && mins < window.floor.minMinutes) return false;
  if (window.ceil && day === window.ceil.day && mins >= window.ceil.maxMinutes) return false;
  return true;
}

function pickFlightsForDisplay(flights) {
  const list = (Array.isArray(flights) ? flights : []).filter(Boolean);
  if (list.length === 0) return { arrival: null, departure: null };
  if (list.length === 1) return { arrival: list[0], departure: null };
  const withIso = list.filter((f) => f.departureAtIso);
  const sorted = withIso.length >= 2 ? [...withIso].sort((a, b) => a.departureAtIso.localeCompare(b.departureAtIso)) : list;
  return { arrival: sorted[0], departure: sorted[sorted.length - 1] };
}

module.exports = { computeLogisticsWindow, withinWindow, pickFlightsForDisplay, hhmmToMinutes, MINUTES_PER_DAY };
