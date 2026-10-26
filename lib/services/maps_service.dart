import 'dart:math';

// ---------------------------------------------------------------------
// "Maps service" abstraction (FYP documentation's Optimised Itinerary
// Generation Algorithm — reused here for the Plan page's transportation
// suggestion between two consecutive activities). A lat/lng-based
// distance/time estimate, deliberately thin and swappable: no billing
// account or API key to configure (this FYP's own scope decision), but
// structured so a real paid API (Google Distance Matrix/Directions)
// could replace the body of [MapsService.suggest] later without any
// caller changing. Mirrors functions/maps_service.js's own constants so
// both halves of the app (Optimise's backend, this frontend suggestion)
// agree on the same speed/threshold assumptions.
// ---------------------------------------------------------------------

/// A plain {lat, lng} point — not tied to any one model, so both an
/// attraction's and a restaurant's resolved coordinates can share it.
class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

enum SuggestedTravelMode { walk, drive, unknown }

/// What the transport row between two activities shows and what it
/// opens Google Maps with — [etaMinutes] is null exactly when [mode] is
/// [SuggestedTravelMode.unknown] (neither stop had a usable coordinate),
/// so the row can show an honest "Get directions" instead of a time
/// estimate it can't actually back up.
class TransportSuggestion {
  final SuggestedTravelMode mode;
  final String label;
  final String googleMapsTravelMode;
  final int? etaMinutes;
  const TransportSuggestion({
    required this.mode,
    required this.label,
    required this.googleMapsTravelMode,
    this.etaMinutes,
  });
}

class MapsService {
  const MapsService._();

  static const double _averageSpeedKmh = 25; // same figure as functions/maps_service.js
  static const double _walkingSpeedKmh = 4.5;
  // Beyond this, walking stops being the sensible suggestion even if it's
  // technically possible — about a 13-minute walk at the speed above.
  static const double _walkThresholdKm = 1.0;

  /// Straight-line km between two points — an equirectangular
  /// approximation, accurate enough at city scale (same approximation
  /// functions/maps_service.js's kmBetween uses).
  static double kmBetween(LatLng a, LatLng b) {
    const r = pi / 180;
    final x = (b.lng - a.lng) * r * cos(((a.lat + b.lat) / 2) * r);
    final y = (b.lat - a.lat) * r;
    return sqrt(x * x + y * y) * 6371;
  }

  /// [km] null means neither stop resolved to a real coordinate (a
  /// manually-typed activity, or a hotel — this app's hotel search
  /// doesn't return coordinates) — falls back to an honest "Get
  /// directions" with no claimed mode or time, same as this row showed
  /// before a suggested mode existed at all.
  static TransportSuggestion suggest(double? km) {
    if (km == null) {
      return const TransportSuggestion(
        mode: SuggestedTravelMode.unknown,
        label: 'Get directions',
        googleMapsTravelMode: 'driving',
      );
    }
    if (km <= _walkThresholdKm) {
      final minutes = max(1, (km / _walkingSpeedKmh * 60).round());
      return TransportSuggestion(
        mode: SuggestedTravelMode.walk,
        label: 'Walk',
        googleMapsTravelMode: 'walking',
        etaMinutes: minutes,
      );
    }
    final minutes = max(1, (km / _averageSpeedKmh * 60).round());
    return TransportSuggestion(
      mode: SuggestedTravelMode.drive,
      label: 'Drive',
      googleMapsTravelMode: 'driving',
      etaMinutes: minutes,
    );
  }
}
