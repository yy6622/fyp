import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ClaimDocumentService {
  ClaimDocumentService._();
  static final ClaimDocumentService instance = ClaimDocumentService._();

  final ImagePicker _picker = ImagePicker();

  static const int maxBytes = 5 * 1024 * 1024;

  Future<XFile?> pick(ImageSource source) {
    return _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
  }

  Future<PickedDocument?> pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final bytes = await file.readAsBytes();
    return PickedDocument(bytes: bytes, name: file.name, extension: 'pdf', contentType: 'application/pdf');
  }

  Future<String> upload({
    required String kind,
    required String uid,
    XFile? file,
    PickedDocument? document,
  }) async {
    assert(file != null || document != null, 'Pass either an image file or a picked document.');
    final Uint8List bytes = document?.bytes ?? await file!.readAsBytes();
    if (bytes.length > maxBytes) {
      throw ClaimDocumentTooLargeException();
    }
    final extension = document?.extension ?? 'jpg';
    final contentType = document?.contentType ?? 'image/jpeg';
    final key = '${DateTime.now().millisecondsSinceEpoch}_${1000 + Random().nextInt(9000)}';
    final ref = FirebaseStorage.instance.ref('${kind}_documents/$uid/$key.$extension');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}

/// A PDF (or other non-image) file picked via [ClaimDocumentService.pickPdf],
/// carrying the bytes straight off the picker so [ClaimDocumentService.upload]
/// never needs a real filesystem path -- which Flutter Web doesn't have.
class PickedDocument {
  final Uint8List bytes;
  final String name;
  final String extension;
  final String contentType;

  PickedDocument({
    required this.bytes,
    required this.name,
    required this.extension,
    required this.contentType,
  });
}

class ClaimDocumentTooLargeException implements Exception {
  @override
  String toString() => "That file is larger than 5MB. Please choose a smaller file.";
}
