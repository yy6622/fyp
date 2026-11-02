import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/community_models.dart';
import '../models/review_models.dart';
import '../services/content_moderation_service.dart';
import '../services/format_utils.dart';
import 'review_helpers.dart';

class CommunityRepository {
  CommunityRepository._();
  static final CommunityRepository instance = CommunityRepository._();

  CollectionReference<Map<String, dynamic>> get _posts => FirebaseFirestore.instance.collection('posts');

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

  Stream<List<CommunityPost>> watchPosts(String myUid) {
    return _posts.orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs
        .where((d) => d.data()['autoFlagged'] != true || d.data()['authorId'] == myUid)
        .map((d) => _fromDoc(d, myUid))
        .toList());
  }

  Future<bool> createPost({
    required String authorId,
    required String author,
    required String title,
    required String description,
    required String location,
    String flagEmoji = '📍',
    List<Map<String, dynamic>> itinerary = const [],
    List<String> tags = const [],
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

  Future<void> deletePost(String postId) {
    return _posts.doc(postId).delete();
  }

  Future<void> toggleLike(String postId, String uid, bool liked) {
    return _posts.doc(postId).update({
      'likedBy': liked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

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
    }
  }

  Stream<Map<String, int>> watchTagAffinity(String uid) {
    if (uid.isEmpty) return Stream.value(const {});
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['tagAffinity'] as Map? ?? const {};
      return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
  }

  Future<void> reportPost(String postId, {required String reportedByUid, required String reason}) {
    return _posts.doc(postId).update({
      'reported': true,
      'reportedBy': reportedByUid,
      'reportReason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
      'reportCount': FieldValue.increment(1),
    });
  }

  Future<void> setRating(String postId, String uid, int stars) {
    return _posts.doc(postId).update({'ratings.$uid': stars});
  }

  Stream<List<PlaceReview>> watchReviews(String postId, {String myUid = ''}) => watchReviewsFor(_posts.doc(postId), myUid: myUid);

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

  Future<bool> addReview(String postId, {required String authorId, required String authorName, required int rating, required String comment}) async {
    final flagged = await addReviewFor(_posts.doc(postId), authorId: authorId, authorName: authorName, rating: rating, comment: comment, bumpAggregate: false);
    if (!flagged) await setRating(postId, authorId, rating);
    return flagged;
  }


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
