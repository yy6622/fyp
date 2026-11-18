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

  /// Gallery multi-select, for the "up to 9 photos" community post picker.
  /// [limit] asks the OS picker to cap selection there directly (supported
  /// on Android/iOS/web); still truncated again by the caller in case a
  /// platform ignores it.
  Future<List<PickedPostMedia>> pickMultiImages({int? limit}) async {
    final picked = await _picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 85, limit: limit);
    return picked.map((x) => PickedPostMedia(file: File(x.path), isVideo: false)).toList();
  }

  /// [index] makes the storage key unique when several images from the same
  /// post are uploaded together (e.g. via Future.wait) -- without it,
  /// uploads kicked off in the same millisecond would share the exact same
  /// key and silently overwrite each other in Storage.
  Future<String> upload(String uid, PickedPostMedia media, {int index = 0}) async {
    final ext = media.isVideo ? 'mp4' : 'jpg';
    final key = '${uid}_${DateTime.now().millisecondsSinceEpoch}_$index';
    final ref = FirebaseStorage.instance.ref('community_posts/$uid/$key.$ext');
    await ref.putFile(media.file, SettableMetadata(contentType: media.isVideo ? 'video/mp4' : 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
