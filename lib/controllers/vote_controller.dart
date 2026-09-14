import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';

/// Controller for [VoteTab] — streams every real vote/poll created for a
/// trip (`trips/{tripId}/votes`).
class VoteTabController extends ChangeNotifier {
  final String tripId;
  VoteTabController({required this.tripId}) {
    _sub = TripRepository.instance.watchVotes(tripId).listen((v) {
      _votes = v;
      _loading = false;
      notifyListeners();
    });
  }

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  List<TripVote> _votes = [];
  List<TripVote> get votes => _votes;

  bool _loading = true;
  bool get loading => _loading;

  StreamSubscription<List<TripVote>>? _sub;

  bool votedByMe(VoteOption option) => option.votedBy.contains(_uid);

  Future<void> castVote(TripVote vote, String optionId) {
    return TripRepository.instance.castVote(tripId, vote, optionId, _uid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Controller for [CreateVotePage] — writes a real vote/poll document.
class CreateVoteController extends ChangeNotifier {
  final String tripId;
  CreateVoteController({required this.tripId});

  final TextEditingController titleController = TextEditingController();
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowAddOptions = true;
  bool get allowAddOptions => _allowAddOptions;

  bool _allowMultipleChoice = false;
  bool get allowMultipleChoice => _allowMultipleChoice;

  bool _saving = false;
  bool get saving => _saving;

  void addOption() {
    optionControllers.add(TextEditingController());
    notifyListeners();
  }

  void removeOptionAt(int index) {
    optionControllers.removeAt(index).dispose();
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

  /// Returns true if the vote was created (false if the title/options
  /// weren't filled in).
  Future<bool> create() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
    final title = titleController.text.trim();
    final options = optionControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (title.isEmpty || options.length < 2) return false;
    _saving = true;
    notifyListeners();
    try {
      await TripRepository.instance.createVote(
        tripId,
        title: title,
        options: options,
        allowAddOptions: _allowAddOptions,
        allowMultipleChoice: _allowMultipleChoice,
        createdBy: uid,
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
    for (final c in optionControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
