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

  StreamSubscription<List<CommunityPost>>? _sub;

  CommunityController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      CommunityRepository.instance.seedIfEmpty(uid);
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
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return _posts;
    return _posts
        .where((p) =>
            p.title.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query) ||
            p.author.toLowerCase().contains(query))
        .toList();
  }

  void toggleLike(CommunityPost post) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.toggleLike(post.id, uid, !post.liked);
  }

  void toggleSaved(CommunityPost post) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.toggleSaved(post.id, uid, !post.saved);
  }

  void setRating(CommunityPost post, int stars) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || post.id.isEmpty) return;
    CommunityRepository.instance.setRating(post.id, uid, stars);
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
    search.dispose();
    super.dispose();
  }
}

/// Controller for [CreatePostPage].
class CreatePostController extends ChangeNotifier {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  bool _mediaAdded = false;
  bool get mediaAdded => _mediaAdded;

  bool _allowComments = true;
  bool get allowComments => _allowComments;

  bool _allowShare = true;
  bool get allowShare => _allowShare;

  bool _publishing = false;
  bool get publishing => _publishing;

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

      await CommunityRepository.instance.createPost(
        authorId: user.uid,
        author: name,
        title: title,
        description: descController.text.trim(),
        location: itineraryTitle ?? '',
        itinerary: itinerary,
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
