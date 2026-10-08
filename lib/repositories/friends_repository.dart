import 'package:cloud_firestore/cloud_firestore.dart';

import 'notifications_repository.dart';
import 'user_repository.dart';

/// One row in a friends or blocked-users list.
class FriendEntry {
  final String uid;
  final String name;
  const FriendEntry({required this.uid, required this.name});
}

/// Outcome of [FriendsRepository.sendFriendRequest] — a plain result
/// instead of a bare nullable string, so the UI can show the right message
/// for every case (no match, already friends, already pending, ...) rather
/// than collapsing them all into "it didn't work".
enum FriendRequestStatus { sent, autoAccepted, alreadyFriends, alreadyRequested, isSelf, noMatch }

class FriendRequestOutcome {
  final FriendRequestStatus status;
  final String? name;
  const FriendRequestOutcome({required this.status, this.name});
}

/// Reads/writes the `users/{uid}/friends` and `users/{uid}/blocked`
/// subcollections, plus the top-level `friendRequests` collection that
/// sits between them: adding a friend is a request the other person has to
/// approve (see [sendFriendRequest]/[respondToFriendRequest]), not an
/// instant mutual add — they get a real notification (see
/// NotificationsRepository) and choose to accept or decline it.
class FriendsRepository {
  FriendsRepository._();
  static final FriendsRepository instance = FriendsRepository._();

  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('friends');

  CollectionReference<Map<String, dynamic>> _blockedOf(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('blocked');

  // Top-level (not nested under users/{uid}) so a request can be read and
  // deleted by either the sender or the recipient — see firestore.rules'
  // `friendRequests` match, which checks the fromUid/toUid fields rather
  // than "whose subcollection is this". The deterministic id means both
  // sides can .doc(id).get() it directly instead of needing a query.
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

  /// Incoming pending requests addressed to [uid] — shown on the
  /// Notifications page with Accept/Decline. Sorted client-side (not via
  /// `orderBy`) so this doesn't need a composite index alongside the
  /// `toUid`/`status` equality filters.
  Stream<List<FriendRequest>> watchIncomingRequests(String uid) => _requests
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(FriendRequest.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// Looks [query] up by email/name and, if a real match is found, sends
  /// them a friend request (and a notification) instead of adding each
  /// other instantly. If they'd already sent *you* one, this accepts that
  /// one rather than creating a pointless second request in the other
  /// direction.
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

  /// Accepts or declines a pending request addressed to [uid] from
  /// [fromUid]. Accepting writes both halves of the mutual friendship in
  /// one batch and notifies the sender; declining just removes the
  /// request. Either way the request doc itself is deleted rather than
  /// kept around with a status flag — [sendFriendRequest]'s own checks
  /// only care whether a *pending* one exists, not history.
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
    // Writing into the *other* person's friends subcollection — allowed by
    // firestore.rules because the entry being written is yourself
    // (friendId == your own uid), never an arbitrary third party.
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

  /// Requests *you've* sent that the other person hasn't answered yet —
  /// shown on the Friends page with Resend/Cancel, so "request sent"
  /// isn't just a one-time snackbar that's gone the moment it fades.
  Stream<List<SentFriendRequest>> watchSentRequests(String uid) => _requests
      .where('fromUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(SentFriendRequest.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// Re-notifies the recipient of a still-pending request and bumps its
  /// createdAt so it sorts back to the top of both your and their list.
  /// A no-op if it was answered or cancelled in the meantime (someone
  /// else's tab, or the recipient just declined it).
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

  /// Cancels a request you sent before the other person answered it.
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
}

/// A pending `friendRequests` doc, from the recipient's point of view.
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

/// A pending `friendRequests` doc, from the sender's point of view.
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
