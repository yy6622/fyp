import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PickedPostMedia {
  final File file;
  final bool isVideo;
  const PickedPostMedia({required this.file, required this.isVideo});
}

class CommunityMediaService {
  CommunityMediaService._();
  static final CommunityMediaService instance = CommunityMediaService._();

  final ImagePicker _picker = ImagePicker();

  Future<PickedPostMedia?> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    return picked == null ? null : PickedPostMedia(file: File(picked.path), isVideo: false);
  }

  Future<PickedPostMedia?> pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 60));
    return picked == null ? null : PickedPostMedia(file: File(picked.path), isVideo: true);
  }

  Future<String> upload(String uid, PickedPostMedia media) async {
    final ext = media.isVideo ? 'mp4' : 'jpg';
    final key = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('community_posts/$uid/$key.$ext');
    await ref.putFile(media.file, SettableMetadata(contentType: media.isVideo ? 'video/mp4' : 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
