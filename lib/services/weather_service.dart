import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'places_api_service.dart';

// ---------------------------------------------------------------------
// Real weather for a trip's destination — shown on Home's "Next
// Adventure" card (see home_page.dart's _cardInfoTile for 'Weather').
// Backed by Open-Meteo, which — like Nominatim/Overpass already used for
// geocoding/POIs (see PlacesApiService) — is free and keyless: no billing
// account to set up, nothing to add to secrets.dart. Geocodes the
// destination with the same PlacesApiService.geocode this app already
// uses for catalogue/POI search, then asks Open-Meteo for either today's
// actual reading or a specific day's forecast.
// ---------------------------------------------------------------------

/// One day's (or "right now"'s) weather for a destination. [tempMinC]/
/// [tempMaxC] are set for a day's forecast; for "right now" only [tempC]
/// is set (a single current reading has no min/max).
class DestinationWeather {
  final double tempC;
  final double? tempMinC;
  final double? tempMaxC;
  final int weatherCode;
  const DestinationWeather({required this.tempC, this.tempMinC, this.tempMaxC, required this.weatherCode});

  /// Short label for the WMO weather code Open-Meteo returns — see
  /// https://open-meteo.com/en/docs#weathervariables for the full table;
  /// this only distinguishes the ranges that actually change what a
  /// traveller would want to see at a glance.
  String get label {
    if (weatherCode == 0) return 'Clear';
    if (weatherCode <= 3) return 'Cloudy';
    if (weatherCode == 45 || weatherCode == 48) return 'Fog';
    if (weatherCode >= 51 && weatherCode <= 57) return 'Drizzle';
    if (weatherCode >= 61 && weatherCode <= 67) return 'Rain';
    if (weatherCode >= 71 && weatherCode <= 77) return 'Snow';
    if (weatherCode >= 80 && weatherCode <= 82) return 'Showers';
    if (weatherCode >= 95) return 'Storm';
    return 'Mild';
  }

  IconData get icon {
    if (weatherCode == 0) return Icons.wb_sunny_outlined;
    if (weatherCode <= 3) return Icons.wb_cloudy_outlined;
    // Icons.foggy only exists in newer Material icon sets than this
    // project's Flutter SDK is guaranteed to have — cloud_outlined reads
    // close enough and is a long-standing, definitely-available icon.
    if (weatherCode == 45 || weatherCode == 48) return Icons.cloud_outlined;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.water_drop_outlined;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.grain;
    if (weatherCode >= 95) return Icons.thunderstorm_outlined;
    return Icons.wb_cloudy_outlined;
  }

  /// "24° - 30°C" for a day's forecast, "28°C" for a single current reading.
  String get tempLabel {
    if (tempMinC != null && tempMaxC != null) return '${tempMinC!.round()}°-${tempMaxC!.round()}°C';
    return '${tempC.round()}°C';
  }
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  /// Open-Meteo only forecasts about this many days ahead — a trip
  /// further out than this just has no weather yet.
  static const _forecastHorizonDays = 15;

  // Keyed by "destination|dateKey" ('now' for a current reading). Short
  // TTL so Home's StreamBuilder rebuilding on every Firestore snapshot
  // doesn't re-hit the API every time, without ever going stale for long.
  final Map<String, (DateTime fetchedAt, DestinationWeather? weather)> _cache = {};
  static const _cacheTtl = Duration(minutes: 30);

  /// [forDate] should be a midnight-normalized date (same convention as
  /// Trip.startDate elsewhere); pass null for "right now" (an ongoing
  /// trip, or one starting today). Returns null — never a fabricated
  /// reading — when the destination can't be geocoded, the date is
  /// beyond Open-Meteo's forecast horizon, or the request fails for any
  /// reason (offline, endpoint down).
  Future<DestinationWeather?> forDestination(String destination, {DateTime? forDate}) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return null;
    final dateKey = forDate == null ? 'now' : '${forDate.year}-${forDate.month}-${forDate.day}';
    final key = '$trimmed|$dateKey';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _cacheTtl) return cached.$2;

    DestinationWeather? result;
    try {
      final geo = await PlacesApiService.instance.geocode(trimmed);
      if (geo != null) result = await _fetch(geo.lat, geo.lon, forDate);
    } catch (_) {
      result = null;
    }
    _cache[key] = (DateTime.now(), result);
    return result;
  }

  Future<DestinationWeather?> _fetch(double lat, double lon, DateTime? forDate) async {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final wantsCurrent = forDate == null || !forDate.isAfter(todayMidnight);

    if (wantsCurrent) {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lon',
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final current = decoded['current'] as Map<String, dynamic>?;
      final temp = (current?['temperature_2m'] as num?)?.toDouble();
      final code = (current?['weather_code'] as num?)?.toInt();
      if (temp == null || code == null) return null;
      return DestinationWeather(tempC: temp, weatherCode: code);
    }

    final daysAhead = forDate!.difference(todayMidnight).inDays;
    if (daysAhead > _forecastHorizonDays) return null;
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'daily': 'temperature_2m_max,temperature_2m_min,weather_code',
      'forecast_days': '16',
      'timezone': 'auto',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final daily = decoded['daily'] as Map<String, dynamic>?;
    if (daily == null) return null;
    final times = List<String>.from(daily['time'] as List? ?? const []);
    String two(int n) => n.toString().padLeft(2, '0');
    final targetKey = '${forDate.year}-${two(forDate.month)}-${two(forDate.day)}';
    final idx = times.indexOf(targetKey);
    if (idx == -1) return null;
    final maxList = List<dynamic>.from(daily['temperature_2m_max'] as List? ?? const []);
    final minList = List<dynamic>.from(daily['temperature_2m_min'] as List? ?? const []);
    final codeList = List<dynamic>.from(daily['weather_code'] as List? ?? const []);
    if (idx >= maxList.length || idx >= minList.length || idx >= codeList.length) return null;
    final maxT = (maxList[idx] as num?)?.toDouble();
    final minT = (minList[idx] as num?)?.toDouble();
    final code = (codeList[idx] as num?)?.toInt();
    if (maxT == null || minT == null || code == null) return null;
    return DestinationWeather(tempC: (maxT + minT) / 2, tempMinC: minT, tempMaxC: maxT, weatherCode: code);
  }
}
