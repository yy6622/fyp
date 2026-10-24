import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../repositories/discussion_decisions.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/discussion_summary_service.dart';
import '../../theme.dart';

/// "Decide now" for everything the group chat left undecided.
///
/// For each undecided item the group can:
///  - Agree   -> it counts as decided; a place / activity can be added to the plan right away
///  - Skip    -> turned down
///  - Vote    -> a poll in the Vote tab (competing options of the same kind go into one poll)
///  - Split   -> only the members who want it get it in their plan ("Who is this for"),
///               everyone else keeps their own plan for that time
/// Decisions are stored on the trip (see discussion_decisions.dart) and the summary /
/// AI Summarise treat them as final.
Future<void> showDecideNowSheet(BuildContext context, GroupTripController controller, DiscussionSummary summary) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _DecideNowSheet(controller: controller, summary: summary, pageContext: context),
  );
}

const _planCategories = {'ATTRACTION', 'TRANSPORT'};
const _titles = {
  'DESTINATION': 'Destination',
  'DATE': 'Dates',
  'BUDGET': 'Budget',
  'ACCOMMODATION': 'Accommodation',
  'ATTRACTION': 'Places to visit',
  'TRANSPORT': 'Transport',
};

class _DecideNowSheet extends StatefulWidget {
  final GroupTripController controller;
  final DiscussionSummary summary;
  final BuildContext pageContext;
  const _DecideNowSheet({required this.controller, required this.summary, required this.pageContext});

  @override
  State<_DecideNowSheet> createState() => _DecideNowSheetState();
}

class _DecideNowSheetState extends State<_DecideNowSheet> {
  /// messageId -> what was just decided here (so the row updates without a reload)
  final Map<String, String> _done = {};
  String? _busy;
  String? _error;

  GroupTripController get c => widget.controller;
  Trip? get trip => c.trip;
  String get _uid => AuthService.instance.currentUser?.uid ?? '';
  String get _myName => trip?.memberNames[_uid] ?? AuthService.instance.currentUser?.displayName ?? 'Someone';

  /// Chat names -> member uids (chat sender names are the members' display names).
  Set<String> _uidsFor(List<String> names) {
    final byName = <String, String>{};
    trip?.memberNames.forEach((uid, name) => byName[name.trim().toLowerCase()] = uid);
    return {for (final n in names) if (byName[n.trim().toLowerCase()] != null) byName[n.trim().toLowerCase()]!};
  }

  Future<void> _record(DiscussionItem it, String status,
      {List<String> memberUids = const [], String voteTitle = ''}) {
    return TripRepository.instance.recordDiscussionDecision(
      c.tripId,
      it.messageId,
      status: status,
      byUid: _uid,
      byName: _myName,
      memberUids: memberUids,
      memberNames: [for (final u in memberUids) trip?.memberNames[u] ?? u],
      voteTitle: voteTitle,
    );
  }

  Future<void> _run(DiscussionItem it, Future<String?> Function() action) async {
    setState(() {
      _busy = it.messageId;
      _error = null;
    });
    try {
      final done = await action();
      if (done != null) _done[it.messageId] = done;
    } catch (e) {
      _error = 'Could not save: $e';
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _agree(DiscussionItem it) => _run(it, () async {
        if (_planCategories.contains(it.category) && c.days.isNotEmpty) {
          final added = await _planDialog(it, split: false);
          if (added == null) return null;
        }
        await _record(it, 'confirmed');
        return 'Agreed';
      });

  Future<void> _skip(DiscussionItem it) => _run(it, () async {
        await _record(it, 'rejected');
        return 'Skipped';
      });

  Future<void> _split(DiscussionItem it) => _run(it, () async {
        final going = await _planDialog(it, split: true);
        if (going == null) return null;
        await _record(it, 'split', memberUids: going.toList());
        return 'Split: ${going.length} going';
      });

  Future<void> _vote(DiscussionItem it) => _run(it, () async {
        // competing undecided options of the same kind go into one poll
        final rivals = widget.summary.pending
            .where((p) => p.category == it.category && !_done.containsKey(p.messageId) && p.decided == null)
            .toList();
        final group = rivals.length >= 2 ? rivals.take(6).toList() : [it];
        final title = group.length >= 2 ? 'Decide: ${_titles[it.category] ?? 'which one'}' : 'Go with "${_short(it.display, 40)}"?';
        final options = group.length >= 2
            ? [for (final g in group) _short(g.display, 60)]
            : ['Yes, ${_short(it.display, 40)}', 'No, skip it'];
        await TripRepository.instance.createVote(
          c.tripId,
          title: title,
          options: options,
          allowAddOptions: false,
          allowMultipleChoice: false,
          createdBy: _uid,
        );
        for (final g in group) {
          await _record(g, 'voting', voteTitle: title);
          if (g != it) _done[g.messageId] = 'In poll';
        }
        return 'In poll';
      });

  /// Add-to-plan dialog. Returns the members it was added for (empty = everyone), or null if cancelled.
  Future<Set<String>?> _planDialog(DiscussionItem it, {required bool split}) async {
    final t = trip;
    if (t == null || c.days.isEmpty) return null;
    final label = TextEditingController(text: _short(it.display, 60));
    var dayIndex = 0;
    var time = const TimeOfDay(hour: 10, minute: 0);
    final supporters = _uidsFor([it.proposer, ...it.support]);
    var going = split ? (supporters.isEmpty ? {_uid} : supporters) : <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(split ? 'Split the plan' : 'Add to plan', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (split)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Only the ticked members get this in their plan. Everyone else keeps their own plan for that time.',
                        style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Activity'),
                  onChanged: (_) => setD(() {}),
                ),
                const SizedBox(height: 10),
                DropdownButton<int>(
                  isExpanded: true,
                  value: dayIndex,
                  items: [
                    for (var i = 0; i < c.days.length; i++)
                      DropdownMenuItem(value: i, child: Text('Day ${c.days[i].day}  ·  ${c.days[i].weekday} ${c.days[i].date}')),
                  ],
                  onChanged: (v) => setD(() => dayIndex = v ?? 0),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(time.format(ctx)),
                  onPressed: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: time);
                    if (picked != null) setD(() => time = picked);
                  },
                ),
                if (split) ...[
                  const SizedBox(height: 6),
                  const Text('Who is going?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  for (final e in t.memberNames.entries)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: going.contains(e.key),
                      title: Text(e.value, style: const TextStyle(fontSize: 13)),
                      onChanged: (v) => setD(() => v == true ? going.add(e.key) : going.remove(e.key)),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: label.text.trim().isEmpty || (split && going.isEmpty) ? null : () => Navigator.pop(ctx, true),
              child: Text(split ? 'Split' : 'Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    await c.addActivity(
      dayIndex,
      time: '$hh:$mm',
      label: label.text.trim(),
      iconKey: it.category == 'TRANSPORT' ? 'activity' : 'place',
      forMemberUids: split ? going.toList() : const [],
    );
    return going;
  }

  String _short(String s, int n) {
    final t = s.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).join(' ');
    final cps = t.runes.toList();
    return cps.length <= n ? t : '${String.fromCharCodes(cps.take(n - 1))}…';
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.summary.pending;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Decide now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'The chat left these open. Agree, skip, put them to a vote, or split the plan so only the people who want it go.',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Nothing undecided 🎉', style: TextStyle(color: AppColors.textGrey)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (_, i) => _row(items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(DiscussionItem it) {
    final done = _done[it.messageId] ?? (it.decided?.status == 'voting' ? 'In poll' : null);
    final busy = _busy == it.messageId;
    final who = [
      'by ${it.proposer}',
      if (it.support.length > 1) 'for: ${it.support.join(', ')}',
      if (it.against.isNotEmpty) 'against: ${it.against.join(', ')}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_titles[it.category] ?? it.category, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        Text(_short(it.display, 90), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        Text(who, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        const SizedBox(height: 6),
        if (busy)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
        else if (done != null && done != 'In poll')
          Text('✓ $done', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2E9E5B)))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (done == 'In poll')
                const Padding(
                  padding: EdgeInsets.only(right: 4, top: 6),
                  child: Text('In a poll · ', style: TextStyle(fontSize: 12, color: AppColors.orange)),
                ),
              _btn('Agree', Icons.check, () => _agree(it)),
              _btn('Skip', Icons.close, () => _skip(it)),
              if (done != 'In poll') _btn('Vote', Icons.how_to_vote_outlined, () => _vote(it)),
              if (_planCategories.contains(it.category) && (trip?.memberIds.length ?? 0) > 1)
                _btn('Split', Icons.call_split, () => _split(it)),
            ],
          ),
      ],
    );
  }

  Widget _btn(String text, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _busy == null ? onTap : null,
      icon: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  void dispose() {
    // Re-read the chat + decisions so the summary card shows the new state.
    DiscussionSummaryService.instance.start(c.tripId);
    super.dispose();
  }
}
