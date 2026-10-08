import 'package:cloud_firestore/cloud_firestore.dart';

import 'trip_repository.dart';

/// Two edits to an activity that is already in a trip's plan, used when the
/// AI itinerary sheet applies "move this" / "change the time" suggestions
/// (lib/views/group/ai_itinerary_sheet.dart). Kept beside [TripRepository]
/// as an extension, writing the same `trips/{tripId}.days.{dayIndex}.items`
/// map that [TripRepository.addActivity] / `removeActivity` write.
extension TripPlanEdits on TripRepository {
  DocumentReference<Map<String, dynamic>> _trip(String tripId) =>
      FirebaseFirestore.instance.collection('trips').doc(tripId);

  /// Changes only the time of an existing activity; votes are kept.
  Future<void> setActivityTime(String tripId, int dayIndex, String itemId, String time) {
    return _trip(tripId).update({
      'days.$dayIndex.items.$itemId.time': time,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  /// Moves an activity to another day (optionally with a new time) in one
  /// write, so it can never end up on both days or on neither. The activity
  /// gets a new id on the target day — ids decide the display order within
  /// a day — and its votes start again, since they were cast for the old day.
  Future<void> moveActivity(
    String tripId, {
    required int fromDayIndex,
    required int toDayIndex,
    required String itemId,
    required String time,
    required String label,
    required String iconKey,
    String location = '',
  }) {
    final newId = '${DateTime.now().microsecondsSinceEpoch}';
    return _trip(tripId).update({
      'days.$fromDayIndex.items.$itemId': FieldValue.delete(),
      'days.$toDayIndex.items.$newId': {
        'time': time,
        'label': label,
        'icon': iconKey,
        'location': location,
        'votedBy': <String>[],
      },
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }
}
