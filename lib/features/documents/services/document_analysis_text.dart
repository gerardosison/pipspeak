import 'dart:convert';

import '../../../core/errors/analysis_failure.dart';

/// Text-only checks shared by local document analysis and its tests.
class DocumentAnalysisText {
  static bool isUnreadable(String text) {
    final clean = text.trim();
    if (clean.length < 20) return true;
    // Unicode letters/numbers are legitimate text, including Filipino accents
    // and non-Latin scripts. Reject replacement characters/control noise.
    final readable = RegExp(
      r'[\p{L}\p{N}]',
      unicode: true,
    ).allMatches(clean).length;
    final nonSpace = clean.runes.where((rune) => rune > 32).length;
    return nonSpace == 0 || readable / nonSpace < 0.35;
  }

  /// Fits beginning, middle and ending passages within an exact UTF-8 budget.
  /// This samples long documents; it does not claim to analyze every page.
  static String excerpt(String text, int byteBudget) {
    if (byteBudget < 120) {
      throw const AnalysisFailure(
        'Not enough model context for this document request. Shorten the instructions and retry.',
      );
    }
    if (utf8.encode(text).length <= byteBudget) return text;
    const separator = '\n[...sampled passage...]\n';
    final partBudget = (byteBudget - utf8.encode(separator).length * 2) ~/ 3;
    final runes = text.runes.toList();
    String takeFrom(int start) {
      final result = StringBuffer();
      var bytes = 0;
      for (var i = start; i < runes.length; i++) {
        final char = String.fromCharCode(runes[i]);
        final size = utf8.encode(char).length;
        if (bytes + size > partBudget) break;
        result.write(char);
        bytes += size;
      }
      return result.toString();
    }

    // Work backwards for the last passage, preserving complete Unicode runes.
    var endStart = runes.length;
    var endBytes = 0;
    while (endStart > 0) {
      final bytes = utf8
          .encode(String.fromCharCode(runes[endStart - 1]))
          .length;
      if (endBytes + bytes > partBudget) break;
      endBytes += bytes;
      endStart--;
    }
    return '${takeFrom(0)}$separator'
        '${takeFrom(runes.length ~/ 2)}$separator${takeFrom(endStart)}';
  }

  static DocumentAnalysisSections parse(String answer) {
    final sections = <String, List<String>>{};
    String? current;
    for (final raw in answer.split('\n')) {
      final line = raw.trim().replaceAll('**', '').replaceAll('__', '');
      final heading = line
          .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
          .replaceFirst(RegExp(r':\s*$'), '')
          .trim()
          .toUpperCase();
      if (_headings.contains(heading)) {
        current = heading;
        sections.putIfAbsent(current, () => []);
        continue;
      }
      if (current == null) continue;
      final body = line
          .replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.)])\s*'), '')
          .trim();
      if (body.isEmpty ||
          RegExp(r'^none[.!]?$', caseSensitive: false).hasMatch(body)) {
        continue;
      }
      final values = sections[current]!;
      if (values.length < 3) values.add(body);
    }
    if (!_headings.every(sections.containsKey) ||
        sections.values.every((values) => values.isEmpty)) {
      throw const AnalysisFailure(
        'The local model returned incomplete document feedback. Try a shorter script or retry the analysis.',
      );
    }
    return DocumentAnalysisSections(
      covered: sections[_headings[0]]!,
      weak: sections[_headings[1]]!,
      improvements: sections[_headings[2]]!,
    );
  }

  static const _headings = [
    'COVERED TOPICS',
    'MISSING OR WEAK TOPICS',
    'SPEECH IMPROVEMENTS',
  ];
}

class DocumentAnalysisSections {
  const DocumentAnalysisSections({
    required this.covered,
    required this.weak,
    required this.improvements,
  });

  final List<String> covered;
  final List<String> weak;
  final List<String> improvements;
}
