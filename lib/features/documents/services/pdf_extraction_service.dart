
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Image, ImageByteFormat;

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_ocr_backend_unsupported.dart'
    if (dart.library.io) 'pdf_ocr_backend_mlkit.dart' as ocr;

class PdfExtractionResult {
  const PdfExtractionResult({
    required this.text,
    required this.pageCount,
    required this.ocrPageCount,
  });

  final String text;
  final int pageCount;
  final int ocrPageCount;
}

/// Extracts selectable PDF text and falls back to on-device OCR page by page.
class PdfExtractionService {
  static const int _maxOcrPages = 40;
  static const int _maxRenderDimension = 2200;
  static const int _minimumSelectableTextLength = 40;

  Future<PdfExtractionResult> extractFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return extractBytes(bytes, sourceName: p.basename(path));
  }

  Future<PdfExtractionResult> extractBytes(
    Uint8List bytes, {
    String sourceName = 'uploaded.pdf',
  }) async {
    final document = await PdfDocument.openData(
      bytes,
      sourceName: sourceName,
    );
    // Native ML Kit OCR is optional. On web and desktop, pdfrx still extracts
    // selectable PDF text without loading an unsupported OCR plugin.
    final recognizer = ocr.createPdfOcrSession();
    final pageTexts = <String>[];
    var ocrPageCount = 0;

    try {
      for (final page in document.pages) {
        final selectableText = (await page.loadText())?.fullText.trim() ?? '';
        if (selectableText.length >= _minimumSelectableTextLength) {
          pageTexts.add(selectableText);
          continue;
        }

        if (recognizer == null) {
          pageTexts.add(selectableText);
          continue;
        }

        if (ocrPageCount >= _maxOcrPages) {
          pageTexts.add(selectableText);
          continue;
        }

        final longestPageSide = math.max(page.width, page.height);
        final scale = math.min(2.0, _maxRenderDimension / longestPageSide);
        final width = math.max(1, (page.width * scale).round()).toInt();
        final height = math.max(1, (page.height * scale).round()).toInt();
        final image = await page.render(
          fullWidth: width.toDouble(),
          fullHeight: height.toDouble(),
        );
        if (image == null) {
          pageTexts.add(selectableText);
          continue;
        }

        Directory? ocrTempDir;
        Image? rasterImage;
        try {
          rasterImage = await image.createImage();
          final pngData = await rasterImage.toByteData(format: ImageByteFormat.png);
          if (pngData == null) {
            pageTexts.add(selectableText);
            continue;
          }
          ocrTempDir = await Directory.systemTemp.createTemp('hawkabuild_ocr_');
          final pngFile = File(p.join(ocrTempDir.path, 'page.png'));
          await pngFile.writeAsBytes(
            pngData.buffer.asUint8List(pngData.offsetInBytes, pngData.lengthInBytes),
            flush: true,
          );
          final ocrText = (await recognizer.recognizeFile(pngFile.path)).trim();
          ocrPageCount++;
          pageTexts.add(ocrText.length > selectableText.length ? ocrText : selectableText);
        } finally {
          rasterImage?.dispose();
          image.dispose();
          if (ocrTempDir != null) await ocrTempDir.delete(recursive: true);
        }
      }

      return PdfExtractionResult(
        text: pageTexts.where((text) => text.isNotEmpty).join('\n\n'),
        pageCount: document.pages.length,
        ocrPageCount: ocrPageCount,
      );
    } finally {
      await recognizer?.close();
      await document.dispose();
    }
  }
}
