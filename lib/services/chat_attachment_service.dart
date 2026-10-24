import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a Chat tab photo attachment (the Camera/Gallery
/// buttons in the attachment row) — same shape as [ReceiptService], each
/// upload getting its own unique path (`chat_images/{tripId}/{uid}_{timestamp}.jpg`)
/// since a trip's chat can have many photos and each one needs to keep
/// its own file rather than overwriting the last.
class ChatAttachmentService {
  ChatAttachmentService._();
  static final ChatAttachmentService instance = ChatAttachmentService._();

  final ImagePicker _picker = ImagePicker();

  /// Returns null if the person backs out of the camera/gallery picker —
  /// not an error, just nothing to send.
  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload(String tripId, String uid, File file) async {
    final key = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('chat_images/$tripId/$key.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
