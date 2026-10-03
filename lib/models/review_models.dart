/// A single real, Firestore-backed review left by a signed-in user on a
/// hotel/restaurant/attraction (a `catalog_*` doc) or a Community post —
/// every one of those parent docs keeps its written reviews in a `reviews`
/// subcollection with this exact shape, so this one model backs all of
/// them (see `lib/repositories/review_helpers.dart`). Nothing here is
/// canned/sample content — every field comes from an actual write.
class PlaceReview {
  final String id;
  final String authorId;
  final String authorName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const PlaceReview({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });
}
