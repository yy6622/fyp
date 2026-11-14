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

  /// Traffic is only meaningful for *today*'s schedule — never shown for a
  /// day that already passed or one that hasn't happened yet.
  bool get _isToday {
    final forDate = widget.forDate;
    if (forDate == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateStart = DateTime(forDate.year, forDate.month, forDate.day);
    return dateStart.isAtSameMomentAs(todayStart);
  }

  /// Once the whole trip is over, neither weather nor traffic is shown for
  /// any day of it anymore.
  bool get _tripEnded => widget.controller.trip?.hasEnded ?? false;

  /// Weather/traffic only matter close to when a day will actually happen —
  /// a forecast for a day 3 months away is meaningless (and most providers
  /// don't even have one), so this card does nothing at all for a day more
  /// than a week out. That also means opening a far-future trip's itinerary
  /// doesn't burn a weather/geocoding API call per day for nothing.
  bool get _tooFarAhead {
    final forDate = widget.forDate;
    if (forDate == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateStart = DateTime(forDate.year, forDate.month, forDate.day);
    return dateStart.isAfter(todayStart.add(const Duration(days: 7)));
  }

  Future<void> _load() async {
    if (_tripEnded || _tooFarAhead || _isPastDay) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _route = null;
        _loading = false;
      });
      return;
    }

    final dest = widget.destination.trim();
    final forDate = widget.forDate;
    final tripId = widget.controller.trip?.id;

    // Weather covers the whole itinerary: today/future is fetched live and
    // remembered, a past day replays what was already tracked instead of
    // hitting the API again.
    final weatherFuture = (forDate != null && tripId != null)
        ? WeatherService.instance.forTripDay(tripId: tripId, dayNumber: widget.dayNumber, destination: dest, date: forDate)
        : _weatherOrNull(dest);

    final withLocation = widget.activities.where((a) => a.location.trim().isNotEmpty).toList();
    final hasRoute = _isToday && withLocation.length >= 2;

    final fromGeoFuture = _geocodeOrNull(hasRoute ? withLocation[0].location : '');
    final toGeoFuture = _geocodeOrNull(hasRoute ? withLocation[1].location : '');

    final weather = await weatherFuture;
    final fromGeo = await fromGeoFuture;
    final toGeo = await toGeoFuture;
    final route = (hasRoute && fromGeo != null && toGeo != null)
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

  /// Weather/traffic only matter when something that day is actually
  /// exposed to them — if every activity is confidently indoor (a museum,
  /// mall, restaurant day, say), rain or heavier traffic isn't worth a
  /// re-optimise nudge at all.
  bool get _allIndoor => allActivitiesLikelyIndoor(widget.activities);

  bool get _hasBadCondition =>
      !_allIndoor && (_weather?.isDisruptive == true || _route?.isCongested == true);

  // Compact, single-line pill -- same shape/size family as _longBar() below
  // (same pill radius, same ~12px text), not a tall boxed card. The CTA
  // question ("...re-optimise this day's order?") is now just the
  // "Re-optimise" link itself rather than repeated in the sentence, so the
  // whole thing fits on one line next to the dismiss (x).
  String get _nudgeMessage {
    final weatherBad = _weather?.isDisruptive == true;
    final trafficBad = _route?.isCongested == true;
    if (weatherBad && trafficBad) return '${_weather!.label} forecast · heavier traffic today';
    if (weatherBad) return '${_weather!.label} is forecast for this day';
    return 'Traffic between your activities is heavier than usual today';
  }

  void _reoptimiseNow() {
    setState(() => _dismissedNudge = true);
    startAndShowOptimise(context, widget.controller, OptimiseMode.day, dayIndex: widget.dayIndex, dayNumber: widget.dayNumber);
  }

  Widget _conditionNudge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFCE4BE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB8740A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _nudgeMessage,
              style: const TextStyle(fontSize: 12, color: AppColors.navy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _reoptimiseNow,
            child: const Text('Re-optimise', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _dismissedNudge = true),
            child: const Icon(Icons.close, size: 15, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tripEnded || _tooFarAhead || _isPastDay) return const SizedBox.shrink();
    if (_loading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(30)),
        child: const Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            SizedBox(width: 10),
            Text('Loading conditions…', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
      );
    }
    if (_weather == null && _route == null) return const SizedBox.shrink();

    final showNudge = _hasBadCondition && !_dismissedNudge && !_isPastDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showNudge) _conditionNudge() else _longBar(),
      ],
    );
  }

  /// A single slim horizontal bar: weather on the left, today's traffic (if
  /// any) on the right, separated by a thin divider.
  Widget _longBar() {
    final hasWeather = _weather != null;
    final hasTraffic = _route != null && _routeFromLabel != null && _routeToLabel != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          if (hasWeather) ...[
            Icon(_weather!.icon, size: 18, color: AppColors.navy),
            const SizedBox(width: 6),
            Text(_weather!.tempLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(width: 4),
            Text(_weather!.label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
          if (hasWeather && hasTraffic) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 18, color: const Color(0xFFD9D9D9)),
            const SizedBox(width: 12),
          ],
          if (hasTraffic) ...[
            const Icon(Icons.directions_outlined, size: 16, color: AppColors.textGrey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$_routeFromLabel → $_routeToLabel: ${_route!.durationLabel} (${_route!.distanceLabel})',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else if (hasWeather)
            const Spacer(),
        ],
      ),
    );
  }
}
