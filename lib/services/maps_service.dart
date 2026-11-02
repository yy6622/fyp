import 'dart:math';


class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

enum SuggestedTravelMode { walk, drive, unknown }

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

  static const double _averageSpeedKmh = 25;
  static const double _walkingSpeedKmh = 4.5;
  static const double _walkThresholdKm = 1.0;

  static double kmBetween(LatLng a, LatLng b) {
    const r = pi / 180;
    final x = (b.lng - a.lng) * r * cos(((a.lat + b.lat) / 2) * r);
    final y = (b.lat - a.lat) * r;
    return sqrt(x * x + y * y) * 6371;
  }

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
