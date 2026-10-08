import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';

/// Controller for [ExportItineraryPage]. The export format choice is local
/// UI state; actually generating a PDF/image file is a real feature this
/// project doesn't build (no PDF-rendering library wired in) — the button
/// stays a placeholder, same as e.g. the AI-optimise action elsewhere.
class ExportItineraryController extends ChangeNotifier {
  String _format = 'PDF';
  String get format => _format;

  void setFormat(String value) {
    _format = value;
    notifyListeners();
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

  bool get muteChat => _trip?.muteChat ?? false;
  bool get pinChat => _trip?.pinChat ?? false;
  bool get realTimeLocation => _trip?.realTimeLocation ?? false;
  String get notificationOption => _trip?.notificationOption ?? 'All Messages';

  void setMuteChat(bool v) => TripRepository.instance.updateSettings(tripId, muteChat: v);
  void setPinChat(bool v) => TripRepository.instance.updateSettings(tripId, pinChat: v);
  void setRealTimeLocation(bool v) => TripRepository.instance.updateSettings(tripId, realTimeLocation: v);
  void setNotificationOption(String v) => TripRepository.instance.updateSettings(tripId, notificationOption: v);

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

  @override
  void dispose() {
    _sub?.cancel();
    nameController.dispose();
    aboutController.dispose();
    super.dispose();
  }
}
