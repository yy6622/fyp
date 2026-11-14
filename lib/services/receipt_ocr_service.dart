import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';


class ReceiptOcrResult {
  final List<({String label, double price})> items;

  final double? total;

  final String? error;

  const ReceiptOcrResult({required this.items, this.total, this.error});

  bool get isEmpty => items.isEmpty && total == null;
}

class ReceiptOcrService {
  ReceiptOcrService._();
  static final ReceiptOcrService instance = ReceiptOcrService._();

  // Price: optional currency marker, 1-3 digits, optional thousands groups,
  // a decimal point OR comma, exactly 2 decimal digits, at the end of the line.
  static final RegExp _priceAtEnd = RegExp(
    r'(?:RM|MYR|\$)?\s*(\d{1,3}(?:[,.]\d{3})*[.,]\d{2})\s*$',
    caseSensitive: false,
  );

  static final RegExp _totalWord = RegExp(r'\b(grand\s*total|total|amount\s*due)\b', caseSensitive: false);
  static final RegExp _subtotalWord = RegExp(r'\bsub[\s-]?total\b', caseSensitive: false);

  static final RegExp _nonItemWord = RegExp(
    r'\b(subtotal|sub-total|tax|gst|sst|service\s*charge|cash|change|card|visa|master|'
    r'rounding|discount|vat|qty|quantity|thank\s*you|receipt\s*no|invoice|cashier|'
    r'table\s*no|order\s*no|date|time|balance|amount\s*paid|paid|net\s*total)\b',
    caseSensitive: false,
  );

  Future<ReceiptOcrResult> scan(File image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(InputImage.fromFile(image));
      // A receipt's label and its price are often two separate OCR blocks
      // (the dotted leader / wide gap between them reads as a block break),
      // so `recognized.text` can come back as all the labels, a blank line,
      // then all the prices — never "Lorem   6.50" on one line. Rebuild each
      // visual row from the line bounding boxes instead, across blocks.
      final rows = _reconstructRows(recognized);
      final result = _parseLines(rows);
      if (!result.isEmpty) return result;
      // Fall back to the flat text in case a receipt really is single-block.
      final fallback = _parseLines(recognized.text.split('\n'));
      if (!fallback.isEmpty) return fallback;
      // Nothing matched either way — surface what OCR actually read AND how
      // it got grouped into rows, so this is diagnosable without a debugger.
      final rawPreview = _clip(recognized.text.trim().replaceAll('\n', ' / '), 300);
      final rowsPreview = _clip(rows.join(' | '), 300);
      if (rawPreview.isEmpty) {
        return const ReceiptOcrResult(items: [], error: 'no text detected in the photo — try a clearer, well-lit shot');
      }
      return ReceiptOcrResult(
        items: const [],
        error: 'no price lines matched. raw: "$rawPreview" rows: "$rowsPreview"',
      );
    } catch (e) {
      return ReceiptOcrResult(items: const [], error: e.toString());
    } finally {
      await recognizer.close();
    }
  }

  String _clip(String s, int max) => s.length > max ? '${s.substring(0, max)}…' : s;

  /// Collects every line from every block, sorts by vertical position, then
  /// groups lines into visual rows by the GAP between consecutive centers
  /// (not strict bounding-box containment) — tolerant of the two columns
  /// (label vs. price) having slightly different line heights or a small
  /// amount of photo skew, which a tight containment check is not.
  List<String> _reconstructRows(RecognizedText recognized) {
    final lines = <TextLine>[
      for (final block in recognized.blocks) ...block.lines,
    ];
    if (lines.isEmpty) return const [];

    final centered = lines.map((l) => (line: l, center: l.boundingBox.top + l.boundingBox.height / 2)).toList()
      ..sort((a, b) => a.center.compareTo(b.center));

    final rows = <List<TextLine>>[];
    double? lastCenter;
    double? lastHeight;
    for (final entry in centered) {
      final height = entry.line.boundingBox.height;
      final avgHeight = lastHeight == null ? height : (lastHeight + height) / 2;
      final gapThreshold = avgHeight * 0.6;
      if (lastCenter == null || (entry.center - lastCenter).abs() > gapThreshold) {
        rows.add([entry.line]);
      } else {
        rows.last.add(entry.line);
      }
      lastCenter = entry.center;
      lastHeight = height;
    }

    return rows.map((row) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      return row.map((l) => l.text).join('   ');
    }).toList();
  }

  ReceiptOcrResult _parseLines(List<String> rawLines) {
    final items = <({String label, double price})>[];
    double? total;

    for (final rawLine in rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _priceAtEnd.firstMatch(line);
      if (match == null) continue;
      final price = double.tryParse(match.group(1)!.replaceFirstMapped(RegExp(r'[,.](\d{2})$'), (m) => '.${m.group(1)}').replaceAll(',', ''));
      if (price == null || price <= 0) continue;

      if (_totalWord.hasMatch(line) && !_subtotalWord.hasMatch(line)) {
        total = price;
        continue;
      }
      if (_nonItemWord.hasMatch(line)) continue;

      final label = line.substring(0, match.start).trim();
      if (label.isEmpty || !RegExp(r'[A-Za-z]{2,}').hasMatch(label)) continue;

      items.add((label: label, price: price));
    }

    return ReceiptOcrResult(items: items, total: total);
  }
}
