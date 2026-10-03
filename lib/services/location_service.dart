import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../data/malaysia_airports.dart';

/// What [LocationService.suggestNearestAirport] found, or why it
/// couldn't. Kept as one result type (rather than throwing for the
/// "couldn't" cases) because every non-success case here is an
/// everyday, expected outcome — location off, permission declined —
/// not a bug, so the caller should show a plain message, not an error
/// state.
enum LocationLookupStatus { success, serviceDisabled, permissionDenied, permissionDeniedForever, failed }

class LocationLookupResult {
  final LocationLookupStatus status;

  /// The nearest airport, and every other airport sorted by distance —
  /// set only when [status] is [LocationLookupStatus.success].
  final List<MapEntry<MalaysiaAirport, double>>? rankedByDistanceKm;

  const LocationLookupResult(this.status, [this.rankedByDistanceKm]);

  MalaysiaAirport? get nearest => rankedByDistanceKm?.first.key;
}

/// Suggests the nearest Malaysian airport to the person's current
/// device location — used by Account Setting's Home Airport picker so
/// someone in Penang gets offered PEN instead of always being assumed
/// to be near KUL (see `malaysia_airports.dart`'s doc comment for why
/// the app needed this at all).
///
/// This is a one-shot, on-demand read triggered by opening that picker
/// — never a background location subscription, and the result isn't
/// stored anywhere by this service; only the airport code the person
/// actually confirms gets saved (`AppUser.homeAirportCode`).
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

  /// Great-circle (haversine) distance between two lat/lng points, in
  /// kilometres — plenty accurate for "which airport is closest",
  /// without pulling in a maps/geo package just for this.
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

  /// One-shot current position read for Privacy and Security's "Share
  /// Location with Group" toggle and Group Info > Member Location — same
  /// permission dance as [suggestNearestAirport], just returning the raw
  /// position (or null on anything short of success) instead of ranking
  /// airports by it. Still never a background subscription.
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

  /// The one background subscription this service hands out — a live
  /// stream that only emits when the device has moved roughly
  /// [distanceFilterMeters] or more since the last emission (Geolocator's
  /// own `distanceFilter`, not a timer), so "Share Location with Group"
  /// updates Group Info > Member Location on real movement instead of a
  /// one-shot snapshot from whenever the toggle was flipped. Callers
  /// (see [MainPage] in bottom_nav.dart) are responsible for only
  /// subscribing while the person actually has sharing turned on, and
  /// for cancelling the subscription — this method itself does no
  /// permission/service gating, since [getCurrentPosition] above already
  /// has to have succeeded once (via the toggle's own flow) before this
  /// is ever started.
  Stream<Position> trackPosition({int distanceFilterMeters = 100}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: distanceFilterMeters),
    );
  }
}
