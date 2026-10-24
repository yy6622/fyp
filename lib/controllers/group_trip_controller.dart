import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/day_plan_models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/chat_attachment_service.dart';
import '../services/location_service.dart';
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
  // Saved listing first; otherwise any listing the app has for this trip's destination
  // (catalog_attractions / catalog_restaurants — including the ones AI Summarise found in
  // catalog_places / OpenStreetMap), so a real place in Firebase always shows as a card.
  CatalogAttraction? attractionForActivity(ActivityItem item) =>
      _firstWhereOrNull(_saved.attractions, (a) => _sameName(a.name, item.label)) ??
      _firstWhereOrNull(_cityAttractions, (a) => _sameName(a.name, item.label));
  CatalogRestaurant? restaurantForActivity(ActivityItem item) =>
      _firstWhereOrNull(_saved.restaurants, (r) => _sameName(r.name, item.label)) ??
      _firstWhereOrNull(_cityRestaurants, (r) => _sameName(r.name, item.label));

  /// This trip's destination's attractions / restaurants (not only saved ones), see above.
  List<CatalogAttraction> _cityAttractions = const [];
  List<CatalogRestaurant> _cityRestaurants = const [];
  String _cityKey = '';
  StreamSubscription<List<CatalogAttraction>>? _cityAttractionsSub;
  StreamSubscription<List<CatalogRestaurant>>? _cityRestaurantsSub;

  void _watchCity(String destination) {
    final key = destination.trim().toLowerCase();
    if (key == _cityKey) return;
    _cityKey = key;
    _cityAttractionsSub?.cancel();
    _cityRestaurantsSub?.cancel();
    _cityAttractions = const [];
    _cityRestaurants = const [];
    if (key.isEmpty) return;
    _cityAttractionsSub = CatalogRepository.instance.watchAttractions(destination: destination).listen((list) {
      _cityAttractions = list;
      notifyListeners();
    }, onError: (_) {});
    _cityRestaurantsSub = CatalogRepository.instance.watchRestaurants(destination: destination).listen((list) {
      _cityRestaurants = list;
      notifyListeners();
    }, onError: (_) {});
  }

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
    _markSeenForTab(value);
  }

  /// Marks [t] seen for the signed-in user the moment they're on it — so
  /// the Plan Home card's "Plan Updated"/"Expenses Updated" tags (see
  /// [Trip.planUnseenFor]/[expensesUnseenFor]) clear as soon as the
  /// member actually opens that tab, not just when they make an edit
  /// themselves. Called both from [setTab] (switching tabs within this
  /// page) and once right after the trip's first load (covers opening
  /// straight into [widget.initialTab] from a Plan Home card tap, which
  /// never goes through [setTab]).
  void _markSeenForTab(GroupTab t) {
    final uid = _uid;
    if (uid.isEmpty) return;
    if (t == GroupTab.plan) {
      TripRepository.instance.markPlanSeen(tripId, uid);
    } else if (t == GroupTab.expenses) {
      TripRepository.instance.markExpensesSeen(tripId, uid);
    }
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
    // Covers landing directly on [_tab] (the tab a Plan Home card tap
    // asked to open) without going through [setTab] — see
    // [_markSeenForTab]'s doc comment.
    _markSeenForTab(_tab);
    final me = await UserRepository.instance.fetchProfile(uid);
    _myName = me?.name ?? 'You';

    _tripSub = TripRepository.instance.watchTrip(tripId, uid).listen((trip) {
      _trip = trip;
      if (trip != null) _watchCity(trip.destination);
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
    return TripRepository.instance.updateActivityTime(tripId, dayIndex, itemId, time, actorUid: _uid);
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

  bool _sendingAttachment = false;
  bool get sendingAttachment => _sendingAttachment;

  /// Camera/Gallery attachment row — picks a photo, uploads it, then sends
  /// it as its own chat message ([TripMessage.isImage]). Returns a
  /// user-facing error string on failure, or null on success/the person
  /// just backing out of the picker (both "nothing to show" from the
  /// caller's point of view, so it doesn't distinguish them with an
  /// exception).
  Future<String?> sendImageMessage(ImageSource source) async {
    File? file;
    try {
      file = await ChatAttachmentService.instance.pick(source);
    } catch (e) {
      return 'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e';
    }
    if (file == null) return null;
    _showAttachments = false;
    _sendingAttachment = true;
    notifyListeners();
    try {
      final url = await ChatAttachmentService.instance.upload(tripId, _uid, file);
      await TripRepository.instance.sendMessage(tripId, senderId: _uid, senderName: _myName, type: 'image', imageUrl: url);
      return null;
    } catch (e) {
      return 'Could not send photo: $e';
    } finally {
      _sendingAttachment = false;
      notifyListeners();
    }
  }

  /// Location attachment row button — a one-shot current-position read
  /// (same [LocationService.getCurrentPosition] used by Account Setting's
  /// Home Airport picker and Member Location), sent as its own chat
  /// message ([TripMessage.isLocation]) rather than anything live/
  /// ongoing. Returns a user-facing error string on failure (location
  /// services off, permission denied), or null on success.
  Future<String?> sendLocationMessage() async {
    _showAttachments = false;
    notifyListeners();
    final position = await LocationService.instance.getCurrentPosition();
    if (position == null) {
      return 'Could not get your location — check that location is turned on and allowed for this app, then try again.';
    }
    await TripRepository.instance.sendMessage(
      tripId,
      senderId: _uid,
      senderName: _myName,
      type: 'location',
      lat: position.latitude,
      lng: position.longitude,
    );
    return null;
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _cityAttractionsSub?.cancel();
    _cityRestaurantsSub?.cancel();
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
/// "Guests" tab in place of "Passenger". (No Review tab — reviews were
/// removed from every hotel/attraction/restaurant surface.)
enum PlanHotelTab { detail, guests, documents }

/// Controller for [PlanHotelDetailPage].
class PlanHotelDetailController extends ChangeNotifier {
  PlanHotelTab _tab = PlanHotelTab.detail;
  PlanHotelTab get tab => _tab;
  void setTab(PlanHotelTab value) {
    _tab = value;
    notifyListeners();
  }
}
