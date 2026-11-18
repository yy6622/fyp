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

class CommunityController extends ChangeNotifier {
  bool _composeOpen = false;
  bool get composeOpen => _composeOpen;

  final TextEditingController search = TextEditingController();

  List<CommunityPost> _posts = [];
  bool _loading = true;
  bool get loading => _loading;

  Set<String> _myReviewedPostIds = {};
  Set<String> get myReviewedPostIds => _myReviewedPostIds;

  String? _activeTagFilter;
  String? get activeTagFilter => _activeTagFilter;

  void setActiveTagFilter(String? tag) {
    _activeTagFilter = tag;
    notifyListeners();
  }

  double _minRating = 0;
  double get minRating => _minRating;
  void setMinRating(double v) {
    _minRating = v;
    notifyListeners();
  }

  Set<String> get allTags => {for (final p in _posts) ...p.tags};

  Set<String> _myViewedPostIds = {};

  StreamSubscription<List<CommunityPost>>? _sub;
  StreamSubscription<Set<String>>? _reviewedSub;
  StreamSubscription<Set<String>>? _viewedSub;

  CommunityController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _sub = CommunityRepository.instance.watchPosts(uid).listen((incoming) {
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
      _viewedSub = CommunityRepository.instance.watchMyViewedPostIds(uid).listen((ids) {
        _myViewedPostIds = ids;
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
    if (query.isNotEmpty) {
      result = result
          .where((p) =>
              p.title.toLowerCase().contains(query) ||
              p.location.toLowerCase().contains(query) ||
              p.author.toLowerCase().contains(query))
          .toList();
    }
    // Posts already opened sink below posts not yet seen -- a stable
    // partition (not a re-sort of the whole list) so within each group
    // nothing shuffles relative to how watchPosts() already ordered it.
    final notViewed = result.where((p) => !_myViewedPostIds.contains(p.id)).toList();
    final viewed = result.where((p) => _myViewedPostIds.contains(p.id)).toList();
    return [...notViewed, ...viewed];
  }

  void toggleLike(CommunityPost post) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.toggleLike(post.id, uid, !post.liked);
  }

  void recordView(CommunityPost post) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.recordView(post.id, uid);
  }

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

  Future<String?> deletePost(CommunityPost post) async {
    if (post.id.isEmpty) return 'This post can\'t be deleted.';
    try {
      await CommunityRepository.instance.deletePost(post.id);
      return null;
    } catch (e) {
      return 'Could not delete your post — please try again.';
    }
  }


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
    _viewedSub?.cancel();
    search.dispose();
    super.dispose();
  }
}

class CreatePostController extends ChangeNotifier {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController tagInputController = TextEditingController();

  final String? editingPostId;
  bool get isEditing => editingPostId != null;

  CreatePostController({this.editingPostId, CommunityPost? editingPost}) {
    if (editingPost != null) {
      titleController.text = editingPost.title;
      descController.text = editingPost.description;
      _tags.addAll(editingPost.tags);
    }
  }

  final List<String> _tags = [];
  List<String> get tags => List.unmodifiable(_tags);

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

  /// A post is either up to [maxMediaCount] photos, or a single video --
  /// never mixed (matches how `images`/`videoUrl` are stored as separate
  /// fields on CommunityPost). Picking a video replaces any photos already
  /// chosen, and vice versa.
  static const int maxMediaCount = 9;

  final List<PickedPostMedia> _mediaItems = [];
  List<File> get mediaFiles => _mediaItems.map((m) => m.file).toList(growable: false);
  int get mediaCount => _mediaItems.length;
  bool get mediaAdded => _mediaItems.isNotEmpty;
  bool get mediaIsVideo => _mediaItems.isNotEmpty && _mediaItems.first.isVideo;
  bool get canAddMoreMedia => !mediaIsVideo && _mediaItems.length < maxMediaCount;

  Future<String?> pickMedia(ImageSource source, {required bool video}) async {
    try {
      if (video) {
        final picked = await CommunityMediaService.instance.pickVideo(source);
        if (picked == null) return null;
        _mediaItems
          ..clear()
          ..add(picked);
        notifyListeners();
        return null;
      }

      // Switching from a previously-picked video back to photos.
      if (_mediaItems.isNotEmpty && _mediaItems.first.isVideo) {
        _mediaItems.clear();
      }
      if (_mediaItems.length >= maxMediaCount) {
        return 'You can add up to $maxMediaCount photos.';
      }

      if (source == ImageSource.gallery) {
        final remaining = maxMediaCount - _mediaItems.length;
        final picked = await CommunityMediaService.instance.pickMultiImages(limit: remaining);
        if (picked.isEmpty) return null;
        _mediaItems.addAll(picked.take(remaining));
        notifyListeners();
        return null;
      }

      // Camera: one photo at a time.
      final picked = await CommunityMediaService.instance.pickImage(source);
      if (picked == null) return null;
      _mediaItems.add(picked);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e';
    }
  }

  void removeMediaAt(int index) {
    if (index < 0 || index >= _mediaItems.length) return;
    _mediaItems.removeAt(index);
    notifyListeners();
  }

  void removeMedia() {
    _mediaItems.clear();
    notifyListeners();
  }

  bool _allowComments = true;
  bool get allowComments => _allowComments;

  bool _publishing = false;
  bool get publishing => _publishing;

  bool _lastPublishWasFlagged = false;
  bool get lastPublishWasFlagged => _lastPublishWasFlagged;

  void setAllowComments(bool v) {
    _allowComments = v;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  bool _generatingSummary = false;
  bool get generatingSummary => _generatingSummary;

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

  Future<String?> publish({Trip? itineraryTrip}) async {
    final title = titleController.text.trim();
    if (title.isEmpty) return 'Please add a title before publishing';
    final user = AuthService.instance.currentUser;
    if (user == null) return 'You need to be signed in to post.';

    _publishing = true;
    notifyListeners();
    try {
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

      var images = const <String>[];
      var videoUrl = '';
      if (_mediaItems.isNotEmpty) {
        if (_mediaItems.first.isVideo) {
          videoUrl = await CommunityMediaService.instance.upload(user.uid, _mediaItems.first);
        } else {
          // Uploaded in parallel (up to 9, each independent) but Future.wait
          // preserves input order in its result regardless of completion
          // order, so the post's photo order still matches what the user
          // arranged/picked.
          images = await Future.wait([
            for (var i = 0; i < _mediaItems.length; i++)
              CommunityMediaService.instance.upload(user.uid, _mediaItems[i], index: i),
          ]);
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
      // Past plans only live on the Plan tab -- hide them here too.
      _trips = list.where((t) => !t.isInactive).toList();
      _loading = false;
      notifyListeners();
    });
  }

  int? _expanded = 0;
  int? get expanded => _expanded;

  int? _selected;
  int? get selected => _selected;
  Trip? get selectedTrip => _selected == null ? null : _trips[_selected!];

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
