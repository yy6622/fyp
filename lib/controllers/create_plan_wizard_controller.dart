import 'dart:io';

import 'package:flutter/material.dart';

import '../repositories/friends_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/places_api_service.dart';
import '../services/trip_cover_service.dart';

/// Controller for [CreatePlanWizard] — the 3-step "New Plan" wizard. Ends
/// by writing a real `trips/{tripId}` document via [TripRepository].
class CreatePlanWizardController extends ChangeNotifier {
  int _step = 0;
  int get step => _step;

  final TextEditingController tripNameController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  String ownerName = 'You';

  // Optional — picked on Step 1 ("Basic Trip Information"). Left null when
  // the person skips it, in which case createTrip() fetches a real photo
  // of [destinationController]'s destination instead (see
  // PlacesApiService.destinationPhoto) rather than leaving the group with
  // no photo at all.
  File? coverImage;

  void setCoverImage(File? file) {
    coverImage = file;
    notifyListeners();
  }

  /// Friends added as fellow travellers — the signed-in user is always the
  /// (implicit) owner and isn't in this list.
  final List<FriendEntry> travellers = [];

  double _budget = 3000;
  double get budget => _budget;

  final Set<String> interests = {};

  static const interestOptions = [
    'Beach', 'City', 'Nature', 'Food', 'Adventure', 'Culture', 'Shopping', 'Nightlife', 'Relaxation',
  ];

  bool _creating = false;
  bool get creating => _creating;

  CreatePlanWizardController() {
    _loadOwnerName();
  }

  Future<void> _loadOwnerName() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final me = await UserRepository.instance.fetchProfile(uid);
    if (me != null && me.name.isNotEmpty) {
      ownerName = me.name;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    _step = step;
    notifyListeners();
  }

  void back() {
    if (_step > 0) {
      _step--;
      notifyListeners();
    }
  }

  void setDestination(String value) {
    destinationController.text = value;
    notifyListeners();
  }

  void setStartDate(DateTime date) {
    startDate = date;
    if (endDate != null && endDate!.isBefore(date)) endDate = date;
    notifyListeners();
  }

  void setEndDate(DateTime date) {
    endDate = date;
    notifyListeners();
  }

  void addTraveller(FriendEntry friend) {
    if (travellers.any((t) => t.uid == friend.uid)) return;
    travellers.add(friend);
    notifyListeners();
  }

  void removeTravellerAt(int index) {
    travellers.removeAt(index);
    notifyListeners();
  }

  void setBudget(double value) {
    _budget = value;
    notifyListeners();
  }

  void toggleInterest(String label) {
    if (interests.contains(label)) {
      interests.remove(label);
    } else {
      interests.add(label);
    }
    notifyListeners();
  }

  /// Writes the real trip document and returns its id.
  Future<String> createTrip() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    _creating = true;
    notifyListeners();
    try {
      final start = startDate ?? DateTime.now();
      final end = endDate ?? start.add(const Duration(days: 6));
      final destination = destinationController.text.trim();
      // No photo of their own — look one up for the destination so the
      // group still gets a real, relevant cover instead of a generic
      // stock photo. Done before creating the doc so it can go straight
      // into the initial write (no second update needed for this path).
      final fetchedCoverImage = coverImage == null ? await PlacesApiService.instance.destinationPhoto(destination) : null;
      final tripId = await TripRepository.instance.createTrip(
        ownerId: uid,
        ownerName: ownerName,
        name: tripNameController.text.trim(),
        destination: destination,
        startDate: start,
        endDate: end,
        budgetPerPerson: _budget,
        interests: interests.toList(),
        extraMembers: {for (final t in travellers) t.uid: t.name},
        coverImage: fetchedCoverImage,
      );
      // A photo of their own — uploaded after creation since the storage
      // path is keyed by tripId, which doesn't exist until the doc does.
      final localCover = coverImage;
      if (localCover != null) {
        try {
          final url = await TripCoverService.instance.upload(tripId, localCover);
          await TripRepository.instance.updateSettings(tripId, coverImage: url);
        } catch (_) {
          // The trip itself was created fine — losing the custom photo
          // isn't worth failing trip creation over. It keeps whatever
          // createTrip wrote (the destination photo, or the generic
          // fallback) and the person can set a photo from Group Setting.
        }
      }
      return tripId;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    tripNameController.dispose();
    destinationController.dispose();
    super.dispose();
  }
}
