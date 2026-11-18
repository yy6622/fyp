import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class FlightDocumentService {
  FlightDocumentService._();
  static final FlightDocumentService instance = FlightDocumentService._();

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pick(ImageSource source) {
    return _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
  }

  Future<String> upload({
    required String tripId,
    required String flightId,
    required String docType,
    required XFile file,
  }) async {
    final key = '${docType}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('flight_documents/$tripId/$flightId/$key.jpg');
    await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
