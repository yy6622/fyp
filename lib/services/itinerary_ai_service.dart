import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AiItineraryAdd {
  final int day;

  final int dayIndex;
  final String time;
  final String label;
  final String location;
  final String iconKey;

  final bool warnNotSaved;

  final bool alreadyInPlan;

  final String source;

  final String reason;

  bool get fromSaved => source == 'saved';

  const AiItineraryAdd({
    this.source = '',
    this.reason = '',
    required this.day,
    required this.dayIndex,
    required this.time,
    required this.label,
    required this.location,
    required this.iconKey,
    required this.warnNotSaved,
    required this.alreadyInPlan,
  });
}

class AiItineraryUpdate {
  final String itemId;
  final String label;
  final String location;
  final String iconKey;
  final int fromDay;
  final int fromDayIndex;
  final int toDay;
  final int toDayIndex;
  final String oldTime;
  final String newTime;

  final String reason;

  const AiItineraryUpdate({
    this.reason = '',
    required this.itemId,
    required this.label,
    required this.location,
    required this.iconKey,
    required this.fromDay,
    required this.fromDayIndex,
    required this.toDay,
    required this.toDayIndex,
    required this.oldTime,
    required this.newTime,
  });

  bool get changesDay => fromDayIndex != toDayIndex;
}

class AiItineraryRemove {
  final String itemId;
  final String label;
  final int day;
  final int dayIndex;
  final String time;
  const AiItineraryRemove({
    required this.itemId,
    required this.label,
    required this.day,
    required this.dayIndex,
    required this.time,
  });
}

class AiItineraryIdea {
  final String label;
  final String hint;

  final String saved;
  const AiItineraryIdea({required this.label, required this.hint, this.saved = ''});
}

class AiItineraryFixed {
  final int day;
  final String time;
  final String label;

  /// "flight" or "hotel".
  final String kind;
  const AiItineraryFixed({required this.day, required this.time, required this.label, required this.kind});
}

class AiItineraryResult {
  final List<AiItineraryAdd> add;
  final List<AiItineraryUpdate> update;
  final List<AiItineraryRemove> remove;

  final List<String> unresolved;
  final List<AiItineraryIdea> ideas;

  final List<AiItineraryFixed> fixed;
  final bool flightsBooked;
  final bool hotelsBooked;
  final int messageCount;
  final int savedCount;

  const AiItineraryResult({
    required this.add,
    required this.update,
    required this.remove,
    required this.unresolved,
    this.ideas = const [],
    this.fixed = const [],
    this.flightsBooked = false,
    this.hotelsBooked = false,
    required this.messageCount,
    required this.savedCount,
  });

  bool get isEmpty => add.isEmpty && update.isEmpty && remove.isEmpty && unresolved.isEmpty && ideas.isEmpty;
}

class ItineraryAiException implements Exception {
  final String message;
  const ItineraryAiException(this.message);
  @override
  String toString() => message;
}

enum AiItineraryStatus { idle, running, ready, failed }

class AiItineraryJob {
  final AiItineraryStatus status;
  final AiItineraryResult? result;
  final String? error;
  const AiItineraryJob._(this.status, {this.result, this.error});
  static const idle = AiItineraryJob._(AiItineraryStatus.idle);
  static const running = AiItineraryJob._(AiItineraryStatus.running);
}

class ItineraryAiService extends ChangeNotifier {
  ItineraryAiService._();
  static final ItineraryAiService instance = ItineraryAiService._();

  final Map<String, ValueNotifier<AiItineraryJob>> _jobs = {};

  ValueNotifier<AiItineraryJob> jobFor(String tripId) =>
      _jobs.putIfAbsent(tripId, () => ValueNotifier<AiItineraryJob>(AiItineraryJob.idle));

  ({String tripId, AiItineraryJob job})? get anyActiveJob {
    for (final entry in _jobs.entries) {
      if (entry.value.value.status != AiItineraryStatus.idle) {
        return (tripId: entry.key, job: entry.value.value);
      }
    }
    return null;
  }

  void start(String tripId) {
    final job = jobFor(tripId);
    if (job.value.status == AiItineraryStatus.running) return;
    job.value = AiItineraryJob.running;
    notifyListeners();
    _generate(tripId).then((result) {
      job.value = AiItineraryJob._(AiItineraryStatus.ready, result: result);
      notifyListeners();
    }).catchError((Object e) {
      job.value = AiItineraryJob._(AiItineraryStatus.failed, error: e.toString());
      notifyListeners();
    });
  }

  void clear(String tripId) {
    final job = jobFor(tripId);
    if (job.value.status != AiItineraryStatus.running) {
      job.value = AiItineraryJob.idle;
      notifyListeners();
    }
  }

  Future<AiItineraryResult> _generate(String tripId) async {
    final Map<String, dynamic> data;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateItinerary',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final result = await callable.call({'tripId': tripId, 'consent': true});
      data = (result.data as Map).cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[ItineraryAiService] generateItinerary failed: ${e.code} ${e.message} ${e.details}');
      if (e.code == 'not-found') {
        throw const ItineraryAiException('The AI itinerary service is not set up yet.');
      }
      final message = e.message?.trim();
      throw ItineraryAiException(
        (message != null && message.isNotEmpty) ? message : 'Could not generate the itinerary. Please try again.',
      );
    } catch (e) {
      debugPrint('[ItineraryAiService] generateItinerary unreachable: $e');
      throw const ItineraryAiException('Could not reach the AI itinerary service. Check your connection and try again.');
    }

    List<Map<String, dynamic>> rows(String key) =>
        [for (final raw in (data[key] as List? ?? const [])) (raw as Map).cast<String, dynamic>()];
    String str(Map<String, dynamic> m, String key) => (m[key] as String?) ?? '';
    int number(Map<String, dynamic> m, String key) => (m[key] as num?)?.toInt() ?? 0;

    return AiItineraryResult(
      add: [
        for (final m in rows('add'))
          if (str(m, 'label').isNotEmpty)
            AiItineraryAdd(
              day: number(m, 'day'),
              dayIndex: number(m, 'dayIndex'),
              time: str(m, 'time'),
              label: str(m, 'label'),
              location: str(m, 'location'),
              iconKey: str(m, 'icon').isEmpty ? 'activity' : str(m, 'icon'),
              warnNotSaved: m['warnNotSaved'] == true,
              alreadyInPlan: m['alreadyInPlan'] == true,
              source: str(m, 'source'),
              reason: str(m, 'reason'),
            ),
      ],
      update: [
        for (final m in rows('update'))
          if (str(m, 'itemId').isNotEmpty)
            AiItineraryUpdate(
              itemId: str(m, 'itemId'),
              label: str(m, 'label'),
              location: str(m, 'location'),
              iconKey: str(m, 'icon').isEmpty ? 'activity' : str(m, 'icon'),
              fromDay: number(m, 'fromDay'),
              fromDayIndex: number(m, 'fromDayIndex'),
              toDay: number(m, 'toDay'),
              toDayIndex: number(m, 'toDayIndex'),
              oldTime: str(m, 'oldTime'),
              newTime: str(m, 'newTime'),
            ),
      ],
      remove: [
        for (final m in rows('remove'))
          if (str(m, 'itemId').isNotEmpty)
            AiItineraryRemove(
              itemId: str(m, 'itemId'),
              label: str(m, 'label'),
              day: number(m, 'day'),
              dayIndex: number(m, 'dayIndex'),
              time: str(m, 'time'),
            ),
      ],
      unresolved: [for (final u in (data['unresolved'] as List? ?? const [])) u.toString()],
      ideas: [
        for (final m in rows('ideas'))
          if (str(m, 'label').isNotEmpty) AiItineraryIdea(label: str(m, 'label'), hint: str(m, 'hint'), saved: str(m, 'saved')),
      ],
      fixed: [
        for (final raw in ((data['logistics'] as Map?)?['fixed'] as List? ?? const []))
          if (raw is Map)
            AiItineraryFixed(
              day: (raw['day'] as num?)?.toInt() ?? 0,
              time: (raw['time'] as String?) ?? '',
              label: (raw['label'] as String?) ?? '',
              kind: (raw['kind'] as String?) ?? 'flight',
            ),
      ],
      flightsBooked: (data['logistics'] as Map?)?['flightsBooked'] == true,
      hotelsBooked: (data['logistics'] as Map?)?['hotelsBooked'] == true,
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
      savedCount: (data['savedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
