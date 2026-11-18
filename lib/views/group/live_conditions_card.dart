import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../models/day_plan_models.dart';
import '../../services/format_utils.dart' show parseClockTime;
import '../../services/places_api_service.dart';
import '../../services/itinerary_optimise_service.dart' show OptimiseMode;
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';
import '../../theme.dart';
import 'optimise_sheet.dart' show startOptimiseFlow;

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

/// One activity-to-activity leg of the day's route with its traffic
/// reading -- there can be several of these across a day, not just one.
class _RouteLeg {
  final String fromLabel;
  final String toLabel;
  final TrafficRoute route;
  const _RouteLeg({required this.fromLabel, required this.toLabel, required this.route});

  int get extraMinutes {
    final typical = route.staticDurationSeconds ?? route.travelTimeSeconds;
    return ((route.travelTimeSeconds - typical) / 60).round();
  }
}

class _LiveConditionsCardState extends State<LiveConditionsCard> {
  bool _loading = true;
  DestinationWeather? _weather;

  // Every consecutive activity-to-activity leg of the day that has a
  // traffic reading -- not just the first pair, so a jam later in the day
  // (e.g. activity #3 -> #4) is never missed just because the first leg
  // of the day happened to be clear.
  List<_RouteLeg> _legs = const [];

  // Hour-by-hour rain windows for this day, fetched only once the day's
  // weather actually looks disruptive -- used to say exactly when it rains
  // instead of a vague "rain is forecast", and fed to Optimise when the
  // user taps re-optimise.
  List<({int start, int end})> _rainWindows = const [];

  // A live "right now" traffic reading has no predictive value for a leg
  // that's many hours away -- by the time the user actually leaves, current
  // congestion will be long gone (or new congestion will have appeared),
  // and there's enough slack that *when* exactly they leave is flexible
  // anyway (they might even go back to the hotel in between, not travel
  // this leg directly at all). So a leg is only checked for traffic if its
  // two activities are within this many minutes of each other -- mirrored
  // in optimise_sheet.dart's _congestedLegsForOptimise.
  static const int _maxTrafficGapMinutes = 180;

  // Shown once per card lifetime: a delay/bad-condition popup should nudge
  // the user to re-optimise, not sit as a permanent inline warning banner.
  bool _promptShown = false;

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

  bool get _tooFarAhead {
    final forDate = widget.forDate;
    if (forDate == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateStart = DateTime(forDate.year, forDate.month, forDate.day);
    return dateStart.isAfter(todayStart.add(const Duration(days: 7)));
  }

  /// The automatic "conditions have changed" popup only makes sense for
  /// the very near term: a multi-day-out weather forecast is unreliable,
  /// and a popup firing on every day of a long trip would just annoy the
  /// user. Only today's or tomorrow's card offers to auto re-optimise --
  /// further-out days still show the plain weather/traffic bar (nothing is
  /// hidden), and any day can still be re-optimised manually from the
  /// "Optimise Day" / "Optimise Whole Trip" menu regardless of this.
  bool get _withinNudgeWindow {
    final forDate = widget.forDate;
    if (forDate == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateStart = DateTime(forDate.year, forDate.month, forDate.day);
    return !dateStart.isBefore(todayStart) && !dateStart.isAfter(todayStart.add(const Duration(days: 1)));
  }

  Future<void> _load() async {
    if (_tripEnded || _tooFarAhead || _isPastDay) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _legs = const [];
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
    final checkRoutes = _isToday && withLocation.length >= 2;

    final weather = await weatherFuture;
    final rainWindows = (weather?.isDisruptive == true && forDate != null && dest.isNotEmpty)
        ? await WeatherService.instance.hourlyRainWindows(dest, forDate)
        : const <({int start, int end})>[];

    // Check every consecutive pair for the day, not just the first -- a day
    // with 4 activities has 3 legs, and a jam on any one of them is just as
    // real as a jam on the first.
    final legs = <_RouteLeg>[];
    if (checkRoutes) {
      for (var i = 0; i < withLocation.length - 1; i++) {
        final a = withLocation[i];
        final b = withLocation[i + 1];
        final at = parseClockTime(a.time);
        final bt = parseClockTime(b.time);
        if (at != null && bt != null) {
          final gap = (bt.hour * 60 + bt.minute) - (at.hour * 60 + at.minute);
          if (gap > _maxTrafficGapMinutes) continue; // too far apart for a live reading to mean anything
        }
        final fromGeo = await _geocodeOrNull(a.location);
        final toGeo = await _geocodeOrNull(b.location);
        if (fromGeo == null || toGeo == null) continue;
        final route = await TrafficService.instance
            .travelTime(fromLat: fromGeo.lat, fromLon: fromGeo.lon, toLat: toGeo.lat, toLon: toGeo.lon);
        if (route != null) legs.add(_RouteLeg(fromLabel: a.label, toLabel: b.label, route: route));
      }
    }

    if (!mounted) return;
    setState(() {
      _weather = weather;
      _rainWindows = rainWindows;
      _legs = legs;
      _loading = false;
    });
    _maybeShowOptimisePopup();
  }

  bool get _allIndoor => allActivitiesLikelyIndoor(widget.activities);

  /// True only when a forecast rain window actually overlaps a confidently
  /// *outdoor* activity's scheduled time on this day -- not just "the
  /// weather looks bad today" (the day's plan could be empty, all-indoor,
  /// or simply not scheduled anywhere near the rain). "Disruptive weather"
  /// alone is not a reason to nudge the user if nothing in their plan would
  /// actually collide with it.
  bool get _weatherCrashesPlan {
    if (_weather?.isDisruptive != true || _rainWindows.isEmpty) return false;
    for (final a in widget.activities) {
      if (isLikelyIndoor(a.label) != false) continue; // only confidently-outdoor activities count
      final t = parseClockTime(a.time);
      if (t == null) continue;
      final mins = t.hour * 60 + t.minute;
      if (_rainWindows.any((w) => mins >= w.start && mins < w.end)) return true;
    }
    return false;
  }

  // Every leg currently measured as congested today -- not just one.
  List<_RouteLeg> get _congestedLegs => _legs.where((l) => l.route.isCongested).toList();

  /// The single most-delayed leg, for the one-line summary -- `null` if
  /// nothing today is actually congested.
  _RouteLeg? get _worstLeg {
    final congested = _congestedLegs;
    if (congested.isEmpty) return null;
    return congested.reduce((a, b) => a.extraMinutes >= b.extraMinutes ? a : b);
  }

  bool get _hasBadCondition => _weatherCrashesPlan || (!_allIndoor && _congestedLegs.isNotEmpty);

  String _minuteLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }

  /// "2:00 PM–5:00 PM" (joined by ", " if there's more than one window), or
  /// null if no hourly window could be resolved -- in which case the
  /// message falls back to the day-level weather label instead of a time.
  String? get _rainWindowsLabel => _rainWindows.isEmpty
      ? null
      : _rainWindows.map((w) => '${_minuteLabel(w.start)}–${_minuteLabel(w.end)}').join(', ');

  // Message shown inside the re-optimise popup when a delay/bad condition
  // is detected -- describes what changed, and when, so the question
  // ("re-optimise this day's order?") has concrete context instead of a
  // vague "conditions changed".
  String get _nudgeMessage {
    final weatherBad = _weatherCrashesPlan;
    final congested = _congestedLegs;
    final worst = _worstLeg;
    final rain = _rainWindowsLabel;
    final weatherPart = rain != null ? 'Rain forecast $rain today' : '${_weather?.label ?? 'Bad weather'} is forecast for this day';
    final moreCount = congested.length - 1;
    final trafficPhrase = worst == null
        ? null
        : 'heavier traffic from ${worst.fromLabel} to ${worst.toLabel}${moreCount > 0 ? ' (+$moreCount more)' : ''}';
    if (weatherBad && trafficPhrase != null) return '$weatherPart, and $trafficPhrase';
    if (weatherBad) {
      return rain != null
          ? '$weatherPart. Re-optimising will try to move outdoor plans outside that window.'
          : weatherPart;
    }
    if (trafficPhrase != null) return 'Today\'s plan has $trafficPhrase';
    return 'Traffic between your activities is heavier than usual today';
  }

  void _reoptimiseNow() {
    startOptimiseFlow(context, widget.controller, OptimiseMode.day, dayIndex: widget.dayIndex, dayNumber: widget.dayNumber);
  }

  /// Pops up once (per card lifetime) when a delay/bad condition is first
  /// detected, asking the user whether to re-optimise this day -- instead
  /// of a permanent inline warning banner sitting under the weather bar.
  void _maybeShowOptimisePopup() {
    if (!_hasBadCondition || _promptShown || _isPastDay || !_withinNudgeWindow) return;
    _promptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB8740A)),
          title: const Text('Conditions have changed'),
          content: Text(_nudgeMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _reoptimiseNow();
              },
              child: const Text('Re-optimise'),
            ),
          ],
        ),
      );
    });
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
    if (_weather == null && _legs.isEmpty) return const SizedBox.shrink();

    // Weather (and traffic, when relevant) always display as a plain bar --
    // a delay/bad condition surfaces as a one-time popup instead of a
    // permanent inline warning row here.
    return _longBar();
  }

  /// Weather on its own full-width row; when traffic is also relevant
  /// today, a second row of the *same* height sits right below it (split by
  /// a thin divider) instead of being crammed sideways into one row and
  /// ellipsized into unreadable text -- that cramped single-row layout was
  /// the whole reason Day 1 (weather + traffic) and Day 2 (weather only)
  /// used to look like two different, unrelated UI shapes.
  Widget _longBar() {
    final hasWeather = _weather != null;
    // Shows the worst (most-delayed) leg when anything is congested, else
    // just the first leg of the day -- same layout either way, with a
    // "+N more" suffix so a second/third jam is never silently dropped
    // just because there's only room to name one.
    final shownLeg = _worstLeg ?? (_legs.isNotEmpty ? _legs.first : null);
    final hasTraffic = shownLeg != null;
    final moreCount = _congestedLegs.length - 1;
    final trafficLabel = shownLeg == null
        ? ''
        : '${shownLeg.fromLabel} → ${shownLeg.toLabel}: ${shownLeg.route.durationLabel} '
          '(${shownLeg.route.distanceLabel})${moreCount > 0 ? ' +$moreCount more' : ''}';

    Widget row({required Widget icon, required Widget content}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [icon, const SizedBox(width: 8), Expanded(child: content)]),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasWeather)
            row(
              icon: Icon(_weather!.icon, size: 18, color: AppColors.navy),
              content: Row(
                children: [
                  Text(_weather!.tempLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(_weather!.label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          if (hasWeather && hasTraffic)
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: const Color(0xFFD9D9D9)),
          if (hasTraffic)
            row(
              icon: const Icon(Icons.directions_outlined, size: 16, color: AppColors.textGrey),
              content: Text(
                trafficLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }
}
