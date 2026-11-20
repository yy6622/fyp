import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'name_translation_service.dart';

class ReceiptOcrResult {
  final List<({String label, double price})> items;

  /// Best-effort guess at the business name, read from the first few
  /// plausible text lines near the TOP of the receipt (store names are
  /// almost always printed before the address/tel/invoice-number block).
  /// This is a positional heuristic, not a trained classifier -- it can
  /// come back null (or wrong) if the photo is cropped above the name, or
  /// if the receipt's header layout is unusual.
  final String? storeName;

  final double? subtotal;

  /// Sum of every tax/GST/SST/VAT/service-charge line found (several can
  /// appear on one receipt). Separate from [items] -- this money wasn't
  /// spent on any one item, it's a charge on top of the whole order.
  final double? tax;

  final double? total;

  /// Sum of every voucher/loyalty/coupon/promo discount line found
  /// (always a positive magnitude -- the amount taken OFF the bill, not a
  /// negative price). Kept separate from [items] for the same reason
  /// [tax] is: it isn't something any one item or person "owns", so the
  /// caller splits it equally across the trip's members, same as tax,
  /// rather than trying to pro-rate it per item.
  final double? discount;

  /// Currency label for the unconverted amounts shown on the receipt.
  /// An explicit ISO code/symbol on the receipt wins over the trip destination.
  final String? currencyCode;
  final bool currencyDetectedOnReceipt;

  final String? error;

  const ReceiptOcrResult({
    required this.items,
    this.storeName,
    this.subtotal,
    this.tax,
    this.total,
    this.discount,
    this.currencyCode,
    this.currencyDetectedOnReceipt = false,
    this.error,
  });

  bool get isEmpty => items.isEmpty && total == null;

  /// Some receipts show informational/inclusive VAT or GST separately even
  /// though the product prices already include it. Do not add that tax to
  /// the expense a second time. Check against the printed total, not a
  /// country assumption (tax conventions and till formats differ).
  bool get taxAlreadyIncluded {
    if (total == null || tax == null || tax! <= 0 || items.isEmpty) return false;
    final itemSum = items.fold<double>(0, (s, i) => s + i.price);
    return (itemSum - (discount ?? 0) - total!).abs() <= 0.05;
  }

  /// Tax to ADD to item prices (zero when already included in the prices).
  double get additionalTax => taxAlreadyIncluded ? 0 : (tax ?? 0);

  /// Cross-check the parsed item amounts against the printed receipt
  /// total. Included-tax and extra-tax receipts are both supported; when
  /// the check fails the UI must ask the user to verify the scan.
  bool get looksConsistent {
    final t = total;
    if (t == null || items.isEmpty) return true;
    final itemSum = items.fold<double>(0, (s, i) => s + i.price);
    final netItems = itemSum - (discount ?? 0);
    // Inclusive-tax receipts and exclusive-tax receipts are both valid.
    return (netItems + (tax ?? 0) - t).abs() <= 0.5 ||
        (netItems - t).abs() <= 0.5;
  }

  /// Best-effort category guess from what the scan found (store name +
  /// item labels), matched against this app's fixed expense categories
  /// (see expense_details_form_page.dart's `_categories`). Returns null
  /// when nothing in the text gave any signal at all, so the caller can
  /// keep its own existing default instead of being forced into a guess
  /// with zero basis. Keyword matching, not a trained classifier -- same
  /// honesty as [storeName]/[looksConsistent] above.
  String? get guessedCategory {
    final haystack = ([storeName, ...items.map((i) => i.label)].whereType<String>().join(' ')).toLowerCase();
    if (haystack.trim().isEmpty) return null;
    bool any(List<String> words) => words.any(haystack.contains);

    if (any(const [
      'hotel', 'resort', 'inn', 'homestay', 'lodge', 'hostel', 'airbnb', 'motel', 'guesthouse', 'guest house',
    ])) {
      return 'Accommodation';
    }
    if (any(const [
      'grab', 'taxi', 'uber', 'petrol', 'petronas', 'shell', 'caltex', 'parking', 'toll',
      'touch n go', "touch 'n go", 'tng', 'lrt', 'mrt', 'ktm', 'airasia', 'airline', 'flight', 'car rental',
    ])) {
      return 'Transport';
    }
    if (any(const [
      'ticket', 'admission', 'museum', 'zoo', 'theme park', 'cinema', 'gsc', 'tgv', 'tour',
      'attraction', 'aquarium', 'water park', 'waterpark',
    ])) {
      return 'Activities';
    }
    if (any(const [
      'mall', 'pharmacy', 'watsons', 'guardian', 'mart', 'supermarket', 'hypermarket', 'boutique', 'souvenir', 'duty free',
    ])) {
      return 'Shopping';
    }
    if (any(const [
      'restaurant', 'cafe', 'coffee', 'mcdonald', 'kfc', 'starbucks', 'bakery', 'bar', 'nasi',
      'food court', 'eatery', 'bistro', 'diner', 'pizza', 'burger', 'nugget', 'fries',
    ])) {
      return 'Food & Drinks';
    }
    return null;
  }
}

class ReceiptOcrService {
  ReceiptOcrService._();
  static final ReceiptOcrService instance = ReceiptOcrService._();

  // Price at the end of a reconstructed receipt row. Accept ungrouped
  // four-plus digit amounts (1234.56), comma/dot thousands separators
  // (1,234.56 / 1.234,56), and common currency prefixes or suffixes.
  // Require TWO decimal digits to avoid matching order/phone numbers.
  static final RegExp _priceAtEnd = RegExp(
    r'(?:RM|MYR|SGD|USD|\$|€|£)?\s*(\d+(?:[.,]\d{3})*[.,]\d{2})\s*(?:RM|MYR|SGD|USD|€|£)?\s*$',
    caseSensitive: false,
  );

  // Currencies that are printed as plain whole numbers in practice (JPY,
  // KRW, VND, IDR, HUF have no commonly-used decimal subunit on a till
  // receipt) -- _priceAtEnd's "must end in exactly 2 decimal digits" rule
  // would never match any of these at all. Only used when the trip's
  // destination resolves to one of these currencies (see scan()); every
  // other receipt keeps using the decimal-required pattern above exactly
  // as before.
  static const Set<String> _wholeNumberCurrencies = {'JPY', 'KRW', 'VND', 'IDR', 'HUF'};

  /// The right ML Kit recognizer model for the destination's script --
  /// Latin's model cannot read kanji/hiragana/katakana (or Hangul, or
  /// Chinese characters) at all, so a receipt in one of these scripts
  /// previously came back as if the photo had no text in it whatsoever.
  TextRecognitionScript _scriptFor(String? currency) {
    switch (currency) {
      case 'JPY':
        return TextRecognitionScript.japanese;
      case 'KRW':
        return TextRecognitionScript.korean;
      case 'CNY':
        return TextRecognitionScript.chinese;
      default:
        return TextRecognitionScript.latin;
    }
  }

  // Same idea as _priceAtEnd but for a currency with no decimal subunit:
  // either a comma-grouped number ("12,000") or a plain run of digits of
  // any length ("500", "25000") -- NOT capped at 3 digits like the plain
  // fallback in _priceAtEnd's group would be, since a 4+ digit whole
  // number with no separator is completely normal for these currencies.
  static final RegExp _priceAtEndWhole = RegExp(
    r'(?:¥|JPY|₩|KRW|₫|VND|Rp|IDR|Ft|HUF)?\s*(\d{1,3}(?:[,.]\d{3})+|\d+)\s*(?:円|원)?\s*$',
    caseSensitive: false,
  );

  // Whole-number parsing must not be attempted indiscriminately: a normal
  // MYR receipt's invoice number/date could otherwise be read as an item.
  static final RegExp _wholeCurrencyMarker = RegExp(
    r'¥|JPY|₩|KRW|₫|VND|\bRp\b|\bIDR\b|\bHUF\b|\bFt\b|円|원',
    caseSensitive: false,
  );

  // Once the currency's price is matched, the last separator before exactly
  // two digits is the decimal separator, irrespective of locale. All other
  // separators are thousands grouping and must be removed.
  double? _decimalPrice(String raw) {
    final decimalSeparator = raw.lastIndexOf(RegExp(r'[.,]'));
    if (decimalSeparator < 0) return null;
    final major = raw.substring(0, decimalSeparator).replaceAll(RegExp(r'[.,]'), '');
    final minor = raw.substring(decimalSeparator + 1);
    return double.tryParse('$major.$minor');
  }

  static final RegExp _totalWord = RegExp(
    r'\b(grand\s*total|total|amount\s*due)\b|(合計|お会計|会計)',
    caseSensitive: false,
  );
  static final RegExp _subtotalWord = RegExp(r'\bsub[\s-]?total\b', caseSensitive: false);

  // Checked BEFORE _totalWord: a line like "TakeOut Total (incl Tax)" reads
  // as a total, but the word actually being reported is the tax figure, so
  // tax-ness wins when both appear together.
  static final RegExp _taxWord = RegExp(r'\b(tax|gst|sst|vat|service\s*charge)\b', caseSensitive: false);

  // Checked alongside tax, before the generic "total" word, for the same
  // reason: "Total after discount" contains both words but is reporting
  // the discount figure, not a second total.
  static final RegExp _discountWord = RegExp(
    r'\b(discount|voucher|coupon|promo(tion)?|loyalty|redeem(ed)?|rebate|cashback)\b',
    caseSensitive: false,
  );

  static final RegExp _nonItemWord = RegExp(
    r'\b(cash|change|card|visa|master|rounding|qty|quantity|thank\s*you|'
    r'receipt\s*no|invoice|cashier|table\s*no|order\s*no|date|time|balance|'
    r'amount\s*paid|paid|net\s*total)\b'
    // Japanese receipt noise that isn't an item and isn't a total/tax we
    // can safely add up (consumption tax on a Japanese receipt is usually
    // already included in the total, unlike Malaysia's SST/GST, so this
    // is excluded rather than added as a second tax figure on top).
    r'|(消費税|内税|外税|現金|お釣り|お預り|客数|名様|卓|レジ|伝票|店番|領収証|ありがとう)',
    caseSensitive: false,
  );

  // Receipt header/footer metadata (phone number, address block, store
  // number, register number, table number, receipt/invoice number,
  // customer number, printed date) -- checked STRUCTURALLY (digit/hyphen
  // shape, "No:" markers) rather than by keyword, because a line like this
  // stays recognisably a phone number or a reference number even when the
  // OCR model misreads the surrounding script entirely (e.g. a kanji like
  // 店 getting read as a stray Latin "E" still leaves "No:0001412" with its
  // digit shape intact). Without this, these lines were being read as
  // priced items -- e.g. "TEL:06-6926-0777" or "都島本通3-21-3" matching the
  // generic "line ending in digits" price pattern below and being added as
  // a bogus RM 0.xx "item".
  static final RegExp _metadataNoise = RegExp(
    r'\b(tel|phone|fax)\s*[:.]|' // phone number labels
    r'\bno[.:]\s*\d|' // "Store No:", "Table No:", "Receipt No:", "Customer No. 24"
    r'\d{1,4}-\d{1,4}(-\d{1,4})?|' // hyphenated address block / phone fragment
    r'\d{4}[-/]\d{1,2}[-/]\d{1,2}|' // ISO-ish date
    r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|' // day/month/year date
    r'\d{7,}', // long unseparated digit run -- a store/register/receipt/customer reference number
    caseSensitive: false,
  );

  // A label is "real" if it has at least 2 Latin letters, OR at least one
  // CJK ideograph / kana / Hangul syllable -- a single kanji can already
  // be a meaningful word, unlike a lone stray Latin letter.
  static final RegExp _hasRealWord = RegExp(r'[A-Za-z]{2,}|[\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7A3]');

  // Store-name extraction: only lines that could plausibly be a business
  // name, and only near the very top of the receipt (checked against the
  // first few reconstructed rows -- see scan()).
  static final RegExp _storeHeaderWord = RegExp(
    r'^(tax\s*invoice|invoice|official\s*receipt|receipt|cash\s*bill|simplified\s*tax\s*invoice|order\s*summary)$',
    caseSensitive: false,
  );
  static final RegExp _storeNoiseLine = RegExp(r'(tel|phone|fax)\s*[:.]|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{7,}', caseSensitive: false);

  // A much weaker "this line mentions money at all" signal, used only to
  // decide between "not a receipt" and "couldn't read this receipt" once
  // full parsing has already failed -- see _hasReceiptSignal below.
  static final RegExp _looksMonetary = RegExp(r'[\$\u00a5\u20a9\u20ab]|\bRM\b|\bMYR\b|\d+[.,]\d{2}\b');

  /// True if [lines] contains at least one thing an actual receipt would
  /// have -- a price-shaped number, or a total/subtotal/tax label -- or,
  /// failing that, at least two lines that merely look monetary. Used only
  /// after normal item/total parsing has already failed, to tell a photo
  /// that plainly isn't a receipt (a selfie, a landscape, a random
  /// document -- no price or money-shaped text anywhere) apart from an
  /// actual receipt that OCR just couldn't read cleanly (blur, glare, an
  /// unfamiliar layout) -- those two should show the traveller different
  /// messages instead of the same generic "couldn't scan" either way.
  bool _hasReceiptSignal(List<String> lines, RegExp priceRegex) {
    var monetaryHits = 0;
    for (final line in lines) {
      if (priceRegex.hasMatch(line)) return true;
      if (_totalWord.hasMatch(line) || _subtotalWord.hasMatch(line) || _taxWord.hasMatch(line)) return true;
      if (_looksMonetary.hasMatch(line)) monetaryHits++;
    }
    return monetaryHits >= 2;
  }

  // Tries one price-format regex end to end (reconstructed rows, then the
  // flat-text fallback if that finds nothing) and reports whether it found
  // anything real, plus which store name it read under that format --
  // _extractStoreName also needs the price shape, to correctly skip a
  // priced line when picking the header's business-name line.
  ({ReceiptOcrResult result, String? storeName}) _attemptParse(
      List<String> rows, List<String> flatLines, RegExp regex) {
    final storeName = _extractStoreName(rows, priceRegex: regex);
    final rowResult = _parseLines(rows, storeName: storeName, priceRegex: regex);
    final flatResult = _parseLines(flatLines, storeName: storeName, priceRegex: regex);
    // OCR sometimes splits price and description into separate TextLines.
    // Prefer the candidate with more recoverable items/total, rather than
    // accepting a partially parsed row reconstruction immediately.
    int score(ReceiptOcrResult r) {
      var result = r.items.length * 3 + (r.total != null ? 4 : 0) +
          (r.subtotal != null ? 1 : 0);
      if (r.items.isNotEmpty && r.total != null) {
        // A longer list of bad OCR rows must not beat a shorter list that
        // correctly reconciles to the receipt's printed grand total.
        result += r.looksConsistent ? 5 : -10;
      }
      return result;
    }
    final result = score(flatResult) > score(rowResult) ? flatResult : rowResult;
    return (result: result, storeName: storeName);
  }

  /// [localCurrency] is the trip destination's local currency (e.g. 'JPY'
  /// for a Japan trip -- see country_gateways.dart's `currencyForDestination`),
  /// Used only for parsing whole-number prices and as a fallback currency
  /// label when the receipt does not explicitly show its own currency.
  /// Neither receipt totals nor item prices are exchanged into MYR.
  Future<ReceiptOcrResult> scan(File image, {String? localCurrency}) async {
    final currency = (localCurrency == null || localCurrency.isEmpty) ? null : localCurrency.toUpperCase();
    final destinationIsWholeNumber = currency != null && _wholeNumberCurrencies.contains(currency);

    final recognizer = TextRecognizer(script: _scriptFor(currency));
    try {
      final recognized = await recognizer.processImage(InputImage.fromFile(image));
      final rows = _reconstructRows(recognized);
      final flatLines = recognized.text.split('\n');

      // Which price SHAPE is actually printed on this receipt decides the
      // regex -- not just the trip's destination currency. A traveller can
      // pay in a different currency than their destination (a card charge,
      // cash left over from an earlier stop, a duty-free counter billing
      // its own way), and a receipt whose prices plainly use 2 decimal
      // places should always be read that way even on a JPY/VND/KRW/IDR/
      // HUF trip, rather than being torn apart by a format expecting bare
      // whole numbers -- that used to truncate "48.00" down to a bogus
      // "00" and chop the item's own name into "Dolor Sit 48." instead of
      // reading the real "Dolor Sit" for RM 48.00. The decimal format is
      // tried FIRST always, and it's free to try: a genuine whole-number
      // receipt never ends a line in exactly 2 decimal digits after a
      // separator, so it can never accidentally match here. The whole-
      // number format is only used as a fallback when decimal finds
      // nothing at all.
      var attempt = _attemptParse(rows, flatLines, _priceAtEnd);
      if (attempt.result.isEmpty &&
          (destinationIsWholeNumber || _wholeCurrencyMarker.hasMatch(recognized.text))) {
        final wholeAttempt = _attemptParse(rows, flatLines, _priceAtEndWhole);
        if (!wholeAttempt.result.isEmpty) {
          attempt = wholeAttempt;
        }
      }

      if (attempt.result.isEmpty) {
        // Nothing matched either way. Keep the raw OCR read in a debug
        // log only -- the traveller just needs a short, plain "couldn't
        // scan this" message, not a dump of recognized text and rows.
        final rawPreview = _clip(recognized.text.trim().replaceAll('\n', ' / '), 300);
        final rowsPreview = _clip(rows.join(' | '), 300);
        // ignore: avoid_print
        print('[ReceiptOcrService] no match. raw: "$rawPreview" rows: "$rowsPreview"');
        final hasSignal = _hasReceiptSignal(rows, _priceAtEnd) ||
            _hasReceiptSignal(flatLines, _priceAtEnd) ||
            (destinationIsWholeNumber &&
                (_hasReceiptSignal(rows, _priceAtEndWhole) ||
                 _hasReceiptSignal(flatLines, _priceAtEndWhole)));
        if (!hasSignal) {
          return const ReceiptOcrResult(items: [], error: 'not a receipt');
        }
        return const ReceiptOcrResult(items: [], error: 'cannot scan');
      }

      // Never convert receipt amounts. They are saved exactly as scanned.
      // A currency token printed on the receipt is stronger evidence than
      // the trip destination; fall back to destination when it is absent.
      final explicitCurrency = _currencyPrintedOnReceipt(recognized.text);
      final result = attempt.result;
      return _translateToEnglish(ReceiptOcrResult(
        items: result.items,
        storeName: result.storeName,
        subtotal: result.subtotal,
        tax: result.tax,
        total: result.total,
        discount: result.discount,
        currencyCode: explicitCurrency ?? currency,
        currencyDetectedOnReceipt: explicitCurrency != null,
      ));
    } catch (e) {
      // ignore: avoid_print
      print('[ReceiptOcrService] scan threw: $e');
      return const ReceiptOcrResult(items: [], error: 'cannot scan');
    } finally {
      await recognizer.close();
    }
  }

  // Symbols such as '$' can mean several currencies; ignore those and
  // use the destination fallback instead of guessing USD.
  static String? _currencyPrintedOnReceipt(String text) {
    final match = RegExp(
      r'\b(MYR|RM|SGD|USD|EUR|GBP|JPY|KRW|CNY|TWD|HKD|THB|VND|IDR|PHP|INR|AUD|NZD|CAD|CHF|AED|SAR|TRY|ZAR|BRL|MXN)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      final value = match.group(1)!.toUpperCase();
      return value == 'RM' ? 'MYR' : value;
    }
    // ¥ is ambiguous between JPY and CNY; prefer the trip destination.
    if (text.contains('¥')) return null;
    if (text.contains('₩')) return 'KRW';
    if (text.contains('€')) return 'EUR';
    if (text.contains('£')) return 'GBP';
    if (text.contains('฿')) return 'THB';
    if (text.contains('₫')) return 'VND';
    if (text.contains('₹')) return 'INR';
    return null;
  }

  /// Translates every item label (and the store name, if it's part of
  /// the display) that isn't already in English, so a receipt scanned in
  /// Japan/Korea/China/etc. shows readable English item names in the app
  /// instead of raw kanji/hiragana/hangul the traveller can't read. Runs
  /// AFTER OCR, on the already-cropped/parsed item
  /// list, not on the raw photo -- only the handful of labels that
  /// actually survived parsing get sent out, never the whole receipt
  /// text. Falls back to the original label per item on a translation
  /// failure (offline, quota, no confident translation) rather than
  /// failing the whole scan -- an untranslated label is still usable.
  Future<ReceiptOcrResult> _translateToEnglish(ReceiptOcrResult result) async {
    final needsTranslation = result.items.any((i) => NameTranslationService.looksNonEnglish(i.label)) ||
        (result.storeName != null && NameTranslationService.looksNonEnglish(result.storeName!));
    if (!needsTranslation) return result;

    final itemFutures = result.items.map((item) async {
      if (!NameTranslationService.looksNonEnglish(item.label)) return item;
      try {
        final english = await NameTranslationService.instance.translateToEnglish(item.label);
        return english == null ? item : (label: english, price: item.price);
      } catch (_) {
        return item;
      }
    }).toList();
    final storeNameNeedsTranslation = result.storeName != null && NameTranslationService.looksNonEnglish(result.storeName!);
    final storeNameFuture = storeNameNeedsTranslation
        ? NameTranslationService.instance.translateToEnglish(result.storeName!).catchError((_) => null)
        : Future<String?>.value(null);

    final translatedItems = await Future.wait(itemFutures);
    final translatedStoreName = await storeNameFuture;

    return ReceiptOcrResult(
      items: translatedItems,
      storeName: translatedStoreName ?? result.storeName,
      subtotal: result.subtotal,
      tax: result.tax,
      total: result.total,
      discount: result.discount,
      currencyCode: result.currencyCode,
      currencyDetectedOnReceipt: result.currencyDetectedOnReceipt,
      error: result.error,
    );
  }

  String _clip(String s, int max) => s.length > max ? '${s.substring(0, max)}…' : s;

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
      final gapThreshold = avgHeight * 0.72;
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

  // Classifies a single already-trimmed, non-empty row: null means "not a
  // priced line at all, or a priced line that's noise (metadata/non-item
  // keyword)"; otherwise its kind is 'subtotal' | 'tax' | 'discount' |
  // 'total' | 'item', with [label] only set for 'item'. Factored out of
  // _parseLines so the
  // item-region crop below and the main collection pass classify every row
  // exactly the same way -- they can never disagree about what a row is.
  ({String kind, double price, String? label})? _classifyLine(String line, RegExp regex, bool isWholeNumberFormat) {
    final match = regex.firstMatch(line);
    if (match == null) return null;
    final price = isWholeNumberFormat
        // Both 12,000 and 12.000 mean twelve thousand for these currencies.
        ? double.tryParse(match.group(1)!.replaceAll(RegExp(r'[.,]'), ''))
        : _decimalPrice(match.group(1)!);
    if (price == null || price <= 0) return null;
    // A row like "INV# 002440100073367" has no decimal point either, so in
    // whole-number mode it would otherwise read as a plausible price. No
    // real receipt line (even a VND/IDR total) runs into the tens of
    // millions, so this cheaply rejects an invoice/reference number that
    // slipped past the keyword filters below without needing to special-
    // case every possible header label.
    if (isWholeNumberFormat && price > 100000000) return null;

    // Order matters: subtotal/tax are checked before the generic "total"
    // word, since a line like "TakeOut Total (incl Tax)" contains both
    // words but is really reporting the tax figure, not a second total.
    if (_subtotalWord.hasMatch(line)) return (kind: 'subtotal', price: price, label: null);
    if (_taxWord.hasMatch(line)) return (kind: 'tax', price: price, label: null);
    if (_discountWord.hasMatch(line)) return (kind: 'discount', price: price, label: null);
    if (_totalWord.hasMatch(line)) return (kind: 'total', price: price, label: null);
    if (_nonItemWord.hasMatch(line)) return null;
    if (_metadataNoise.hasMatch(line)) return null;

    final label = line.substring(0, match.start).trim();
    if (label.isEmpty || !_hasRealWord.hasMatch(label)) return null;
    return (kind: 'item', price: price, label: label);
  }

  ReceiptOcrResult _parseLines(List<String> rawLines, {String? storeName, RegExp? priceRegex}) {
    final regex = priceRegex ?? _priceAtEnd;
    final isWholeNumberFormat = identical(regex, _priceAtEndWhole);
    final lines = rawLines.map((l) => l.trim()).toList();
    final classified = lines.map((l) => l.isEmpty ? null : _classifyLine(l, regex, isWholeNumberFormat)).toList();

    // Crop the item table out of the receipt: items only ever appear
    // between the store's header block (name, address, phone,
    // invoice/table number, date) and the grand total line. A header or
    // footer line that happens to slip past every keyword/structural
    // noise filter above (OCR can garble the very keyword that would have
    // flagged it) used to still get added as a bogus item simply because
    // nothing stopped the scan from considering every row equally.
    // Instead, item collection is restricted to the rows between the
    // FIRST row that already looks like a genuine priced item on its own
    // merits (whatever the header's actual length on this receipt) and
    // the FIRST confirmed grand-total row at or after it (everything past
    // that is footer -- cash tendered, change, "thank you"). Subtotal/tax/
    // discount/total themselves are still recognised across the WHOLE
    // receipt regardless of this crop, since they're only ever matched by
    // their own explicit keyword, never just by shape, so there's no
    // header/footer line that could be mistaken for one.
    var itemsStart = lines.length;
    for (var i = 0; i < classified.length; i++) {
      if (classified[i]?.kind == 'item') {
        itemsStart = i;
        break;
      }
    }
    var itemsEnd = lines.length;
    for (var i = itemsStart; i < classified.length; i++) {
      if (classified[i]?.kind == 'total') {
        itemsEnd = i;
        break;
      }
    }

    final items = <({String label, double price})>[];
    double? subtotal;
    double? tax;
    double? discount;
    double? total;
    for (var i = 0; i < classified.length; i++) {
      final c = classified[i];
      if (c == null) continue;
      switch (c.kind) {
        case 'subtotal':
          subtotal = c.price;
          break;
        case 'tax':
          tax = (tax ?? 0) + c.price;
          break;
        case 'discount':
          discount = (discount ?? 0) + c.price;
          break;
        case 'total':
          total = c.price;
          break;
        case 'item':
          if (i >= itemsStart && i < itemsEnd) {
            items.add((label: c.label!, price: c.price));
          }
          break;
      }
    }

    if (total != null && subtotal != null) {
      final itemSum = items.fold<double>(0, (s, i) => s + i.price);
      final expectedFromItems = itemSum + (tax ?? 0) - (discount ?? 0);
      final inclusiveExpected = itemSum - (discount ?? 0);
      if ((expectedFromItems - total).abs() > 0.5 &&
          (inclusiveExpected - total).abs() > 0.5 &&
          ((expectedFromItems - subtotal).abs() <= 0.5 ||
           (inclusiveExpected - subtotal).abs() <= 0.5)) {
        // The "TOTAL" row's own price doesn't add up with the items at
        // all, but the subtotal does -- almost always because the row
        // reconstruction above merged the real TOTAL line with an
        // unrelated line below it (e.g. "CHANGE $25.80"), picking up that
        // line's price instead of the total's own. A number that can't
        // possibly be the total is worse than falling back to the
        // subtotal, which is only ever matched by its own explicit
        // keyword and is far less likely to collide with footer noise.
        total = subtotal;
      }
    }

    return ReceiptOcrResult(
      items: items,
      storeName: storeName,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
    );
  }

  /// Checked against only the first handful of reconstructed rows -- a
  /// store name is always printed before the address/tel/invoice-number
  /// block, never in the middle or at the bottom of a receipt.
  String? _extractStoreName(List<String> rows, {RegExp? priceRegex}) {
    final regex = priceRegex ?? _priceAtEnd;
    for (final rawLine in rows.take(6)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (regex.hasMatch(line)) continue;
      if (_storeNoiseLine.hasMatch(line)) continue;
      if (_storeHeaderWord.hasMatch(line)) continue;
      if (!RegExp(r'[A-Za-z]{3,}|[\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7A3]{2,}').hasMatch(line)) continue;
      return line;
    }
    return null;
  }
}
