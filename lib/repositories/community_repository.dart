import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/community_models.dart';
import '../services/format_utils.dart';

/// Reads/writes the `posts` collection backing the Community feed.
///
/// Likes/saves are stored as uid arrays directly on the post doc
/// (`likedBy`/`savedBy`) and ratings as a `{uid: stars}` map — all updated
/// with atomic field operations, so no transactions are needed and the
/// displayed counts (`likedBy.length`, average of `ratings.values`) are
/// always consistent with the arrays themselves.
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
      'savedBy': <String>[],
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

  Future<void> toggleSaved(String postId, String uid, bool saved) {
    return _posts.doc(postId).update({
      'savedBy': saved ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> setRating(String postId, String uid, int stars) {
    return _posts.doc(postId).update({'ratings.$uid': stars});
  }

  /// Writes the two original starter posts once, attributed to whichever
  /// signed-in user happens to trigger it, so a brand-new Firebase project
  /// doesn't start with a completely empty feed. No-ops once there's any
  /// real data.
  Future<void> seedIfEmpty(String myUid) async {
    final existing = await _posts.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    for (final post in mockCommunityPosts) {
      await _posts.add({
        'authorId': myUid,
        'author': post.author,
        'handle': post.handle,
        'avatarColorValue': post.avatarColor.toARGB32(),
        'title': post.title,
        'description': post.description,
        'location': post.location,
        'flagEmoji': post.flagEmoji,
        'images': post.images,
        'itinerary': post.itinerary.map((d) => {'day': d.day, 'items': d.items}).toList(),
        'likedBy': <String>[],
        'savedBy': <String>[],
        'ratings': <String, dynamic>{},
        'commentsCount': post.comments,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  CommunityPost _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc, String myUid) {
    final data = doc.data();
    final likedBy = List<String>.from(data['likedBy'] as List? ?? const []);
    final savedBy = List<String>.from(data['savedBy'] as List? ?? const []);
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
      reviews: const [],
      avgRating: ratingValues.isEmpty ? 0 : ratingValues.reduce((a, b) => a + b) / ratingValues.length,
      ratingCount: ratingValues.length,
      likes: likedBy.length,
      comments: (data['commentsCount'] as num?)?.toInt() ?? 0,
      liked: likedBy.contains(myUid),
      saved: savedBy.contains(myUid),
      myRating: (ratingsMap[myUid] as num?)?.toInt() ?? 0,
    );
  }
}
