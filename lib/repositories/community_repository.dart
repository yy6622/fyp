import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/community_models.dart';
import '../models/review_models.dart';
import '../services/content_moderation_service.dart';
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

  /// Cleans up author-typed hashtags before they're stored: trims
  /// whitespace, lowercases, strips a leading '#' (so "#Foodie" and
  /// "foodie" land on the same tag), drops anything left empty, and
  /// de-duplicates while keeping the author's original order.
  static List<String> normalizeTags(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final t in raw) {
      var tag = t.trim().toLowerCase();
      if (tag.startsWith('#')) tag = tag.substring(1);
      if (tag.isEmpty || seen.contains(tag)) continue;
      seen.add(tag);
      out.add(tag);
    }
    return out;
  }

  /// Hides a post that [ContentModerationService] auto-flagged (see
  /// [createPost]) from everyone except its own author, while it's still
  /// awaiting an admin's approve/reject decision — a manually-reported
  /// post (plain `reported`, no `autoFlagged`) stays visible to everyone
  /// throughout review, same as before this feature; only an
  /// AI-auto-flagged one is held back, since unlike a human report it was
  /// never seen and judged fine by anyone before going live.
  /// [approvePostReport] (admin_web/js/data.js) clears `autoFlagged` on
  /// approve, which is what makes an approved post reappear for everyone.
  Stream<List<CommunityPost>> watchPosts(String myUid) {
    return _posts.orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs
        .where((d) => d.data()['autoFlagged'] != true || d.data()['authorId'] == myUid)
        .map((d) => _fromDoc(d, myUid))
        .toList());
  }

  /// Creates the post, after first checking its title+description with
  /// [ContentModerationService]. Returns true when the post was flagged
  /// (so the caller — see CreatePostController.publish — can tell the
  /// author it's pending review instead of saying it's live). A flagged
  /// post is still created, never blocked outright: it's saved with the
  /// same `reported`/`reportedBy`/`reportReason`/`reportedAt` fields a
  /// human "Report post" tap sets (see [reportPost]) — `reportedBy:
  /// 'system'` marks it as AI-detected rather than human-reported, for
  /// admin/content-moderation.html's display — plus `autoFlagged: true`,
  /// which is what [watchPosts] uses to hold it out of the public feed
  /// until an admin reviews it. Deliberately does NOT bump `reportCount`
  /// — that field is specifically a lifetime count of human reports (see
  /// its doc comment on [CommunityPost]), and an auto-flag isn't one.
  Future<bool> createPost({
    required String authorId,
    required String author,
    required String title,
    required String description,
    required String location,
    String flagEmoji = '📍',
    List<Map<String, dynamic>> itinerary = const [],
    List<String> tags = const [],
    // FR61 — a real photo or video attached at compose time (see
    // CreatePostController.publish, which uploads whichever one the
    // person picked via CommunityMediaService before calling this).
    // Previously always hardcoded to images: [] regardless of what the
    // "Upload Media" toggle showed, since that toggle never actually
    // picked or uploaded anything.
    List<String> images = const [],
    String videoUrl = '',
  }) async {
    final moderation = await ContentModerationService.instance.check('$title\n$description');
    await _posts.add({
      'authorId': authorId,
      'author': author,
      'handle': handleForName(author),
      'avatarColorValue': colorValueForName(author),
      'title': title,
      'description': description,
      'location': location.isEmpty ? 'Unknown' : location,
      'flagEmoji': flagEmoji,
      'images': images,
      'videoUrl': videoUrl,
      'itinerary': itinerary,
      'tags': normalizeTags(tags),
      'likedBy': <String>[],
      'ratings': <String, dynamic>{},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      if (moderation.flagged) ...{
        'autoFlagged': true,
        'reported': true,
        'reportedBy': 'system',
        'reportReason': 'Auto-detected: ${moderation.reason}',
        'reportedAt': FieldValue.serverTimestamp(),
      },
    });
    return moderation.flagged;
  }

  /// FR62 — edits an existing post's own title/description/tags. Only
  /// ever called by the post's own author (firestore.rules' `posts/
  /// {postId}` update rule — "the author can change anything" — double-
  /// checks that server-side); doesn't touch likedBy/ratings/comments/
  /// moderation fields, so a passing re-run through content moderation
  /// isn't needed here the way it is for a brand-new [createPost] — this
  /// only lets the author fix their own wording, not post fresh content
  /// that was never checked.
  Future<void> updatePost(
    String postId, {
    required String title,
    required String description,
    List<String> tags = const [],
  }) {
    return _posts.doc(postId).update({
      'title': title,
      'description': description,
      'tags': normalizeTags(tags),
    });
  }

  /// FR64 — permanently deletes one of your own posts.
  Future<void> deletePost(String postId) {
    return _posts.doc(postId).delete();
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
  ///
  /// [tags] — the viewed post's own [CommunityPost.tags] — are folded
  /// into `users/{uid}.tagAffinity`, a `{tag: viewCount}` map that is the
  /// whole basis for [CommunityController.recommendedPosts] ("based on
  /// what you've viewed before"). Only bumped on a first view of this
  /// post by this viewer (same `isFirstView` check as `uniqueViewerCount`
  /// above) — re-opening a post you already saw shouldn't make its tags
  /// look more interesting to you than a brand-new one you just glanced
  /// at once.
  Future<void> recordView(String postId, String uid, {List<String> tags = const []}) async {
    if (uid.isEmpty || postId.isEmpty) return;
    final postRef = _posts.doc(postId);
    final viewerRef = postRef.collection('viewers').doc(uid);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
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
        if (isFirstView && tags.isNotEmpty) {
          tx.set(
            userRef,
            {'tagAffinity': {for (final tag in normalizeTags(tags)) tag: FieldValue.increment(1)}},
            SetOptions(merge: true),
          );
        }
      });
    } catch (_) {
      // Analytics-only — see doc comment above.
    }
  }

  /// Streams [uid]'s `tagAffinity` map (tag → number of distinct posts
  /// with that tag they've viewed) — see [recordView]. Missing/empty for
  /// a user who hasn't viewed any tagged post yet.
  Stream<Map<String, int>> watchTagAffinity(String uid) {
    if (uid.isEmpty) return Stream.value(const {});
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['tagAffinity'] as Map? ?? const {};
      return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
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
  Stream<List<PlaceReview>> watchReviews(String postId, {String myUid = ''}) => watchReviewsFor(_posts.doc(postId), myUid: myUid);

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
  ///
  /// Returns true when [addReviewFor] flagged the comment as possibly
  /// inappropriate — when that happens, [setRating] is deliberately
  /// skipped too, same reasoning as [addReviewFor]'s deferred
  /// `ratingSum`/`ratingCount` bump for hotels/restaurants/attractions:
  /// a flagged review's star rating shouldn't count toward the post's
  /// average until an admin approves it. admin_web/js/data.js's
  /// `approveReview` sets `ratings.$authorId` directly to finish that
  /// deferred write then.
  Future<bool> addReview(String postId, {required String authorId, required String authorName, required int rating, required String comment}) async {
    final flagged = await addReviewFor(_posts.doc(postId), authorId: authorId, authorName: authorName, rating: rating, comment: comment, bumpAggregate: false);
    if (!flagged) await setRating(postId, authorId, rating);
    return flagged;
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
      videoUrl: (data['videoUrl'] as String?) ?? '',
      location: (data['location'] as String?) ?? '',
      itinerary: itineraryRaw
          .map((d) => CommunityItineraryDay(
                day: (d['day'] as num).toInt(),
                items: List<String>.from(d['items'] as List? ?? const []),
                // Absent on any post made before FR31/FR68 — those just
                // can't be imported, same as a day with no activities.
                activities: (d['activities'] as List? ?? const [])
                    .map((a) => Map<String, dynamic>.from(a as Map))
                    .map((a) => ImportableActivity(
                          time: (a['time'] as String?) ?? '',
                          label: (a['label'] as String?) ?? '',
                          location: (a['location'] as String?) ?? '',
                          iconKey: (a['icon'] as String?) ?? '',
                        ))
                    .toList(),
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
      autoFlagged: data['autoFlagged'] == true,
      tags: List<String>.from(data['tags'] as List? ?? const []),
    );
  }
}
