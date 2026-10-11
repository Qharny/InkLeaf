import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Gets a photo of a page and reads the text on it, on the device. An
/// interface so tests can swap in a fake through [create]; the app uses
/// `image_picker` and ML Kit text recognition.
abstract class PageScanner {
  static PageScanner Function() create = _MlKitScanner.new;

  /// A photo from the camera (or the gallery), as a temporary file path.
  /// Null if the user backed out.
  Future<String?> pickImage({required bool camera});

  /// The text found in the image at [path]; empty if there is none.
  Future<String> recognize(String path);

  Future<void> dispose();
}

class _MlKitScanner implements PageScanner {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String?> pickImage({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      // Plenty for reading text, and keeps stored scans small.
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
    );
    return file?.path;
  }

  @override
  Future<String> recognize(String path) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(path),
    );
    return result.text.trim();
  }

  @override
  Future<void> dispose() => _recognizer.close();
}
