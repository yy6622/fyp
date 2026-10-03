import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review_models.dart';

/// Shared review-subcollection logic used by [CatalogRepository] (hotels,
/// restaurants, attractions) and [CommunityRepository] (posts) — every
/// review lives at `<parentDoc>/reviews/<reviewId>` with the same
/// `{authorId, authorName, rating, comment, createdAt}` shape, so this one
/// implementation backs all of them instead of near-identical copies in
/// each repository.
Stream<List<PlaceReview>> watchReviewsFor(DocumentReference<Map<String, dynamic>> parent) {
  return parent.collection('reviews').orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs.map(_reviewFromDoc).toList());
}

/// Writes one review under [parent]. When [bumpAggregate] is true (the
/// default — hotels/restaurants/attractions want this so their star
/// summary reflects real reviews), [parent]'s own `ratingSum`/`ratingCount`
/// fields are atomically incremented too, so the average can be recomputed
/// from them without re-reading every review. Community posts pass
/// `bumpAggregate: false` since they already track their star rating
/// separately via a `ratings` map (the "quick rate" widget) — a written
/// review there is supplementary text, not a second rating input.
Future<void> addReviewFor(
  DocumentReference<Map<String, dynamic>> parent, {
  required String authorId,
  required String authorName,
  required int rating,
  required String comment,
  bool bumpAggregate = true,
}) async {
  await parent.collection('reviews').add({
    'authorId': authorId,
    'authorName': authorName,
    'rating': rating,
    'comment': comment,
    'createdAt': FieldValue.serverTimestamp(),
  });
  if (bumpAggregate) {
    await parent.update({
      'ratingSum': FieldValue.increment(rating),
      'ratingCount': FieldValue.increment(1),
    });
  }
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
  );
}
