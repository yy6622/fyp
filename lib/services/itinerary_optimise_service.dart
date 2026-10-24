import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'itinerary_ai_service.dart' show AiItineraryUpdate;

/// Which scope the diamond "Optimise" button (group_trip_page.dart's Day
/// header) runs over.
enum OptimiseMode { day, whole }

/// Which day/mode a trip's current (or last) Optimise run was actually for
/// — kept alongside the job itself so a minimised run can be told apart
/// from a *different* day/mode the person might ask for next (see
/// [ItineraryOptimiseService.start]'s "same scope" check), and so
/// [OptimiseStatusBar] (optimise_sheet.dart) can say which one it is.
class OptimiseScope {
  final OptimiseMode mode;

  /// The `trips/{tripId}.days` key, only set for [OptimiseMode.day].
  final int? dayIndex;

  /// 1-based day number, only set for [OptimiseMode.day] — display only.
  final int? dayNumber;

  /// The group's choice: keep places of one area on the same day (Optimise Whole Trip).
  final bool groupByArea;

  const OptimiseScope({required this.mode, this.dayIndex, this.dayNumber, this.groupByArea = true});

  bool sameAs(OptimiseMode otherMode, int? otherDayIndex, [bool otherGroupByArea = true]) =>
      mode == otherMode && dayIndex == otherDayIndex && groupByArea == otherGroupByArea;
}

/// Voya's own scheduler's reworked plan (functions/optimise_engine.js, no AI) — reuses [AiItineraryUpdate] (same
/// itemId/label/location/iconKey/fromDay(Index)/toDay(Index)/oldTime/
/// newTime shape ai_itinerary_sheet.dart already applies) since optimise
/// only ever reorders/re-times existing activities, never adds or removes
/// one — there's no "add"/"remove" list to carry.
class OptimiseResult {
  final List<AiItineraryUpdate> changes;

  /// How many activities were actually considered (the day's count, or the
  /// whole trip's) — shown so "nothing to change" reads as "I looked at
  /// your N activities and they're already in a good order", not silence.
  final int itemCount;

  /// What could not be fixed, e.g. "Day 2 is very full: ... Try Optimise Whole Trip".
  final List<String> notes;

  const OptimiseResult({required this.changes, required this.itemCount, this.notes = const []});

  bool get isEmpty => changes.isEmpty;
}

/// Thrown with a message that is safe to show to the user as-is.
class OptimiseException implements Exception {
  final String message;
  const OptimiseException(this.message);
  @override
  String toString() => message;
}

enum OptimiseStatus { idle, running, ready, failed }

/// Where one trip's "Optimise" run currently stands.
class OptimiseJob {
  final OptimiseStatus status;
  final OptimiseResult? result;
  final String? error;
  const OptimiseJob._(this.status, {this.result, this.error});
  static const idle = OptimiseJob._(OptimiseStatus.idle);
  static const running = OptimiseJob._(OptimiseStatus.running);
}

/// Asks the `optimiseItinerary` Cloud Function (functions/optimise.js) to
/// rework a trip's existing plan — one day, or the whole trip — into a
/// better-flowing schedule. Unlike [ItineraryAiService] ("AI Summarise",
/// which reads the group chat and can add/remove activities), this never
/// reads the chat and never adds or removes anything: it only reorders/
/// re-times what's already in the plan.
///
/// Kept as its own service rather than folded into [ItineraryAiService] so
/// the two features' job state can never clobber each other — a person
/// could plausibly have an AI Summarise suggestion waiting while also
/// tapping Optimise, and the two draw on completely different input (chat
/// messages vs. just the current plan). Same per-trip [ValueNotifier]
/// pattern, so the same minimise-and-come-back flow works for both — see
/// [OptimiseStatusBar] (optimise_sheet.dart), the Optimise equivalent of
/// [AiItineraryStatusBar].
class ItineraryOptimiseService extends ChangeNotifier {
  ItineraryOptimiseService._();
  static final ItineraryOptimiseService instance = ItineraryOptimiseService._();

  final Map<String, ValueNotifier<OptimiseJob>> _jobs = {};

  /// Which day/mode each trip's current job entry actually belongs to —
  /// `null` once [clear] has been called (no run to show).
  final Map<String, OptimiseScope> _scopes = {};

  ValueNotifier<OptimiseJob> jobFor(String tripId) =>
      _jobs.putIfAbsent(tripId, () => ValueNotifier<OptimiseJob>(OptimiseJob.idle));

  /// What [jobFor] (that trip's one job slot) currently holds the result
  /// *for* — e.g. so a status bar can say "Day 2" instead of just
  /// "Optimise". `null` when there's nothing running or waiting.
  OptimiseScope? scopeFor(String tripId) => _scopes[tripId];

  /// Per trip: does the group want each area kept on one day? Asked in the Optimise sheet, default yes.
  final Map<String, bool> _groupByArea = {};
  bool groupByAreaFor(String tripId) => _groupByArea[tripId] ?? true;
  void setGroupByArea(String tripId, bool value) {
    _groupByArea[tripId] = value;
    notifyListeners();
  }

  /// Starts a run for [tripId]/[mode]/[dayIndex], unless that exact scope
  /// is already running or already has a result waiting — reopening
  /// "Optimise Day 1" after minimising it (or after it finished) just
  /// shows what's already there instead of running it again and
  /// losing the person's ticks. A *different* scope (another day, or
  /// switching Day ⇄ Whole) always replaces whatever's there: there is
  /// only one Optimise slot per trip, same as AI Summarise, so switching
  /// scope must never leave a stale, wrongly-scoped result silently
  /// showing instead of the one just asked for.
  void start(String tripId, {required OptimiseMode mode, int? dayIndex, int? dayNumber}) {
    assert(mode != OptimiseMode.day || dayIndex != null, 'dayIndex is required for OptimiseMode.day');
    final job = jobFor(tripId);
    final current = _scopes[tripId];
    final groupByArea = groupByAreaFor(tripId);
    final sameScope = current != null && current.sameAs(mode, dayIndex, groupByArea);
    if (sameScope && (job.value.status == OptimiseStatus.running || job.value.status == OptimiseStatus.ready)) {
      return;
    }
    _scopes[tripId] = OptimiseScope(mode: mode, dayIndex: dayIndex, dayNumber: dayNumber, groupByArea: groupByArea);
    job.value = OptimiseJob.running;
    notifyListeners();
    _optimise(tripId, mode: mode, dayIndex: dayIndex, groupByArea: groupByArea).then((result) {
      job.value = OptimiseJob._(OptimiseStatus.ready, result: result);
      notifyListeners();
    }).catchError((Object e) {
      job.value = OptimiseJob._(OptimiseStatus.failed, error: e.toString());
      notifyListeners();
    });
  }

  /// Forgets the finished run (after the user applied or discarded it, or
  /// before "Run again" forces a fresh call for the same scope).
  void clear(String tripId) {
    final job = jobFor(tripId);
    if (job.value.status != OptimiseStatus.running) {
      job.value = OptimiseJob.idle;
      _scopes.remove(tripId);
      notifyListeners();
    }
  }

  Future<OptimiseResult> _optimise(String tripId, {required OptimiseMode mode, int? dayIndex, bool groupByArea = true}) async {
    final Map<String, dynamic> data;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'optimiseItinerary',
        options: HttpsCallableOptions(timeout: Duration(seconds: 120)),
      );
      final result = await callable.call({
        'tripId': tripId,
        'mode': mode == OptimiseMode.day ? 'day' : 'whole',
        if (mode == OptimiseMode.day) 'dayIndex': dayIndex,
        'groupByArea': groupByArea,
      });
      // Cast after the call rather than through call<T>() — same reason as
      // ItineraryAiService: the plugin hands back a loosely-typed Map.
      data = (result.data as Map).cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[ItineraryOptimiseService] optimiseItinerary failed: ${e.code} ${e.message} ${e.details}');
      if (e.code == 'not-found') {
        throw const OptimiseException('The Optimise service is not set up yet.');
      }
      final message = e.message?.trim();
      throw OptimiseException(
        (message != null && message.isNotEmpty) ? message : 'Could not optimise the plan. Please try again.',
      );
    } catch (e) {
      debugPrint('[ItineraryOptimiseService] optimiseItinerary unreachable: $e');
      throw const OptimiseException('Could not reach the Optimise service. Check your connection and try again.');
    }

    List<Map<String, dynamic>> rows(String key) =>
        [for (final raw in (data[key] as List? ?? const [])) (raw as Map).cast<String, dynamic>()];
    String str(Map<String, dynamic> m, String key) => (m[key] as String?) ?? '';
    int number(Map<String, dynamic> m, String key) => (m[key] as num?)?.toInt() ?? 0;

    return OptimiseResult(
      changes: [
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
              reason: str(m, 'reason'),
            ),
      ],
      notes: [for (final n in (data['notes'] as List? ?? const [])) n.toString()],
      itemCount: (data['itemCount'] as num?)?.toInt() ?? 0,
    );
  }
}
