import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../data/country_gateways.dart';
import '../models/booking_details.dart';
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

  Future<String> createOrder({
    required String offerId,
    required List<DuffelOfferPassenger> offerPassengers,
    required List<PassengerDetail> passengerDetails,
    required double totalAmount,
    required String totalCurrency,
    required String contactEmail,
    required String contactPhone,
  }) async {
    if (!isConfigured) throw const DuffelApiException('Duffel API key is not set yet — see lib/config/secrets.dart.');
    if (offerId.isEmpty) throw const DuffelApiException('Missing Duffel offer id — please search again.');
    if (offerPassengers.isEmpty || offerPassengers.length != passengerDetails.length) {
      throw const DuffelApiException('Passenger count no longer matches the searched fare — please search again.');
    }

    final passengersPayload = <Map<String, dynamic>>[];
    for (var i = 0; i < offerPassengers.length; i++) {
      final detail = passengerDetails[i];
      final nameParts = detail.name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final givenName = nameParts.length > 1 ? nameParts.sublist(0, nameParts.length - 1).join(' ') : (nameParts.isNotEmpty ? nameParts.first : 'Traveller');
      final familyName = nameParts.length > 1 ? nameParts.last : 'Traveller';
      passengersPayload.add({
        'id': offerPassengers[i].id,
        'title': (detail.title ?? 'Mr').toLowerCase(),
        'gender': detail.gender == 'Female' ? 'f' : 'm',
        'given_name': givenName,
        'family_name': familyName,
        if (detail.dob != null) 'born_on': _dateOnly(detail.dob!),
        'email': contactEmail,
        'phone_number': contactPhone,
      });
    }

    final body = {
      'data': {
        'type': 'instant',
        'selected_offers': [offerId],
        // The traveller already paid us directly (Stripe/PayPal, just above
        // in booking_payment_page.dart) -- we are the merchant of record,
        // not the traveller's own card. There is no Duffel card-tokenisation
        // flow anywhere in this app to produce a real card_id (that needs
        // Duffel's own Components SDK to collect the card a SECOND time,
        // which we don't do), so "card" payment with a made-up card_id was
        // always going to be rejected by Duffel as invalid. "balance" pays
        // from this Duffel account's own prepaid balance instead, which is
        // the correct type for a platform that collects payment itself.
        'payments': [
          {
            'type': 'balance',
            'amount': totalAmount.toStringAsFixed(2),
            'currency': totalCurrency,
          }
        ],
        'passengers': passengersPayload,
      }
    };

    final res = await _post('/air/orders', body);
    return (res['id'] as String?) ?? '';
  }

  Future<String> resolveDestinationCode(String freeText) async {
    final text = freeText.trim();
    if (_looksLikeIataCode(text)) return text;

    final viaCountry = kCountryGateways[text.toLowerCase()]?.flightIataCode;
    if (viaCountry != null) return viaCountry;

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
