import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final String country;
  final String currencyCode;

  final String homeAirportCode;

  final bool shareLocation;
  final double? lastLat;
  final double? lastLng;
  final DateTime? locationUpdatedAt;

  final bool publicProfile;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatarUrl = '',
    this.country = '',
    this.currencyCode = '',
    this.homeAirportCode = '',
    this.shareLocation = false,
    this.lastLat,
    this.lastLng,
    this.locationUpdatedAt,
    this.publicProfile = true,
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
      homeAirportCode: (data['homeAirportCode'] as String?) ?? '',
      shareLocation: (data['shareLocation'] as bool?) ?? false,
      lastLat: (data['lastLat'] as num?)?.toDouble(),
      lastLng: (data['lastLng'] as num?)?.toDouble(),
      locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
      publicProfile: (data['publicProfile'] as bool?) ?? true,
    );
  }
}

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
      'homeAirportCode': '',
      'shareLocation': false,
      'publicProfile': true,
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

  Future<void> deleteProfile(String uid) => _users.doc(uid).delete();

  /// True when an admin has suspended this account in the console (FR96).
  Future<bool> isSuspended(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      final status = (doc.data()?['status'] as String?)?.trim().toLowerCase();
      return status == 'suspended' || status == 'blocked';
    } catch (_) {
      return false;
    }
  }

  Future<void> updateProfile(String uid,
      {String? name,
      String? phone,
      String? avatarUrl,
      String? country,
      String? currencyCode,
      String? homeAirportCode}) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (country != null) data['country'] = country;
    if (currencyCode != null) data['currencyCode'] = currencyCode;
    if (homeAirportCode != null) data['homeAirportCode'] = homeAirportCode;
    if (data.isEmpty) return Future.value();
    return _users.doc(uid).update(data);
  }

  Future<void> setShareLocation(String uid, bool value) {
    return _users.doc(uid).update({'shareLocation': value});
  }

  Future<void> setPublicProfile(String uid, bool value) {
    return _users.doc(uid).update({'publicProfile': value});
  }

  Future<void> updateLocation(String uid, double lat, double lng) {
    return _users.doc(uid).update({
      'lastLat': lat,
      'lastLng': lng,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

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
