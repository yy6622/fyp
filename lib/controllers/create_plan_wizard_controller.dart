import 'dart:io';

import 'package:flutter/material.dart';

import '../repositories/friends_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/places_api_service.dart';
import '../services/trip_cover_service.dart';

class CreatePlanWizardController extends ChangeNotifier {
  int _step = 0;
  int get step => _step;

  final TextEditingController tripNameController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  String ownerName = 'You';

  File? coverImage;

  void setCoverImage(File? file) {
    coverImage = file;
    notifyListeners();
  }

  final List<FriendEntry> travellers = [];

  double _budget = 3000;
  double get budget => _budget;

  final Set<String> interests = {};

  static const interestOptions = [
    'Beach', 'City', 'Nature', 'Food', 'Adventure', 'Culture', 'Shopping', 'Nightlife', 'Relaxation',
  ];

  bool _creating = false;
  bool _disposed = false;
  bool get creating => _creating;

  CreatePlanWizardController() {
    _loadOwnerName();
  }

  Future<void> _loadOwnerName() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final me = await UserRepository.instance.fetchProfile(uid);
    if (_disposed) return;
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

  Future<String> createTrip() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    _creating = true;
    notifyListeners();
    try {
      final start = startDate ?? DateTime.now();
      final end = endDate ?? start.add(const Duration(days: 6));
      final destination = destinationController.text.trim();
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
      final localCover = coverImage;
      if (localCover != null) {
        try {
          final url = await TripCoverService.instance.upload(tripId, localCover);
          await TripRepository.instance.updateSettings(tripId, coverImage: url);
        } catch (_) {
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
    _disposed = true;
    tripNameController.dispose();
    destinationController.dispose();
    super.dispose();
  }
}
