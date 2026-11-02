import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class TripCoverService {
  TripCoverService._();
  static final TripCoverService instance = TripCoverService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload(String tripId, File file) async {
    final ref = FirebaseStorage.instance.ref('trip_covers/$tripId.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
