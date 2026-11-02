import 'package:cloud_firestore/cloud_firestore.dart';

import 'notifications_repository.dart';
import 'user_repository.dart';

class FriendEntry {
  final String uid;
  final String name;
  const FriendEntry({required this.uid, required this.name});
}

enum FriendRequestStatus { sent, autoAccepted, alreadyFriends, alreadyRequested, isSelf, noMatch }

class FriendRequestOutcome {
  final FriendRequestStatus status;
  final String? name;
  const FriendRequestOutcome({required this.status, this.name});
}

class FriendsRepository {
  FriendsRepository._();
  static final FriendsRepository instance = FriendsRepository._();

  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('friends');

  CollectionReference<Map<String, dynamic>> _blockedOf(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('blocked');

  CollectionReference<Map<String, dynamic>> get _requests => FirebaseFirestore.instance.collection('friendRequests');
  String _reqId(String fromUid, String toUid) => '${fromUid}_$toUid';

  List<FriendEntry> _toEntries(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => FriendEntry(uid: d.id, name: (d.data()['name'] as String?) ?? '')).toList();

  Stream<List<FriendEntry>> watchFriends(String uid) =>
      _friendsOf(uid).orderBy('name').snapshots().map(_toEntries);

  Stream<List<FriendEntry>> watchBlocked(String uid) =>
      _blockedOf(uid).orderBy('name').snapshots().map(_toEntries);

  Stream<Set<String>> watchBlockedIds(String uid) =>
      _blockedOf(uid).snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());

  Stream<List<FriendRequest>> watchIncomingRequests(String uid) => _requests
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(FriendRequest.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Future<FriendRequestOutcome> sendFriendRequest({
    required String myUid,
    required String myName,
    required String query,
  }) async {
    final match = await UserRepository.instance.findByEmailOrName(query);
    if (match == null) return const FriendRequestOutcome(status: FriendRequestStatus.noMatch);
    if (match.uid == myUid) return const FriendRequestOutcome(status: FriendRequestStatus.isSelf);

    final alreadyFriend = await _friendsOf(myUid).doc(match.uid).get();
    if (alreadyFriend.exists) {
      return FriendRequestOutcome(status: FriendRequestStatus.alreadyFriends, name: match.name);
    }

    final mine = await _requests.doc(_reqId(myUid, match.uid)).get();
    if (mine.exists && mine.data()?['status'] == 'pending') {
      return FriendRequestOutcome(status: FriendRequestStatus.alreadyRequested, name: match.name);
    }

    final theirs = await _requests.doc(_reqId(match.uid, myUid)).get();
    if (theirs.exists && theirs.data()?['status'] == 'pending') {
      await respondToFriendRequest(
        uid: myUid,
        fromUid: match.uid,
        fromName: match.name,
        myName: myName,
        accept: true,
      );
      return FriendRequestOutcome(status: FriendRequestStatus.autoAccepted, name: match.name);
    }

    await _requests.doc(_reqId(myUid, match.uid)).set({
      'fromUid': myUid,
      'fromName': myName,
      'toUid': match.uid,
      'toName': match.name,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await NotificationsRepository.instance.send(
      toUid: match.uid,
      type: 'friend_request',
      title: 'New friend request',
      body: '$myName wants to be your friend.',
      data: {'fromUid': myUid, 'fromName': myName},
    );
    return FriendRequestOutcome(status: FriendRequestStatus.sent, name: match.name);
  }

  Future<void> respondToFriendRequest({
    required String uid,
    required String fromUid,
    required String fromName,
    required String myName,
    required bool accept,
  }) async {
    final ref = _requests.doc(_reqId(fromUid, uid));
    if (!accept) {
      await ref.delete();
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(ref);
    batch.set(_friendsOf(uid).doc(fromUid), {'name': fromName, 'addedAt': FieldValue.serverTimestamp()});
    batch.set(_friendsOf(fromUid).doc(uid), {'name': myName, 'addedAt': FieldValue.serverTimestamp()});
    await batch.commit();
    await NotificationsRepository.instance.send(
      toUid: fromUid,
      type: 'friend_request_accepted',
      title: 'Friend request accepted',
      body: '$myName accepted your friend request.',
      data: {'friendUid': uid, 'friendName': myName},
    );
  }

  Stream<List<SentFriendRequest>> watchSentRequests(String uid) => _requests
      .where('fromUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(SentFriendRequest.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Future<void> resendFriendRequest({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String toName,
  }) async {
    final ref = _requests.doc(_reqId(fromUid, toUid));
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['status'] != 'pending') return;
    await ref.update({'createdAt': FieldValue.serverTimestamp()});
    await NotificationsRepository.instance.send(
      toUid: toUid,
      type: 'friend_request',
      title: 'New friend request',
      body: '$fromName wants to be your friend.',
      data: {'fromUid': fromUid, 'fromName': fromName},
    );
  }

  Future<void> cancelFriendRequest({required String fromUid, required String toUid}) {
    return _requests.doc(_reqId(fromUid, toUid)).delete();
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

  Future<void> removeFriend({required String uid, required String friendUid}) {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_friendsOf(uid).doc(friendUid));
    batch.delete(_friendsOf(friendUid).doc(uid));
    return batch.commit();
  }
}

class FriendRequest {
  final String id;
  final String fromUid;
  final String fromName;
  final DateTime? createdAt;
  const FriendRequest({required this.id, required this.fromUid, required this.fromName, required this.createdAt});

  factory FriendRequest.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return FriendRequest(
      id: doc.id,
      fromUid: (m['fromUid'] as String?) ?? '',
      fromName: (m['fromName'] as String?) ?? 'Someone',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SentFriendRequest {
  final String toUid;
  final String toName;
  final DateTime? createdAt;
  const SentFriendRequest({required this.toUid, required this.toName, required this.createdAt});

  factory SentFriendRequest.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return SentFriendRequest(
      toUid: (m['toUid'] as String?) ?? '',
      toName: (m['toName'] as String?) ?? 'Someone',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
