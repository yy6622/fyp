import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live foreign-exchange rates, used to show every Flights/Hotels price
/// (Duffel returns flight prices in whatever currency the fare was
/// quoted in; RollingGo returns hotel prices the same way) converted
/// into the traveller's own chosen currency (Account Setting >
/// Currency, [AppUser.currencyCode]) instead of whatever currency the
/// provider happened to quote. No API key, no account — Frankfurter
/// (https://frankfurter.dev) is a free, keyless, no-attribution-required
/// exchange-rate service covering 200+ currencies, live-verified against
/// its own docs before picking it (see claude/
/// session-2026-10-01-group-info-real-features.md "Phase 9").
///
/// Rates are fetched once (all of them, relative to a single USD base)
/// and cached in memory — a Flutter app showing a list of 15 hotel cards
/// shouldn't make 15 network calls just to display 15 prices, and
/// exchange rates don't move fast enough to need a fresh fetch per
/// screen anyway. [convert] is synchronous and reads only the cache —
/// call [ensureRatesLoaded] first (once, e.g. from a controller's
/// constructor) and rebuild (`notifyListeners()`) once it resolves so
/// prices that rendered before the rates arrived pick up the real
/// conversion on the next frame instead of staying stuck in the
/// original currency.
class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const String _base = 'https://api.frankfurter.dev/v2';
  static const String _ratesBaseCurrency = 'USD';
  static const Duration _ttl = Duration(hours: 6);

  Map<String, double>? _ratesPerUsd; // currency code -> units per 1 USD
  DateTime? _fetchedAt;
  Future<void>? _inFlight;

  bool get hasRates => _ratesPerUsd != null;

  /// The signed-in person's chosen display currency (Account Setting >
  /// Currency, [AppUser.currencyCode]) — kept up to date by [MainPage]'s
  /// long-lived profile subscription (the same one driving location
  /// tracking) for as long as they're signed in, so any page can read it
  /// synchronously without running its own profile stream just for this.
  /// Null for a signed-out session or before the first profile snapshot
  /// arrives — callers treat that the same as "no preference set" and
  /// fall back to showing each price in its original provider currency.
  /// Explore has its own dedicated, more immediately-fresh copy of this
  /// ([ExploreController.userCurrencyCode], driven by its own
  /// subscription) since it's the screen a currency change most visibly
  /// affects.
  String? lastKnownUserCurrency;

  /// Fetches/refreshes the rate table if it's missing or stale. Safe to
  /// call repeatedly (e.g. once per controller) — concurrent calls share
  /// the same in-flight request, and a failure leaves whatever rates
  /// were already cached in place (a temporarily-offline rate lookup
  /// shouldn't blank out prices that were converting fine a moment ago).
  Future<void> ensureRatesLoaded() {
    if (_ratesPerUsd != null && _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < _ttl) {
      return Future.value();
    }
    return _inFlight ??= _fetchRates().whenComplete(() => _inFlight = null);
  }

  Future<void> _fetchRates() async {
    // IMPORTANT: the endpoint is /v2/rates, not /v2/latest (that was the
    // older frankfurter.app v1 path) — that part was already confirmed
    // correct. What was still wrong (found via the diagnostic log added
    // for this exact bug): this app assumed the classic Frankfurter body
    // shape, `{"amount":1,"base":"USD","date":"...","rates":{"MYR":4.08,
    // ...}}` — a single object with one `rates` map. The real response
    // from this host is a flat JSON *array*, one record per currency:
    // `[{"date":"2026-10-01","base":"USD","quote":"MYR","rate":4.0806},
    // ...]`. `decoded['rates'] is! Map` was true for every single
    // response (there's no `rates` key at all on an array), so this
    // silently bailed out on every fetch, every time, and _ratesPerUsd
    // stayed null forever — indistinguishable from "no currency
    // preference set" from the outside, exactly like the /latest bug
    // before it. Parses the real `quote`/`rate` shape now; the old
    // `rates`-map shape is kept as a fallback in case a future response
    // ever reverts to it.
    final uri = Uri.parse('$_base/rates?base=$_ratesBaseCurrency');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        // Diagnostic-only console log (no UI change) — kept from the
        // previous round in case this host ever starts failing outright.
        // ignore: avoid_print
        print('[CurrencyService] GET $uri -> HTTP ${res.statusCode}: ${res.body}');
        return;
      }
      final decoded = jsonDecode(res.body);
      final rates = <String, double>{_ratesBaseCurrency: 1.0};
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map && entry['quote'] is String && entry['rate'] is num) {
            rates[(entry['quote'] as String).toUpperCase()] = (entry['rate'] as num).toDouble();
          }
        }
      } else if (decoded is Map && decoded['rates'] is Map) {
        final ratesJson = (decoded['rates'] as Map).cast<String, dynamic>();
        for (final entry in ratesJson.entries) {
          final v = entry.value;
          if (v is num) rates[entry.key.toUpperCase()] = v.toDouble();
        }
      } else {
        // ignore: avoid_print
        print('[CurrencyService] GET $uri -> 200 but unrecognized JSON shape: ${res.body}');
        return;
      }
      if (rates.length <= 1) {
        // ignore: avoid_print
        print('[CurrencyService] GET $uri -> 200 but parsed 0 currencies out of: ${res.body}');
        return;
      }
      _ratesPerUsd = rates;
      _fetchedAt = DateTime.now();
      // ignore: avoid_print
      print('[CurrencyService] loaded ${rates.length} rates (has MYR: ${rates.containsKey('MYR')})');
    } catch (e) {
      // Offline, timeout, unexpected response shape — keep whatever was
      // cached before (possibly nothing yet); callers fall back to the
      // original provider currency when conversion isn't available.
      // ignore: avoid_print
      print('[CurrencyService] GET $uri failed: $e');
    }
  }

  /// Converts [amount] from [from] to [to] (ISO 4217 codes) using the
  /// cached rate table — null if rates haven't loaded yet or either
  /// currency isn't in the table, so the caller can fall back to showing
  /// the original amount/currency rather than a wrong/blank price.
  double? convert(double amount, {required String from, required String to}) {
    final fromCode = from.toUpperCase();
    final toCode = to.toUpperCase();
    if (fromCode.isEmpty || toCode.isEmpty) return null;
    if (fromCode == toCode) return amount;
    final rates = _ratesPerUsd;
    if (rates == null) return null;
    final fromRate = rates[fromCode];
    final toRate = rates[toCode];
    if (fromRate == null || toRate == null) return null;
    return amount / fromRate * toRate;
  }

  /// The label shown in front of an amount for an ISO 4217 code — plain
  /// code by default, except where locals commonly use a different short
  /// label instead of the ISO code itself (e.g. Malaysians say "RM", not
  /// "MYR"). Display-only: [convert]/the rate table still key everything
  /// by the real ISO code.
  String _displayLabel(String code) {
    switch (code.toUpperCase()) {
      case 'MYR':
        return 'RM';
      default:
        return code.toUpperCase();
    }
  }

  /// [convert] plus formatting — the one call-site views actually use.
  /// Falls back to the original `"$currency $amount"` shape (matching
  /// what every price label looked like before this existed) whenever
  /// conversion isn't possible, so a missing/stale rate table degrades
  /// gracefully instead of hiding the price.
  String format(double amount, String fromCurrency, String? userCurrency) {
    if (userCurrency != null && userCurrency.isNotEmpty) {
      final converted = convert(amount, from: fromCurrency, to: userCurrency);
      if (converted != null) return '${_displayLabel(userCurrency)} ${converted.toStringAsFixed(0)}';
    }
    return '${_displayLabel(fromCurrency)} ${amount.toStringAsFixed(0)}';
  }
}
