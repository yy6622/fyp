import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/community_models.dart';
import '../repositories/community_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/community_media_service.dart';
import '../services/itinerary_summary_service.dart';

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

  /// Minimum star rating the Community search bar's filter icon (the
  /// "tune" icon — see CommunityPage._openFilters) can require, 0
  /// meaning "no minimum". That icon used to open a completely unrelated
  /// "Trip Duration (days)" sheet (FilterType.plan, apparently copied
  /// from Explore's wiring) whose selections were never read back into
  /// [filteredPosts] at all — this and [allTags] are the real filtering
  /// state its replacement sheet actually uses.
  double _minRating = 0;
  double get minRating => _minRating;
  void setMinRating(double v) {
    _minRating = v;
    notifyListeners();
  }

  /// Every hashtag currently in use across the feed, for the filter
  /// sheet's tag picker — [activeTagFilter] already exists and is real
  /// (tapping a tag chip on any post sets it), this just surfaces the
  /// full set somewhere that isn't "whatever chip happens to be on
  /// screen".
  Set<String> get allTags => {for (final p in _posts) ...p.tags};

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
    if (_minRating > 0) {
      result = result.where((p) => p.avgRating >= _minRating).toList();
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

  /// FR64 — returns null on success, or an error message to show.
  Future<String?> deletePost(CommunityPost post) async {
    if (post.id.isEmpty) return 'This post can\'t be deleted.';
    try {
      await CommunityRepository.instance.deletePost(post.id);
      return null;
    } catch (e) {
      return 'Could not delete your post — please try again.';
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

/// Controller for [CreatePostPage]. Doubles as the Edit Post controller
/// (FR62) — pass an existing post's id to [editingPostId] and its
/// constructor pre-fills title/description/tags from it; [publish] then
/// calls [CommunityRepository.updatePost] instead of [CommunityRepository.
/// createPost].
class CreatePostController extends ChangeNotifier {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController tagInputController = TextEditingController();

  /// Non-null when this controller is editing an existing post (FR62)
  /// rather than composing a new one.
  final String? editingPostId;
  bool get isEditing => editingPostId != null;

  CreatePostController({this.editingPostId, CommunityPost? editingPost}) {
    if (editingPost != null) {
      titleController.text = editingPost.title;
      descController.text = editingPost.description;
      _tags.addAll(editingPost.tags);
    }
  }

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

  /// FR61 — the one photo or video a post can attach, actually picked
  /// (and later uploaded by [publish]) rather than the old [_mediaAdded]
  /// bool, which only ever toggled a checkmark with nothing behind it.
  PickedPostMedia? _media;
  File? get mediaFile => _media?.file;
  bool get mediaAdded => _media != null;
  bool get mediaIsVideo => _media?.isVideo ?? false;

  /// Returns a user-facing error message on failure, or null on success —
  /// including the person just backing out of the picker, which isn't an
  /// error (same "no error, nothing to show" convention CreatePostPage's
  /// other async actions use).
  Future<String?> pickMedia(ImageSource source, {required bool video}) async {
    try {
      final picked = video
          ? await CommunityMediaService.instance.pickVideo(source)
          : await CommunityMediaService.instance.pickImage(source);
      if (picked == null) return null;
      _media = picked;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e';
    }
  }

  void removeMedia() {
    _media = null;
    notifyListeners();
  }

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

  void setAllowComments(bool v) {
    _allowComments = v;
    notifyListeners();
  }

  void setAllowShare(bool v) {
    _allowShare = v;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  bool _generatingSummary = false;
  bool get generatingSummary => _generatingSummary;

  /// FR65 — "AI summary when sharing": fills [descController] from
  /// [itineraryTrip]'s real day plan via [ItinerarySummaryService]. Only
  /// meaningful for an Itinerary Post (there's nothing to summarise for a
  /// plain Community Post). Returns a message to show either way — what
  /// happened on success, or why nothing changed on failure — never
  /// throws, same fails-open convention as the summary service itself.
  Future<String> generateAiSummary(Trip itineraryTrip) async {
    _generatingSummary = true;
    notifyListeners();
    try {
      final summary = await ItinerarySummaryService.instance.summarise(itineraryTrip.destination, itineraryTrip.days);
      if (summary == null) {
        return "Couldn't generate a summary right now — please write your own description.";
      }
      descController.text = summary;
      return 'Description filled in from your itinerary — feel free to edit it.';
    } finally {
      _generatingSummary = false;
      notifyListeners();
    }
  }

  /// Publishes the post to Firestore. Returns null on success, or an error
  /// message to show. [itineraryTrip] (when set) is the real trip this
  /// Itinerary Post is sharing — its days/activities are attached to the
  /// post (FR31/FR68's structured [ImportableActivity] data, alongside
  /// the plain display text every post has always had).
  Future<String?> publish({Trip? itineraryTrip}) async {
    final title = titleController.text.trim();
    if (title.isEmpty) return 'Please add a title before publishing';
    final user = AuthService.instance.currentUser;
    if (user == null) return 'You need to be signed in to post.';

    _publishing = true;
    notifyListeners();
    try {
      // FR62 — editing never touches location/itinerary/authorship/media,
      // only the fields the person can actually see a field for on this
      // page.
      final editingId = editingPostId;
      if (editingId != null) {
        await CommunityRepository.instance.updatePost(
          editingId,
          title: title,
          description: descController.text.trim(),
          tags: _tags,
        );
        return null;
      }

      final profile = await UserRepository.instance.fetchProfile(user.uid);
      final name = (profile != null && profile.name.isNotEmpty) ? profile.name : (user.email ?? 'Traveller');

      List<Map<String, dynamic>> itinerary = const [];
      if (itineraryTrip != null) {
        itinerary = [
          for (var i = 0; i < itineraryTrip.days.length; i++)
            {
              'day': i + 1,
              'items': [for (final it in itineraryTrip.days[i].items) '${it.time}  ${it.label}'],
              'activities': [
                for (final it in itineraryTrip.days[i].items)
                  {'time': it.time, 'label': it.label, 'location': it.location, 'icon': iconKeyFor(it.icon)},
              ],
            },
        ];
      }

      // FR61 — upload whatever media was picked, if any.
      var images = const <String>[];
      var videoUrl = '';
      final media = _media;
      if (media != null) {
        final url = await CommunityMediaService.instance.upload(user.uid, media);
        if (media.isVideo) {
          videoUrl = url;
        } else {
          images = [url];
        }
      }

      _lastPublishWasFlagged = await CommunityRepository.instance.createPost(
        authorId: user.uid,
        author: name,
        title: title,
        description: descController.text.trim(),
        location: itineraryTrip?.destination.trim().isNotEmpty == true ? itineraryTrip!.destination.trim() : (itineraryTrip?.name ?? ''),
        itinerary: itinerary,
        tags: _tags,
        images: images,
        videoUrl: videoUrl,
      );
      return null;
    } catch (e) {
      return 'Could not ${editingPostId != null ? 'save' : 'publish'} your post — please try again.';
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

/// Controller for [ItinerarySelectPage] — streams the signed-in person's
/// REAL trips (see [TripRepository.watchMyTrips]) instead of the
/// hardcoded "Japan Trips"/"Korea Trips" sample pair this used to offer,
/// which meant every single Itinerary Post ever shared on Community was
/// actually one of those two fake plans regardless of whose trips existed.
class ItinerarySelectController extends ChangeNotifier {
  List<Trip> _trips = [];
  List<Trip> get trips => _trips;

  bool _loading = true;
  bool get loading => _loading;

  StreamSubscription<List<Trip>>? _sub;

  ItinerarySelectController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      _loading = false;
      return;
    }
    _sub = TripRepository.instance.watchMyTrips(uid).listen((list) {
      _trips = list;
      _loading = false;
      notifyListeners();
    });
  }

  int? _expanded = 0;
  int? get expanded => _expanded;

  int? _selected;
  int? get selected => _selected;
  Trip? get selectedTrip => _selected == null ? null : _trips[_selected!];

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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
