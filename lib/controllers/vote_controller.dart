import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';
import 'saved_items_controller.dart';

/// A single "From Saved" pick for Create Vote's option list — carries
/// enough of the real catalog row (not just its display label) to render
/// as a card (image/subtitle/rating) instead of a plain text field, and
/// to tell two picks apart by the real catalog id rather than by name
/// text (so renaming something elsewhere, or two differently-worded
/// options that happen to be the same place, can't be confused — and so
/// the exact same listing can be reliably blocked from being added
/// twice). Built by saved_item_picker_sheet.dart (the view) from whatever
/// catalog row the person tapped; lives here, not there, since it's what
/// [CreateVoteController.optionDrafts] is actually made of.
class PickedSavedItem {
  /// 'flight' | 'hotel' | 'attraction' | 'restaurant'.
  final String kind;
  final String id;
  final String label;
  final String subtitle;
  final String imageUrl;
  final String rating;
  final IconData fallbackIcon;
  const PickedSavedItem({
    required this.kind,
    required this.id,
    required this.label,
    this.subtitle = '',
    this.imageUrl = '',
    this.rating = '',
    required this.fallbackIcon,
  });

  /// Stable identity for duplicate detection — "<kind>:<id>", independent
  /// of [label] text.
  String get dedupeKey => '$kind:$id';
}

/// One row of Create Vote's option list — either typed by hand (has its
/// own [textController], freely editable) or picked "From Saved" (has
/// [saved] instead, shown as a read-only card and only removable, not
/// editable, since it's tied to a real catalog listing).
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

  /// Key used to catch a duplicate option at [CreateVoteController.create]
  /// time — the real catalog id for a saved pick (two picker trips can't
  /// add the same listing twice either, see [PickedSavedItem.dedupeKey]),
  /// or the trimmed/lowercased typed text for a manual row (so retyping
  /// the same name twice, or retyping a saved item's exact name by hand,
  /// is still caught).
  String get dedupeKey => isSaved ? saved!.dedupeKey : label.toLowerCase();

  void dispose() => textController?.dispose();
}

/// Controller for [VoteTab] — streams every real vote/poll created for a
/// trip (`trips/{tripId}/votes`), plus everything [VoteTab] needs to show
/// an option as a real card instead of a plain text row:
///  - the trip doc itself, for the member count/names behind each
///    option's "X/Total voted" fraction and avatar stack;
///  - the trip's saved flights/hotels/attractions/restaurants, so an
///    option that was added via "From Saved" in Create Vote can be
///    matched back to the real listing behind it (image, rating,
///    location, price) rather than just showing its label text.
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

  /// Total trip members — the denominator shown next to each option's
  /// vote count (e.g. "3/5"). Falls back to 1 before the trip doc has
  /// loaded rather than 0, so nothing ever divides by zero.
  int get totalMembers => (_trip?.memberIds.isNotEmpty ?? false) ? _trip!.memberIds.length : 1;

  /// Not exposed as a loading flag of its own — [VoteTab] just renders
  /// whatever's loaded so far (empty lists until each stream's first
  /// snapshot arrives), same as the rest of this controller. `late` so
  /// its initializer (which reads the `tripId` field) runs after that
  /// field is set, not before.
  late final SavedItemsController _saved = SavedItemsController(tripId: tripId);

  bool votedByMe(VoteOption option) => option.votedBy.contains(_uid);

  /// Matches an option's plain-text label back to the trip's saved
  /// hotel/attraction/restaurant with that exact name (case/whitespace
  /// insensitive) — best-effort only: an option typed by hand instead of
  /// picked "From Saved" just won't match anything, which [VoteTab]
  /// treats as a plain card rather than an error. Only one of these four
  /// will ever match for a given option in practice (a saved item's name
  /// is only ever that one listing's), so [VoteTab] checks them in this
  /// same order and stops at the first hit.
  CatalogHotel? hotelFor(VoteOption option) => _firstWhereOrNull(_saved.hotels, (h) => _sameName(h.name, option.label));
  CatalogAttraction? attractionFor(VoteOption option) =>
      _firstWhereOrNull(_saved.attractions, (a) => _sameName(a.name, option.label));
  CatalogRestaurant? restaurantFor(VoteOption option) =>
      _firstWhereOrNull(_saved.restaurants, (r) => _sameName(r.name, option.label));
  /// Flight options are saved from the same "From → To" label the "From
  /// Saved" picker builds (see saved_item_picker_sheet.dart), so that's
  /// what's matched against here rather than a single flight field.
  CatalogFlight? flightFor(VoteOption option) =>
      _firstWhereOrNull(_saved.flights, (f) => _sameName('${f.from} → ${f.to}', option.label));

  bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

  Future<void> castVote(TripVote vote, String optionId) {
    return TripRepository.instance.castVote(tripId, vote, optionId, _uid);
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

/// Controller for [CreateVotePage] — writes a real vote/poll document.
class CreateVoteController extends ChangeNotifier {
  final String tripId;
  CreateVoteController({required this.tripId});

  final TextEditingController titleController = TextEditingController();

  /// Option 1 and Option 2 always exist and can never be removed (see
  /// [removeOptionAt]'s guard in create_vote_page.dart).
  final List<VoteOptionDraft> optionDrafts = [
    VoteOptionDraft.manual(),
    VoteOptionDraft.manual(),
  ];

  bool _allowAddOptions = true;
  bool get allowAddOptions => _allowAddOptions;

  bool _allowMultipleChoice = false;
  bool get allowMultipleChoice => _allowMultipleChoice;

  DateTime? _deadline;
  DateTime? get deadline => _deadline;

  bool _saving = false;
  bool get saving => _saving;

  /// Set by [create] when it returns false for a reason more specific
  /// than "nothing filled in yet" (right now, just a duplicate option) —
  /// the page reads this right after a failed [create] to show the right
  /// message instead of always the same generic one.
  String? lastError;

  /// The real catalog listings already sitting in [optionDrafts] as
  /// "From Saved" picks — passed to [showSavedItemPicker] so it can grey
  /// those rows out and stop the exact same listing being picked twice.
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

  /// Appends one option row per item picked from the trip's saved
  /// flights/hotels/attractions/restaurants (see [showSavedItemPicker] in
  /// saved_item_picker_sheet.dart) — always as new rows, never merged
  /// into an existing manual row, since a "From Saved" row is a different
  /// shape (a read-only card, not a text field) from a typed one.
  /// [showSavedItemPicker] already won't hand back anything in
  /// [savedDedupeKeys], but it's checked again here too, defensively, in
  /// case of a race between opening the sheet and this call landing.
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

  /// Returns true if the vote was created. False either for the existing
  /// "nothing filled in" reason, or for a duplicate option (same saved
  /// listing picked twice, or two options whose text is the same once
  /// trimmed/lowercased) — [lastError] says which, for the page to show.
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
