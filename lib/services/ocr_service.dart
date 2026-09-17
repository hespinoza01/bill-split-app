import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Wraps mlkit's on-device text recognizer. One recognizer instance is kept
/// alive for the lifetime of the service and must be closed when no longer
/// needed (see [dispose]).
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Runs OCR on the image at [imagePath] and returns the raw recognized
  /// text (all blocks/lines concatenated as mlkit reports them). Returns an
  /// empty string if nothing was recognized (e.g. blank/garbage photo) —
  /// callers should treat that as a signal to fall back to manual entry.
  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    return result.text.trim();
  }

  void dispose() {
    _recognizer.close();
  }
}
