import 'package:flutter/material.dart';

// ---------------------------------------------------------------------
// Real, Firestore-backed data shapes for the Community page. There used
// to be a `mockCommunityPosts` list here, seeded into the real `posts`
// collection by CommunityRepository.seedIfEmpty so a brand-new Firebase
// project didn't start with an empty feed — removed because it silently
// attributed those two fake posts (author shown as "Jamie Lee"/
// "Sarah.W") to whichever real signed-in account happened to open
// Community first, so that account would see someone else's name on a
// post sitting under their own "My Posts" tab. A genuinely empty feed
// (see CommunityPage's empty state) is the honest state until someone
// actually posts.
// ---------------------------------------------------------------------

/// Which sub-tab of a [CommunityPost]'s itinerary section is showing —
/// used both on the feed card and the full post detail page.
enum CommunityPostTab { itinerary, review }

/// One day inside a [CommunityPost]'s attached itinerary.
class CommunityItineraryDay {
  final int day;
  final List<String> items;
  const CommunityItineraryDay({required this.day, required this.items});
}

/// A social post in the Community feed. Mutable — likes/comments/liked/
/// myRating/tab/expandedDay all change as the user interacts with it.
///
/// Only one engagement toggle is kept (like) — an earlier version also had
/// a separate bookmark/save toggle, but having both a heart and a bookmark
/// right next to each other read as two ways to do the same thing, so it
/// was dropped in favor of just "like".
class CommunityPost {
  /// Firestore document id — always real; the only place a [CommunityPost]
  /// is ever constructed is [CommunityRepository]'s own Firestore read.
  final String id;

  /// uid of the post's author — used to check ownership, e.g. for delete.
  final String authorId;
  final String author;
  final String handle;
  final Color avatarColor;
  final String timeAgo;
  final String title;
  final String flagEmoji;
  final String description;
  final List<String> images;
  final String location;
  final List<CommunityItineraryDay> itinerary;
  final double avgRating;
  final int ratingCount;
  int likes;
  int comments;
  bool liked;
  int myRating;

  /// Total number of times this post's detail page has been opened
  /// (repeat views by the same traveller included) — bumped by
  /// [CommunityRepository.recordView]. Feeds the Community Post Analysis
  /// Report's "total views" figures; not shown anywhere in the app UI
  /// itself.
  final int viewCount;

  /// Number of DISTINCT authenticated travellers who have ever opened
  /// this post, derived server-side from the `posts/{id}/viewers`
  /// marker subcollection so a repeat view never double-counts. Also
  /// report-only, like [viewCount].
  final int uniqueViewerCount;

  /// Lifetime count of "Report post" submissions against this post (see
  /// [CommunityRepository.reportPost]) — unlike the transient `reported`
  /// flag the content-moderation queue clears once reviewed, this never
  /// resets, so it stays a true total for the Community Post Analysis
  /// Report's "user-report count" column.
  final int reportCount;

  CommunityPostTab tab;
  int? expandedDay;
  CommunityPost({
    required this.id,
    required this.authorId,
    required this.author,
    required this.handle,
    required this.avatarColor,
    required this.timeAgo,
    required this.title,
    required this.flagEmoji,
    required this.description,
    required this.images,
    required this.location,
    this.itinerary = const [],
    required this.avgRating,
    required this.ratingCount,
    required this.likes,
    required this.comments,
    this.liked = false,
    this.myRating = 0,
    this.viewCount = 0,
    this.uniqueViewerCount = 0,
    this.reportCount = 0,
    this.tab = CommunityPostTab.itinerary,
    this.expandedDay = 1,
  });
}

/// One of the current user's own itineraries, offered when composing an
/// "Itinerary Post". [days] holds one entry per day of the trip — an empty
/// list for a day with no activities planned yet.
class SelectableItinerary {
  final String title;
  final String image;
  final List<List<String>> days;
  const SelectableItinerary({required this.title, required this.image, required this.days});
}

const List<SelectableItinerary> myItineraries = [
  SelectableItinerary(
    title: 'Japan Trips',
    image: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=200',
    days: [
      ['10:30  Arrive to Narita Airport (NRT)', '14:30  Check-in L Hotel', '16:30  Shibaya Shopping Mall', '19:30  Dinner at Uobei Shibuya'],
      [],
      [],
      [],
    ],
  ),
  SelectableItinerary(
    title: 'Korea Trips',
    image: 'https://images.unsplash.com/photo-1517154421773-0529f29ea451?w=200',
    days: [
      ['09:00  Arrive Incheon Airport (ICN)', '13:00  Check-in Myeongdong Hotel', '15:30  Namsan Tower', '19:00  Dinner at Myeongdong Street'],
      [],
    ],
  ),
];
