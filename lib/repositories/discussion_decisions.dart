import 'package:cloud_firestore/cloud_firestore.dart';

import 'trip_repository.dart';

extension DiscussionDecisions on TripRepository {
  Future<void> recordDiscussionDecision(
    String tripId,
    String messageId, {
    required String status,
    required String byUid,
    required String byName,
    List<String> memberUids = const [],
    List<String> memberNames = const [],
    String voteTitle = '',
    String voteId = '',
  }) {
    return FirebaseFirestore.instance.collection('trips').doc(tripId).update({
      'discussionDecisions.$messageId': {
        'status': status,
        'byUid': byUid,
        'byName': byName,
        'memberUids': memberUids,
        'memberNames': memberNames,
        'voteTitle': voteTitle,
        'voteId': voteId,
        'at': FieldValue.serverTimestamp(),
      },
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }
}
