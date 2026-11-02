import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../models/day_plan_models.dart';
import '../../services/places_api_service.dart';
import '../../services/itinerary_optimise_service.dart' show OptimiseMode;
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';
import '../../theme.dart';
import 'optimise_sheet.dart' show startAndShowOptimise;

class LiveConditionsCard extends StatefulWidget {
  final String destination;
  final DateTime? forDate;
  final List<ActivityItem> activities;

  final GroupTripController controller;
  final int dayIndex;
  final int dayNumber;

  const LiveConditionsCard({
    super.key,
    required this.destination,
    required this.forDate,
    required this.activities,
    required this.controller,
    required this.dayIndex,
    required this.dayNumber,
  });

  @override
  State<LiveConditionsCard> createState() => _LiveConditionsCardState();
}

class _LiveConditionsCardState extends State<LiveConditionsCard> {
  bool _loading = true;
  DestinationWeather? _weather;
  TrafficRoute? _route;
  String? _routeFromLabel;
  String? _routeToLabel;

  bool _dismissedNudge = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<DestinationWeather?> _weatherOrNull(String destination) =>
      destination.trim().isEmpty ? Future.value(null) : WeatherService.instance.forDestination(destination, forDate: widget.forDate);

  Future<({double lat, double lon, String? countryCode, String? label})?> _geocodeOrNull(String query) =>
      query.trim().isEmpty ? Future.value(null) : PlacesApiService.instance.geocode(query);

  bool get _isPastDay {
    final forDate = widget.forDate;
    if (forDate == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return forDate.isBefore(todayStart);
  }

  Future<void> _load() async {
    if (_isPastDay) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _route = null;
        _loading = false;
      });
      return;
    }

    final dest = widget.destination.trim();
    final withLocation = widget.activities.where((a) => a.location.trim().isNotEmpty).toList();
    final hasRoute = withLocation.length >= 2;

    final weatherFuture = _weatherOrNull(dest);
    final fromGeoFuture = _geocodeOrNull(hasRoute ? withLocation[0].location : '');
    final toGeoFuture = _geocodeOrNull(hasRoute ? withLocation[1].location : '');

    final weather = await weatherFuture;
    final fromGeo = await fromGeoFuture;
    final toGeo = await toGeoFuture;
    final route = (fromGeo != null && toGeo != null)
        ? await TrafficService.instance.travelTime(fromLat: fromGeo.lat, fromLon: fromGeo.lon, toLat: toGeo.lat, toLon: toGeo.lon)
        : null;

    if (!mounted) return;
    setState(() {
      _weather = weather;
      _route = route;
      _routeFromLabel = hasRoute ? withLocation[0].label : null;
      _routeToLabel = hasRoute ? withLocation[1].label : null;
      _loading = false;
    });
  }

  bool get _hasBadCondition => _weather?.isDisruptive == true || _route?.isCongested == true;

  String get _nudgeMessage {
    final weatherBad = _weather?.isDisruptive == true;
    final trafficBad = _route?.isCongested == true;
    if (weatherBad && trafficBad) {
      return '${_weather!.label} is forecast and traffic is heavier than usual today — re-optimise this day\'s order?';
    }
    if (weatherBad) {
      return '${_weather!.label} is forecast for this day — re-optimise this day\'s order?';
    }
    return 'Traffic between your activities is heavier than usual today — re-optimise this day\'s order?';
  }

  void _reoptimiseNow() {
    setState(() => _dismissedNudge = true);
    startAndShowOptimise(context, widget.controller, OptimiseMode.day, dayIndex: widget.dayIndex, dayNumber: widget.dayNumber);
  }

  Widget _conditionNudge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_nudgeMessage, style: const TextStyle(fontSize: 12.5, color: AppColors.navy, height: 1.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => _dismissedNudge = true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Not now', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _reoptimiseNow,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Re-optimise Day', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
        child: const Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            SizedBox(width: 10),
            Text('Checking live weather & traffic…', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
      );
    }
    if (_weather == null && _route == null) return const SizedBox.shrink();

    final showNudge = _hasBadCondition && !_dismissedNudge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showNudge) _conditionNudge() else _conditionsBox(),
      ],
    );
  }

  Widget _conditionsBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_weather != null) _infoChip(_weather!.icon, _weather!.tempLabel, _weather!.label, AppColors.navy),
          if (_route != null && _routeFromLabel != null && _routeToLabel != null) ...[
            if (_weather != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E2E2)),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.directions_outlined, size: 16, color: AppColors.textGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_routeFromLabel → $_routeToLabel: ${_route!.durationLabel} (${_route!.distanceLabel}), with current traffic',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
          ],
        ),
      ],
    );
  }
}
