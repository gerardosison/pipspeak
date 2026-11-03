import 'dart:async';

abstract interface class PdfOcrSession {
  Future<String> recognizeFile(String imagePath);
  Future<void> close();
}
