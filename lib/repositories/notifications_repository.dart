import 'package:cloud_firestore/cloud_firestore.dart';

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

class NotificationsRepository {
  NotificationsRepository._();
  static final NotificationsRepository instance = NotificationsRepository._();

  CollectionReference<Map<String, dynamic>> _of(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watch(String uid) => _of(uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());

  Stream<int> watchUnreadCount(String uid) =>
      _of(uid).where('read', isEqualTo: false).snapshots().map((snap) => snap.docs.length);

  Future<void> markRead(String uid, String id) => _of(uid).doc(id).update({'read': true});

  Future<void> delete(String uid, String id) => _of(uid).doc(id).delete();

  Future<void> deleteAll(String uid) async {
    final docs = await _of(uid).get();
    for (var i = 0; i < docs.docs.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs.docs.skip(i).take(450)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

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
