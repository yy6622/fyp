import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/booking_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/friends_repository.dart';
import '../repositories/user_repository.dart';
import '../services/attraction_report_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/places_api_service.dart';

/// Controller for [ProfilePage] — loads/streams the signed-in user's
/// Firestore profile doc.
class ProfileController extends ChangeNotifier {
  AppUser? _profile;
  AppUser? get profile => _profile;

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

  List<SentFriendRequest> _sentRequests = [];
  List<SentFriendRequest> get sentRequests => _sentRequests;

  bool _loading = true;
  bool get loading => _loading;

  final TextEditingController search = TextEditingController();

  StreamSubscription<List<FriendEntry>>? _friendsSub;
  StreamSubscription<Set<String>>? _blockedSub;
  StreamSubscription<List<SentFriendRequest>>? _sentSub;

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
      _sentSub = FriendsRepository.instance.watchSentRequests(uid).listen((list) {
        _sentRequests = list;
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

  /// FR07: removes the mutual friendship entirely (both sides), unlike
  /// [toggleBlock] which only hides/mutes without undoing the friendship.
  Future<void> removeFriend(FriendEntry friend) {
    return FriendsRepository.instance.removeFriend(uid: _uid, friendUid: friend.uid);
  }

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

  /// Looks [query] up (email or username) and sends them a friend
  /// request — see [FriendRequestOutcome] for what can come back.
  Future<FriendRequestOutcome> sendFriendRequest(String query) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const FriendRequestOutcome(status: FriendRequestStatus.noMatch);
    final me = await UserRepository.instance.fetchProfile(uid);
    return FriendsRepository.instance.sendFriendRequest(myUid: uid, myName: me?.name ?? 'Traveller', query: query);
  }

  Future<void> resendRequest(SentFriendRequest request) async {
    final me = await UserRepository.instance.fetchProfile(_uid);
    await FriendsRepository.instance.resendFriendRequest(
      fromUid: _uid,
      fromName: me?.name ?? 'Traveller',
      toUid: request.toUid,
      toName: request.toName,
    );
  }

  Future<void> cancelRequest(SentFriendRequest request) {
    return FriendsRepository.instance.cancelFriendRequest(fromUid: _uid, toUid: request.toUid);
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _blockedSub?.cancel();
    _sentSub?.cancel();
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

  // Real "Filter" behaviour for the History list (was previously an
  // unwired icon next to a hardcoded "March" label that had nothing to
  // do with the bookings actually shown). watchBookings already orders
  // newest-first from Firestore, so oldest-first is just the reverse of
  // that same list client-side — no extra query needed.
  bool _oldestFirst = false;
  bool get oldestFirst => _oldestFirst;
  void setOldestFirst(bool v) {
    _oldestFirst = v;
    notifyListeners();
  }

  List<BookingEntry> _sorted(List<BookingEntry> list) => _oldestFirst ? list.reversed.toList() : list;

  List<BookingEntry> _flightBookings = [];
  List<BookingEntry> get flightBookings => _sorted(_flightBookings);
  bool _loadingFlight = true;
  bool get loadingFlight => _loadingFlight;

  List<BookingEntry> _hotelBookings = [];
  List<BookingEntry> get hotelBookings => _sorted(_hotelBookings);
  bool _loadingHotel = true;
  bool get loadingHotel => _loadingHotel;

  List<BookingEntry> _insuranceBookings = [];
  List<BookingEntry> get insuranceBookings => _sorted(_insuranceBookings);
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

/// Controller for [ReportAttractionPage]. Real Firestore-backed submission
/// (CatalogRepository.submitAttractionReport writes to
/// `attraction_reports/{id}`) with a real Storage-uploaded photo
/// (AttractionReportService) — previously `mediaAdded` was just a bool
/// toggle with no actual image picker/upload behind it, and the page's
/// own `_submit()` never wrote anything at all: tapping Submit just
/// showed a SnackBar and popped the page.
class ReportAttractionController extends ChangeNotifier {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  File? _photo;
  File? get photo => _photo;
  bool get mediaAdded => _photo != null;

  bool _submitting = false;
  bool get submitting => _submitting;

  Future<void> pickPhoto(ImageSource source) async {
    final file = await AttractionReportService.instance.pick(source);
    if (file == null) return;
    _photo = file;
    notifyListeners();
  }

  bool _locating = false;
  bool get locating => _locating;

  /// Fills [locationController] from the device's current GPS position
  /// — the tappable location icon next to the Location field, so a
  /// rider standing at the spot doesn't have to type the address by
  /// hand. Gets a real position via [LocationService.getCurrentPosition]
  /// (same permission dance used elsewhere in the app, e.g. Privacy and
  /// Security's "Share Location" toggle) then reverse-geocodes it via
  /// [PlacesApiService.reverseGeocode]; falls back to raw coordinates if
  /// reverse geocoding itself fails but the position was found, so a
  /// flaky Nominatim request doesn't throw away a real GPS fix. Returns
  /// null on success (the field is already updated) or an error message
  /// for the page to show in a SnackBar; never throws.
  Future<String?> useCurrentLocation() async {
    _locating = true;
    notifyListeners();
    try {
      final position = await LocationService.instance.getCurrentPosition();
      if (position == null) {
        return "Couldn't get your current location. Check that location services and permission are enabled.";
      }
      final label = await PlacesApiService.instance.reverseGeocode(position.latitude, position.longitude);
      locationController.text =
          label ?? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      return null;
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  void removePhoto() {
    _photo = null;
    notifyListeners();
  }

  /// The first validation problem found, or null once the report has
  /// everything it needs to submit.
  String? validate() {
    if (nameController.text.trim().isEmpty) return 'Please enter the attraction name.';
    if (locationController.text.trim().isEmpty) return 'Please add a location.';
    return null;
  }

  /// Uploads the photo (if any) and writes the real report doc. Returns
  /// null on success, or an error message on failure — the page decides
  /// how to show it rather than this controller holding UI state like a
  /// SnackBar.
  Future<String?> submit() async {
    final error = validate();
    if (error != null) return error;
    final user = AuthService.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return 'You need to be signed in to submit a report.';

    _submitting = true;
    notifyListeners();
    try {
      String photoUrl = '';
      final photo = _photo;
      if (photo != null) {
        photoUrl = await AttractionReportService.instance.upload(uid, photo);
      }
      final authorName =
          user?.displayName?.trim().isNotEmpty == true ? user!.displayName!.trim() : (user?.email ?? 'Voya user');
      await CatalogRepository.instance.submitAttractionReport(
        authorId: uid,
        authorName: authorName,
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        photoUrl: photoUrl,
      );
      return null;
    } catch (e) {
      return 'Could not submit your report: $e';
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}

/// Controller for [PrivacySecurityPage]. [shareLocation] is real — it
/// streams `users/{uid}.shareLocation` and flipping it on captures one
/// real device position (see [LocationService.getCurrentPosition]) so
/// Group Info > Member Location has something to show right away instead
/// of an empty "last updated: never". [profileVisible] is also real now
/// (streams/writes `users/{uid}.publicProfile` — see
/// [AppUser.publicProfile] and AuthorProfilePage, which is what actually
/// gates on it). [twoFactor] is real too now (streams/writes
/// `users/{uid}.twoFactorEnabled` — see [AppUser.twoFactorEnabled]); it
/// used to be local-only UI state that reset to off on every app
/// restart, which is also why the admin console's User Account Report
/// couldn't show a real 2FA-adoption figure before this.
class PrivacySecurityController extends ChangeNotifier {
  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  bool _profileVisible = true;
  bool get profileVisible => _profileVisible;

  bool _shareLocation = false;
  bool get shareLocation => _shareLocation;
  bool _locationLoading = true;
  bool get locationLoading => _locationLoading;

  bool _twoFactor = false;
  bool get twoFactor => _twoFactor;

  StreamSubscription<AppUser?>? _sub;

  PrivacySecurityController() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _sub = UserRepository.instance.watchProfile(uid).listen((user) {
        _shareLocation = user?.shareLocation ?? false;
        _profileVisible = user?.publicProfile ?? true;
        _twoFactor = user?.twoFactorEnabled ?? false;
        _locationLoading = false;
        notifyListeners();
      });
    } else {
      _locationLoading = false;
    }
  }

  Future<void> setProfileVisible(bool v) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    // Optimistic, same pattern as setShareLocation below — the stream
    // above reconciles once the write lands.
    _profileVisible = v;
    notifyListeners();
    await UserRepository.instance.setPublicProfile(uid, v);
  }

  Future<void> setShareLocation(bool v) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    // Optimistic — the Firestore stream above will reconcile this once
    // the write lands, same as every other switch in this app.
    _shareLocation = v;
    notifyListeners();
    await UserRepository.instance.setShareLocation(uid, v);
    if (!v) return;
    final position = await LocationService.instance.getCurrentPosition();
    if (position != null) {
      await UserRepository.instance.updateLocation(uid, position.latitude, position.longitude);
    }
  }

  Future<void> setTwoFactor(bool v) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    // Optimistic, same pattern as setShareLocation/setProfileVisible above.
    _twoFactor = v;
    notifyListeners();
    await UserRepository.instance.setTwoFactorEnabled(uid, v);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
