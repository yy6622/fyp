import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'currency_service.dart';
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

  /// Set only when a receipt was converted from a foreign currency (see
  /// [scan]'s `localCurrency` parameter) -- the un-converted total as
  /// printed on the receipt, paired with [originalCurrency], purely so the
  /// traveller can see what they actually paid in local cash even though
  /// [total] (and every item/tax/subtotal figure) is always expressed in
  /// MYR for the rest of the app's maths to work.
  final double? originalTotal;
  final String? originalCurrency;

  final String? error;

  const ReceiptOcrResult({
    required this.items,
    this.storeName,
    this.subtotal,
    this.tax,
    this.total,
    this.discount,
    this.originalTotal,
    this.originalCurrency,
    this.error,
  });

  bool get isEmpty => items.isEmpty && total == null;

  /// Cross-check, not a guarantee: items + tax should roughly match the
  /// printed total (a few cents of slack for rounding adjustments that
  /// receipts often print as their own tiny line). When this is false the
  /// scan is still returned -- OCR can misread a digit -- but the caller
  /// can use it to tell the traveller "please double-check this scan"
  /// instead of silently trusting a read that doesn't add up.
  bool get looksConsistent {
    final t = total;
    if (t == null) return true;
    final itemSum = items.fold<double>(0, (s, i) => s + i.price);
    final expected = itemSum + (tax ?? 0) - (discount ?? 0);
    return (expected - t).abs() <= 0.5;
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

  // Price: optional currency marker, 1-3 digits, optional thousands groups,
  // a decimal point OR comma, exactly 2 decimal digits, at the end of the line.
  static final RegExp _priceAtEnd = RegExp(
    r'(?:RM|MYR|\$)?\s*(\d{1,3}(?:[,.]\d{3})*[.,]\d{2})\s*$',
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
    r'(?:¥|JPY|₩|KRW|₫|VND|Rp|IDR|Ft|HUF)?\s*(\d{1,3}(?:,\d{3})+|\d+)\s*(?:円|원)?\s*$',
    caseSensitive: false,
  );

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
    var result = _parseLines(rows, storeName: storeName, priceRegex: regex);
    if (result.isEmpty) {
      result = _parseLines(flatLines, storeName: storeName, priceRegex: regex);
    }
    return (result: result, storeName: storeName);
  }

  /// [localCurrency] is the trip destination's local currency (e.g. 'JPY'
  /// for a Japan trip -- see country_gateways.dart's `currencyForDestination`),
  /// NOT read off the photo itself: a receipt doesn't always show its
  /// currency clearly enough to OCR, but the trip the traveller is on
  /// already tells us what they were almost certainly paying in. Pass null
  /// (or 'MYR') for a Malaysia trip or when the destination isn't known --
  /// parsing and the returned amounts are unchanged from before this
  /// parameter existed.
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
      var usedWholeNumberFormat = false;
      if (attempt.result.isEmpty) {
        final wholeAttempt = _attemptParse(rows, flatLines, _priceAtEndWhole);
        if (!wholeAttempt.result.isEmpty) {
          attempt = wholeAttempt;
          usedWholeNumberFormat = true;
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
            _hasReceiptSignal(rows, _priceAtEndWhole) ||
            _hasReceiptSignal(flatLines, _priceAtEndWhole);
        if (!hasSignal) {
          return const ReceiptOcrResult(items: [], error: 'not a receipt');
        }
        return const ReceiptOcrResult(items: [], error: 'cannot scan');
      }

      // Only convert when the receipt actually turned out to be in the
      // SHAPE naturally expected for [currency] -- a decimal-currency trip
      // (anything not in _wholeNumberCurrencies) that parsed in decimal
      // format, or a whole-number-currency trip that genuinely needed the
      // whole-number fallback above. A whole-number-currency trip (JPY,
      // VND, ...) whose receipt parsed cleanly in plain decimal format
      // anyway is far more likely to already be a normal, familiar-looking
      // amount (paid by card, or just not actually in that destination's
      // currency -- see this function's demo/bug case above) than one that
      // still needs converting down from a whole-number currency's face
      // value, so that case is deliberately left unconverted instead of
      // compounding the mismatch.
      final formatMatchesDestination = usedWholeNumberFormat == destinationIsWholeNumber;
      final needsConversion = currency != null && currency != 'MYR' && formatMatchesDestination;
      final converted = needsConversion ? await _convertToMyr(attempt.result, currency!) : attempt.result;
      return _translateToEnglish(converted);
    } catch (e) {
      // ignore: avoid_print
      print('[ReceiptOcrService] scan threw: $e');
      return const ReceiptOcrResult(items: [], error: 'cannot scan');
    } finally {
      await recognizer.close();
    }
  }

  /// Converts every monetary figure the scan found from [currency] into
  /// MYR, using CurrencyService's live exchange rate (the same service
  /// insurance pricing already uses to convert MYR plan prices into a
  /// traveller's preferred currency -- same idea, opposite direction).
  /// Fails loudly rather than silently: if today's rate can't be fetched
  /// (e.g. offline), returning the raw foreign numbers as if they were
  /// already MYR would badly misrepresent the amount (a JPY 5,000 lunch
  /// is NOT RM 5,000), so this surfaces an error instead and leaves the
  /// traveller to enter the (already-converted, roughly-known) amount by
  /// hand rather than trust a wrong one.
  Future<ReceiptOcrResult> _convertToMyr(ReceiptOcrResult result, String currency) async {
    await CurrencyService.instance.ensureRatesLoaded();
    double? conv(double amount) => CurrencyService.instance.convert(amount, from: currency, to: 'MYR');

    final convertedItems = <({String label, double price})>[];
    for (final item in result.items) {
      final converted = conv(item.price);
      if (converted == null) {
        return const ReceiptOcrResult(items: [], error: 'cannot scan');
      }
      convertedItems.add((label: item.label, price: converted));
    }
    final subtotal = result.subtotal == null ? null : conv(result.subtotal!);
    final tax = result.tax == null ? null : conv(result.tax!);
    final discount = result.discount == null ? null : conv(result.discount!);
    final total = result.total == null ? null : conv(result.total!);
    if ((result.subtotal != null && subtotal == null) ||
        (result.tax != null && tax == null) ||
        (result.discount != null && discount == null) ||
        (result.total != null && total == null)) {
      return const ReceiptOcrResult(items: [], error: 'cannot scan');
    }

    return ReceiptOcrResult(
      items: convertedItems,
      storeName: result.storeName,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      originalTotal: result.total,
      originalCurrency: currency,
    );
  }

  /// Translates every item label (and the store name, if it's part of
  /// the display) that isn't already in English, so a receipt scanned in
  /// Japan/Korea/China/etc. shows readable English item names in the app
  /// instead of raw kanji/hiragana/hangul the traveller can't read. Runs
  /// AFTER OCR + currency conversion, on the already-cropped/parsed item
  /// list, not on the raw photo -- only the handful of labels that
  /// actually survived parsing get sent out, never the whole receipt
  /// text. Falls back to the original label per item on a translation
  /// failure (offline, quota, no confident translation) rather than
  /// failing the whole scan -- an untranslated label is still usable,
  /// unlike a wrong converted amount.
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
      originalTotal: result.originalTotal,
      originalCurrency: result.originalCurrency,
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
        // No decimal subunit to detect -- every comma here is a
        // thousands separator, full stop.
        ? double.tryParse(match.group(1)!.replaceAll(',', ''))
        : double.tryParse(match.group(1)!.replaceFirstMapped(RegExp(r'[,.](\d{2})$'), (m) => '.${m.group(1)}').replaceAll(',', ''));
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
      if ((expectedFromItems - total).abs() > 0.5 && (expectedFromItems - subtotal).abs() <= 0.5) {
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
