import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ---------------------------------------------------------------------
// FR56 — OCR receipt scanning. Runs entirely on-device via Google ML
// Kit's text recognizer (no network call, no cloud OCR billing, nothing
// added to secrets.dart), then applies plain-text heuristics to turn the
// raw recognized text into draft line items + a possible total.
//
// This is deliberately a *draft*, never a silent auto-fill: a receipt
// photographed at an angle, in poor light, or in a font ML Kit doesn't
// recognize well can come back with nothing, a short list, or an
// occasional wrong line — which is exactly why AddExpenseController.
// scanReceipt feeds this into the existing Itemized Split review screen
// (where every item still needs a person assigned to it) rather than
// ever submitting an expense straight from it.
// ---------------------------------------------------------------------

/// What [ReceiptOcrService.scan] managed to read off a receipt photo.
class ReceiptOcrResult {
  final List<({String label, double price})> items;

  /// Only set when a line literally labelled total/grand total/amount
  /// due was found — never a sum ReceiptOcrService computed itself, so
  /// it can't silently disagree with what the receipt actually prints.
  final double? total;

  /// Set when [scan] itself threw (the recognizer failing to load/run —
  /// e.g. no Play Services text-recognition module available/downloaded
  /// yet, which needs a network connection the first time a device ever
  /// runs on-device OCR, or a corrupt/unreadable image file) — distinct
  /// from a clean run that simply found no price-shaped lines. Without
  /// this, both cases looked identical to the caller ("nothing found"),
  /// which made a real OCR failure indistinguishable from an honestly
  /// blank/illegible receipt.
  final String? error;

  const ReceiptOcrResult({required this.items, this.total, this.error});

  bool get isEmpty => items.isEmpty && total == null;
}

class ReceiptOcrService {
  ReceiptOcrService._();
  static final ReceiptOcrService instance = ReceiptOcrService._();

  /// A trailing price on a receipt line: an optional currency marker
  /// (RM/MYR/$) then a number with exactly 2 decimal places — what every
  /// real line-item price, subtotal and total look like on a receipt.
  /// Requiring the 2 decimals keeps this from also matching a bare
  /// quantity like "x2" or a product code.
  static final RegExp _priceAtEnd = RegExp(
    r'(?:RM|MYR|\$)?\s*(\d{1,3}(?:[,.]\d{3})*\.\d{2})\s*$',
    caseSensitive: false,
  );

  static final RegExp _totalWord = RegExp(r'\b(grand\s*total|total|amount\s*due)\b', caseSensitive: false);
  static final RegExp _subtotalWord = RegExp(r'\bsub[\s-]?total\b', caseSensitive: false);

  /// Lines that mention a price but aren't a purchasable item — receipt
  /// boilerplate (tax lines, payment method, thank-you footer, ...).
  static final RegExp _nonItemWord = RegExp(
    r'\b(subtotal|sub-total|tax|gst|sst|service\s*charge|cash|change|card|visa|master|'
    r'rounding|discount|vat|qty|quantity|thank\s*you|receipt\s*no|invoice|cashier|'
    r'table\s*no|order\s*no|date|time)\b',
    caseSensitive: false,
  );

  /// Reads [image]'s text and parses it into draft items/total. Never
  /// throws — any OCR/platform failure (corrupt file, unsupported
  /// format) just comes back as an empty result, which the caller
  /// already treats the same as "couldn't read anything useful".
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

      // A real total line ("Total RM 45.00", "Grand Total ... 45.00") —
      // but never a subtotal, which matches "total" too. Keep the LAST
      // one seen: receipts sometimes print subtotal, then tax, then the
      // real total further down, and the last total-labelled line is the
      // one most likely to be the final amount actually due.
      if (_totalWord.hasMatch(line) && !_subtotalWord.hasMatch(line)) {
        total = price;
        continue;
      }
      if (_nonItemWord.hasMatch(line)) continue;

      final label = line.substring(0, match.start).trim();
      // A bare quantity/code with no real wording ("2", "x3", "A102")
      // isn't a nameable item — skip rather than add a nameless row.
      if (label.isEmpty || !RegExp(r'[A-Za-z]{2,}').hasMatch(label)) continue;

      items.add((label: label, price: price));
    }

    return ReceiptOcrResult(items: items, total: total);
  }
}
