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

  /// The same day's activities again, but structured (time/label/
  /// location/icon) rather than flattened into display strings — carries
  /// what's actually needed to import this day into someone else's own
  /// trip (FR31/FR68's "Add to My Plan", see CommunityPostDetailPage).
  /// Empty for a post made before this field existed, or for a day with
  /// no activities — [items] (plain display text) still always has
  /// whatever was shown at the time, so older posts keep rendering
  /// exactly as before; they just can't be imported.
  final List<ImportableActivity> activities;

  const CommunityItineraryDay({required this.day, required this.items, this.activities = const []});
}

/// One real scheduled activity from an attached itinerary day, carried
/// alongside [CommunityItineraryDay.items]'s display text — see that
/// field's doc comment for why both exist. Mirrors exactly what
/// [TripRepository.addActivity] needs to recreate it on another trip.
class ImportableActivity {
  final String time;
  final String label;
  final String location;
  final String iconKey;
  const ImportableActivity({required this.time, required this.label, this.location = '', required this.iconKey});
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

  /// Set when the author attached a video instead of a photo when
  /// composing (FR61) — a post has at most one media item today (same
  /// single-"Upload Media" slot the compose form has always offered),
  /// never both a video and photos. Empty for a photo-only or media-less
  /// post.
  final String videoUrl;
  bool get hasVideo => videoUrl.isNotEmpty;

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

  /// True when [ContentModerationService] flagged this post's text as
  /// possibly inappropriate at creation time (see
  /// [CommunityRepository.createPost]) and it's still awaiting an admin's
  /// approve/reject decision in admin/content-moderation.html. While
  /// true, [CommunityRepository.watchPosts] hides the post from everyone
  /// except its own author — see that method's doc comment — so the UI
  /// only ever needs this to show the author their own "pending review"
  /// state, never to filter anything itself.
  final bool autoFlagged;

  /// Hashtags the author attached when composing this post (e.g. "foodie",
  /// "budget", "solo") — lowercase, no leading '#'. Shown as tappable chips
  /// on the feed card and detail page, and the basis for
  /// [CommunityRepository.recordView]'s per-viewer tag-affinity tracking,
  /// which in turn drives [CommunityController.recommendedPosts].
  final List<String> tags;

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
    this.videoUrl = '',
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
    this.autoFlagged = false,
    this.tags = const [],
    this.tab = CommunityPostTab.itinerary,
    this.expandedDay = 1,
  });
}

