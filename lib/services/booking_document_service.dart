import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a document photo (booking confirmation, passport
/// scan, ...) for a *past booking* in History (`users/{uid}/bookings`) —
/// same shape as [FlightDocumentService], with its own path
/// (`booking_documents/{uid}/{bookingId}/{docType}_{timestamp}.jpg`)
/// since a History booking isn't tied to a trip's own flight/hotel-stay
/// entry (see history_detail_pages.dart's scope note) and so has nowhere
/// else to attach a document to.
class BookingDocumentService {
  BookingDocumentService._();
  static final BookingDocumentService instance = BookingDocumentService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload({
    required String uid,
    required String bookingId,
    required String docType,
    required File file,
  }) async {
    final key = '${docType}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('booking_documents/$uid/$bookingId/$key.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
