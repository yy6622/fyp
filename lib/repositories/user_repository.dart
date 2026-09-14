import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's profile document, stored at `users/{uid}`.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final bool favorited;
  final String avatarUrl;
  final String country;
  final String currencyCode;
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.favorited = false,
    this.avatarUrl = '',
    this.country = '',
    this.currencyCode = '',
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      favorited: (data['favorited'] as bool?) ?? false,
      avatarUrl: (data['avatarUrl'] as String?) ?? '',
      country: (data['country'] as String?) ?? '',
      currencyCode: (data['currencyCode'] as String?) ?? '',
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
      'favorited': false,
      'avatarUrl': '',
      'country': '',
      'currencyCode': '',
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

  Future<void> setFavorited(String uid, bool value) {
    return _users.doc(uid).update({'favorited': value});
  }

  Future<void> updateProfile(String uid, {String? name, String? phone, String? avatarUrl, String? country, String? currencyCode}) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (country != null) data['country'] = country;
    if (currencyCode != null) data['currencyCode'] = currencyCode;
    if (data.isEmpty) return Future.value();
    return _users.doc(uid).update(data);
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
