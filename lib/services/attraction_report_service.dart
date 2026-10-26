import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Picks and uploads a photo for "Report New Attraction" — same shape as
/// [ReceiptService]: each report gets its own unique path
/// (`attraction_reports/{uid}/{timestamp}.jpg`, see storage.rules)
/// instead of a fixed per-user path, since one rider can submit more than
/// one report over time.
class AttractionReportService {
  AttractionReportService._();
  static final AttractionReportService instance = AttractionReportService._();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    return picked == null ? null : File(picked.path);
  }

  Future<String> upload(String uid, File file) async {
    final ref = FirebaseStorage.instance.ref('attraction_reports/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
