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
  // Links this booking back to its catalog document (e.g. `catalog_hotels`
  // doc id) so a past booking's detail page can show real reviews for the
  // actual place — empty when the booking has no such catalog target (a
  // manually-typed stay, or a type with no reviewable catalog at all).
  final String refId;
  // Uploaded documents for this booking — docType (e.g. 'Booking
  // Confirmation') -> real Firebase Storage download URL (see
  // BookingDocumentService). Empty until someone actually uploads one
  // from History's Documents tab.
  final Map<String, String> documents;
  // The real payment/booking reference (Stripe PaymentIntent id for now)
  // and status — previously only ever written for Insurance; Flight and
  // Hotel's payment flows now pass their real values here too instead of
  // leaving every past booking's detail page to show a hardcoded fallback.
  final String bookingRef;
  final String status;
  // Guest/traveller + stay details, captured at the moment of payment so
  // History's detail pages can show what was actually booked instead of
  // nothing at all (these used to be collected on the guest-details page
  // and then thrown away — never written to `users/{uid}/bookings`).
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  final String checkIn;
  final String checkOut;
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
            ))
        .where((b) => type == null || b.type == type)
        .toList());
  }

  /// Attaches an uploaded document's download URL to a past booking —
  /// same idea as TripRepository.setFlightDocument, for a History entry
  /// instead of a trip's own flight.
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
