import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads paragraph text from a DOCX package locally without uploading it.
class DocxExtractionService {
  Future<String> extractBytes(Uint8List bytes) async {
    try {
      final package = ZipDecoder().decodeBytes(bytes);
      final document = package.findFile('word/document.xml');
      if (document == null) return '';
      final xml = XmlDocument.parse(utf8.decode(document.content as List<int>));
      final paragraphs = <String>[];
      for (final paragraph in xml.findAllElements('w:p')) {
        final text = paragraph
            .findAllElements('w:t')
            .map((node) => node.innerText)
            .join();
        if (text.trim().isNotEmpty) paragraphs.add(text.trim());
      }
      return paragraphs.join('\n\n');
    } on Object catch (error) {
      throw FormatException('Could not read this DOCX file: $error');
    }
  }
}
