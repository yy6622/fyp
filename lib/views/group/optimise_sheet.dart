import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../repositories/trip_plan_edits.dart';
import '../../repositories/trip_repository.dart';
import '../../services/itinerary_ai_service.dart' show AiItineraryUpdate;
import '../../services/itinerary_optimise_service.dart';
import '../../services/missing_bookings.dart';
import '../../services/format_utils.dart' show parseClockTime;
import '../../services/places_api_service.dart';
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';
import '../../theme.dart';

Future<void> showOptimiseModeSheet(
  BuildContext context,
  GroupTripController controller, {
  required int dayIndex,
  required int dayNumber,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: AppColors.navy),
                SizedBox(width: 8),
                Text('Optimise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.today_outlined, color: AppColors.primary),
            title: Text('Optimise Day $dayNumber'),
            subtitle: const Text('Reorder and re-time just this day\'s activities', style: TextStyle(fontSize: 11.5)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              startOptimiseFlow(context, controller, OptimiseMode.day, dayIndex: dayIndex, dayNumber: dayNumber);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: AppColors.primary),
            title: const Text('Optimise Whole Trip'),
            subtitle: const Text('Rework the schedule across every day', style: TextStyle(fontSize: 11.5)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              startOptimiseFlow(context, controller, OptimiseMode.whole);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void startAndShowOptimise(
  BuildContext context,
  GroupTripController controller,
  OptimiseMode mode, {
  int? dayIndex,
  int? dayNumber,
  Map<int, List<(int start, int end)>> rainWindows = const {},
  List<({String fromItemId, String toItemId, int extraMinutes})> congestedLegs = const [],
}) {
  ItineraryOptimiseService.instance.start(
    controller.tripId,
    mode: mode,
    dayIndex: dayIndex,
    dayNumber: dayNumber,
    rainWindows: rainWindows,
    congestedLegs: congestedLegs,
  );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _OptimiseSheet(controller: controller, mode: mode, dayIndex: dayIndex, dayNumber: dayNumber, pageContext: context),
  );
}

/// Forecast rain windows (minute-of-day [start, end) pairs) for every day
/// [mode] will touch -- just [dayNumber] for a single day, every day in the
/// trip for a whole-trip run -- so Optimise can route outdoor activities
/// around them. Empty wherever the destination can't be geocoded or the
/// forecast doesn't reach that far; never throws.
Future<Map<int, List<(int start, int end)>>> _rainWindowsForOptimise(
  Trip trip,
  OptimiseMode mode, {
  int? dayNumber,
}) async {
  if (trip.destination.trim().isEmpty) return const {};
  final targets = mode == OptimiseMode.day
      ? (dayNumber != null ? [dayNumber] : const <int>[])
      : [for (final day in trip.days) day.day];
  if (targets.isEmpty) return const {};
  final entries = await Future.wait(targets.map((n) async {
    final date = trip.dateForDay(n);
    if (date == null) return null;
    final windows = await WeatherService.instance.hourlyRainWindows(trip.destination, date);
    if (windows.isEmpty) return null;
    return MapEntry(n, [for (final w in windows) (w.start, w.end)]);
  }));
  return {for (final e in entries) if (e != null) e.key: e.value};
}

/// Adjacent-activity legs that are *currently* measured as congested, for
/// every day [mode] will touch -- by the two plan item ids either side of
/// the leg plus how many minutes over the typical drive time it currently
/// is. Traffic has no hour-by-hour forecast the way rain does, so this only
/// ever reflects *today's* plan -- empty for every other day, for any day
/// with fewer than 2 located activities, or when geocoding/the routes API
/// fails; never throws. Lets Optimise add a realistic buffer (and prefer
/// not to keep the two stops adjacent when a reorder can avoid it) instead
/// of silently using the same fixed 15/30 min gap it would for any other
/// pair of stops.
Future<List<({String fromItemId, String toItemId, int extraMinutes})>> _congestedLegsForOptimise(
  Trip trip,
  OptimiseMode mode, {
  int? dayNumber,
}) async {
  bool isToday(DateTime? d) {
    if (d == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateStart = DateTime(d.year, d.month, d.day);
    return dateStart.isAtSameMomentAs(todayStart);
  }

  final targetDays = mode == OptimiseMode.day
      ? (dayNumber != null ? [dayNumber] : const <int>[])
      : [for (final day in trip.days) day.day];

  // A live "right now" traffic reading has no predictive value for a leg
  // many hours away -- mirrored in live_conditions_card.dart's
  // _maxTrafficGapMinutes (same value, same reasoning: by departure time
  // the reading is stale, and that much slack means the user may not even
  // travel this leg directly, e.g. a stop back at the hotel in between).
  const maxTrafficGapMinutes = 180;

  final legs = <({String fromItemId, String toItemId, int extraMinutes})>[];
  for (final n in targetDays) {
    if (!isToday(trip.dateForDay(n))) continue; // traffic is only meaningful for today
    final dayPlan = trip.days.where((d) => d.day == n).firstOrNull;
    if (dayPlan == null) continue;
    final located = dayPlan.items.where((it) => it.id.isNotEmpty && it.location.trim().isNotEmpty).toList();
    for (var i = 0; i < located.length - 1; i++) {
      final a = located[i];
      final b = located[i + 1];
      final at = parseClockTime(a.time);
      final bt = parseClockTime(b.time);
      if (at != null && bt != null) {
        final gap = (bt.hour * 60 + bt.minute) - (at.hour * 60 + at.minute);
        if (gap > maxTrafficGapMinutes) continue;
      }
      final fromGeo = await PlacesApiService.instance.geocode(a.location);
      final toGeo = await PlacesApiService.instance.geocode(b.location);
      if (fromGeo == null || toGeo == null) continue;
      final route = await TrafficService.instance.travelTime(
        fromLat: fromGeo.lat, fromLon: fromGeo.lon, toLat: toGeo.lat, toLon: toGeo.lon,
      );
      if (route == null || !route.isCongested) continue;
      final typical = route.staticDurationSeconds ?? route.travelTimeSeconds;
      final extraMinutes = ((route.travelTimeSeconds - typical) / 60).round();
      if (extraMinutes <= 0) continue;
      legs.add((fromItemId: a.id, toItemId: b.id, extraMinutes: extraMinutes));
    }
  }
  return legs;
}

/// Entry point for starting a *new* Optimise run (not for reopening an
/// already-running/ready one -- see [_reopenOptimiseSheet]). Before handing
/// off to [startAndShowOptimise], checks whether the trip has a flight or
/// hotel stay from Overview that was never added into the day-by-day plan,
/// and if so asks the user whether to add it in first -- timed around its
/// real departure/landing or check-in/check-out -- so Optimise has it to
/// work with. Also looks up the forecast for the day(s) in scope so
/// Optimise can route outdoor activities around any rain.
Future<void> startOptimiseFlow(
  BuildContext context,
  GroupTripController controller,
  OptimiseMode mode, {
  int? dayIndex,
  int? dayNumber,
}) async {
  final trip = controller.trip;
  if (trip != null) {
    final missing = findMissingBookings(trip);
    if (missing.isNotEmpty) {
      if (!context.mounted) return;
      await _offerToAddMissingBookings(context, controller, missing);
    }
  }
  if (!context.mounted) return;
  final rainWindows = trip != null
      ? await _rainWindowsForOptimise(trip, mode, dayNumber: dayNumber)
      : const <int, List<(int, int)>>{};
  if (!context.mounted) return;
  final congestedLegs = trip != null
      ? await _congestedLegsForOptimise(trip, mode, dayNumber: dayNumber)
      : const <({String fromItemId, String toItemId, int extraMinutes})>[];
  if (!context.mounted) return;
  startAndShowOptimise(context, controller, mode,
      dayIndex: dayIndex, dayNumber: dayNumber, rainWindows: rainWindows, congestedLegs: congestedLegs);
}

String _missingBookingTime12h(String time24) {
  final parts = time24.split(':');
  if (parts.length != 2) return time24;
  final h = int.tryParse(parts[0]);
  if (h == null) return time24;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${parts[1]} ${h < 12 ? 'AM' : 'PM'}';
}

Future<void> _offerToAddMissingBookings(
  BuildContext context,
  GroupTripController controller,
  List<MissingBooking> missing,
) async {
  final selected = Set<int>.from(List.generate(missing.length, (i) => i));
  final add = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.luggage_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      missing.length == 1 ? 'Add this booking to your plan?' : 'Add these bookings to your plan?',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                (missing.length == 1
                        ? "This flight/hotel from Overview isn't"
                        : "These flights/hotels from Overview aren't") +
                    ' in the day-by-day plan yet. Add them in, timed around the real departure/landing and '
                        'check-in/check-out times.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < missing.length; i++) _missingBookingRow(missing[i], i, selected, setState),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Skip', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: selected.isEmpty ? null : () => Navigator.of(ctx).pop(true),
                      child: Text(
                        selected.isEmpty ? 'Nothing selected' : 'Add ${selected.length} & Optimise',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (add != true) return;
  for (var i = 0; i < missing.length; i++) {
    if (!selected.contains(i)) continue;
    final m = missing[i];
    await controller.addActivity(
      m.dayIndex,
      time: m.time,
      label: m.label,
      iconKey: m.iconKey,
      location: m.location,
      sourceRef: m.sourceRef,
    );
  }
}

Widget _missingBookingRow(MissingBooking m, int i, Set<int> selected, StateSetter setState) {
  final isSelected = selected.contains(i);
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => isSelected ? selected.remove(i) : selected.add(i)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconForKey(m.iconKey), size: 18, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 2),
                Text(
                  'Day ${m.dayIndex + 1}, ${_missingBookingTime12h(m.time)}'
                  '${m.location.isEmpty ? '' : ' \u00b7 ${m.location}'}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20, color: isSelected ? AppColors.primary : AppColors.textGrey),
        ],
      ),
    ),
  );
}

void _reopenOptimiseSheet(BuildContext context, GroupTripController controller) {
  final scope = ItineraryOptimiseService.instance.scopeFor(controller.tripId);
  if (scope == null) return;
  startAndShowOptimise(context, controller, scope.mode, dayIndex: scope.dayIndex, dayNumber: scope.dayNumber);
}

class OptimiseStatusBar extends StatelessWidget {
  final GroupTripController controller;
  const OptimiseStatusBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OptimiseJob>(
      valueListenable: ItineraryOptimiseService.instance.jobFor(controller.tripId),
      builder: (context, job, _) {
        if (job.status == OptimiseStatus.idle) return const SizedBox.shrink();
        final running = job.status == OptimiseStatus.running;
        final scope = ItineraryOptimiseService.instance.scopeFor(controller.tripId);
        final scopeLabel = scope?.mode == OptimiseMode.day
            ? (scope?.dayNumber != null ? 'Day ${scope!.dayNumber}' : 'this day')
            : 'your whole trip';
        final text = switch (job.status) {
          OptimiseStatus.running => 'Optimising $scopeLabel...',
          OptimiseStatus.ready => 'Optimise suggestions ready',
          _ => 'Optimise didn\'t finish',
        };
        return Material(
          color: AppColors.chipGrey,
          child: InkWell(
            onTap: () => _reopenOptimiseSheet(context, controller),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  if (running)
                    const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  else
                    const Icon(Icons.auto_awesome, size: 16, color: AppColors.navy),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.navy))),
                  Text(running ? 'Show' : 'View',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OptimiseSheet extends StatefulWidget {
  final GroupTripController controller;
  final OptimiseMode mode;

  final int? dayIndex;

  final int? dayNumber;

  final BuildContext pageContext;

  const _OptimiseSheet({
    required this.controller,
    required this.mode,
    required this.dayIndex,
    required this.dayNumber,
    required this.pageContext,
  });

  @override
  State<_OptimiseSheet> createState() => _OptimiseSheetState();
}

class _OptimiseSheetState extends State<_OptimiseSheet> {
  late final ValueNotifier<OptimiseJob> _job = ItineraryOptimiseService.instance.jobFor(widget.controller.tripId);

  OptimiseResult? _selectionFor;

  final Set<int> _selected = {};
  bool _applying = false;
  String? _applyError;

  @override
  void initState() {
    super.initState();
    _job.addListener(_onJob);
    _syncSelection();
  }

  @override
  void dispose() {
    _job.removeListener(_onJob);
    super.dispose();
  }

  void _onJob() {
    _syncSelection();
    if (mounted) setState(() {});
  }

  void _syncSelection() {
    final result = _job.value.result;
    if (result != null && !identical(result, _selectionFor)) {
      _selectionFor = result;
      _selected
        ..clear()
        ..addAll(List.generate(result.changes.length, (i) => i));
    }
  }

  void _regenerate() {
    setState(() => _applyError = null);
    ItineraryOptimiseService.instance.clear(widget.controller.tripId);
    ItineraryOptimiseService.instance.start(
      widget.controller.tripId,
      mode: widget.mode,
      dayIndex: widget.dayIndex,
      dayNumber: widget.dayNumber,
    );
  }

  void _discard() {
    ItineraryOptimiseService.instance.clear(widget.controller.tripId);
    Navigator.of(context).pop();
  }

  Future<void> _apply() async {
    final result = _job.value.result;
    if (result == null || _selected.isEmpty || _applying) return;
    setState(() {
      _applying = true;
      _applyError = null;
    });
    final tripId = widget.controller.tripId;
    var done = 0;
    try {
      for (var i = 0; i < result.changes.length; i++) {
        if (!_selected.contains(i)) continue;
        final u = result.changes[i];
        if (u.changesDay) {
          await TripRepository.instance.moveActivity(
            tripId,
            fromDayIndex: u.fromDayIndex,
            toDayIndex: u.toDayIndex,
            itemId: u.itemId,
            time: u.newTime,
            label: u.label,
            iconKey: u.iconKey,
            location: u.location,
          );
        } else {
          await TripRepository.instance.setActivityTime(tripId, u.fromDayIndex, u.itemId, u.newTime);
        }
        _selected.remove(i);
        done++;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _applyError = done == 0 ? 'Could not update the plan: $e' : 'Applied $done, then stopped: $e';
      });
      return;
    }
    ItineraryOptimiseService.instance.clear(tripId);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (widget.pageContext.mounted) {
      ScaffoldMessenger.of(widget.pageContext).showSnackBar(
        SnackBar(content: Text('Plan optimised — $done ${done == 1 ? 'change' : 'changes'} applied')),
      );
    }
  }

  String _time12h(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    final h = int.tryParse(parts[0]);
    if (h == null) return time24;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${parts[1]} ${h < 12 ? 'AM' : 'PM'}';
  }

  String get _title => widget.mode == OptimiseMode.day
      ? (widget.dayNumber != null ? 'Optimise Day ${widget.dayNumber}' : 'Optimise This Day')
      : 'Optimise Whole Trip';

  @override
  Widget build(BuildContext context) {
    final job = _job.value;
    final running = job.status == OptimiseStatus.running;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 6, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 20, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                  if (!running)
                    IconButton(
                      tooltip: 'Run again',
                      icon: const Icon(Icons.refresh, color: AppColors.textGrey),
                      onPressed: _applying ? null : _regenerate,
                    ),
                  IconButton(
                    tooltip: 'Minimise',
                    icon: const Icon(Icons.keyboard_arrow_down, size: 28, color: AppColors.textGrey),
                    onPressed: _applying ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(job)),
            if (job.status == OptimiseStatus.ready && !job.result!.isEmpty) _footer(),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {Widget? action, bool spinner = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 18),
            ],
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            if (action != null) ...[const SizedBox(height: 14), action],
          ],
        ),
      ),
    );
  }

  Widget _body(OptimiseJob job) {
    switch (job.status) {
      case OptimiseStatus.idle:
        return const SizedBox.shrink();
      case OptimiseStatus.running:
        return _message(
          'Working out the best order for ${widget.mode == OptimiseMode.day ? 'this day' : 'your whole trip'}...\n\n'
          'You can minimise this and keep using the app.',
          spinner: true,
          action: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Minimise', style: TextStyle(color: AppColors.primary)),
          ),
        );
      case OptimiseStatus.failed:
        return _message(
          job.error ?? 'Something went wrong.',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: _discard, child: const Text('Close', style: TextStyle(color: AppColors.textGrey))),
              TextButton(onPressed: _regenerate, child: const Text('Try again', style: TextStyle(color: AppColors.primary))),
            ],
          ),
        );
      case OptimiseStatus.ready:
        break;
    }

    final result = job.result!;
    if (result.isEmpty) {
      return _message(
        'Your ${widget.mode == OptimiseMode.day ? 'day' : 'trip'} is already in a good order — looked at '
        '${result.itemCount} ${result.itemCount == 1 ? 'activity' : 'activities'}, nothing to change.'
        '${result.notes.isEmpty ? '' : '\n\n${result.notes.join('\n')}'}',
        action: TextButton(onPressed: _discard, child: const Text('Close', style: TextStyle(color: AppColors.primary))),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      children: [
        // The explanatory paragraph that used to sit here ("Based on N
        // activities in your current plan...") was just noise -- each row
        // below already has its own checkbox-style selection icon, so
        // "tick what you want applied" is obvious without a caption.
        for (final note in result.notes) _note(note),
        if (_applyError != null) ...[
          const SizedBox(height: 10),
          Text(_applyError!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ],
        const SizedBox(height: 10),
        for (var i = 0; i < result.changes.length; i++) _changeRow(result.changes[i], i),
      ],
    );
  }

  Widget _changeRow(AiItineraryUpdate u, int i) {
    final selected = _selected.contains(i);
    final from = 'Day ${u.fromDay}, ${_time12h(u.oldTime)}';
    final to = u.changesDay ? 'Day ${u.toDay}, ${_time12h(u.newTime)}' : _time12h(u.newTime);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _applying ? null : () => setState(() => selected ? _selected.remove(i) : _selected.add(i)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(iconForKey(u.iconKey), size: 20, color: AppColors.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text('$from  →  $to', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  if (u.reason.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(u.reason, style: const TextStyle(fontSize: 11.5, color: Color(0xFF2E9E5B), fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22, color: selected ? AppColors.primary : AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _note(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _footer() {
    final n = _selected.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          TextButton(
            onPressed: _applying ? null : _discard,
            child: const Text('Discard', style: TextStyle(color: AppColors.textGrey)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: n == 0 || _applying ? null : _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _applying
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(n == 0 ? 'Nothing selected' : 'Apply $n ${n == 1 ? 'change' : 'changes'}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
