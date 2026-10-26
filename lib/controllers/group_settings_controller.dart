import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';

/// Controller for [ExportItineraryPage]. Streams the real trip doc and its
/// expenses so the Export button can build an actual PDF (ItineraryExportService)
/// from the real day-by-day plan/flights/hotels/expenses — this used to just
/// show a fake "Itinerary exported as PDF" SnackBar with nothing behind it.
class ExportItineraryController extends ChangeNotifier {
  final String tripId;
  ExportItineraryController({required this.tripId}) {
    _tripSub = TripRepository.instance.watchTrip(tripId, AuthService.instance.currentUser?.uid ?? '').listen((trip) {
      _trip = trip;
      notifyListeners();
    });
    _expensesSub = TripRepository.instance.watchExpenses(tripId).listen((list) {
      _expenses = list;
      notifyListeners();
    });
  }

  String _format = 'PDF';
  String get format => _format;

  Trip? _trip;
  Trip? get trip => _trip;
  List<TripExpense> _expenses = [];
  List<TripExpense> get expenses => _expenses;

  StreamSubscription<Trip?>? _tripSub;
  StreamSubscription<List<TripExpense>>? _expensesSub;

  void setFormat(String value) {
    _format = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _expensesSub?.cancel();
    super.dispose();
  }
}

/// Controller for [GroupSettingPage] — streams and updates the real trip
/// document's name/about/notification settings.
class GroupSettingController extends ChangeNotifier {
  final String tripId;
  GroupSettingController({required this.tripId}) {
    _sub = TripRepository.instance.watchTrip(tripId, AuthService.instance.currentUser?.uid ?? '').listen((trip) {
      _trip = trip;
      if (trip != null) {
        nameController.text = trip.name;
        aboutController.text = trip.about;
      }
      notifyListeners();
    });
  }

  Trip? _trip;
  Trip? get trip => _trip;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  /// Real-Time Location affects every member's privacy, not just the
  /// toggler's own — so only the trip owner may flip it.
  bool get isOwner => _trip != null && _trip!.ownerId.isNotEmpty && _trip!.ownerId == _uid;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();

  StreamSubscription<Trip?>? _sub;

  // Per-member now (see Trip.pinChatFor's doc comment) — always read/write
  // the signed-in person's OWN entry, never the whole map.
  bool get pinChat => _trip?.pinChatFor(_uid) ?? false;
  bool get realTimeLocation => _trip?.realTimeLocation ?? false;
  String get notificationOption => _trip?.notificationOptionFor(_uid) ?? 'All Messages';

  void setPinChat(bool v) => TripRepository.instance.setPinChatFor(tripId, _uid, v);
  void setRealTimeLocation(bool v) => TripRepository.instance.updateSettings(tripId, realTimeLocation: v);
  void setNotificationOption(String v) => TripRepository.instance.setNotificationOptionFor(tripId, _uid, v);

  Future<void> saveName(String name) {
    if (name.trim().isEmpty) return Future.value();
    return TripRepository.instance.updateSettings(tripId, name: name.trim(), actorUid: _uid);
  }

  Future<void> saveAbout(String about) {
    return TripRepository.instance.updateSettings(tripId, about: about.trim(), actorUid: _uid);
  }

  Future<void> saveCoverImage(String url) {
    return TripRepository.instance.updateSettings(tripId, coverImage: url, actorUid: _uid);
  }

  Future<void> leaveGroup() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return Future.value();
    return TripRepository.instance.leaveTrip(tripId, uid);
  }

  /// FR12 — permanently deletes the whole group. Only [isOwner] should
  /// ever be able to reach this from the UI; [TripRepository.deleteTrip]
  /// double-checks ownership itself (and firestore.rules triple-checks it
  /// server-side), so this never silently fails open even if a UI check
  /// is ever missed.
  Future<void> deleteGroup() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return Future.value();
    return TripRepository.instance.deleteTrip(tripId, uid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    nameController.dispose();
    aboutController.dispose();
    super.dispose();
  }
}
