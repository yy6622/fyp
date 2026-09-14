import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a profile avatar photo to Firebase Storage.
///
/// SETUP REQUIRED — this project didn't have image upload wired in before:
/// add the `image_picker` and `firebase_storage` packages to pubspec.yaml
/// (`flutter pub add image_picker firebase_storage`) and deploy
/// `storage.rules` (`firebase deploy --only storage`) before this compiles
/// and works. See the onboarding wizard's doc comment for the full list.
class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    return picked == null ? null : File(picked.path);
  }

  /// Uploads [file] as this user's avatar and returns its public download
  /// URL. Always the same storage path per user (`avatars/{uid}.jpg`), so a
  /// re-upload just replaces the previous photo instead of accumulating
  /// orphaned files.
  Future<String> upload(String uid, File file) async {
    final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    // Firebase Storage keeps the same download token across overwrites, so
    // re-uploading a photo can return the exact same URL string as before —
    // Flutter's image cache keys on that string and would keep showing the
    // old photo. Appending a changing, harmless query param busts that
    // cache; Firebase ignores unknown query params when serving the file.
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
