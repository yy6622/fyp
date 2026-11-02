import 'package:cloud_firestore/cloud_firestore.dart';

import 'trip_repository.dart';

extension TripPlanEdits on TripRepository {
  DocumentReference<Map<String, dynamic>> _trip(String tripId) =>
      FirebaseFirestore.instance.collection('trips').doc(tripId);

  Future<void> setActivityTime(String tripId, int dayIndex, String itemId, String time) {
    return _trip(tripId).update({
      'days.$dayIndex.items.$itemId.time': time,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

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
