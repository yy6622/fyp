import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review_models.dart';
import '../services/content_moderation_service.dart';

Stream<List<PlaceReview>> watchReviewsFor(DocumentReference<Map<String, dynamic>> parent, {String myUid = ''}) {
  return parent.collection('reviews').orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs
      .where((d) => d.data()['autoFlagged'] != true || d.data()['authorId'] == myUid)
      .map(_reviewFromDoc)
      .toList());
}

Future<bool> addReviewFor(
  DocumentReference<Map<String, dynamic>> parent, {
  required String authorId,
  required String authorName,
  required int rating,
  required String comment,
  bool bumpAggregate = true,
}) async {
  final moderation = comment.trim().isEmpty
      ? ModerationResult.clean
      : await ContentModerationService.instance.check(comment);
  await parent.collection('reviews').add({
    'authorId': authorId,
    'authorName': authorName,
    'rating': rating,
    'comment': comment,
    'createdAt': FieldValue.serverTimestamp(),
    if (moderation.flagged) ...{
      'autoFlagged': true,
      'reported': true,
      'reportedBy': 'system',
      'reportReason': 'Auto-detected: ${moderation.reason}',
      'reportedAt': FieldValue.serverTimestamp(),
    },
  });
  if (bumpAggregate && !moderation.flagged) {
    await parent.update({
      'ratingSum': FieldValue.increment(rating),
      'ratingCount': FieldValue.increment(1),
    });
  }
  return moderation.flagged;
}

PlaceReview _reviewFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();
  return PlaceReview(
    id: d.id,
    authorId: (data['authorId'] as String?) ?? '',
    authorName: (data['authorName'] as String?) ?? 'Traveller',
    rating: (data['rating'] as num?)?.toInt() ?? 5,
    comment: (data['comment'] as String?) ?? '',
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    autoFlagged: data['autoFlagged'] == true,
  );
}
