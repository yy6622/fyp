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

  Map<String, int> _tagAffinity = {};

  StreamSubscription<List<CommunityPost>>? _sub;
  StreamSubscription<Set<String>>? _reviewedSub;
  StreamSubscription<Map<String, int>>? _affinitySub;

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

  void recordView(CommunityPost post) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.recordView(post.id, uid, tags: post.tags);
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
    _affinitySub?.cancel();
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

  PickedPostMedia? _media;
  File? get mediaFile => _media?.file;
  bool get mediaAdded => _media != null;
  bool get mediaIsVideo => _media?.isVideo ?? false;

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
