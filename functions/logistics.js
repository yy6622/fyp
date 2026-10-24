// Shared "when can things actually be scheduled" math for generateItinerary
// (itinerary.js) and optimiseItinerary (optimise.js).
//
// Both system prompts already *ask* the model to respect real flight/hotel
// times, but a prompt rule is only ever a request — nothing stopped a model
// answer from ignoring it. This is the deterministic half: it drops/clamps
// anything a model answer gets wrong anyway, exactly the same "belt and
// braces" idea optimise.js already uses for its day-mode scope (see
// optimise.js's `mode === "day"` filter) — never *ask and hope* for
// something you can compute exactly.
//
// The hard cutoff (computeLogisticsWindow) only ever uses a flight with a
// real ISO timestamp (TripFlight.departureAtIso/arrivalAtIso) — set only
// when a flight was booked straight from a live Duffel search result (see
// explore_page.dart's _flightDetailFor). A flight added from Saved or typed
// in by hand has no ISO timestamp and is skipped here entirely, rather than
// guessed at from its free-text display string — a wrong guess would be
// worse than no enforcement at all. pickFlightsForDisplay below is the
// separate, lenient version used only for the prompt's own FYI text, where
// an imprecise guess costs nothing (the model was never going to be
// perfectly reliable about it anyway).

const HHMM_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;
const MINUTES_PER_DAY = 24 * 60;

function hhmmToMinutes(hhmm) {
  const m = HHMM_RE.exec(String(hhmm || ""));
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

/** Which 1-based trip day a real Date falls on, or null if outside [1, dayCount] or there's no trip start date. */
function dayNumberForDate(tripStartDate, date, dayCount) {
  if (!tripStartDate || !date || Number.isNaN(date.getTime())) return null;
  const startMidnight = new Date(tripStartDate.getFullYear(), tripStartDate.getMonth(), tripStartDate.getDate());
  const dateMidnight = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diffDays = Math.round((dateMidnight - startMidnight) / 86400000);
  const day = diffDays + 1;
  return day >= 1 && day <= dayCount ? day : null;
}

/** trip.flights that carry a real ISO departure timestamp, earliest first — see module doc comment. */
function flightsWithRealTimes(flights) {
  return (Array.isArray(flights) ? flights : [])
    .filter((f) => f && typeof f.departureAtIso === "string" && f.departureAtIso)
    .map((f) => ({ ...f, _dep: new Date(f.departureAtIso) }))
    .filter((f) => !Number.isNaN(f._dep.getTime()))
    .sort((a, b) => a._dep - b._dep);
}

/**
 * The window within which activities may be freely scheduled:
 *  - floor: {day, minMinutes} — nothing on the arrival flight's actual
 *    landing day should be earlier than (landing + arrivalBufferMinutes).
 *  - ceil: {day, maxMinutes} — nothing on the return flight's actual
 *    departure day should be at or after (departure - departureBufferMinutes).
 *    Only set when there are 2+ real-timestamped flights, so a single
 *    one-way/arrival flight is never mistaken for a return flight home.
 * Either half is null when the data needed for it isn't there (no
 * ISO-timestamped flight, or no trip.startDate to place it on a day).
 */
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

/** False if (day, time) falls outside the window — used to drop model output that violates it. */
function withinWindow(window, day, time) {
  const mins = hhmmToMinutes(time);
  if (mins === null) return true; // malformed time isn't this guard's job
  if (window.floor && day === window.floor.day && mins < window.floor.minMinutes) return false;
  if (window.ceil && day === window.ceil.day && mins >= window.ceil.maxMinutes) return false;
  return true;
}

/**
 * Best-effort arrival/return flight for the prompt's own FYI text only —
 * unlike computeLogisticsWindow this is allowed to guess from storage order
 * when fewer than 2 flights have a real timestamp, since being wrong here
 * only means a slightly-off hint to the model, not a wrongly-enforced cutoff.
 */
function pickFlightsForDisplay(flights) {
  const list = (Array.isArray(flights) ? flights : []).filter(Boolean);
  if (list.length === 0) return { arrival: null, departure: null };
  if (list.length === 1) return { arrival: list[0], departure: null };
  const withIso = list.filter((f) => f.departureAtIso);
  const sorted = withIso.length >= 2 ? [...withIso].sort((a, b) => a.departureAtIso.localeCompare(b.departureAtIso)) : list;
  return { arrival: sorted[0], departure: sorted[sorted.length - 1] };
}

module.exports = { computeLogisticsWindow, withinWindow, pickFlightsForDisplay, hhmmToMinutes, MINUTES_PER_DAY };
