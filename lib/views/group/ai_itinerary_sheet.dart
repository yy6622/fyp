import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../models/day_plan_models.dart';
import '../../repositories/trip_plan_edits.dart';
import '../../repositories/trip_repository.dart';
import '../../services/itinerary_ai_service.dart';
import '../../services/discussion_summary_service.dart';
import 'decide_now_sheet.dart';
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
    // The model's view of what is still undecided - behind the "Decide now" button below.
    DiscussionSummaryService.instance.start(widget.controller.tripId);
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
    DiscussionSummaryService.instance.start(widget.controller.tripId);
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

    final planDays = <int>{
      for (final a in result.add) a.day,
      for (final u in result.update) u.toDay,
    }.toList()
      ..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: [
        _overview(result),
        if (_applyError != null) ...[
          const SizedBox(height: 10),
          Text(_applyError!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ],
        if (planDays.isNotEmpty) ...[
          _sectionTitle('Suggested plan', hint: 'Tick what to add. Grey rows are already in your plan, so nothing overlaps.'),
          for (final day in planDays) _dayBlock(day, result),
        ],
        if (result.remove.isNotEmpty) ...[
          _sectionTitle('Take out of the plan', hint: 'The group agreed to drop these. Tick to remove.'),
          for (var i = 0; i < result.remove.length; i++) _removeRow(result.remove[i], 'r$i'),
        ],
        if (result.unresolved.isNotEmpty) ...[
          _undecidedHeader(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final name in result.unresolved) _chip(name, Icons.help_outline, AppColors.orange)],
          ),
        ],
        if (result.ideas.isNotEmpty) ...[
          _sectionTitle('Ideas without a place yet'),
          const SizedBox(height: 4),
          for (final idea in result.ideas) _ideaRow(idea),
        ],
      ],
    );
  }

  /// "Still undecided" + a "Decide now" button (agree / skip / vote / split, see decide_now_sheet.dart),
  /// enabled once the discussion summary for this trip is ready.
  Widget _undecidedHeader() {
    return ValueListenableBuilder<DiscussionSummaryJob>(
      valueListenable: DiscussionSummaryService.instance.jobFor(widget.controller.tripId),
      builder: (context, job, _) {
        final summary = job.status == DiscussionSummaryStatus.ready ? job.result : null;
        final open = summary == null ? 0 : summary.pending.where((p) => p.decided?.status != 'voting').length;
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Still undecided', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    SizedBox(height: 2),
                    Text('Talked about, but the group hasn\'t agreed yet.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  ],
                ),
              ),
              if (job.status == DiscussionSummaryStatus.running)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange)),
                )
              else if (summary != null && summary.pending.isNotEmpty)
                TextButton.icon(
                  onPressed: () => showDecideNowSheet(context, widget.controller, summary),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.how_to_vote_outlined, size: 16, color: AppColors.orange),
                  label: Text(open > 0 ? 'Decide now' : 'In a poll',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.orange)),
                ),
            ],
          ),
        );
      },
    );
  }

  /// One line of numbers: what this run found, and where it came from.
  Widget _overview(AiItineraryResult result) {
    final saved = result.add.where((a) => a.fromSaved).length;
    final stops = result.add.where((a) => !a.alreadyInPlan).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (stops > 0) _chip('$stops new ${stops == 1 ? 'stop' : 'stops'}', Icons.add_location_alt_outlined, AppColors.navy),
              if (saved > 0) _chip('$saved from saved list', Icons.bookmark_outline, _green),
              if (result.update.isNotEmpty)
                _chip('${result.update.length} ${result.update.length == 1 ? 'change' : 'changes'}', Icons.swap_horiz, AppColors.navy),
              if (result.remove.isNotEmpty) _chip('${result.remove.length} to remove', Icons.remove_circle_outline, AppColors.textGrey),
              // flights and hotel: shown so it is clear the plan was built around them
              result.flightsBooked
                  ? _chip('Around your flights', Icons.flight_outlined, _green)
                  : _chip('No flight booked', Icons.flight_outlined, AppColors.orange),
              result.hotelsBooked
                  ? _chip('Around your hotel', Icons.hotel_outlined, _green)
                  : _chip('No hotel booked', Icons.hotel_outlined, AppColors.orange),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'From ${result.messageCount} chat messages, ${result.savedCount} saved '
            '${result.savedCount == 1 ? 'place' : 'places'}, your flights and hotel, and your current plan.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  static const _green = Color(0xFF2E9E5B);

  Widget _chip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
          ],
        ],
      ),
    );
  }

  /// One day as a timeline: what is already planned (grey) and the suggestions (tickable), by time.
  Widget _dayBlock(int day, AiItineraryResult result) {
    DayPlan? plan;
    for (final p in widget.controller.days) {
      if (p.day == day) plan = p;
    }
    final removing = {for (final r in result.remove) r.itemId};
    final moving = {for (final u in result.update) u.itemId: u};
    final rows = <({String time, Widget child})>[];
    for (final it in plan?.items ?? const <ActivityItem>[]) {
      final u = moving[it.id];
      if (u != null && !u.changesDay) continue; // shown below as its "new time" card
      final note = removing.contains(it.id) ? 'Agreed to drop' : u != null ? 'Moves to Day ${u.toDay}' : 'In your plan';
      rows.add((time: it.time, child: _existingRow(it, note: note)));
    }
    for (var i = 0; i < result.add.length; i++) {
      if (result.add[i].day == day) rows.add((time: result.add[i].time, child: _addCard(result.add[i], 'a$i')));
    }
    for (var i = 0; i < result.update.length; i++) {
      if (result.update[i].toDay == day) rows.add((time: result.update[i].newTime, child: _updateCard(result.update[i], 'u$i')));
    }
    // flights the plan was built around (hotel check-in / out come as suggestions or are already planned)
    for (final f in result.fixed) {
      if (f.day == day && f.kind == 'flight') rows.add((time: f.time, child: _fixedRow(f)));
    }
    rows.sort((a, b) => a.time.compareTo(b.time));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Day $day', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(width: 8),
              if (plan != null)
                Text('${plan.weekday} ${plan.date}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 62,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(r.time.isEmpty ? '—' : _time12h(r.time),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    ),
                  ),
                  Expanded(child: r.child),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The saved listing's photo when the place is in the saved list (same matching as the plan's
  /// activity cards), otherwise the activity icon.
  Widget _thumb(AiItineraryAdd a) {
    final probe = ActivityItem(time: a.time, icon: iconForKey(a.iconKey), label: a.label, voted: 0, total: 0);
    final c = widget.controller;
    final url = c.attractionForActivity(probe)?.image ?? c.restaurantForActivity(probe)?.image ?? c.hotelForActivity(probe)?.image ?? '';
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
      child: Icon(iconForKey(a.iconKey), size: 20, color: AppColors.navy),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(url, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }

  Widget _tick(String key, {bool disabled = false}) {
    if (disabled) return const SizedBox(width: 22);
    final selected = _selected.contains(key);
    return Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 22, color: selected ? AppColors.primary : AppColors.textGrey);
  }

  void _toggle(String key) {
    if (_applying) return;
    setState(() => _selected.contains(key) ? _selected.remove(key) : _selected.add(key));
  }

  Widget _addCard(AiItineraryAdd a, String key) {
    final selected = _selected.contains(key);
    final disabled = a.alreadyInPlan;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: disabled ? null : () => _toggle(key),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.45) : const Color(0xFFE6E6E6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(a),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(a.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: disabled ? AppColors.textGrey : AppColors.navy)),
                      ),
                      if (a.fromSaved) ...[const SizedBox(width: 6), _badge('Saved', _green)],
                      if (a.source == 'booked') ...[const SizedBox(width: 6), _badge('Booked', AppColors.navy)],
                      // a wish with no place yet ("Night market"): a time block to swap for a real place
                      if (a.source == 'generic') ...[const SizedBox(width: 6), _badge('Pick a place', AppColors.orange)],
                    ],
                  ),
                  if (a.location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(a.location,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    ),
                  if (a.reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.chat_bubble_outline, size: 11, color: AppColors.textGrey),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(a.reason, style: const TextStyle(fontSize: 11, color: AppColors.textGrey, height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  if (disabled)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Already in your plan', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    )
                  else if (a.warnNotSaved && a.source == 'pattern')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Name taken from the chat — check it before you go',
                          style: TextStyle(fontSize: 11, color: AppColors.orange)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _tick(key, disabled: disabled),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  /// Something already in the plan, for context (not tickable).
  Widget _existingRow(ActivityItem it, {required String note}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(it.icon, size: 18, color: AppColors.textGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(it.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                    decoration: note == 'Agreed to drop' ? TextDecoration.lineThrough : null)),
          ),
          const SizedBox(width: 6),
          Text(note, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  /// A booked flight (or one the chat mentioned): nothing is planned around it too closely.
  Widget _fixedRow(AiItineraryFixed f) {
    final fromChat = f.label.contains('(from the chat)');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.flight_outlined, size: 18, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(f.label.replaceAll(' (from the chat)', ''),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.navy)),
          ),
          const SizedBox(width: 6),
          Text(fromChat ? 'From the chat' : 'Booked', style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _updateCard(AiItineraryUpdate u, String key) {
    final selected = _selected.contains(key);
    final from = u.changesDay ? 'Day ${u.fromDay}, ${_time12h(u.oldTime)}' : _time12h(u.oldTime);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _toggle(key),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.45) : const Color(0xFFE6E6E6)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.swap_horiz, size: 20, color: AppColors.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(u.changesDay ? 'Moved here from $from' : 'New time (was $from)', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            _tick(key),
          ],
        ),
      ),
    );
  }

  Widget _removeRow(AiItineraryRemove r, String key) {
    final selected = _selected.contains(key);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _toggle(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.textGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text('Day ${r.day}${r.time.isEmpty ? '' : ', ${_time12h(r.time)}'}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
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

  Widget _ideaRow(AiItineraryIdea idea) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.lightbulb_outline, size: 18, color: AppColors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(idea.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
                if (idea.hint.isNotEmpty)
                  Text(idea.hint, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey, height: 1.3)),
              ],
            ),
          ),
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
