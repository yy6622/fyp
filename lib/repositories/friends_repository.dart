import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_repository.dart';

/// One row in a friends or blocked-users list.
class FriendEntry {
  final String uid;
  final String name;
  const FriendEntry({required this.uid, required this.name});
}

/// Reads/writes the `users/{uid}/friends` and `users/{uid}/blocked`
/// subcollections.
class FriendsRepository {
  FriendsRepository._();
  static final FriendsRepository instance = FriendsRepository._();

  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('friends');

  CollectionReference<Map<String, dynamic>> _blockedOf(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('blocked');

  List<FriendEntry> _toEntries(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => FriendEntry(uid: d.id, name: (d.data()['name'] as String?) ?? '')).toList();

  Stream<List<FriendEntry>> watchFriends(String uid) =>
      _friendsOf(uid).orderBy('name').snapshots().map(_toEntries);

  Stream<List<FriendEntry>> watchBlocked(String uid) =>
      _blockedOf(uid).orderBy('name').snapshots().map(_toEntries);

  Stream<Set<String>> watchBlockedIds(String uid) =>
      _blockedOf(uid).snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());

  /// Looks [query] up by email/name and, if a match is found (and it isn't
  /// yourself), adds each other as friends. Returns the matched friend's
  /// name on success, or null if nobody matched.
  Future<String?> addFriend({required String myUid, required String myName, required String query}) async {
    final match = await UserRepository.instance.findByEmailOrName(query);
    if (match == null || match.uid == myUid) return null;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_friendsOf(myUid).doc(match.uid), {
      'name': match.name,
      'addedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_friendsOf(match.uid).doc(myUid), {
      'name': myName,
      'addedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return match.name;
  }

  Future<void> setBlocked({
    required String uid,
    required String friendUid,
    required String friendName,
    required bool blocked,
  }) {
    final ref = _blockedOf(uid).doc(friendUid);
    return blocked
        ? ref.set({'name': friendName, 'blockedAt': FieldValue.serverTimestamp()})
        : ref.delete();
  }
}
