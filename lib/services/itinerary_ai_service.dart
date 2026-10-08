import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// A new activity the group agreed on — same fields
/// [TripRepository.addActivity] takes, so it can be added as-is.
class AiItineraryAdd {
  /// 1-based day number, as shown in the app.
  final int day;

  /// The key under `trips/{tripId}.days` — what `addActivity` wants.
  final int dayIndex;
  final String time;
  final String label;
  final String location;
  final String iconKey;

  /// The place was mentioned in the chat but nobody in the group has it in
  /// their saved list for this trip — shown as a warning, still addable.
  final bool warnNotSaved;

  /// That day already has an activity with this name.
  final bool alreadyInPlan;

  const AiItineraryAdd({
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

/// An activity that is already in the plan and that the group agreed to
/// move to another day and/or another time.
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

  const AiItineraryUpdate({
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

/// An activity that is already in the plan and that the group agreed to drop.
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

class AiItineraryResult {
  final List<AiItineraryAdd> add;
  final List<AiItineraryUpdate> update;
  final List<AiItineraryRemove> remove;

  /// Places that came up in the chat but the group never decided on.
  final List<String> unresolved;
  final int messageCount;
  final int savedCount;

  const AiItineraryResult({
    required this.add,
    required this.update,
    required this.remove,
    required this.unresolved,
    required this.messageCount,
    required this.savedCount,
  });

  bool get isEmpty => add.isEmpty && update.isEmpty && remove.isEmpty && unresolved.isEmpty;
}

/// Thrown with a message that is safe to show to the user as-is.
class ItineraryAiException implements Exception {
  final String message;
  const ItineraryAiException(this.message);
  @override
  String toString() => message;
}

enum AiItineraryStatus { idle, running, ready, failed }

/// Where one trip's "AI Summarise" run currently stands.
class AiItineraryJob {
  final AiItineraryStatus status;
  final AiItineraryResult? result;
  final String? error;
  const AiItineraryJob._(this.status, {this.result, this.error});
  static const idle = AiItineraryJob._(AiItineraryStatus.idle);
  static const running = AiItineraryJob._(AiItineraryStatus.running);
}

/// Asks the `generateItinerary` Cloud Function (functions/itinerary.js) to
/// read a trip's group chat — together with the group's saved places and
/// the current plan — and return the changes the group agreed on. The model
/// runs server-side; nothing is written to the trip until the user confirms
/// in the app.
///
/// A run belongs to this service, not to whatever screen started it, so the
/// user can minimise the sheet (or leave the group page) and carry on; the
/// result is waiting in [jobFor] when they come back.
///
/// A [ChangeNotifier] (in addition to each trip's own [ValueNotifier] from
/// [jobFor]) so something that doesn't already know which trip to watch —
/// [GlobalAiItineraryBar], shown on every tab via [MainPage], not just the
/// one group's own page — can still react the instant any trip's run
/// changes status, the same reason [LanguageService] became one.
class ItineraryAiService extends ChangeNotifier {
  ItineraryAiService._();
  static final ItineraryAiService instance = ItineraryAiService._();

  final Map<String, ValueNotifier<AiItineraryJob>> _jobs = {};

  ValueNotifier<AiItineraryJob> jobFor(String tripId) =>
      _jobs.putIfAbsent(tripId, () => ValueNotifier<AiItineraryJob>(AiItineraryJob.idle));

  /// The first non-idle run found, for whichever trip it belongs to — what
  /// [GlobalAiItineraryBar] shows regardless of which tab the person is on.
  /// In practice at most one or two trips ever have a run going at once, so
  /// "first found" rather than "most recent" is a fine tie-break; nothing
  /// here claims to order them.
  ({String tripId, AiItineraryJob job})? get anyActiveJob {
    for (final entry in _jobs.entries) {
      if (entry.value.value.status != AiItineraryStatus.idle) {
        return (tripId: entry.key, job: entry.value.value);
      }
    }
    return null;
  }

  /// Starts a run for [tripId] unless one is already going.
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

  /// Forgets the finished run (after the user applied or discarded it).
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
      // Cast after the call rather than through call<T>() — same reason as
      // StripeService: the plugin hands back a loosely-typed Map.
      final result = await callable.call({'tripId': tripId});
      data = (result.data as Map).cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      // e.message is already a plain, customer-facing sentence —
      // functions/itinerary.js is responsible for never putting a raw
      // SDK/HTTP error in there (those go to `firebase functions:log`
      // instead). Still logged here too (debugPrint only reaches the
      // terminal/IDE console a developer is watching, never the user),
      // in case e.message ever comes back empty or unexpectedly technical.
      debugPrint('[ItineraryAiService] generateItinerary failed: ${e.code} ${e.message} ${e.details}');
      if (e.code == 'not-found') {
        throw const ItineraryAiException('The AI itinerary service is not set up yet.');
      }
      final message = e.message?.trim();
      throw ItineraryAiException(
        (message != null && message.isNotEmpty) ? message : 'Could not generate the itinerary. Please try again.',
      );
    } catch (e) {
      // Anything else (no network, request timed out, ...) carries Dart's
      // own exception text, which is just as unfit for the UI — log it for
      // whoever is watching the terminal, show the person a plain sentence.
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
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
      savedCount: (data['savedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
