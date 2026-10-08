import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's profile document, stored at `users/{uid}`.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final String country;
  final String currencyCode;

  /// Account Setting > Language (see LanguageService/TranslationService)
  /// — drives which language attraction/restaurant/hotel names are shown
  /// translated into. '' means "never explicitly chosen", treated the
  /// same as English (no translation shown) everywhere this is read.
  final String languageCode;

  /// IATA code of the person's chosen departure airport (e.g. "PEN"),
  /// set from Account Setting's Home Airport picker — see
  /// `location_service.dart`. Empty means "never set"; callers fall
  /// back to [kDefaultHomeAirport] (KUL) in that case rather than
  /// treating empty as its own airport.
  final String homeAirportCode;

  /// Privacy and Security's "Share Location with Group" toggle — real now,
  /// not just local UI state. When true, [lastLat]/[lastLng] (captured the
  /// moment the person turns this on, and refreshed each time they open
  /// Group Info > Member Location for a trip that has it on) are shown to
  /// the other members of any trip whose owner has turned on that trip's
  /// own Real-Time Location setting — two separate switches have to agree
  /// (the person's own privacy choice, and the trip's), matching
  /// `firestore.rules`' `users/{uid}` rule: any signed-in member can read
  /// this doc, but only its own owner can write it.
  final bool shareLocation;
  final double? lastLat;
  final double? lastLng;
  final DateTime? locationUpdatedAt;

  /// Privacy and Security's "Public Profile" switch — when true (the
  /// default, matching that switch's default-on state), tapping this
  /// user's name on a Community post opens their profile and shows the
  /// trips they've posted (see AuthorProfilePage); when false, everyone
  /// but the user themself sees a plain "this profile is private"
  /// notice there instead. Was local-only UI state before this field
  /// existed — PrivacySecurityController now reads/writes it for real.
  final bool publicProfile;

  /// Privacy and Security's "Two-Factor Authentication" switch — real now
  /// (was a local-only `_twoFactor` stub on [PrivacySecurityController]
  /// before, that reset to off every time the app restarted). Backs the
  /// admin console's User Account Report "2FA adoption" figure.
  final bool twoFactorEnabled;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatarUrl = '',
    this.country = '',
    this.currencyCode = '',
    this.languageCode = '',
    this.homeAirportCode = '',
    this.shareLocation = false,
    this.lastLat,
    this.lastLng,
    this.locationUpdatedAt,
    this.publicProfile = true,
    this.twoFactorEnabled = false,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      avatarUrl: (data['avatarUrl'] as String?) ?? '',
      country: (data['country'] as String?) ?? '',
      currencyCode: (data['currencyCode'] as String?) ?? '',
      languageCode: (data['languageCode'] as String?) ?? '',
      homeAirportCode: (data['homeAirportCode'] as String?) ?? '',
      shareLocation: (data['shareLocation'] as bool?) ?? false,
      lastLat: (data['lastLat'] as num?)?.toDouble(),
      lastLng: (data['lastLng'] as num?)?.toDouble(),
      locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
      publicProfile: (data['publicProfile'] as bool?) ?? true,
      twoFactorEnabled: (data['twoFactorEnabled'] as bool?) ?? false,
    );
  }
}

/// Reads/writes `users/{uid}` profile documents in Cloud Firestore.
class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  CollectionReference<Map<String, dynamic>> get _users => FirebaseFirestore.instance.collection('users');

  Future<void> createProfile({required String uid, required String name, required String email}) {
    return _users.doc(uid).set({
      'name': name,
      'email': email.toLowerCase(),
      'phone': '',
      'avatarUrl': '',
      'country': '',
      'currencyCode': '',
      'languageCode': '',
      'homeAirportCode': '',
      'shareLocation': false,
      'publicProfile': true,
      'twoFactorEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<AppUser?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);
  }

  Future<AppUser?> fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Future<void> updateProfile(String uid,
      {String? name,
      String? phone,
      String? avatarUrl,
      String? country,
      String? currencyCode,
      String? languageCode,
      String? homeAirportCode}) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (country != null) data['country'] = country;
    if (currencyCode != null) data['currencyCode'] = currencyCode;
    if (languageCode != null) data['languageCode'] = languageCode;
    if (homeAirportCode != null) data['homeAirportCode'] = homeAirportCode;
    if (data.isEmpty) return Future.value();
    return _users.doc(uid).update(data);
  }

  /// Flips Privacy and Security's "Share Location with Group" switch.
  /// Turning it off leaves any previously-captured [AppUser.lastLat]/
  /// [lastLng] in place but [AppUser.shareLocation]=false hides them from
  /// every Member Location page immediately — there's no need to also
  /// clear the stale coordinates for that, and clearing them would lose
  /// the "last seen" position right as it stops being updated.
  Future<void> setShareLocation(String uid, bool value) {
    return _users.doc(uid).update({'shareLocation': value});
  }

  /// Flips Privacy and Security's "Public Profile" switch — see
  /// [AppUser.publicProfile].
  Future<void> setPublicProfile(String uid, bool value) {
    return _users.doc(uid).update({'publicProfile': value});
  }

  /// Flips Privacy and Security's "Two-Factor Authentication" switch —
  /// see [AppUser.twoFactorEnabled].
  Future<void> setTwoFactorEnabled(String uid, bool value) {
    return _users.doc(uid).update({'twoFactorEnabled': value});
  }

  /// Records a fresh on-demand position read — called right when the
  /// person turns location-sharing on, and again each time they (or
  /// another member, implicitly, by opening the page) view Member
  /// Location while it's on. Never a background/periodic write.
  Future<void> updateLocation(String uid, double lat, double lng) {
    return _users.doc(uid).update({
      'lastLat': lat,
      'lastLng': lng,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Finds a user by exact email or exact display name — used by "Add
  /// Friend", which lets people search by either.
  Future<AppUser?> findByEmailOrName(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final byEmail = await _users.where('email', isEqualTo: trimmed.toLowerCase()).limit(1).get();
    if (byEmail.docs.isNotEmpty) return AppUser.fromDoc(byEmail.docs.first);
    final byName = await _users.where('name', isEqualTo: trimmed).limit(1).get();
    if (byName.docs.isNotEmpty) return AppUser.fromDoc(byName.docs.first);
    return null;
  }
}
