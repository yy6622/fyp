import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'itinerary_ai_service.dart' show AiItineraryUpdate;

enum OptimiseMode { day, whole }

class OptimiseScope {
  final OptimiseMode mode;

  final int? dayIndex;

  final int? dayNumber;

  final bool groupByArea;

  const OptimiseScope({required this.mode, this.dayIndex, this.dayNumber, this.groupByArea = true});

  bool sameAs(OptimiseMode otherMode, int? otherDayIndex, [bool otherGroupByArea = true]) =>
      mode == otherMode && dayIndex == otherDayIndex && groupByArea == otherGroupByArea;
}

class OptimiseResult {
  final List<AiItineraryUpdate> changes;

  final int itemCount;

  final List<String> notes;

  const OptimiseResult({required this.changes, required this.itemCount, this.notes = const []});

  bool get isEmpty => changes.isEmpty;
}

class OptimiseException implements Exception {
  final String message;
  const OptimiseException(this.message);
  @override
  String toString() => message;
}

enum OptimiseStatus { idle, running, ready, failed }

class OptimiseJob {
  final OptimiseStatus status;
  final OptimiseResult? result;
  final String? error;
  const OptimiseJob._(this.status, {this.result, this.error});
  static const idle = OptimiseJob._(OptimiseStatus.idle);
  static const running = OptimiseJob._(OptimiseStatus.running);
}

class ItineraryOptimiseService extends ChangeNotifier {
  ItineraryOptimiseService._();
  static final ItineraryOptimiseService instance = ItineraryOptimiseService._();

  final Map<String, ValueNotifier<OptimiseJob>> _jobs = {};

  final Map<String, OptimiseScope> _scopes = {};

  ValueNotifier<OptimiseJob> jobFor(String tripId) =>
      _jobs.putIfAbsent(tripId, () => ValueNotifier<OptimiseJob>(OptimiseJob.idle));

  OptimiseScope? scopeFor(String tripId) => _scopes[tripId];

  final Map<String, bool> _groupByArea = {};
  bool groupByAreaFor(String tripId) => _groupByArea[tripId] ?? true;
  void setGroupByArea(String tripId, bool value) {
    _groupByArea[tripId] = value;
    notifyListeners();
  }

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
