import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';


class TrafficRoute {
  final int travelTimeSeconds;
  final int lengthMeters;

  final int? staticDurationSeconds;
  const TrafficRoute({required this.travelTimeSeconds, required this.lengthMeters, this.staticDurationSeconds});

  bool get isCongested {
    final typical = staticDurationSeconds;
    if (typical == null || typical <= 0) return false;
    final extra = travelTimeSeconds - typical;
    return extra >= 600 && travelTimeSeconds >= typical * 1.3;
  }

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

  static const _cacheTtl = Duration(minutes: 15);
  final Map<String, (DateTime fetchedAt, TrafficRoute? data)> _routeCache = {};

  String _point(double lat, double lon) => '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

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
    }
    _routeCache[key] = (DateTime.now(), result);
    return result;
  }
}
