import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload(String uid, File file) async {
    final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
