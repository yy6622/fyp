import 'package:cloud_firestore/cloud_firestore.dart';

/// One row in a user's `users/{uid}/notifications` subcollection — a
/// general-purpose in-app notification (the Home bell icon, previously a
/// dead "No new notifications" snackbar with nothing behind it, now reads
/// this for real). [type] distinguishes what it's about ('friend_request',
/// 'friend_request_accepted', ...) and [data] carries whatever that type
/// needs (e.g. the sender's uid/name for a pending friend request, so the
/// Notifications page can act on it without a second read).
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.data,
  });

  factory AppNotification.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return AppNotification(
      id: doc.id,
      type: (m['type'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      read: (m['read'] as bool?) ?? false,
      data: Map<String, dynamic>.from((m['data'] as Map?) ?? const {}),
    );
  }
}

/// Reads/writes `users/{uid}/notifications`. See firestore.rules: the
/// owner can read/update(mark-read)/delete their own; any signed-in user
/// may create one in someone else's inbox (same trust level already given
/// to liking a post or joining a trip by invite link elsewhere in this
/// app) — that's what [send] does when, say, a friend request goes out.
class NotificationsRepository {
  NotificationsRepository._();
  static final NotificationsRepository instance = NotificationsRepository._();

  CollectionReference<Map<String, dynamic>> _of(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');

  /// Most recent 100 — plenty for an inbox nobody is expected to let pile
  /// up much further than that before clearing it.
  Stream<List<AppNotification>> watch(String uid) => _of(uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());

  /// Drives the Home bell icon's unread badge.
  Stream<int> watchUnreadCount(String uid) =>
      _of(uid).where('read', isEqualTo: false).snapshots().map((snap) => snap.docs.length);

  Future<void> markRead(String uid, String id) => _of(uid).doc(id).update({'read': true});

  Future<void> delete(String uid, String id) => _of(uid).doc(id).delete();

  Future<void> send({
    required String toUid,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) {
    return _of(toUid).add({
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
