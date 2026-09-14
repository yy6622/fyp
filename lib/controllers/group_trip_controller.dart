import 'dart:async';

import 'package:flutter/material.dart';

import '../models/day_plan_models.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

/// Tabs of [GroupTripPage].
enum GroupTab { plan, chat, expenses, vote }

/// Controller for [GroupTripPage]. Streams the real trip document (and its
/// chat messages) from Firestore.
class GroupTripController extends ChangeNotifier {
  final String tripId;
  GroupTab _tab;
  GroupTripController({required this.tripId, GroupTab initialTab = GroupTab.plan}) : _tab = initialTab {
    _load();
  }

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  GroupTab get tab => _tab;
  void setTab(GroupTab value) {
    _tab = value;
    notifyListeners();
  }

  Trip? _trip;
  Trip? get trip => _trip;
  bool _loading = true;
  bool get loading => _loading;

  List<DayPlan> get days => _trip?.days ?? const [];

  String _myName = '';

  List<TripMessage> _messages = [];
  List<TripMessage> get messages => _messages;

  final TextEditingController messageController = TextEditingController();

  StreamSubscription<Trip?>? _tripSub;
  StreamSubscription<List<TripMessage>>? _messagesSub;

  Future<void> _load() async {
    final uid = _uid;
    if (uid.isEmpty) {
      _loading = false;
      notifyListeners();
      return;
    }
    final me = await UserRepository.instance.fetchProfile(uid);
    _myName = me?.name ?? 'You';

    _tripSub = TripRepository.instance.watchTrip(tripId, uid).listen((trip) {
      _trip = trip;
      _loading = false;
      notifyListeners();
    });
    _messagesSub = TripRepository.instance.watchMessages(tripId).listen((msgs) {
      _messages = msgs;
      notifyListeners();
    });
  }

  /// Which page of the Plan tab's Overview/Day pager is showing.
  /// -1 = Overview, 0..days.length-1 = that day (0-indexed).
  int _planIndex = -1;
  int get planIndex => _planIndex;
  void setPlanIndex(int value) {
    _planIndex = value;
    notifyListeners();
  }

  bool _showAttachments = false;
  bool get showAttachments => _showAttachments;
  void toggleAttachments() {
    _showAttachments = !_showAttachments;
    notifyListeners();
  }

  Future<void> addActivity(int dayIndex, {required String time, required String label, required String iconKey}) {
    return TripRepository.instance.addActivity(tripId, dayIndex, time: time, label: label, iconKey: iconKey);
  }

  Future<void> toggleActivityVote(int dayIndex, ActivityItem item) {
    return TripRepository.instance.toggleActivityVote(tripId, dayIndex, item.id, _uid, !item.votedByMe);
  }

  Future<void> addFlight(TripFlight flight) => TripRepository.instance.addFlight(tripId, flight);
  Future<void> addHotelStay(TripHotelStay stay) => TripRepository.instance.addHotelStay(tripId, stay);

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    messageController.clear();
    await TripRepository.instance.sendMessage(tripId, senderId: _uid, senderName: _myName, text: text);
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _messagesSub?.cancel();
    messageController.dispose();
    super.dispose();
  }
}

/// Tabs of [PlanFlightDetailPage].
enum PlanFlightTab { detail, passenger, documents }

/// Controller for [PlanFlightDetailPage].
class PlanFlightDetailController extends ChangeNotifier {
  PlanFlightTab _tab = PlanFlightTab.detail;
  PlanFlightTab get tab => _tab;
  void setTab(PlanFlightTab value) {
    _tab = value;
    notifyListeners();
  }
}
