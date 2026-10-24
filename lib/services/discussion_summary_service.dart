import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// One option the group talked about (a place, a hotel, a budget, dates...)
/// and how the discussion left it.
/// A decision the group made in the app for an item the chat left undecided.
class DiscussionDecision {
  /// confirmed / rejected / split / voting
  final String status;
  final String byName;

  /// For "split": the members who go; everyone else keeps their own plan.
  final List<String> memberNames;
  final String voteTitle;
  const DiscussionDecision({required this.status, required this.byName, required this.memberNames, required this.voteTitle});
}

class DiscussionItem {
  /// DESTINATION, DATE, BUDGET, ATTRACTION, TRANSPORT or ACCOMMODATION.
  final String category;

  /// confirmed / pending / rejected.
  final String status;

  /// The message that proposed it, as written in the chat.
  final String text;

  /// A cleaned-up value when one could be read ("RM3000 per person", "18-23 Dec").
  final String? value;
  final String proposer;
  final List<String> support;
  final List<String> against;

  /// The chat message that proposed it - the key decisions are stored under.
  final String messageId;
  final DiscussionDecision? decided;

  const DiscussionItem({
    required this.messageId,
    this.decided,
    required this.category,
    required this.status,
    required this.text,
    required this.value,
    required this.proposer,
    required this.support,
    required this.against,
  });

  String get display => (value != null && value!.isNotEmpty) ? value! : text;
}

class DiscussionSection {
  final String category;
  final String title;
  final List<DiscussionItem> items;
  const DiscussionSection({required this.category, required this.title, required this.items});
}

class DiscussionPreference {
  final String speaker;
  final String text;
  const DiscussionPreference({required this.speaker, required this.text});
}

class DiscussionSummary {
  final String? destination;
  final String? dates;
  final String? budget;
  final List<DiscussionSection> sections;
  final List<DiscussionPreference> preferences;
  final List<DiscussionItem> pending;

  /// The most important messages, picked by the importance score S(m).
  final List<({String speaker, String text})> highlights;

  /// The whole summary as plain text (for copying).
  final String text;

  final int messageCount;
  final int confirmedCount;

  const DiscussionSummary({
    required this.destination,
    required this.dates,
    required this.budget,
    required this.sections,
    required this.preferences,
    required this.pending,
    required this.highlights,
    required this.text,
    required this.messageCount,
    required this.confirmedCount,
  });

  bool get isEmpty => sections.isEmpty && preferences.isEmpty;
}

/// Thrown with a message that is safe to show to the user as-is.
class DiscussionSummaryException implements Exception {
  final String message;
  const DiscussionSummaryException(this.message);
  @override
  String toString() => message;
}

enum DiscussionSummaryStatus { idle, running, ready, failed }

class DiscussionSummaryJob {
  final DiscussionSummaryStatus status;
  final DiscussionSummary? result;
  final String? error;
  const DiscussionSummaryJob._(this.status, {this.result, this.error});
  static const idle = DiscussionSummaryJob._(DiscussionSummaryStatus.idle);
  static const running = DiscussionSummaryJob._(DiscussionSummaryStatus.running);
}

/// Calls the `summariseDiscussion` Cloud Function (functions/discussion_summary/),
/// which runs Voya's own trained model (ml/discussion_summary/) over a trip's
/// group chat. No external AI API is involved, so it is fast and free.
class DiscussionSummaryService {
  DiscussionSummaryService._();
  static final DiscussionSummaryService instance = DiscussionSummaryService._();

  final Map<String, ValueNotifier<DiscussionSummaryJob>> _jobs = {};

  ValueNotifier<DiscussionSummaryJob> jobFor(String tripId) =>
      _jobs.putIfAbsent(tripId, () => ValueNotifier<DiscussionSummaryJob>(DiscussionSummaryJob.idle));

  /// (Re)computes the summary for [tripId] unless a run is already going.
  void start(String tripId) {
    final job = jobFor(tripId);
    if (job.value.status == DiscussionSummaryStatus.running) return;
    job.value = DiscussionSummaryJob.running;
    _fetch(tripId).then((result) {
      job.value = DiscussionSummaryJob._(DiscussionSummaryStatus.ready, result: result);
    }).catchError((Object e) {
      job.value = DiscussionSummaryJob._(DiscussionSummaryStatus.failed, error: e.toString());
    });
  }

  Future<DiscussionSummary> _fetch(String tripId) async {
    final Map<String, dynamic> data;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'summariseDiscussion',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final result = await callable.call({'tripId': tripId});
      data = (result.data as Map).cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[DiscussionSummaryService] summariseDiscussion failed: ${e.code} ${e.message} ${e.details}');
      if (e.code == 'not-found') {
        throw const DiscussionSummaryException('The discussion summary service is not set up yet.');
      }
      final message = e.message?.trim();
      throw DiscussionSummaryException(
          (message != null && message.isNotEmpty) ? message : 'Could not summarise the discussion.');
    } catch (e) {
      debugPrint('[DiscussionSummaryService] summariseDiscussion unreachable: $e');
      throw const DiscussionSummaryException('Could not reach the summary service. Check your connection and try again.');
    }

    List<Map<String, dynamic>> rows(dynamic raw) =>
        [for (final r in (raw as List? ?? const [])) (r as Map).cast<String, dynamic>()];
    List<String> names(dynamic raw) => [for (final n in (raw as List? ?? const [])) n.toString()];
    String str(Map<String, dynamic> m, String key) => (m[key] ?? '').toString();
    DiscussionDecision? decision(dynamic raw) {
      if (raw is! Map) return null;
      final d = raw.cast<String, dynamic>();
      return DiscussionDecision(
        status: str(d, 'status'),
        byName: str(d, 'byName'),
        memberNames: names(d['memberNames']),
        voteTitle: str(d, 'voteTitle'),
      );
    }

    DiscussionItem item(Map<String, dynamic> m) => DiscussionItem(
          messageId: str(m, 'messageId'),
          decided: decision(m['decided']),
          category: str(m, 'category'),
          status: str(m, 'status'),
          text: str(m, 'text'),
          value: m['value'] as String?,
          proposer: str(m, 'proposer'),
          support: names(m['support']),
          against: names(m['against']),
        );

    final facts = ((data['facts'] as Map?) ?? const {}).cast<String, dynamic>();
    String? budget;
    final amount = facts['budget'] as num?;
    if (amount != null) {
      final basis = facts['budget_basis'];
      budget = 'RM${amount.toInt()}${basis == 'per_person' ? ' per person' : basis == 'total' ? ' in total' : ''}';
    }
    final stats = ((data['stats'] as Map?) ?? const {}).cast<String, dynamic>();
    return DiscussionSummary(
      destination: facts['destination'] as String?,
      dates: facts['dates'] as String?,
      budget: budget,
      sections: [
        for (final s in rows(data['sections']))
          DiscussionSection(
            category: str(s, 'category'),
            title: str(s, 'title'),
            items: [for (final i in rows(s['items'])) item(i)],
          ),
      ],
      preferences: [
        for (final p in rows(data['preferences'])) DiscussionPreference(speaker: str(p, 'speaker'), text: str(p, 'text')),
      ],
      pending: [for (final i in rows(data['pending'])) item(i)],
      highlights: [for (final h in rows(data['highlights'])) (speaker: str(h, 'speaker'), text: str(h, 'text'))],
      text: str(data, 'text'),
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
      confirmedCount: (stats['confirmed'] as num?)?.toInt() ?? 0,
    );
  }
}
