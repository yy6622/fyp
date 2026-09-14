import 'package:cloud_firestore/cloud_firestore.dart';

/// A single row of purchase/booking history — mirrors what [HistoryPage]
/// shows for one row (title/subtitle/trailing), plus which tab it belongs
/// to.
class BookingEntry {
  final String id;
  final String type; // 'flight' | 'hotel' | 'insurance'
  final String title;
  final String subtitle;
  final String trailing;
  const BookingEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
}

/// Reads/writes `users/{uid}/bookings` — real purchase history. Only the
/// Insurance purchase flow writes to this for now (Flight/Hotel history
/// still shows placeholder rows until those booking flows exist).
class BookingRepository {
  BookingRepository._();
  static final BookingRepository instance = BookingRepository._();

  CollectionReference<Map<String, dynamic>> _bookingsOf(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('bookings');

  Stream<List<BookingEntry>> watchBookings(String uid, {String? type}) {
    return _bookingsOf(uid).orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs
        .map((d) => BookingEntry(
              id: d.id,
              type: (d.data()['type'] as String?) ?? '',
              title: (d.data()['title'] as String?) ?? '',
              subtitle: (d.data()['subtitle'] as String?) ?? '',
              trailing: (d.data()['trailing'] as String?) ?? '',
            ))
        .where((b) => type == null || b.type == type)
        .toList());
  }

  Future<void> addBooking({
    required String uid,
    required String type,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return _bookingsOf(uid).add({
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'trailing': trailing,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
