import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/community_models.dart';
import '../models/review_models.dart';
import '../services/format_utils.dart';
import 'review_helpers.dart';

/// Reads/writes the `posts` collection backing the Community feed.
///
/// Likes are stored as a uid array directly on the post doc (`likedBy`)
/// and ratings as a `{uid: stars}` map — both updated with atomic field
/// operations, so no transactions are needed and the displayed counts
/// (`likedBy.length`, average of `ratings.values`) are always consistent
/// with the arrays themselves.
class CommunityRepository {
  CommunityRepository._();
  static final CommunityRepository instance = CommunityRepository._();

  CollectionReference<Map<String, dynamic>> get _posts => FirebaseFirestore.instance.collection('posts');

  Stream<List<CommunityPost>> watchPosts(String myUid) {
    return _posts.orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => _fromDoc(d, myUid)).toList());
  }

  Future<void> createPost({
    required String authorId,
    required String author,
    required String title,
    required String description,
    required String location,
    String flagEmoji = '📍',
    List<Map<String, dynamic>> itinerary = const [],
  }) {
    return _posts.add({
      'authorId': authorId,
      'author': author,
      'handle': handleForName(author),
      'avatarColorValue': colorValueForName(author),
      'title': title,
      'description': description,
      'location': location.isEmpty ? 'Unknown' : location,
      'flagEmoji': flagEmoji,
      'images': <String>[],
      'itinerary': itinerary,
      'likedBy': <String>[],
      'ratings': <String, dynamic>{},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike(String postId, String uid, bool liked) {
    return _posts.doc(postId).update({
      'likedBy': liked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  /// Records one view of [postId] by [uid], for the admin console's
  /// Community Post Analysis Report. Called once from
  /// [CommunityPostDetailPage]'s initState every time the post opens.
  ///
  /// Every call bumps the post's `viewCount` by 1 and this calendar
  /// month's aggregate in `post_view_stats/{YYYY-MM}` (the report's
  /// monthly trend chart). The FIRST call for a given uid also bumps
  /// `uniqueViewerCount` — told apart from a repeat view via a marker doc
  /// at `posts/{postId}/viewers/{uid}`, read inside the same transaction
  /// so two near-simultaneous opens can't both think they're "first".
  /// Best-effort: a logged-in uid is required, but any failure (offline,
  /// a stale/deleted post) is swallowed — a view counter is analytics,
  /// never something worth blocking or erroring the post page over.
  Future<void> recordView(String postId, String uid) async {
    if (uid.isEmpty || postId.isEmpty) return;
    final postRef = _posts.doc(postId);
    final viewerRef = postRef.collection('viewers').doc(uid);
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final statsRef = FirebaseFirestore.instance.collection('post_view_stats').doc(monthKey);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final viewerSnap = await tx.get(viewerRef);
        final isFirstView = !viewerSnap.exists;
        tx.set(
          viewerRef,
          {
            'firstViewedAt': isFirstView ? FieldValue.serverTimestamp() : viewerSnap.data()?['firstViewedAt'],
            'lastViewedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        tx.update(postRef, {
          'viewCount': FieldValue.increment(1),
          if (isFirstView) 'uniqueViewerCount': FieldValue.increment(1),
        });
        tx.set(statsRef, {'viewCount': FieldValue.increment(1)}, SetOptions(merge: true));
      });
    } catch (_) {
      // Analytics-only — see doc comment above.
    }
  }

  /// Files a report against [postId] (the mobile-side half of the
  /// content-moderation flow — the admin console's "Reported content"
  /// queue already existed, but nothing in the app could ever actually
  /// put a post into it). Sets the four fields `content-moderation.html`
  /// reads/clears (`reported`/`reportedBy`/`reportReason`/`reportedAt`),
  /// and separately bumps `reportCount`, which — unlike those four —
  /// is never cleared, so it stays a true lifetime total for the
  /// Community Post Analysis Report even after a report is dismissed.
  Future<void> reportPost(String postId, {required String reportedByUid, required String reason}) {
    return _posts.doc(postId).update({
      'reported': true,
      'reportedBy': reportedByUid,
      'reportReason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
      'reportCount': FieldValue.increment(1),
    });
  }

  /// Sets [uid]'s rating on a post directly. No longer called from any UI
  /// — there used to be a standalone "quick rate" star row on the post
  /// detail page, but rating only ever made sense alongside a review (you
  /// rate *and* optionally say why), so that row was dropped in favor of
  /// just rating through [addReview] below. Kept so the `ratings` map
  /// still has a single, named write path.
  Future<void> setRating(String postId, String uid, int stars) {
    return _posts.doc(postId).update({'ratings.$uid': stars});
  }

  /// A post's written reviews — real, Firestore-backed, one per author.
  /// Not the same data as [CommunityPost.reviews], which is always empty;
  /// that field predates this and is no longer read anymore.
  Stream<List<PlaceReview>> watchReviews(String postId) => watchReviewsFor(_posts.doc(postId));

  /// Which post ids [uid] has left a written review on — backs the merged
  /// "Rating & Review" tab on Profile's Community Post page (My Posts /
  /// Liked / Rating & Review). `reviews` is the same subcollection name
  /// [review_helpers.dart] uses under every reviewable doc (hotels,
  /// restaurants, attractions, posts), so a plain collectionGroup query
  /// would also catch those — filtered here to only the ones whose parent
  /// is actually a `posts` doc.
  Stream<Set<String>> watchMyReviewedPostIds(String uid) {
    return FirebaseFirestore.instance
        .collectionGroup('reviews')
        .where('authorId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.reference.parent.parent)
            .where((postDoc) => postDoc != null && postDoc.parent.id == 'posts')
            .map((postDoc) => postDoc!.id)
            .toSet());
  }

  /// Writes the review doc, then also records [rating] into the post's
  /// `ratings` map via [setRating] — a star rating is now only ever given
  /// as part of leaving a review (see [showWriteReviewDialog]'s rating
  /// picker), so submitting one here is what feeds `avgRating`/`myRating`
  /// instead of a separate standalone tap. [bumpAggregate] stays false:
  /// posts track their average through the per-uid `ratings` map, not a
  /// summed `ratingSum`/`ratingCount` pair.
  Future<void> addReview(String postId, {required String authorId, required String authorName, required int rating, required String comment}) async {
    await addReviewFor(_posts.doc(postId), authorId: authorId, authorName: authorName, rating: rating, comment: comment, bumpAggregate: false);
    await setRating(postId, authorId, rating);
  }

  // There used to be a seedIfEmpty(myUid) here that wrote two fake starter
  // posts into this collection so a brand-new Firebase project didn't
  // start with an empty feed. Removed — it attributed those posts'
  // authorId to whichever real signed-in account happened to trigger it,
  // so that one real account would see someone else's name ("Jamie Lee"/
  // "Sarah.W") on a post sitting under their own "My Posts" tab. A
  // genuinely empty feed is the correct state until someone actually
  // posts; see CommunityPage's empty state for that.

  CommunityPost _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc, String myUid) {
    final data = doc.data();
    final likedBy = List<String>.from(data['likedBy'] as List? ?? const []);
    final ratingsMap = Map<String, dynamic>.from(data['ratings'] as Map? ?? const {});
    final ratingValues = ratingsMap.values.map((v) => (v as num).toInt()).toList();
    final itineraryRaw = (data['itinerary'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    return CommunityPost(
      id: doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      author: (data['author'] as String?) ?? 'Traveller',
      handle: (data['handle'] as String?) ?? '@traveller',
      avatarColor: Color((data['avatarColorValue'] as int?) ?? 0xFF104259),
      timeAgo: createdAt == null ? 'Just now' : formatTimeAgo(createdAt),
      title: (data['title'] as String?) ?? '',
      flagEmoji: (data['flagEmoji'] as String?) ?? '📍',
      description: (data['description'] as String?) ?? '',
      images: List<String>.from(data['images'] as List? ?? const []),
      location: (data['location'] as String?) ?? '',
      itinerary: itineraryRaw
          .map((d) => CommunityItineraryDay(
                day: (d['day'] as num).toInt(),
                items: List<String>.from(d['items'] as List? ?? const []),
              ))
          .toList(),
      avgRating: ratingValues.isEmpty ? 0 : ratingValues.reduce((a, b) => a + b) / ratingValues.length,
      ratingCount: ratingValues.length,
      likes: likedBy.length,
      comments: (data['commentsCount'] as num?)?.toInt() ?? 0,
      liked: likedBy.contains(myUid),
      myRating: (ratingsMap[myUid] as num?)?.toInt() ?? 0,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      uniqueViewerCount: (data['uniqueViewerCount'] as num?)?.toInt() ?? 0,
      reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
    );
  }
}
