class PlaceReview {
  final String id;
  final String authorId;
  final String authorName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  final bool autoFlagged;

  const PlaceReview({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.rating,
    required this.comment,
    this.createdAt,
    this.autoFlagged = false,
  });
}
