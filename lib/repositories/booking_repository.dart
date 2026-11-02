import 'package:cloud_firestore/cloud_firestore.dart';

class BookingEntry {
  final String id;
  final String type; // 'flight' | 'hotel' | 'insurance'
  final String title;
  final String subtitle;
  final String trailing;
  final String refId;
  final Map<String, String> documents;
  final String bookingRef;
  final String status;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  final String checkIn;
  final String checkOut;
  final String coverage;
  final String transactionId;
  const BookingEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.refId = '',
    this.documents = const {},
    this.bookingRef = '',
    this.status = '',
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.specialRequests = '',
    this.checkIn = '',
    this.checkOut = '',
    this.coverage = '',
    this.transactionId = '',
  });
}

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
              refId: (d.data()['refId'] as String?) ?? '',
              documents: Map<String, String>.from(d.data()['documents'] as Map? ?? const {}),
              bookingRef: (d.data()['bookingRef'] as String?) ?? '',
              status: (d.data()['status'] as String?) ?? '',
              guestName: (d.data()['guestName'] as String?) ?? '',
              guestEmail: (d.data()['guestEmail'] as String?) ?? '',
              guestPhone: (d.data()['guestPhone'] as String?) ?? '',
              guestIdNumber: (d.data()['guestIdNumber'] as String?) ?? '',
              specialRequests: (d.data()['specialRequests'] as String?) ?? '',
              checkIn: (d.data()['checkIn'] as String?) ?? '',
              checkOut: (d.data()['checkOut'] as String?) ?? '',
              coverage: (d.data()['coverage'] as String?) ?? '',
              transactionId: (d.data()['transactionId'] as String?) ?? '',
            ))
        .where((b) => type == null || b.type == type)
        .toList());
  }

  Future<void> setBookingDocument(String uid, String bookingId, String docType, String url) {
    return _bookingsOf(uid).doc(bookingId).update({'documents.$docType': url});
  }

  Future<void> addBooking({
    required String uid,
    required String type,
    required String title,
    required String subtitle,
    required String trailing,
    String refId = '',
    String bookingRef = '',
    String status = '',
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String guestIdNumber = '',
    String specialRequests = '',
    String checkIn = '',
    String checkOut = '',
    String coverage = '',
    String transactionId = '',
  }) {
    return _bookingsOf(uid).add({
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'trailing': trailing,
      'refId': refId,
      if (bookingRef.isNotEmpty) 'bookingRef': bookingRef,
      if (status.isNotEmpty) 'status': status,
      if (guestName.isNotEmpty) 'guestName': guestName,
      if (guestEmail.isNotEmpty) 'guestEmail': guestEmail,
      if (guestPhone.isNotEmpty) 'guestPhone': guestPhone,
      if (guestIdNumber.isNotEmpty) 'guestIdNumber': guestIdNumber,
      if (specialRequests.isNotEmpty) 'specialRequests': specialRequests,
      if (checkIn.isNotEmpty) 'checkIn': checkIn,
      if (checkOut.isNotEmpty) 'checkOut': checkOut,
      if (coverage.isNotEmpty) 'coverage': coverage,
      if (transactionId.isNotEmpty) 'transactionId': transactionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
