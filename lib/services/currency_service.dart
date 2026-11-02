import 'dart:convert';

import 'package:http/http.dart' as http;

class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const String _base = 'https://api.frankfurter.dev/v2';
  static const String _ratesBaseCurrency = 'USD';
  static const Duration _ttl = Duration(hours: 6);

  Map<String, double>? _ratesPerUsd;
  DateTime? _fetchedAt;
  Future<void>? _inFlight;

  bool get hasRates => _ratesPerUsd != null;

  String? lastKnownUserCurrency;

  Future<void> ensureRatesLoaded() {
    if (_ratesPerUsd != null && _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < _ttl) {
      return Future.value();
    }
    return _inFlight ??= _fetchRates().whenComplete(() => _inFlight = null);
  }

  Future<void> _fetchRates() async {
    final uri = Uri.parse('$_base/rates?base=$_ratesBaseCurrency');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
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
      print('[CurrencyService] GET $uri failed: $e');
    }
  }

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

  String _displayLabel(String code) {
    switch (code.toUpperCase()) {
      case 'MYR':
        return 'RM';
      default:
        return code.toUpperCase();
    }
  }

  String format(double amount, String fromCurrency, String? userCurrency) {
    if (userCurrency != null && userCurrency.isNotEmpty) {
      final converted = convert(amount, from: fromCurrency, to: userCurrency);
      if (converted != null) return '${_displayLabel(userCurrency)} ${converted.toStringAsFixed(0)}';
    }
    return '${_displayLabel(fromCurrency)} ${amount.toStringAsFixed(0)}';
  }
}
