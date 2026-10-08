import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../models/day_plan_models.dart';
import '../../repositories/trip_plan_edits.dart';
import '../../repositories/trip_repository.dart';
import '../../services/itinerary_ai_service.dart';
import '../../theme.dart';

/// Opened from the chat's "AI Summarise" attachment option. Starts (or
/// re-opens) this trip's AI run: the model reads the group's discussion
/// together with their saved places and the current plan, and suggests what
/// to add, move, re-time or remove. Nothing changes until the user confirms.
///
/// The run itself lives in [ItineraryAiService], so this sheet can be
/// minimised while it works — [AiItineraryStatusBar] brings it back.
Future<void> showAiItinerarySheet(BuildContext context, GroupTripController controller) {
  final job = ItineraryAiService.instance.jobFor(controller.tripId);
  if (job.value.status == AiItineraryStatus.idle) ItineraryAiService.instance.start(controller.tripId);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AiItinerarySheet(controller: controller, pageContext: context),
  );
}

/// A thin bar for the top of the group page: shows while this trip's AI run
/// is working or has a result waiting, and re-opens the sheet when tapped.
/// Takes no space otherwise.
class AiItineraryStatusBar extends StatelessWidget {
  final GroupTripController controller;
  const AiItineraryStatusBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiItineraryJob>(
      valueListenable: ItineraryAiService.instance.jobFor(controller.tripId),
      builder: (context, job, _) {
        if (job.status == AiItineraryStatus.idle) return const SizedBox.shrink();
        final running = job.status == AiItineraryStatus.running;
        final text = switch (job.status) {
          AiItineraryStatus.running => 'AI is reading your discussion...',
          AiItineraryStatus.ready => 'AI suggestions are ready',
          _ => 'AI Summarise didn\'t finish',
        };
        return Material(
          color: AppColors.chipGrey,
          child: InkWell(
            onTap: () => showAiItinerarySheet(context, controller),
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

class _AiItinerarySheet extends StatefulWidget {
  final GroupTripController controller;

  /// The page under the sheet — used for the snackbar after the sheet closes.
  final BuildContext pageContext;
  const _AiItinerarySheet({required this.controller, required this.pageContext});

  @override
  State<_AiItinerarySheet> createState() => _AiItinerarySheetState();
}

class _AiItinerarySheetState extends State<_AiItinerarySheet> {
  late final ValueNotifier<AiItineraryJob> _job = ItineraryAiService.instance.jobFor(widget.controller.tripId);

  /// The result the ticks below belong to; a new run resets them.
  AiItineraryResult? _selectionFor;

  /// Ticked rows: "a<i>" additions, "u<i>" changes, "r<i>" removals.
  final Set<String> _selected = {};
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

  /// Resets the ticks whenever a new result arrives.
  void _syncSelection() {
    final result = _job.value.result;
    if (result != null && !identical(result, _selectionFor)) {
      _selectionFor = result;
      _selected.clear();
      // Additions and changes start ticked. Removals start unticked: taking
      // something out of the plan should be a deliberate tap.
      for (var i = 0; i < result.add.length; i++) {
        if (!result.add[i].alreadyInPlan) _selected.add('a$i');
      }
      for (var i = 0; i < result.update.length; i++) {
        _selected.add('u$i');
      }
    }
  }

  void _regenerate() {
    setState(() => _applyError = null);
    ItineraryAiService.instance.clear(widget.controller.tripId);
    ItineraryAiService.instance.start(widget.controller.tripId);
  }

  void _discard() {
    ItineraryAiService.instance.clear(widget.controller.tripId);
    Navigator.of(context).pop();
  }

  Future<void> _apply() async {
    final result = _job.value.result;
    if (result == null || _selected.isEmpty || _applying) return;
    setState(() {
      _applying = true;
      _applyError = null;
    });
    final c = widget.controller;
    var done = 0;
    try {
      for (var i = 0; i < result.remove.length; i++) {
        if (!_selected.contains('r$i')) continue;
        await c.removeActivity(result.remove[i].dayIndex, result.remove[i].itemId);
        _selected.remove('r$i');
        done++;
      }
      for (var i = 0; i < result.update.length; i++) {
        if (!_selected.contains('u$i')) continue;
        final u = result.update[i];
        if (u.changesDay) {
          await TripRepository.instance.moveActivity(c.tripId,
              fromDayIndex: u.fromDayIndex,
              toDayIndex: u.toDayIndex,
              itemId: u.itemId,
              time: u.newTime,
              label: u.label,
              iconKey: u.iconKey,
              location: u.location);
        } else {
          await TripRepository.instance.setActivityTime(c.tripId, u.fromDayIndex, u.itemId, u.newTime);
        }
        _selected.remove('u$i');
        done++;
      }
      // One at a time and in day/time order: the plan shows a day's
      // activities in the order they were added.
      for (var i = 0; i < result.add.length; i++) {
        if (!_selected.contains('a$i')) continue;
        final a = result.add[i];
        await c.addActivity(a.dayIndex, time: a.time, label: a.label, iconKey: a.iconKey, location: a.location);
        _selected.remove('a$i');
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
    ItineraryAiService.instance.clear(c.tripId);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (widget.pageContext.mounted) {
      ScaffoldMessenger.of(widget.pageContext).showSnackBar(
        SnackBar(content: Text('Plan updated — $done ${done == 1 ? 'change' : 'changes'} applied')),
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

  String _dayTitle(int day) {
    for (final plan in widget.controller.days) {
      if (plan.day == day) return 'Day $day  ·  ${plan.weekday} ${plan.date}';
    }
    return 'Day $day';
  }

  @override
  Widget build(BuildContext context) {
    final job = _job.value;
    final running = job.status == AiItineraryStatus.running;
    final trip = widget.controller.trip;
    final conflicts = trip == null ? const <ScheduleConflict>[] : findScheduleConflicts(widget.controller.days, trip.memberIds);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 6, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 20, color: AppColors.navy),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('AI Summarise',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
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
            // Shown regardless of the AI job's own status — this comes
            // straight from the current plan's own data (who each
            // activity is for + its time), not from anything the AI
            // reads, so it's accurate even while a run is still going or
            // has nothing to suggest.
            if (conflicts.isNotEmpty) _conflictsSection(conflicts, trip!.memberNames),
            Expanded(child: _body(job)),
            if (job.status == AiItineraryStatus.ready && !job.result!.isEmpty) _footer(),
          ],
        ),
      ),
    );
  }

  /// "Some members are double-booked" warning — one or more same-day,
  /// same-time activities whose "who's this for" lists overlap (see
  /// [findScheduleConflicts]). This is what surfaces "some people want to
  /// go elsewhere at this time while others want to go here" at a glance,
  /// without needing the AI to have figured that out from the chat.
  Widget _conflictsSection(List<ScheduleConflict> conflicts, Map<String, String> memberNames) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy, size: 16, color: AppColors.orange),
              const SizedBox(width: 6),
              Text('Schedule conflict${conflicts.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Some members are booked into two places at the same time — sort out who\'s actually going where.',
            style: TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
          const SizedBox(height: 8),
          for (final c in conflicts) _conflictRow(c, memberNames),
        ],
      ),
    );
  }

  Widget _conflictRow(ScheduleConflict c, Map<String, String> memberNames) {
    final names = c.sharedMemberUids.map((uid) => memberNames[uid]).whereType<String>().where((n) => n.isNotEmpty).join(', ');
    final labels = c.activities.map((a) => '"${a.label}"').join(' and ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        'Day ${c.day}, ${_time12h(c.time)} — ${names.isEmpty ? 'Someone' : names} '
        '${c.sharedMemberUids.length == 1 ? 'is' : 'are'} down for both $labels.',
        style: const TextStyle(fontSize: 12, color: Colors.black),
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

  Widget _body(AiItineraryJob job) {
    switch (job.status) {
      case AiItineraryStatus.idle:
        return const SizedBox.shrink();
      case AiItineraryStatus.running:
        return _message(
          'Reading your group discussion, saved places and current plan...\n\n'
          'This can take a little while. You can minimise this and keep using the app — '
          'the bar at the top of the group will tell you when it\'s ready.',
          spinner: true,
          action: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Minimise', style: TextStyle(color: AppColors.primary)),
          ),
        );
      case AiItineraryStatus.failed:
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
      case AiItineraryStatus.ready:
        break;
    }

    final result = job.result!;
    if (result.isEmpty) {
      return _message(
        'Nothing to change — no new agreed plans found in the chat. Discuss where to go and when, then run it again.',
        action: TextButton(onPressed: _discard, child: const Text('Close', style: TextStyle(color: AppColors.primary))),
      );
    }

    final addDays = <int>{for (final a in result.add) a.day}.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      children: [
        Text(
          'Based on ${result.messageCount} messages, ${result.savedCount} saved '
          '${result.savedCount == 1 ? 'place' : 'places'} and your current plan. Tick what you want applied.',
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        if (_applyError != null) ...[
          const SizedBox(height: 10),
          Text(_applyError!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ],
        if (result.add.isNotEmpty) ...[
          _sectionTitle('Add to plan'),
          for (final day in addDays) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(_dayTitle(day),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
            ),
            for (var i = 0; i < result.add.length; i++)
              if (result.add[i].day == day) _addRow(result.add[i], 'a$i'),
          ],
        ],
        if (result.update.isNotEmpty) ...[
          _sectionTitle('Change in your plan'),
          for (var i = 0; i < result.update.length; i++) _updateRow(result.update[i], 'u$i'),
        ],
        if (result.remove.isNotEmpty) ...[
          _sectionTitle('Remove from your plan', hint: 'The group agreed to drop these. Tick to remove.'),
          for (var i = 0; i < result.remove.length; i++) _removeRow(result.remove[i], 'r$i'),
        ],
        if (result.unresolved.isNotEmpty) ...[
          _sectionTitle('Still undecided', hint: 'Mentioned in the chat, but the group hasn\'t agreed yet.'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in result.unresolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
                  child: Text(name, style: const TextStyle(fontSize: 12, color: AppColors.navy)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
          ],
        ],
      ),
    );
  }

  /// One tickable row. [disabled] rows are shown greyed and cannot be ticked.
  Widget _row({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    String? warning,
    bool disabled = false,
  }) {
    final selected = _selected.contains(key);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: disabled || _applying
          ? null
          : () => setState(() => selected ? _selected.remove(key) : _selected.add(key)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: disabled ? AppColors.textGrey : AppColors.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: disabled ? AppColors.textGrey : Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  if (warning != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 13, color: AppColors.orange),
                        const SizedBox(width: 4),
                        Expanded(child: Text(warning, style: const TextStyle(fontSize: 11.5, color: AppColors.orange))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!disabled)
              Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22, color: selected ? AppColors.primary : AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _addRow(AiItineraryAdd a, String key) {
    return _row(
      key: key,
      icon: iconForKey(a.iconKey),
      title: a.label,
      subtitle: [
        _time12h(a.time),
        if (a.location.isNotEmpty) a.location,
        if (a.alreadyInPlan) 'Already in plan',
      ].join('  ·  '),
      warning: a.warnNotSaved && !a.alreadyInPlan ? 'Not in your group\'s saved list' : null,
      disabled: a.alreadyInPlan,
    );
  }

  Widget _updateRow(AiItineraryUpdate u, String key) {
    final from = 'Day ${u.fromDay}, ${_time12h(u.oldTime)}';
    final to = u.changesDay ? 'Day ${u.toDay}, ${_time12h(u.newTime)}' : _time12h(u.newTime);
    return _row(key: key, icon: iconForKey(u.iconKey), title: u.label, subtitle: '$from  →  $to');
  }

  Widget _removeRow(AiItineraryRemove r, String key) {
    return _row(
      key: key,
      icon: Icons.remove_circle_outline,
      title: r.label,
      subtitle: 'Day ${r.day}${r.time.isEmpty ? '' : ', ${_time12h(r.time)}'}',
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
