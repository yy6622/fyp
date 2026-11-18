import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class TripCoverService {
  TripCoverService._();
  static final TripCoverService instance = TripCoverService._();

  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    if (picked == null) return null;
    return picked.readAsBytes();
  }

  Future<String> upload(String tripId, Uint8List bytes) async {
    final ref = FirebaseStorage.instance.ref('trip_covers/$tripId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
