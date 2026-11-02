import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class DiscussionDecision {
  /// confirmed / rejected / split / voting
  final String status;
  final String byName;

  final List<String> memberNames;
  final String voteTitle;
  const DiscussionDecision({required this.status, required this.byName, required this.memberNames, required this.voteTitle});
}

class DiscussionItem {
  final String category;

  /// confirmed / pending / rejected.
  final String status;

  final String text;

  final String? value;
  final String proposer;
  final List<String> support;
  final List<String> against;

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

  final List<({String speaker, String text})> highlights;

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

class DiscussionSummaryService {
  DiscussionSummaryService._();
  static final DiscussionSummaryService instance = DiscussionSummaryService._();

  final Map<String, ValueNotifier<DiscussionSummaryJob>> _jobs = {};

  ValueNotifier<DiscussionSummaryJob> jobFor(String tripId) =>
      _jobs.putIfAbsent(tripId, () => ValueNotifier<DiscussionSummaryJob>(DiscussionSummaryJob.idle));

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
