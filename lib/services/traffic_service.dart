import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';

// ---------------------------------------------------------------------
// Live-traffic-aware travel time for Group Trip's Plan page — e.g. one
// day's activity to the next (see live_conditions_card.dart). Backed by
// Google's Routes API (`computeRoutes`, routingPreference TRAFFIC_AWARE)
// per the user's own choice, after weighing it against TomTom (TomTom's
// free tier needs no credit card at all; Google's does, even to stay
// inside the free 5K-requests/month quota — the user decided the
// trade-off was fine). [googleRoutesApiKey] in secrets.dart starts
// empty; every call here returns null (never a fabricated estimate)
// until a real key is pasted in, same "don't fabricate, just show
// nothing" convention WeatherService already uses for Open-Meteo.
//
// Google's Traffic Flow / congestion-level data isn't exposed through a
// plain data API the way TomTom's is (only as a rendered map tile layer,
// which isn't useful here) — so unlike the TomTom version, there's no
// "congestion near this city" reading any more, only a point-to-point
// travel-time estimate. See live_conditions_card.dart for how that's
// shown without it.
// ---------------------------------------------------------------------

/// A live-traffic-aware travel-time estimate between two points.
class TrafficRoute {
  final int travelTimeSeconds;
  final int lengthMeters;

  /// The typical (no-traffic) duration for this same route, when Google
  /// returned one — null on an older cached entry or if the field was
  /// ever absent. Used only to judge [isCongested]; every existing
  /// duration/distance display keeps using [travelTimeSeconds] exactly as
  /// before.
  final int? staticDurationSeconds;
  const TrafficRoute({required this.travelTimeSeconds, required this.lengthMeters, this.staticDurationSeconds});

  /// True when the current traffic-aware travel time is meaningfully
  /// worse than the typical duration for this route — at least 10
  /// minutes worse, and at least 30% worse — the bar
  /// live_conditions_card.dart's weather/traffic nudge uses to decide
  /// whether suggesting a re-optimise is actually worth the person's
  /// attention, rather than flagging ordinary traffic.
  bool get isCongested {
    final typical = staticDurationSeconds;
    if (typical == null || typical <= 0) return false;
    final extra = travelTimeSeconds - typical;
    return extra >= 600 && travelTimeSeconds >= typical * 1.3;
  }

  /// "8 min" / "1h 20min" — matches the plain, no-seconds granularity a
  /// traveller actually cares about when checking it against their plan.
  String get durationLabel {
    final mins = (travelTimeSeconds / 60).round().clamp(1, 999999);
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  String get distanceLabel {
    final km = lengthMeters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }
}

class TrafficService {
  TrafficService._();
  static final TrafficService instance = TrafficService._();

  static const _endpoint = 'https://routes.googleapis.com/directions/v2:computeRoutes';

  // Short in-memory cache, same shape/reasoning as WeatherService's own:
  // the Plan page's "refresh once on open" convention means this only
  // needs to survive a few rebuilds within that one open, not stay fresh
  // for long — and it keeps repeat opens within the window from eating
  // into the free monthly quota for no reason.
  static const _cacheTtl = Duration(minutes: 15);
  final Map<String, (DateTime fetchedAt, TrafficRoute? data)> _routeCache = {};

  String _point(double lat, double lon) => '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

  /// Live-traffic-aware travel time from ([fromLat],[fromLon]) to
  /// ([toLat],[toLon]) — null when no key is configured yet, or the
  /// request fails/times out; callers show nothing rather than a
  /// fabricated estimate.
  Future<TrafficRoute?> travelTime({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) async {
    if (googleRoutesApiKey.isEmpty) return null;
    final key = '${_point(fromLat, fromLon)}>${_point(toLat, toLon)}';
    final cached = _routeCache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _cacheTtl) return cached.$2;

    TrafficRoute? result;
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': googleRoutesApiKey,
              // Only the fields this actually reads — Routes API charges
              // the same regardless of field mask size, but a narrower
              // mask keeps the response (and what's parsed below) small.
              'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.staticDuration',
            },
            body: jsonEncode({
              'origin': {
                'location': {'latLng': {'latitude': fromLat, 'longitude': fromLon}},
              },
              'destination': {
                'location': {'latLng': {'latitude': toLat, 'longitude': toLon}},
              },
              'travelMode': 'DRIVE',
              'routingPreference': 'TRAFFIC_AWARE',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;
        final route = (routes != null && routes.isNotEmpty) ? routes.first as Map<String, dynamic> : null;
        // Duration comes back as a string like "165s", not a bare number.
        final durationStr = route?['duration'] as String?;
        final staticDurationStr = route?['staticDuration'] as String?;
        final lengthMeters = route?['distanceMeters'] as num?;
        final seconds = durationStr == null ? null : int.tryParse(durationStr.replaceAll('s', ''));
        final staticSeconds = staticDurationStr == null ? null : int.tryParse(staticDurationStr.replaceAll('s', ''));
        if (seconds != null && lengthMeters != null) {
          result = TrafficRoute(travelTimeSeconds: seconds, lengthMeters: lengthMeters.toInt(), staticDurationSeconds: staticSeconds);
        }
      }
    } catch (_) {
      // Network hiccup / malformed response / bad key — treated as
      // "unavailable right now", never thrown past the caller.
    }
    _routeCache[key] = (DateTime.now(), result);
    return result;
  }
}
