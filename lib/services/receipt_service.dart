import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a receipt photo for the "Upload Receipt" expense entry
/// point — same shape as [AvatarService], but each upload gets its own
/// unique path (`receipts/{tripId}/{uid}_{timestamp}.jpg`) instead of a
/// fixed per-user path, since a trip can have many receipts and each one
/// needs to keep its own photo rather than overwriting the last.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload(String tripId, String uid, File file) async {
    final key = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('receipts/$tripId/$key.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
