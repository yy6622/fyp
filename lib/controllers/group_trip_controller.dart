import 'dart:async';

import 'package:flutter/material.dart';

import '../models/day_plan_models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import 'saved_items_controller.dart';

/// Tabs of [GroupTripPage].
enum GroupTab { plan, chat, expenses, vote }

/// Controller for [GroupTripPage]. Streams the real trip document (and its
/// chat messages) from Firestore.
class GroupTripController extends ChangeNotifier {
  final String tripId;
  GroupTab _tab;
  GroupTripController({required this.tripId, GroupTab initialTab = GroupTab.plan}) : _tab = initialTab {
    _load();
    _saved.addListener(notifyListeners);
  }

  /// The trip's saved flights/hotels/attractions/restaurants — used to
  /// match an activity's plain-text label back to the real saved listing
  /// behind it (image, rating, location, price) when it was added "From
  /// Saved" in the Add Activity sheet, same idea as VoteTabController's
  /// own hotelFor/attractionFor/restaurantFor. `late` so its initializer
  /// (which reads `tripId`) runs after that field is set.
  late final SavedItemsController _saved = SavedItemsController(tripId: tripId);

  /// Matches an activity's label back to the trip's saved hotel with that
  /// exact name (case/whitespace insensitive) — best-effort: an activity
  /// typed by hand instead of picked "From Saved" just won't match
  /// anything, which the Day view treats as a plain card rather than an
  /// error. Checked in this order (hotel, then attraction, then
  /// restaurant) and stops at the first hit, since a saved item's name is
  /// only ever that one listing's.
  CatalogHotel? hotelForActivity(ActivityItem item) => _firstWhereOrNull(_saved.hotels, (h) => _sameName(h.name, item.label));
  CatalogAttraction? attractionForActivity(ActivityItem item) =>
      _firstWhereOrNull(_saved.attractions, (a) => _sameName(a.name, item.label));
  CatalogRestaurant? restaurantForActivity(ActivityItem item) =>
      _firstWhereOrNull(_saved.restaurants, (r) => _sameName(r.name, item.label));

  bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
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

  Future<void> addActivity(
    int dayIndex, {
    required String time,
    required String label,
    required String iconKey,
    String location = '',
    List<String> forMemberUids = const [],
  }) {
    return TripRepository.instance.addActivity(tripId, dayIndex,
        time: time, label: label, iconKey: iconKey, location: location, forMemberUids: forMemberUids, actorUid: _uid);
  }

  Future<void> toggleActivityVote(int dayIndex, ActivityItem item) {
    return TripRepository.instance.toggleActivityVote(tripId, dayIndex, item.id, _uid, !item.votedByMe);
  }

  Future<void> removeActivity(int dayIndex, String itemId) {
    return TripRepository.instance.removeActivity(tripId, dayIndex, itemId, actorUid: _uid);
  }

  Future<void> updateActivityTime(int dayIndex, String itemId, String time) {
    return TripRepository.instance.updateActivityTime(tripId, dayIndex, itemId, time);
  }

  Future<void> addFlight(TripFlight flight) => TripRepository.instance.addFlight(tripId, flight, actorUid: _uid);
  Future<void> removeFlight(String flightId) => TripRepository.instance.removeFlight(tripId, flightId);
  Future<void> addHotelStay(TripHotelStay stay) => TripRepository.instance.addHotelStay(tripId, stay, actorUid: _uid);
  Future<void> removeHotelStay(String stayId) => TripRepository.instance.removeHotelStay(tripId, stayId);

  Future<void> setDestination(String destination) =>
      TripRepository.instance.updateSettings(tripId, destination: destination, actorUid: _uid);
  Future<void> setDates(DateTime start, DateTime end) =>
      TripRepository.instance.updateSettings(tripId, startDate: start, endDate: end, actorUid: _uid);
  Future<void> setBudget(double budgetPerPerson) =>
      TripRepository.instance.updateSettings(tripId, budgetPerPerson: budgetPerPerson, actorUid: _uid);

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
    _saved.removeListener(notifyListeners);
    _saved.dispose();
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

/// Tabs of [PlanHotelDetailPage] — mirrors [PlanFlightTab], with a
/// "Guests" tab in place of "Passenger" and an optional trailing "Review"
/// tab (only shown when the stay has a real catalog hotelId).
enum PlanHotelTab { detail, guests, documents, review }

/// Controller for [PlanHotelDetailPage].
class PlanHotelDetailController extends ChangeNotifier {
  PlanHotelTab _tab = PlanHotelTab.detail;
  PlanHotelTab get tab => _tab;
  void setTab(PlanHotelTab value) {
    _tab = value;
    notifyListeners();
  }
}
