import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'demo_mode_service.dart';
import 'places_api_service.dart';


class DestinationWeather {
  final double tempC;
  final double? tempMinC;
  final double? tempMaxC;
  final int weatherCode;
  const DestinationWeather({required this.tempC, this.tempMinC, this.tempMaxC, required this.weatherCode});

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
    if (weatherCode == 45 || weatherCode == 48) return Icons.cloud_outlined;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.water_drop_outlined;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.grain;
    if (weatherCode >= 95) return Icons.thunderstorm_outlined;
    return Icons.wb_cloudy_outlined;
  }

  String get tempLabel {
    if (tempMinC != null && tempMaxC != null) return '${tempMinC!.round()}°-${tempMaxC!.round()}°C';
    return '${tempC.round()}°C';
  }

  bool get isDisruptive =>
      (weatherCode >= 61 && weatherCode <= 67) || // Rain
      (weatherCode >= 71 && weatherCode <= 77) || // Snow
      (weatherCode >= 80 && weatherCode <= 82) || // Showers
      weatherCode >= 95; // Storm
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const _forecastHorizonDays = 15;

  final Map<String, (DateTime fetchedAt, DestinationWeather? weather)> _cache = {};
  static const _cacheTtl = Duration(minutes: 30);

  Future<DestinationWeather?> forDestination(String destination, {DateTime? forDate}) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return null;
    if (DemoModeService.instance.enabled) {
      return const DestinationWeather(tempC: DemoModeService.demoTempC, weatherCode: DemoModeService.demoWeatherCode);
    }
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

    final daysAhead = forDate.difference(todayMidnight).inDays;
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

  Future<DestinationWeather?> forTripDay({
    required String tripId,
    required int dayNumber,
    required String destination,
    required DateTime date,
  }) =>
      forDestination(destination, forDate: date);

  final Map<String, (DateTime fetchedAt, List<({int start, int end})> windows)> _rainCache = {};

  /// Hour-by-hour forecast rain/snow/storm windows for [destination] on
  /// [date], as minute-of-day [start, end) ranges (e.g. 14:00-17:00 ->
  /// (840, 1020)). Used by Optimise to avoid scheduling outdoor activities
  /// during them -- not shown anywhere on its own. Empty if the date is
  /// outside the forecast horizon, the destination can't be geocoded, or
  /// the request fails; never throws.
  Future<List<({int start, int end})>> hourlyRainWindows(String destination, DateTime date) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return const [];
    if (DemoModeService.instance.enabled) return DemoModeService.demoRainWindows;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dateMidnight = DateTime(date.year, date.month, date.day);
    final daysAhead = dateMidnight.difference(todayMidnight).inDays;
    if (daysAhead < 0 || daysAhead > _forecastHorizonDays) return const [];

    String two(int n) => n.toString().padLeft(2, '0');
    final dateStr = '${date.year}-${two(date.month)}-${two(date.day)}';
    final key = '$trimmed|$dateStr';
    final cached = _rainCache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _cacheTtl) return cached.$2;

    List<({int start, int end})> windows = const [];
    try {
      final geo = await PlacesApiService.instance.geocode(trimmed);
      if (geo != null) {
        final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': '${geo.lat}',
          'longitude': '${geo.lon}',
          'hourly': 'weather_code',
          'start_date': dateStr,
          'end_date': dateStr,
          'timezone': 'auto',
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final hourly = decoded['hourly'] as Map<String, dynamic>?;
          final codes = List<dynamic>.from(hourly?['weather_code'] as List? ?? const []);
          bool disruptive(int? code) =>
              code != null &&
              ((code >= 61 && code <= 67) || (code >= 71 && code <= 77) || (code >= 80 && code <= 82) || code >= 95);
          final built = <({int start, int end})>[];
          int? openStart;
          for (var h = 0; h < codes.length && h < 24; h++) {
            final bad = disruptive((codes[h] as num?)?.toInt());
            if (bad && openStart == null) openStart = h * 60;
            if (!bad && openStart != null) {
              built.add((start: openStart, end: h * 60));
              openStart = null;
            }
          }
          if (openStart != null) built.add((start: openStart, end: 24 * 60));
          windows = built;
        }
      }
    } catch (_) {
      windows = const [];
    }
    _rainCache[key] = (DateTime.now(), windows);
    return windows;
  }
}
