import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class BookingDocumentService {
  BookingDocumentService._();
  static final BookingDocumentService instance = BookingDocumentService._();

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pick(ImageSource source) {
    return _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
  }

  Future<String> upload({
    required String uid,
    required String bookingId,
    required String docType,
    required XFile file,
  }) async {
    final key = '${docType}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('booking_documents/$uid/$bookingId/$key.jpg');
    await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
