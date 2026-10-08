import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a travel document photo (booking confirmation, room
/// voucher, passport scan, ...) for a hotel stay already on a trip's plan
/// — the hotel-stay sibling of [FlightDocumentService], same shape, its
/// own storage path (`hotel_documents/{tripId}/{stayId}/{docType}_
/// {timestamp}.jpg`) so a re-upload doesn't clobber an earlier one before
/// the new download URL is saved.
class HotelDocumentService {
  HotelDocumentService._();
  static final HotelDocumentService instance = HotelDocumentService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload({
    required String tripId,
    required String stayId,
    required String docType,
    required File file,
  }) async {
    final key = '${docType}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('hotel_documents/$tripId/$stayId/$key.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
