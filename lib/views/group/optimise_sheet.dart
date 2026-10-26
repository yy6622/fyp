import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../repositories/trip_plan_edits.dart';
import '../../repositories/trip_repository.dart';
import '../../services/itinerary_ai_service.dart' show AiItineraryUpdate;
import '../../services/itinerary_optimise_service.dart';
import '../../theme.dart';

/// Opened from the Day header's diamond (sparkle) icon — lets the person
/// choose "Optimise this day" or "Optimise whole trip" before anything
/// runs, then opens [_OptimiseSheet] for whichever they picked.
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
              startAndShowOptimise(context, controller, OptimiseMode.day, dayIndex: dayIndex, dayNumber: dayNumber);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: AppColors.primary),
            title: const Text('Optimise Whole Trip'),
            subtitle: const Text('Rework the schedule across every day', style: TextStyle(fontSize: 11.5)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              startAndShowOptimise(context, controller, OptimiseMode.whole);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Starts (or reopens) an Optimise run and shows its progress/result
/// sheet — exported (not just used inside this file) so other widgets
/// that want to trigger Optimise directly, such as the weather/traffic
/// nudge in live_conditions_card.dart, can reuse the exact same
/// start-then-show flow instead of duplicating it.
void startAndShowOptimise(
  BuildContext context,
  GroupTripController controller,
  OptimiseMode mode, {
  int? dayIndex,
  int? dayNumber,
}) {
  // Always call start(): the service itself now decides whether this is
  // the same scope as what's already running/ready (then it's a no-op, so
  // reopening a minimised run just shows what's there) or a different one
  // (then it replaces it) — see ItineraryOptimiseService.start's doc.
  ItineraryOptimiseService.instance.start(controller.tripId, mode: mode, dayIndex: dayIndex, dayNumber: dayNumber);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _OptimiseSheet(controller: controller, mode: mode, dayIndex: dayIndex, dayNumber: dayNumber, pageContext: context),
  );
}

/// Reopens the sheet for whatever scope is currently running/ready for
/// [controller]'s trip — used by [OptimiseStatusBar] when the person taps
/// it to come back to a run they minimised. Does nothing if there's no
/// scope recorded (shouldn't happen: the status bar only shows when there
/// is one).
void _reopenOptimiseSheet(BuildContext context, GroupTripController controller) {
  final scope = ItineraryOptimiseService.instance.scopeFor(controller.tripId);
  if (scope == null) return;
  startAndShowOptimise(context, controller, scope.mode, dayIndex: scope.dayIndex, dayNumber: scope.dayNumber);
}

/// Persistent bar shown whenever a trip has an Optimise run in progress or
/// waiting — the Optimise equivalent of [AiItineraryStatusBar]
/// (ai_itinerary_sheet.dart), and the actual fix for "I minimised it and
/// then couldn't find the result again": without this there was nothing on
/// screen reminding the person a run existed, so they had no way back to
/// it short of retracing the exact same taps.
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

  /// Needed to re-run [OptimiseMode.day] from "Try again" — unused for
  /// [OptimiseMode.whole].
  final int? dayIndex;

  /// 1-based day number, for the [OptimiseMode.day] title — unused for
  /// [OptimiseMode.whole].
  final int? dayNumber;

  /// The page under the sheet — used for the snackbar after the sheet closes.
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

  /// The result the ticks below belong to; a new run resets them.
  OptimiseResult? _selectionFor;

  /// Ticked rows, by index into [OptimiseResult.changes].
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

  /// Resets the ticks whenever a new result arrives. Every change starts
  /// ticked — unlike AI Summarise's "remove" rows, a reorder/re-time is
  /// never destructive, so there's no reason to make the person opt in
  /// one-by-one.
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
      // What was applied has been unticked above, so "Apply" again only retries the rest.
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
        Text(
          'Based on ${result.itemCount} ${result.itemCount == 1 ? 'activity' : 'activities'} in your current plan, '
          'opening times and visit lengths, and your flights and hotel. Tick what you want applied.',
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
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

  /// Something Optimise could not fix by itself (a day that is too full in "this day" mode).
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
