import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/booking_repository.dart';
import '../repositories/friends_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

/// Controller for [ProfilePage] — loads/streams the signed-in user's
/// Firestore profile doc.
class ProfileController extends ChangeNotifier {
  AppUser? _profile;
  AppUser? get profile => _profile;
  bool get favorited => _profile?.favorited ?? false;

  bool _loading = true;
  bool get loading => _loading;

  StreamSubscription<AppUser?>? _sub;

  ProfileController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _sub = UserRepository.instance.watchProfile(uid).listen((user) {
        _profile = user;
        _loading = false;
        notifyListeners();
      });
    } else {
      _loading = false;
    }
  }

  void toggleFavorited() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    UserRepository.instance.setFavorited(uid, !favorited);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Controller for [FriendsPage] — streams `users/{uid}/friends` and
/// `users/{uid}/blocked` from Firestore.
class FriendsController extends ChangeNotifier {
  List<FriendEntry> _friends = [];
  List<FriendEntry> get friends => _friends;
  Set<String> _blockedIds = {};

  bool _loading = true;
  bool get loading => _loading;

  final TextEditingController search = TextEditingController();

  StreamSubscription<List<FriendEntry>>? _friendsSub;
  StreamSubscription<Set<String>>? _blockedSub;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  FriendsController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _friendsSub = FriendsRepository.instance.watchFriends(uid).listen((list) {
        _friends = list;
        _loading = false;
        notifyListeners();
      });
      _blockedSub = FriendsRepository.instance.watchBlockedIds(uid).listen((ids) {
        _blockedIds = ids;
        notifyListeners();
      });
    } else {
      _loading = false;
    }
  }

  List<FriendEntry> get visible {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends.where((f) => f.name.toLowerCase().contains(query)).toList();
  }

  bool isBlocked(String uid) => _blockedIds.contains(uid);

  void refreshSearch() => notifyListeners();

  /// Returns true if [friend] is now blocked (false if just unblocked).
  Future<bool> toggleBlock(FriendEntry friend) async {
    final nowBlocked = !isBlocked(friend.uid);
    await FriendsRepository.instance.setBlocked(
      uid: _uid,
      friendUid: friend.uid,
      friendName: friend.name,
      blocked: nowBlocked,
    );
    return nowBlocked;
  }

  /// Looks [query] up (email or username) and adds them as a friend.
  /// Returns the matched friend's name, or null if nobody matched.
  Future<String?> addFriend(String query) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return null;
    final me = await UserRepository.instance.fetchProfile(uid);
    return FriendsRepository.instance.addFriend(myUid: uid, myName: me?.name ?? 'Traveller', query: query);
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _blockedSub?.cancel();
    search.dispose();
    super.dispose();
  }
}

/// Controller for [BlockedUsersPage].
class BlockedUsersController extends ChangeNotifier {
  List<FriendEntry> _blocked = [];
  List<FriendEntry> get blocked => _blocked;

  bool _loading = true;
  bool get loading => _loading;

  StreamSubscription<List<FriendEntry>>? _sub;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  BlockedUsersController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _sub = FriendsRepository.instance.watchBlocked(uid).listen((list) {
        _blocked = list;
        _loading = false;
        notifyListeners();
      });
    } else {
      _loading = false;
    }
  }

  Future<void> unblock(FriendEntry friend) {
    return FriendsRepository.instance.setBlocked(
      uid: _uid,
      friendUid: friend.uid,
      friendName: friend.name,
      blocked: false,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Controller for [ChatSettingPage].
class ChatSettingController extends ChangeNotifier {
  bool _saveMedia = true;
  bool get saveMedia => _saveMedia;

  void setSaveMedia(bool v) {
    _saveMedia = v;
    notifyListeners();
  }
}

/// Plans available to pick from on [SelectPlanPage], and each one's own
/// [TravelPreferencesPage] values.
const List<String> travelPlans = ['Japan Trips', 'Korea Trips'];

const Map<String, Map<String, String>> travelPreferencesByPlan = {
  'Japan Trips': {
    'Travel Style': 'Adventure',
    'Budget': 'RM 2,000 - RM 5,000',
    'Accommodation': 'Hotel',
    'Food Preference': 'No restrictions',
    'Interests': 'Culture, Food, Nature',
  },
  'Korea Trips': {
    'Travel Style': 'Relaxation',
    'Budget': 'RM 1,500 - RM 3,500',
    'Accommodation': 'Homestay',
    'Food Preference': 'Halal',
    'Interests': 'Shopping, K-Pop, Food',
  },
};

/// Which tab of [HistoryPage] is showing.
enum HistoryTab { flight, hotel, insurance }

/// Controller for [HistoryPage]. All three tabs stream real purchases from
/// `users/{uid}/bookings` (written by the Insurance payment flow, and now
/// by the flight/hotel "Select Flight"/"Select Hotel" confirm actions too
/// — see [BookingBar] in detail_widgets.dart) — nothing here is a
/// placeholder anymore.
class HistoryController extends ChangeNotifier {
  HistoryTab _tab = HistoryTab.flight;
  HistoryTab get tab => _tab;

  List<BookingEntry> _flightBookings = [];
  List<BookingEntry> get flightBookings => _flightBookings;
  bool _loadingFlight = true;
  bool get loadingFlight => _loadingFlight;

  List<BookingEntry> _hotelBookings = [];
  List<BookingEntry> get hotelBookings => _hotelBookings;
  bool _loadingHotel = true;
  bool get loadingHotel => _loadingHotel;

  List<BookingEntry> _insuranceBookings = [];
  List<BookingEntry> get insuranceBookings => _insuranceBookings;
  bool _loadingInsurance = true;
  bool get loadingInsurance => _loadingInsurance;

  StreamSubscription<List<BookingEntry>>? _flightSub;
  StreamSubscription<List<BookingEntry>>? _hotelSub;
  StreamSubscription<List<BookingEntry>>? _insuranceSub;

  HistoryController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _flightSub = BookingRepository.instance.watchBookings(uid, type: 'flight').listen((list) {
        _flightBookings = list;
        _loadingFlight = false;
        notifyListeners();
      });
      _hotelSub = BookingRepository.instance.watchBookings(uid, type: 'hotel').listen((list) {
        _hotelBookings = list;
        _loadingHotel = false;
        notifyListeners();
      });
      _insuranceSub = BookingRepository.instance.watchBookings(uid, type: 'insurance').listen((list) {
        _insuranceBookings = list;
        _loadingInsurance = false;
        notifyListeners();
      });
    } else {
      _loadingFlight = false;
      _loadingHotel = false;
      _loadingInsurance = false;
    }
  }

  void setTab(HistoryTab tab) {
    _tab = tab;
    notifyListeners();
  }

  @override
  void dispose() {
    _flightSub?.cancel();
    _hotelSub?.cancel();
    _insuranceSub?.cancel();
    super.dispose();
  }
}

/// Controller for [ReportAttractionPage].
class ReportAttractionController extends ChangeNotifier {
  bool _mediaAdded = false;
  bool get mediaAdded => _mediaAdded;

  final TextEditingController locationController = TextEditingController();

  void toggleMediaAdded() {
    _mediaAdded = !_mediaAdded;
    notifyListeners();
  }

  @override
  void dispose() {
    locationController.dispose();
    super.dispose();
  }
}

/// Controller for [PrivacySecurityPage].
class PrivacySecurityController extends ChangeNotifier {
  bool _profileVisible = true;
  bool get profileVisible => _profileVisible;

  bool _shareLocation = true;
  bool get shareLocation => _shareLocation;

  bool _twoFactor = false;
  bool get twoFactor => _twoFactor;

  void setProfileVisible(bool v) {
    _profileVisible = v;
    notifyListeners();
  }

  void setShareLocation(bool v) {
    _shareLocation = v;
    notifyListeners();
  }

  void setTwoFactor(bool v) {
    _twoFactor = v;
    notifyListeners();
  }
}
