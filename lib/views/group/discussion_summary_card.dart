import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/group_trip_controller.dart';
import '../../services/discussion_summary_service.dart';
import '../../theme.dart';
import 'decide_now_sheet.dart';

/// "Discussion summary" card shown at the top of the AI Summarise sheet.
///
/// Produced by Voya's own trained model (functions/discussion_summary/,
/// trained in ml/discussion_summary/): what the group agreed on, what is
/// still undecided, what was turned down, and each person's preferences.
/// Refreshed every time the card is opened. Collapsed it shows one line of
/// key facts; tap to expand.
class DiscussionSummaryCard extends StatefulWidget {
  final String tripId;

  /// Needed for "Decide now" (adding to the plan, members); without it the button is hidden.
  final GroupTripController? controller;
  const DiscussionSummaryCard({super.key, required this.tripId, this.controller});

  @override
  State<DiscussionSummaryCard> createState() => _DiscussionSummaryCardState();
}

class _DiscussionSummaryCardState extends State<DiscussionSummaryCard> {
  static const _green = Color(0xFF2E9E5B);
  late final ValueNotifier<DiscussionSummaryJob> _job = DiscussionSummaryService.instance.jobFor(widget.tripId);
  bool _expanded = false;
  bool _showKeyMessages = false;

  @override
  void initState() {
    super.initState();
    // The chat may have moved on since the last time: always re-read it.
    DiscussionSummaryService.instance.start(widget.tripId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DiscussionSummaryJob>(
      valueListenable: _job,
      builder: (context, job, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          decoration: BoxDecoration(
            color: AppColors.chipGrey,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(job),
              if (job.status == DiscussionSummaryStatus.failed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Text(job.error ?? 'Something went wrong.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ),
              if (job.status == DiscussionSummaryStatus.ready) ...[
                _factsLine(job.result!),
                if (widget.controller != null && job.result!.pending.isNotEmpty) _decideButton(job.result!),
                if (_expanded)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.36),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: _details(job.result!),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _header(DiscussionSummaryJob job) {
    final ready = job.status == DiscussionSummaryStatus.ready;
    final running = job.status == DiscussionSummaryStatus.running;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: ready ? () => setState(() => _expanded = !_expanded) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
        child: Row(
          children: [
            const Icon(Icons.forum_outlined, size: 18, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Discussion summary',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  Text(
                    running
                        ? 'Reading the chat...'
                        : ready
                            ? 'Voya model · ${job.result!.messageCount} messages'
                            : 'Voya model',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            if (running)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              )
            else ...[
              if (ready && _expanded)
                IconButton(
                  tooltip: 'Copy summary',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textGrey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: job.result!.text));
                    ScaffoldMessenger.maybeOf(context)
                        ?.showSnackBar(const SnackBar(content: Text('Summary copied')));
                  },
                ),
              IconButton(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, size: 18, color: AppColors.textGrey),
                onPressed: () => DiscussionSummaryService.instance.start(widget.tripId),
              ),
              if (ready)
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textGrey),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _decideButton(DiscussionSummary s) {
    final open = s.pending.where((p) => p.decided?.status != 'voting').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 14, 8),
      child: TextButton.icon(
        onPressed: () => showDecideNowSheet(context, widget.controller!, s),
        icon: const Icon(Icons.how_to_vote_outlined, size: 18, color: AppColors.orange),
        label: Text(
          open > 0 ? 'Decide now · $open undecided' : 'Undecided items are in a poll',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.orange),
        ),
      ),
    );
  }

  /// One wrap of chips: agreed dates / budget and how many things are settled.
  Widget _factsLine(DiscussionSummary s) {
    final undecided = s.pending.length;
    final chips = <Widget>[
      if (s.dates != null) _chip(Icons.event, s.dates!),
      if (s.budget != null) _chip(Icons.payments_outlined, s.budget!),
      _chip(Icons.check_circle_outline, '${s.confirmedCount} agreed', color: _green),
      if (undecided > 0) _chip(Icons.help_outline, '$undecided undecided', color: AppColors.orange),
    ];
    if (s.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Text('No trip plans found in the chat yet.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(IconData icon, String text, {Color color = AppColors.navy}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _details(DiscussionSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sec in s.sections) ...[
          _title(sec.title),
          for (final it in sec.items) _itemRow(it),
        ],
        if (s.preferences.isNotEmpty) ...[
          _title('Preferences'),
          for (final p in s.preferences)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${p.speaker}  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: p.text),
                ]),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
        ],
        if (s.highlights.isNotEmpty) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _showKeyMessages = !_showKeyMessages),
            child: Text(_showKeyMessages ? 'Hide key messages' : 'Show key messages (${s.highlights.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          if (_showKeyMessages)
            for (final h in s.highlights)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${h.speaker}: ${h.text}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
              ),
        ],
      ],
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
      );

  Widget _itemRow(DiscussionItem it) {
    var (icon, color, word) = switch (it.status) {
      'confirmed' => (Icons.check_circle, _green, 'Agreed'),
      'rejected' => (Icons.cancel, AppColors.textGrey, 'Turned down'),
      _ => (Icons.help, AppColors.orange, 'Undecided'),
    };
    final d = it.decided;
    if (d != null) {
      word = switch (d.status) {
        'split' => 'Split: ${d.memberNames.join(', ')} going',
        'voting' => 'In a poll',
        'rejected' => 'Skipped${d.byName.isEmpty ? '' : ' by ${d.byName}'}',
        _ => 'Agreed${d.byName.isEmpty ? '' : ' by ${d.byName}'}',
      };
    }
    final who = [
      'by ${it.proposer}',
      if (it.support.length > 1) '${it.support.length} for',
      if (it.against.isNotEmpty) 'against: ${it.against.join(', ')}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: it.status == 'rejected' ? AppColors.textGrey : Colors.black,
                        decoration: it.status == 'rejected' ? TextDecoration.lineThrough : null)),
                Text('$word · $who', style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
