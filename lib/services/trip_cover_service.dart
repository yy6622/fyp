import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a group trip's cover photo to Firebase Storage —
/// same pattern as [AvatarService], just keyed by trip id instead of uid
/// since a group's photo belongs to the trip, not to whoever uploaded it.
class TripCoverService {
  TripCoverService._();
  static final TripCoverService instance = TripCoverService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    return picked == null ? null : File(picked.path);
  }

  /// Uploads [file] as [tripId]'s cover photo and returns its public
  /// download URL. Always the same storage path per trip
  /// (`trip_covers/{tripId}.jpg`), so re-uploading just replaces the
  /// previous photo instead of accumulating orphaned files.
  Future<String> upload(String tripId, File file) async {
    final ref = FirebaseStorage.instance.ref('trip_covers/$tripId.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    // Same cache-busting trick as AvatarService.upload — Storage keeps the
    // same download token across overwrites, so a re-upload can return the
    // exact same URL string, and Flutter's image cache keys on that string.
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
