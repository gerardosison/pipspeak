import 'dart:async';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'pdf_ocr_backend_interface.dart';

PdfOcrSession? createPdfOcrSession() {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  return _MlKitPdfOcrSession();
}

class _MlKitPdfOcrSession implements PdfOcrSession {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> recognizeFile(String imagePath) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return result.text;
  }

  @override
  Future<void> close() => _recognizer.close();
}
