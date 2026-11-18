import 'format_utils.dart';
import '../models/day_plan_models.dart';
import '../repositories/trip_repository.dart';

/// A booking from Overview (a flight or a hotel stay) that has no matching
/// item yet in the day-by-day Plan, with the day/time it should land on if
/// the user agrees to add it — computed from the booking's real
/// departure/landing or check-in/check-out times, not guessed.
class MissingBooking {
  final String sourceRef;
  final int dayIndex;
  final String time; // 24h "HH:mm"
  final String label;
  final String location;
  final String iconKey; // 'flight' | 'hotel'
  const MissingBooking({
    required this.sourceRef,
    required this.dayIndex,
    required this.time,
    required this.label,
    required this.location,
    required this.iconKey,
  });
}

String _flightName(TripFlight f) {
  final parts = [f.airline, f.flightNumber].where((s) => s.isNotEmpty).join(' ');
  return parts.isEmpty ? 'Flight' : parts;
}

DateTime? _flightDeparture(TripFlight f) {
  if (f.departureAtIso.isNotEmpty) return DateTime.tryParse(f.departureAtIso);
  return parseLongDateTime(f.dateTime);
}

DateTime _flightArrival(TripFlight f, DateTime departure) {
  if (f.arrivalAtIso.isNotEmpty) return DateTime.tryParse(f.arrivalAtIso) ?? departure;
  final t = parseClockTime(f.arrivalTime);
  if (t == null) return departure;
  return DateTime(departure.year, departure.month, departure.day, t.hour, t.minute);
}

int? _dayIndexFor(DateTime tripStart, DateTime? date, int dayCount) {
  if (date == null) return null;
  final start = DateTime(tripStart.year, tripStart.month, tripStart.day);
  final d = DateTime(date.year, date.month, date.day);
  final idx = d.difference(start).inDays;
  return idx >= 0 && idx < dayCount ? idx : null;
}

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

bool _alreadyInPlan(Trip trip, String sourceRef) {
  for (final day in trip.days) {
    for (final item in day.items) {
      if (item.sourceRef == sourceRef) return true;
    }
  }
  return false;
}

/// Guards against re-flagging a flight/hotel that was already added to the
/// plan manually (same icon, same day, within an hour) before this feature
/// existed to tag it with a sourceRef — avoids ever suggesting a duplicate.
bool _alreadyNearby(Trip trip, int dayIndex, String iconKey, String time) {
  if (dayIndex < 0 || dayIndex >= trip.days.length) return false;
  final target = parseClockTime(time);
  if (target == null) return false;
  final targetMin = target.hour * 60 + target.minute;
  for (final item in trip.days[dayIndex].items) {
    if (iconKeyFor(item.icon) != iconKey) continue;
    final t = parseClockTime(item.time);
    if (t == null) continue;
    if (((t.hour * 60 + t.minute) - targetMin).abs() < 60) return true;
  }
  return false;
}

/// The earliest flight-landing time already known for [dayIndex], looking
/// both at real plan items and at anchors already queued in [soFar] — used
/// so a same-day hotel check-in is never placed before the flight lands.
int? _earliestFlightLandingMinutes(Trip trip, List<MissingBooking> soFar, int dayIndex) {
  int? best;
  void consider(String time) {
    final t = parseClockTime(time);
    if (t == null) return;
    final m = t.hour * 60 + t.minute;
    if (best == null || m < best!) best = m;
  }

  if (dayIndex >= 0 && dayIndex < trip.days.length) {
    for (final item in trip.days[dayIndex].items) {
      if (iconKeyFor(item.icon) == 'flight') consider(item.time);
    }
  }
  for (final b in soFar) {
    if (b.dayIndex == dayIndex && b.iconKey == 'flight') consider(b.time);
  }
  return best;
}

/// Finds every flight/hotel booking in [trip]'s Overview that isn't in the
/// day-by-day Plan yet. Mirrors the "lands"/"departs"/"check in"/"check out"
/// anchors the Optimise cloud function already derives from these same
/// bookings internally (functions/planner/logistics_plan.js) — so what this
/// offers to add is exactly what Optimise already assumes exists.
List<MissingBooking> findMissingBookings(Trip trip) {
  final start = trip.startDate;
  if (start == null || trip.days.isEmpty) return const [];
  final dayCount = trip.days.length;
  final out = <MissingBooking>[];

  // ---- flights: only the first (lands) and last (departs) when there are
  // several legs, same convention the rest of the app already uses for
  // flight logistics (see functions/logistics.js's flightsWithRealTimes).
  final parsed = <({TripFlight f, DateTime dep, DateTime arr})>[];
  for (final f in trip.flights) {
    final dep = _flightDeparture(f);
    if (dep == null) continue;
    parsed.add((f: f, dep: dep, arr: _flightArrival(f, dep)));
  }
  parsed.sort((a, b) => a.dep.compareTo(b.dep));

  if (parsed.isNotEmpty) {
    final lands = parsed.first;
    final dayIndex = _dayIndexFor(start, lands.arr, dayCount);
    if (dayIndex != null) {
      final ref = 'flight:${lands.f.id}:lands';
      final time = _hhmm(lands.arr);
      if (!_alreadyInPlan(trip, ref) && !_alreadyNearby(trip, dayIndex, 'flight', time)) {
        out.add(MissingBooking(
          sourceRef: ref,
          dayIndex: dayIndex,
          time: time,
          label: 'Flight lands · ${_flightName(lands.f)}',
          location: lands.f.routeCities.isNotEmpty ? lands.f.routeCities : lands.f.routeCode,
          iconKey: 'flight',
        ));
      }
    }
  }
  if (parsed.length >= 2) {
    final departs = parsed.last;
    final dayIndex = _dayIndexFor(start, departs.dep, dayCount);
    if (dayIndex != null) {
      final ref = 'flight:${departs.f.id}:departs';
      final time = _hhmm(departs.dep);
      if (!_alreadyInPlan(trip, ref) && !_alreadyNearby(trip, dayIndex, 'flight', time)) {
        out.add(MissingBooking(
          sourceRef: ref,
          dayIndex: dayIndex,
          time: time,
          label: 'Flight departs · ${_flightName(departs.f)}',
          location: departs.f.routeCities.isNotEmpty ? departs.f.routeCities : departs.f.routeCode,
          iconKey: 'flight',
        ));
      }
    }
  }

  // ---- hotels: every stay gets a check-in and, unless it's a same-day
  // stay, a check-out anchor. Check-in defaults to 15:00 but is pushed back
  // if a flight lands later that same day (never schedule check-in before
  // you've actually landed).
  for (final h in trip.hotelStays) {
    final checkIn = parseLongDate(h.checkIn);
    final checkOut = parseLongDate(h.checkOut);
    final inIdx = _dayIndexFor(start, checkIn, dayCount);
    final outIdx = _dayIndexFor(start, checkOut, dayCount);
    if (inIdx == null && outIdx == null) continue;

    if (inIdx != null) {
      var minutes = 15 * 60;
      final landing = _earliestFlightLandingMinutes(trip, out, inIdx);
      if (landing != null && landing > minutes) {
        minutes = ((landing + 14) ~/ 15) * 15;
      }
      minutes = minutes.clamp(0, 23 * 60 + 45).toInt();
      final time = '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
      final ref = 'hotel:${h.id}:checkin';
      if (!_alreadyInPlan(trip, ref) && !_alreadyNearby(trip, inIdx, 'hotel', time)) {
        out.add(MissingBooking(
          sourceRef: ref,
          dayIndex: inIdx,
          time: time,
          label: 'Check in · ${h.name.isEmpty ? 'Hotel' : h.name}',
          location: h.location,
          iconKey: 'hotel',
        ));
      }
    }
    if (outIdx != null && outIdx != inIdx) {
      const time = '11:00';
      final ref = 'hotel:${h.id}:checkout';
      if (!_alreadyInPlan(trip, ref) && !_alreadyNearby(trip, outIdx, 'hotel', time)) {
        out.add(MissingBooking(
          sourceRef: ref,
          dayIndex: outIdx,
          time: time,
          label: 'Check out · ${h.name.isEmpty ? 'Hotel' : h.name}',
          location: h.location,
          iconKey: 'hotel',
        ));
      }
    }
  }

  out.sort((a, b) => a.dayIndex != b.dayIndex ? a.dayIndex.compareTo(b.dayIndex) : a.time.compareTo(b.time));
  return out;
}
