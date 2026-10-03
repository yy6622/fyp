import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a travel document photo (e-ticket, boarding pass,
/// passport scan, ...) for a flight already on a trip's plan — same shape
/// as [ReceiptService], with its own path
/// (`flight_documents/{tripId}/{flightId}/{docType}_{timestamp}.jpg`) so
/// every upload gets its own file and a re-upload doesn't clobber an
/// earlier one before the new download URL is saved.
class FlightDocumentService {
  FlightDocumentService._();
  static final FlightDocumentService instance = FlightDocumentService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload({
    required String tripId,
    required String flightId,
    required String docType,
    required File file,
  }) async {
    final key = '${docType}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('flight_documents/$tripId/$flightId/$key.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
