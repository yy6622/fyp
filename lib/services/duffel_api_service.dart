import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../data/country_gateways.dart';
import '../models/duffel_models.dart';

class DuffelApiService {
  DuffelApiService._();
  static final DuffelApiService instance = DuffelApiService._();

  static const String _base = 'https://api.duffel.com';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $duffelApiKey',
        'Duffel-Version': 'v2',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  bool get isConfigured => duffelApiKey.isNotEmpty && duffelApiKey != 'YOUR_DUFFEL_ACCESS_TOKEN_HERE';

  /// [childAges] -- one entry per child, each 0-17 -- are sent to Duffel
  /// as bare `{'age': n}` passenger objects rather than `{'type':
  /// 'child', 'age': n}`: Duffel's own docs say to give a passenger
  /// EITHER age or type, never both, and it infers child/infant fares
  /// from the age itself. [cabinClass] must be one of Duffel's own
  /// four values ('economy', 'premium_economy', 'business', 'first') --
  /// no longer hardcoded to economy now that the Filter sheet's
  /// Travelers & Cabin picker lets the traveller choose (see
  /// filter_page.dart's _TravelersCabinSheet).
  Future<List<DuffelFlightOffer>> searchFlights({
    required String origin,
    required String destination,
    required DateTime departureDate,
    int adults = 1,
    List<int> childAges = const [],
    String cabinClass = 'economy',
  }) async {
    if (!isConfigured) {
      throw const DuffelApiException('Duffel API key is not set yet — see lib/config/secrets.dart.');
    }
    final originCode = await resolveDestinationCode(origin);
    final destinationCode = await resolveDestinationCode(destination);
    final body = {
      'data': {
        'slices': [
          {
            'origin': originCode,
            'destination': destinationCode,
            'departure_date': _dateOnly(departureDate),
          }
        ],
        'passengers': [
          ...List.generate(adults, (_) => {'type': 'adult'}),
          ...childAges.map((age) => {'age': age}),
        ],
        'cabin_class': cabinClass,
      }
    };
    final res = await _post('/air/offer_requests?return_offers=true', body);
    final offers = (res['offers'] as List?) ?? const [];
    final parsed = offers
        .map((o) => DuffelFlightOffer.fromJson((o as Map).cast<String, dynamic>()))
        .where((o) => o.airlineName != 'Duffel Airways')
        .toList();
    parsed.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
    return parsed;
  }

  Future<String> resolveDestinationCode(String freeText) async {
    final text = freeText.trim();
    if (_looksLikeIataCode(text)) return text;

    final viaCountry = kCountryGateways[text.toLowerCase()]?.flightIataCode;
    if (viaCountry != null) return viaCountry;

    // Trip/catalog destinations are stored as "City, Country" (see
    // country_gateways.dart's hotelPlaceQuery values and trip.destination).
    // That whole string never matches kCountryGateways' country-only keys,
    // so also try the part after the last comma before falling back to a
    // live lookup.
    if (text.contains(',')) {
      final countryPart = text.split(',').last.trim().toLowerCase();
      final viaCountryPart = kCountryGateways[countryPart]?.flightIataCode;
      if (viaCountryPart != null) return viaCountryPart;
    }

    final viaPlaces = await _resolveViaPlacesSuggestions(text);
    if (viaPlaces != null) return viaPlaces;

    // Some place lookups match a bare city name better than "City, Country".
    if (text.contains(',')) {
      final cityPart = text.split(',').first.trim();
      if (cityPart.isNotEmpty && cityPart != text) {
        final viaCity = await _resolveViaPlacesSuggestions(cityPart);
        if (viaCity != null) return viaCity;
      }
    }

    throw DuffelApiException('Could not find a matching airport for "$freeText" — try a city name instead (e.g. "Tokyo").');
  }

  bool _looksLikeIataCode(String s) => RegExp(r'^[A-Z]{3}$').hasMatch(s);

  String? _stringField(Map map, String key) {
    final v = map[key];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  /// The raw suggestion list for a From/To autocomplete field (the
  /// flight Filter sheet's route search -- see DuffelPlace's doc
  /// comment). Unlike [resolveDestinationCode]/[_resolveViaPlacesSuggestions]
  /// below, this doesn't guess a single best match or fall back to
  /// anything -- it's meant to be called on every keystroke (debounced
  /// by the caller) and shown as a picklist, so an empty result or a
  /// thrown error should just mean "no suggestions yet", not block typing.
  Future<List<DuffelPlace>> searchPlaces(String query) async {
    final text = query.trim();
    if (text.length < 2 || !isConfigured) return const [];
    final places = await _get('/places/suggestions', {'query': text});
    return places.map(DuffelPlace.fromJson).where((p) => p.iataCode.isNotEmpty).toList();
  }

  Future<String?> _resolveViaPlacesSuggestions(String query) async {
    List<Map<String, dynamic>> places;
    try {
      places = await _get('/places/suggestions', {'query': query});
    } catch (_) {
      return null;
    }
    try {
      if (places.isEmpty) return null;
      for (final p in places) {
        if (p['type'] == 'city') {
          final cityCode = _stringField(p, 'iata_city_code');
          if (cityCode != null) return cityCode;
        }
      }
      for (final p in places) {
        if (p['type'] == 'airport') {
          final code = _stringField(p, 'iata_code');
          if (code != null) return code;
        }
      }
      for (final p in places) {
        final airports = p['airports'];
        if (airports is List && airports.isNotEmpty && airports.first is Map) {
          final code = _stringField(airports.first as Map, 'iata_code');
          if (code != null) return code;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<DuffelStayResult>> searchStays({
    required String destinationQuery,
    required DateTime checkIn,
    required DateTime checkOut,
    int adults = 1,
    int rooms = 1,
  }) async {
    if (!isConfigured) {
      throw const DuffelApiException('Duffel API key is not set yet — see lib/config/secrets.dart.');
    }
    final resolvedQuery = kCountryGateways[destinationQuery.trim().toLowerCase()]?.hotelPlaceQuery ?? destinationQuery;
    final coords = await _geocode(resolvedQuery);
    if (coords == null) {
      throw DuffelApiException('Could not find a location for "$destinationQuery".');
    }
    final body = {
      'data': {
        'location': {
          'radius': 20,
          'geographic_coordinates': {'latitude': coords.$1, 'longitude': coords.$2},
        },
        'check_in_date': _dateOnly(checkIn),
        'check_out_date': _dateOnly(checkOut),
        'guests': List.generate(adults, (_) => {'type': 'adult'}),
        'rooms': rooms,
      }
    };
    final res = await _post('/stays/search', body);
    final results = (res['results'] as List?) ?? const [];
    return results.map((r) => DuffelStayResult.fromJson((r as Map).cast<String, dynamic>())).toList();
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(Uri.parse('$_base$path'), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      // Log the real cause for debugging (a CORS block, a timeout, a DNS
      // failure, ...) but never show it to the user — it leaks internal
      // URLs and exception class names and reads as a crash, not an error.
      developer.log('Duffel request failed: $e', name: 'DuffelApiService');
      throw const DuffelApiException("Couldn't reach the flight search service. Check your connection and try again.");
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DuffelApiException(_errorMessageFrom(res));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['data'] is Map) return (decoded['data'] as Map).cast<String, dynamic>();
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const DuffelApiException('Unexpected response from Duffel.');
  }

  Future<List<Map<String, dynamic>>> _get(String path, Map<String, String> query) async {
    http.Response res;
    try {
      res = await http
          .get(Uri.parse('$_base$path').replace(queryParameters: query), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      // Log the real cause for debugging (a CORS block, a timeout, a DNS
      // failure, ...) but never show it to the user — it leaks internal
      // URLs and exception class names and reads as a crash, not an error.
      developer.log('Duffel request failed: $e', name: 'DuffelApiService');
      throw const DuffelApiException("Couldn't reach the flight search service. Check your connection and try again.");
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DuffelApiException(_errorMessageFrom(res));
    }
    final decoded = jsonDecode(res.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) return const [];
    return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  String _errorMessageFrom(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      final errors = decoded is Map ? decoded['errors'] : null;
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map) return (first['message'] as String?) ?? (first['title'] as String?) ?? 'Duffel request failed.';
      }
    } catch (_) {
    }
    return 'Duffel request failed (${res.statusCode}).';
  }

  Future<(double, double)?> _geocode(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
    });
    http.Response res;
    try {
      res = await http.get(uri, headers: {
        'User-Agent': 'VoyaFYPApp/1.0 (student final-year project)',
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first as Map;
    final lat = double.tryParse((first['lat'] as String?) ?? '');
    final lon = double.tryParse((first['lon'] as String?) ?? '');
    if (lat == null || lon == null) return null;
    return (lat, lon);
  }
}
