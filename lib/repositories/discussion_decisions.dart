import 'package:cloud_firestore/cloud_firestore.dart';

import 'trip_repository.dart';

/// Decisions for items the group chat left undecided ("Decide now" in the
/// Discussion summary card). Stored on the trip document under
/// `discussionDecisions.{proposalMessageId}`; the summariseDiscussion and
/// generateItinerary Cloud Functions read them and treat them as final.
/// Kept in its own file so other edits to trip_repository.dart can't drop it.
extension DiscussionDecisions on TripRepository {
  /// status: confirmed / rejected / split / voting
  Future<void> recordDiscussionDecision(
    String tripId,
    String messageId, {
    required String status,
    required String byUid,
    required String byName,
    List<String> memberUids = const [],
    List<String> memberNames = const [],
    String voteTitle = '',
  }) {
    return FirebaseFirestore.instance.collection('trips').doc(tripId).update({
      'discussionDecisions.$messageId': {
        'status': status,
        'byUid': byUid,
        'byName': byName,
        'memberUids': memberUids,
        'memberNames': memberNames,
        'voteTitle': voteTitle,
        'at': FieldValue.serverTimestamp(),
      },
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }
}
