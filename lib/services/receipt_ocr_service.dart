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

  static final RegExp _priceAtEnd = RegExp(
    r'(?:RM|MYR|\$)?\s*(\d{1,3}(?:[,.]\d{3})*\.\d{2})\s*$',
    caseSensitive: false,
  );

  static final RegExp _totalWord = RegExp(r'\b(grand\s*total|total|amount\s*due)\b', caseSensitive: false);
  static final RegExp _subtotalWord = RegExp(r'\bsub[\s-]?total\b', caseSensitive: false);

  static final RegExp _nonItemWord = RegExp(
    r'\b(subtotal|sub-total|tax|gst|sst|service\s*charge|cash|change|card|visa|master|'
    r'rounding|discount|vat|qty|quantity|thank\s*you|receipt\s*no|invoice|cashier|'
    r'table\s*no|order\s*no|date|time)\b',
    caseSensitive: false,
  );

  Future<ReceiptOcrResult> scan(File image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(InputImage.fromFile(image));
      return _parse(recognized.text);
    } catch (e) {
      return ReceiptOcrResult(items: const [], error: e.toString());
    } finally {
      await recognizer.close();
    }
  }

  ReceiptOcrResult _parse(String rawText) {
    final items = <({String label, double price})>[];
    double? total;

    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _priceAtEnd.firstMatch(line);
      if (match == null) continue;
      final price = double.tryParse(match.group(1)!.replaceAll(',', ''));
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
