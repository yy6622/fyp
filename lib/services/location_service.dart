import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../data/malaysia_airports.dart';

enum LocationLookupStatus { success, serviceDisabled, permissionDenied, permissionDeniedForever, failed }

class LocationLookupResult {
  final LocationLookupStatus status;

  final List<MapEntry<MalaysiaAirport, double>>? rankedByDistanceKm;

  const LocationLookupResult(this.status, [this.rankedByDistanceKm]);

  MalaysiaAirport? get nearest => rankedByDistanceKm?.first.key;
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<LocationLookupResult> suggestNearestAirport() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationLookupResult(LocationLookupStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationLookupResult(LocationLookupStatus.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationLookupResult(LocationLookupStatus.permissionDeniedForever);
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return const LocationLookupResult(LocationLookupStatus.failed);
    }

    final ranked = kMalaysiaAirports
        .map((a) => MapEntry(a, _distanceKm(position.latitude, position.longitude, a.latitude, a.longitude)))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return LocationLookupResult(LocationLookupStatus.success, ranked);
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  Stream<Position> trackPosition({int distanceFilterMeters = 100}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: distanceFilterMeters),
    );
  }
}
