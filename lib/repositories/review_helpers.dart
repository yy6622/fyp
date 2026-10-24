import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review_models.dart';
import '../services/content_moderation_service.dart';

/// Shared review-subcollection logic used by [CatalogRepository] (hotels,
/// restaurants, attractions) and [CommunityRepository] (posts) — every
/// review lives at `<parentDoc>/reviews/<reviewId>` with the same
/// `{authorId, authorName, rating, comment, createdAt}` shape, so this one
/// implementation backs all of them instead of near-identical copies in
/// each repository.
///
/// Hides a review [ContentModerationService] auto-flagged (see
/// [addReviewFor]) from everyone except its own author, while it's still
/// awaiting an admin's approve/reject decision in
/// admin/content-moderation.html — same reasoning as
/// [CommunityPost.autoFlagged]/`CommunityRepository.watchPosts` for whole
/// posts. [myUid] defaults to '' (hides every flagged review from an
/// anonymous/unresolved caller) — every real call site passes the
/// signed-in uid.
Stream<List<PlaceReview>> watchReviewsFor(DocumentReference<Map<String, dynamic>> parent, {String myUid = ''}) {
  return parent.collection('reviews').orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs
      .where((d) => d.data()['autoFlagged'] != true || d.data()['authorId'] == myUid)
      .map(_reviewFromDoc)
      .toList());
}

/// Writes one review under [parent], after first checking [comment] with
/// [ContentModerationService] (skipped when [comment] is blank — a bare
/// star rating has no text to check). Returns true when the review got
/// flagged, so the caller can tell its author it's pending review rather
/// than already visible.
///
/// A flagged review is still written, never blocked outright — just held
/// back from public view (see [watchReviewsFor]) and routed into the same
/// admin "reported content" queue a Community post auto-flag uses
/// (`reported`/`reportedBy: 'system'`/`reportReason`/`reportedAt`, plus
/// `autoFlagged: true`).
///
/// When [bumpAggregate] is true (the default — hotels/restaurants/
/// attractions want this so their star summary reflects real reviews),
/// [parent]'s own `ratingSum`/`ratingCount` fields are atomically
/// incremented too, so the average can be recomputed from them without
/// re-reading every review — but ONLY for a clean (not flagged) review:
/// a flagged one's rating is deliberately left out of the average until
/// an admin approves it (admin_web/js/data.js's `approveReview` is what
/// finishes that deferred bump then), so a since-rejected review's star
/// rating never counted toward the public average in the first place —
/// no "undo" needed on reject. Community posts pass `bumpAggregate: false`
/// since they already track their star rating separately via a `ratings`
/// map (the "quick rate" widget) — a written review there is
/// supplementary text, not a second rating input.
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
