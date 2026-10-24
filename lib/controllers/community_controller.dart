import 'dart:async';

import 'package:flutter/material.dart';

import '../models/community_models.dart';
import '../repositories/community_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

/// Controller for [CommunityPage] (and reused by [CommunityPostDetailPage],
/// each screen keeping its own instance — both subscribe to the same live
/// Firestore stream, so a like/save/rating made on either page shows up on
/// the other immediately).
class CommunityController extends ChangeNotifier {
  bool _composeOpen = false;
  bool get composeOpen => _composeOpen;

  final TextEditingController search = TextEditingController();

  List<CommunityPost> _posts = [];
  bool _loading = true;
  bool get loading => _loading;

  // Post ids the signed-in user has left a written review/comment on —
  // backs the "Review" tab on Profile's Community Post page. Rating
  // doesn't need an equivalent set: [CommunityPost.myRating] already
  // carries it per-post (see CommunityRepository._fromDoc).
  Set<String> _myReviewedPostIds = {};
  Set<String> get myReviewedPostIds => _myReviewedPostIds;

  // Tag the user tapped on a post's hashtag chip, filtering the feed down
  // to just posts carrying it — cleared by tapping it again or the "✕" on
  // the "Showing: #tag" indicator CommunityPage shows while this is set.
  String? _activeTagFilter;
  String? get activeTagFilter => _activeTagFilter;

  void setActiveTagFilter(String? tag) {
    _activeTagFilter = tag;
    notifyListeners();
  }

  // tag -> number of distinct posts with that tag the signed-in user has
  // viewed (see CommunityRepository.recordView/watchTagAffinity) — the
  // whole basis for [recommendedPosts] below.
  Map<String, int> _tagAffinity = {};

  StreamSubscription<List<CommunityPost>>? _sub;
  StreamSubscription<Set<String>>? _reviewedSub;
  StreamSubscription<Map<String, int>>? _affinitySub;

  CommunityController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _sub = CommunityRepository.instance.watchPosts(uid).listen((incoming) {
        // Preserve transient view-only state (which tab/day is expanded)
        // across snapshot rebuilds, since each Firestore update produces
        // brand-new CommunityPost objects.
        final previousById = {for (final p in _posts) p.id: p};
        for (final post in incoming) {
          final prev = previousById[post.id];
          if (prev != null) {
            post.tab = prev.tab;
            post.expandedDay = prev.expandedDay;
          }
        }
        _posts = incoming;
        _loading = false;
        notifyListeners();
      });
      _reviewedSub = CommunityRepository.instance.watchMyReviewedPostIds(uid).listen((ids) {
        _myReviewedPostIds = ids;
        notifyListeners();
      });
      _affinitySub = CommunityRepository.instance.watchTagAffinity(uid).listen((affinity) {
        _tagAffinity = affinity;
        notifyListeners();
      });
    } else {
      _loading = false;
    }
  }

  void setComposeOpen(bool value) {
    _composeOpen = value;
    notifyListeners();
  }

  void toggleComposeOpen() {
    _composeOpen = !_composeOpen;
    notifyListeners();
  }

  void refreshSearch() => notifyListeners();

  List<CommunityPost> get filteredPosts {
    var result = _posts;
    final tag = _activeTagFilter;
    if (tag != null) {
      result = result.where((p) => p.tags.contains(tag)).toList();
    }
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return result;
    return result
        .where((p) =>
            p.title.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query) ||
            p.author.toLowerCase().contains(query))
        .toList();
  }

  /// Posts whose tags overlap the signed-in user's most-viewed tags,
  /// ranked by how much they overlap (ties broken newest-first — [_posts]
  /// already comes back `createdAt` descending from [watchPosts], and
  /// `List.sort` is stable, so that ordering survives among equal-overlap
  /// posts). Backs the feed's "Recommended for you" section, only shown
  /// there while this is non-empty. Capped at 10 so it stays a highlight
  /// reel, not a second copy of the whole feed.
  ///
  /// Deliberately not tag-filter-aware ([activeTagFilter]) or
  /// search-aware ([filteredPosts]) — it's the user's standing "what
  /// you're into" shelf, not another view of whatever they're currently
  /// filtering the main feed to.
  List<CommunityPost> get recommendedPosts {
    if (_tagAffinity.isEmpty) return const [];
    final topTags = _tagAffinity.keys.toSet();
    final scored = _posts
        .where((p) => p.tags.any(topTags.contains))
        .map((p) => (post: p, score: p.tags.where(topTags.contains).length))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.post).take(10).toList();
  }

  void toggleLike(CommunityPost post) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.toggleLike(post.id, uid, !post.liked);
  }

  /// Fire-and-forget view record for the Community Post Analysis Report —
  /// see [CommunityRepository.recordView]. Called once from
  /// [CommunityPostDetailPage]'s initState.
  void recordView(CommunityPost post) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.recordView(post.id, uid, tags: post.tags);
  }

  /// Returns null on success, or an error message to show. Reports as the
  /// signed-in traveller — see [CommunityRepository.reportPost].
  Future<String?> reportPost(CommunityPost post, String reason) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return 'You need to be signed in to report a post.';
    if (post.id.isEmpty) return 'This post can\'t be reported.';
    try {
      await CommunityRepository.instance.reportPost(post.id, reportedByUid: uid, reason: reason);
      return null;
    } catch (e) {
      return 'Could not submit your report — please try again.';
    }
  }

  // There used to be a setRating(post, stars) here backing a standalone
  // "quick rate" widget on the post detail page. That widget was dropped
  // — rating now only happens as part of leaving a review (the star
  // picker in showWriteReviewDialog), which CommunityRepository.addReview
  // already writes straight to Firestore, so no controller method is
  // needed for it.

  void setTab(CommunityPost post, CommunityPostTab tab) {
    post.tab = tab;
    notifyListeners();
  }

  void setExpandedDay(CommunityPost post, int? day) {
    post.expandedDay = post.expandedDay == day ? null : day;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reviewedSub?.cancel();
    _affinitySub?.cancel();
    search.dispose();
    super.dispose();
  }
}

/// Controller for [CreatePostPage].
class CreatePostController extends ChangeNotifier {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController tagInputController = TextEditingController();

  // Hashtags the author has added so far (chip-style, see CreatePostPage) —
  // normalized on publish by CommunityRepository.normalizeTags, but kept
  // as-typed here so a chip can still show "#Foodie" back to the author
  // exactly as they wrote it.
  final List<String> _tags = [];
  List<String> get tags => List.unmodifiable(_tags);

  /// Adds [tagInputController]'s current text as a tag chip and clears the
  /// field, ready for the next one. No-ops on blank input or a duplicate
  /// (case-insensitive, '#' ignored) so the chip row never shows the same
  /// tag twice.
  void addTagFromInput() {
    final raw = tagInputController.text.trim();
    if (raw.isEmpty) return;
    final normalized = raw.toLowerCase().replaceFirst('#', '');
    if (normalized.isEmpty || _tags.any((t) => t.toLowerCase().replaceFirst('#', '') == normalized)) {
      tagInputController.clear();
      notifyListeners();
      return;
    }
    _tags.add(raw);
    tagInputController.clear();
    notifyListeners();
  }

  void removeTag(String tag) {
    _tags.remove(tag);
    notifyListeners();
  }

  bool _mediaAdded = false;
  bool get mediaAdded => _mediaAdded;

  bool _allowComments = true;
  bool get allowComments => _allowComments;

  bool _allowShare = true;
  bool get allowShare => _allowShare;

  bool _publishing = false;
  bool get publishing => _publishing;

  /// Whether the most recent successful [publish] call got auto-flagged
  /// by content moderation (see CommunityRepository.createPost) and is
  /// therefore pending admin review rather than already live — read by
  /// CreatePostPage right after a successful publish to show the right
  /// message.
  bool _lastPublishWasFlagged = false;
  bool get lastPublishWasFlagged => _lastPublishWasFlagged;

  void toggleMediaAdded() {
    _mediaAdded = !_mediaAdded;
    notifyListeners();
  }

  void setAllowComments(bool v) {
    _allowComments = v;
    notifyListeners();
  }

  void setAllowShare(bool v) {
    _allowShare = v;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  /// Publishes the post to Firestore. Returns null on success, or an error
  /// message to show. [itineraryTitle] (when set) is looked up in
  /// [myItineraries] so the itinerary days get attached to the post.
  Future<String?> publish({String? itineraryTitle}) async {
    final title = titleController.text.trim();
    if (title.isEmpty) return 'Please add a title before publishing';
    final user = AuthService.instance.currentUser;
    if (user == null) return 'You need to be signed in to post.';

    _publishing = true;
    notifyListeners();
    try {
      final profile = await UserRepository.instance.fetchProfile(user.uid);
      final name = (profile != null && profile.name.isNotEmpty) ? profile.name : (user.email ?? 'Traveller');

      List<Map<String, dynamic>> itinerary = const [];
      if (itineraryTitle != null) {
        final matches = myItineraries.where((i) => i.title == itineraryTitle);
        if (matches.isNotEmpty) {
          final days = matches.first.days;
          itinerary = List.generate(days.length, (i) => {'day': i + 1, 'items': days[i]});
        }
      }

      _lastPublishWasFlagged = await CommunityRepository.instance.createPost(
        authorId: user.uid,
        author: name,
        title: title,
        description: descController.text.trim(),
        location: itineraryTitle ?? '',
        itinerary: itinerary,
        tags: _tags,
      );
      return null;
    } catch (e) {
      return 'Could not publish your post — please try again.';
    } finally {
      _publishing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    tagInputController.dispose();
    super.dispose();
  }
}

/// Controller for [ItinerarySelectPage].
class ItinerarySelectController extends ChangeNotifier {
  int? _expanded = 0;
  int? get expanded => _expanded;

  int? _selected;
  int? get selected => _selected;

  /// Which day (0-indexed) is open within each expanded itinerary tile —
  /// keyed by tile index. Day 1 (index 0) starts open once a tile expands.
  final Map<int, int?> _expandedDay = {};
  int? expandedDayFor(int tileIndex) => _expandedDay.containsKey(tileIndex) ? _expandedDay[tileIndex] : 0;
  void setExpandedDay(int tileIndex, int day) {
    final current = expandedDayFor(tileIndex);
    _expandedDay[tileIndex] = current == day ? null : day;
    notifyListeners();
  }

  void select(int index) {
    _selected = index;
    _expanded = _expanded == index ? null : index;
    notifyListeners();
  }
}
