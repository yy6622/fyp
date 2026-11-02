import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';
import 'saved_items_controller.dart';

class PickedSavedItem {
  /// 'flight' | 'hotel' | 'attraction' | 'restaurant'.
  final String kind;
  final String id;
  final String label;
  final String subtitle;
  final String imageUrl;
  final String rating;
  final IconData fallbackIcon;
  final bool showThumb;
  const PickedSavedItem({
    required this.kind,
    required this.id,
    required this.label,
    this.subtitle = '',
    this.imageUrl = '',
    this.rating = '',
    required this.fallbackIcon,
    this.showThumb = true,
  });

  String get dedupeKey => '$kind:$id';
}

class VoteOptionDraft {
  final TextEditingController? textController;
  final PickedSavedItem? saved;

  VoteOptionDraft.manual()
      : textController = TextEditingController(),
        saved = null;

  VoteOptionDraft.fromSaved(PickedSavedItem item)
      : textController = null,
        saved = item;

  bool get isSaved => saved != null;

  String get label => isSaved ? saved!.label : (textController?.text.trim() ?? '');

  String get dedupeKey => isSaved ? saved!.dedupeKey : label.toLowerCase();

  void dispose() => textController?.dispose();
}

class VoteTabController extends ChangeNotifier {
  final String tripId;
  VoteTabController({required this.tripId}) {
    _sub = TripRepository.instance.watchVotes(tripId).listen((v) {
      _votes = v;
      _loading = false;
      notifyListeners();
    });
    _tripSub = TripRepository.instance.watchTrip(tripId, _uid).listen((t) {
      _trip = t;
      notifyListeners();
    });
    _saved.addListener(notifyListeners);
  }

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  List<TripVote> _votes = [];
  List<TripVote> get votes => _votes;

  bool _loading = true;
  bool get loading => _loading;

  StreamSubscription<List<TripVote>>? _sub;

  Trip? _trip;
  StreamSubscription<Trip?>? _tripSub;

  int get totalMembers => (_trip?.memberIds.isNotEmpty ?? false) ? _trip!.memberIds.length : 1;

  late final SavedItemsController _saved = SavedItemsController(tripId: tripId);

  bool votedByMe(VoteOption option) => option.votedBy.contains(_uid);

  bool hasVotedAny(TripVote vote) => vote.options.any((o) => o.votedBy.contains(_uid));

  bool canVote(TripVote vote, VoteOption option) {
    if (vote.isClosed) return false;
    if (vote.allowMultipleChoice) return !votedByMe(option);
    return !hasVotedAny(vote);
  }

  CatalogHotel? hotelFor(VoteOption option) => _firstWhereOrNull(_saved.hotels, (h) => _sameName(h.name, option.label));
  CatalogAttraction? attractionFor(VoteOption option) =>
      _firstWhereOrNull(_saved.attractions, (a) => _sameName(a.name, option.label));
  CatalogRestaurant? restaurantFor(VoteOption option) =>
      _firstWhereOrNull(_saved.restaurants, (r) => _sameName(r.name, option.label));
  CatalogFlight? flightFor(VoteOption option) =>
      _firstWhereOrNull(_saved.flights, (f) => _sameName('${f.from} → ${f.to}', option.label));

  bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

  Future<String?> castVote(TripVote vote, String optionId) async {
    try {
      await TripRepository.instance.castVote(tripId, vote, optionId, _uid);
      return null;
    } on StateError catch (e) {
      return e.message;
    } catch (_) {
      return "Couldn't cast your vote. Please try again.";
    }
  }

  Future<bool> addOption(TripVote vote, String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return false;
    final exists = vote.options.any((o) => o.label.trim().toLowerCase() == trimmed.toLowerCase());
    if (exists) return false;
    await TripRepository.instance.addVoteOption(tripId, vote.id, trimmed);
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tripSub?.cancel();
    _saved.removeListener(notifyListeners);
    _saved.dispose();
    super.dispose();
  }
}

class CreateVoteController extends ChangeNotifier {
  final String tripId;
  CreateVoteController({required this.tripId});

  final TextEditingController titleController = TextEditingController();

  final List<VoteOptionDraft> optionDrafts = [];

  bool _allowAddOptions = true;
  bool get allowAddOptions => _allowAddOptions;

  bool _allowMultipleChoice = false;
  bool get allowMultipleChoice => _allowMultipleChoice;

  DateTime? _deadline;
  DateTime? get deadline => _deadline;

  bool _saving = false;
  bool get saving => _saving;

  String? lastError;

  Set<String> get savedDedupeKeys =>
      optionDrafts.where((d) => d.isSaved).map((d) => d.saved!.dedupeKey).toSet();

  void setDeadline(DateTime? v) {
    _deadline = v;
    notifyListeners();
  }

  void addOption() {
    optionDrafts.add(VoteOptionDraft.manual());
    notifyListeners();
  }

  void addOptions(List<PickedSavedItem> picked) {
    if (picked.isEmpty) return;
    final existing = savedDedupeKeys;
    final toAdd = picked.where((p) => !existing.contains(p.dedupeKey));
    optionDrafts.addAll(toAdd.map(VoteOptionDraft.fromSaved));
    notifyListeners();
  }

  void removeOptionAt(int index) {
    optionDrafts.removeAt(index).dispose();
    notifyListeners();
  }

  void setAllowAddOptions(bool v) {
    _allowAddOptions = v;
    notifyListeners();
  }

  void setAllowMultipleChoice(bool v) {
    _allowMultipleChoice = v;
    notifyListeners();
  }

  Future<bool> create() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
    final title = titleController.text.trim();
    final filled = optionDrafts.where((d) => d.label.isNotEmpty).toList();
    if (title.isEmpty || filled.length < 2) {
      lastError = 'Add a title and at least 2 options first';
      return false;
    }
    final seen = <String>{};
    for (final d in filled) {
      if (!seen.add(d.dedupeKey)) {
        lastError = 'Duplicate option: "${d.label}" — each option must be different';
        return false;
      }
    }
    if (_deadline != null && _deadline!.isBefore(DateTime.now())) {
      lastError = 'Deadline must be in the future';
      return false;
    }
    lastError = null;
    _saving = true;
    notifyListeners();
    try {
      await TripRepository.instance.createVote(
        tripId,
        title: title,
        options: filled.map((d) => d.label).toList(),
        allowAddOptions: _allowAddOptions,
        allowMultipleChoice: _allowMultipleChoice,
        createdBy: uid,
        deadline: _deadline,
      );
      return true;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    for (final d in optionDrafts) {
      d.dispose();
    }
    super.dispose();
  }
}
