import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// What was picked for a Community post's single media slot (FR61) — a
/// photo or a video, never both; see CreatePostController.pickMedia.
class PickedPostMedia {
  final File file;
  final bool isVideo;
  const PickedPostMedia({required this.file, required this.isVideo});
}

/// Picks and uploads the one photo or video a Community post can attach
/// (the "Upload Media" row on the compose form) — same shape as
/// [ReceiptService]/[ChatAttachmentService], each upload getting its own
/// unique path (`community_posts/{uid}/{timestamp}.<ext>`) rather than a
/// fixed per-user path.
///
/// Previously the compose form's "Upload Media" toggle only flipped a
/// local bool (see the old `CreatePostController.mediaAdded`) and never
/// actually picked or uploaded anything — every post's `images` field was
/// hardcoded to `[]` regardless of what the toggle showed. This service
/// is what makes that real.
class CommunityMediaService {
  CommunityMediaService._();
  static final CommunityMediaService instance = CommunityMediaService._();

  final ImagePicker _picker = ImagePicker();

  Future<PickedPostMedia?> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    return picked == null ? null : PickedPostMedia(file: File(picked.path), isVideo: false);
  }

  /// Capped at 60 seconds — plenty for a travel-moment clip on a social
  /// feed, and short enough that a mobile upload over the compose flow
  /// stays quick rather than silently taking minutes on a weak connection.
  Future<PickedPostMedia?> pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 60));
    return picked == null ? null : PickedPostMedia(file: File(picked.path), isVideo: true);
  }

  /// Uploads [media] and returns its download URL. The caller decides
  /// which of [CommunityRepository.createPost]'s `images`/`videoUrl`
  /// params to pass it as, based on [PickedPostMedia.isVideo].
  Future<String> upload(String uid, PickedPostMedia media) async {
    final ext = media.isVideo ? 'mp4' : 'jpg';
    final key = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('community_posts/$uid/$key.$ext');
    await ref.putFile(media.file, SettableMetadata(contentType: media.isVideo ? 'video/mp4' : 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
