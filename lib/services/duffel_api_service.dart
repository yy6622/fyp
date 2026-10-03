import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../data/country_gateways.dart';
import '../models/duffel_models.dart';

/// Talks to Duffel's real Flights + Stays REST API (see
/// https://duffel.com/docs/api) — this is the app's real flights/hotels
/// data source, replacing the fixed seeded `catalog_flights`/
/// `catalog_hotels` Firestore collections whenever a real search is run.
/// The seeded catalogue is kept as-is as the "trending/browse" fallback
/// for when there's nothing to search with yet (see [ExploreController]).
///
/// Auth: a single Bearer access token in [duffelApiKey] (see
/// `lib/config/secrets.dart` — use a `duffel_test_...` sandbox token
/// while developing).
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

  /// One-way flight search. [origin]/[destination] can be an IATA
  /// airport code ("NRT"), an IATA city code ("TYO"), an exact country
  /// name from [kCountries] ("Japan" — how a trip's own destination is
  /// always stored, see [resolveDestinationCode]'s doc comment), or
  /// ordinary city text ("Tokyo") typed into a search box. Whatever form
  /// it's in, it's resolved to the IATA code Duffel actually requires
  /// before the request is sent — Duffel itself has no idea what
  /// "Japan" means. Returns the offers Duffel could find, cheapest
  /// first.
  Future<List<DuffelFlightOffer>> searchFlights({
    required String origin,
    required String destination,
    required DateTime departureDate,
    int adults = 1,
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
        'passengers': List.generate(adults, (_) => {'type': 'adult'}),
        'cabin_class': 'economy',
      }
    };
    final res = await _post('/air/offer_requests?return_offers=true', body);
    final offers = (res['offers'] as List?) ?? const [];
    final parsed = offers
        .map((o) => DuffelFlightOffer.fromJson((o as Map).cast<String, dynamic>()))
        // Duffel's test-mode environment (the only mode this project has
        // credentials for — see secrets.dart) mixes in offers from its own
        // built-in sandbox carrier, "Duffel Airways" (IATA code "ZZ"),
        // alongside real airlines' test-mode offers — confirmed against
        // Duffel's own docs (duffel.com/docs/api/overview/test-mode/
        // duffel-airways): "a proprietary sandbox airline... you won't see
        // realistic flight schedules or prices [from it]". That's exactly
        // the kind of fake/placeholder data this app doesn't show, so its
        // offers are filtered out here rather than shown as if real.
        .where((o) => o.airlineName != 'Duffel Airways')
        .toList();
    parsed.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
    return parsed;
  }

  /// Resolves free text into the single IATA (airport or city) code
  /// Duffel's flight search actually accepts. A person never types or
  /// picks an airport code anywhere in this app — Create Plan/Group
  /// Setting's destination picker offers exact country names from
  /// [kCountries], and Explore's own search bar takes whatever text
  /// someone types ("Tokyo", "Japan", ...) — so this is the one place
  /// that bridges free text to what Duffel needs.
  ///
  /// Resolution order:
  ///  1. Already looks like an IATA code (3 letters) → used as-is, no
  ///     network call. Covers [kDefaultHomeAirport] and
  ///     [kPopularDestinations]' own already-resolved codes.
  ///  2. An exact (case-insensitive) match in [kCountryGateways] — every
  ///     trip-driven search takes this path, since a trip's destination
  ///     is always one of [kCountries]' exact names.
  ///  3. Duffel's own Places Suggestions API (`/places/suggestions`),
  ///     for free-text city names typed into the search bar that aren't
  ///     a country name (e.g. "Tokyo", "Bangkok"). A "city" result's
  ///     `iata_city_code` is preferred (covers every airport in that
  ///     city); an "airport" result's `iata_code` otherwise.
  /// Throws [DuffelApiException] if nothing resolves.
  Future<String> resolveDestinationCode(String freeText) async {
    final text = freeText.trim();
    // Deliberately checked as *uppercase only* — every code this app
    // generates itself ([kDefaultHomeAirport], [kPopularDestinations]'
    // flightIataCode, [kCountryGateways]' flightIataCode) is always
    // uppercase, but a person typing a real place name into the search
    // bar would type it normally ("Goa", not "GOA"). Matching
    // case-insensitively would silently misroute a real 3-letter city
    // name like "Goa" (actual airport code "GOI") straight to Duffel
    // instead of through the Places Suggestions fallback below that's
    // built to resolve exactly that.
    if (_looksLikeIataCode(text)) return text;

    final viaCountry = kCountryGateways[text.toLowerCase()]?.flightIataCode;
    if (viaCountry != null) return viaCountry;

    final viaPlaces = await _resolveViaPlacesSuggestions(text);
    if (viaPlaces != null) return viaPlaces;

    throw DuffelApiException('Could not find a matching airport for "$freeText" — try a city name instead (e.g. "Tokyo").');
  }

  bool _looksLikeIataCode(String s) => RegExp(r'^[A-Z]{3}$').hasMatch(s);

  /// Reads [key] off [map] as a non-empty string, or null for anything
  /// else (missing, wrong JSON type, empty) — never throws, since this
  /// is parsing a third-party API response that's merely *documented*
  /// to have string fields here, not guaranteed to.
  String? _stringField(Map map, String key) {
    final v = map[key];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  Future<String?> _resolveViaPlacesSuggestions(String query) async {
    List<Map<String, dynamic>> places;
    try {
      places = await _get('/places/suggestions', {'query': query});
    } catch (_) {
      // A Places lookup failing (offline, rate limit, ...) shouldn't be
      // fatal on its own — resolveDestinationCode still throws its own
      // clear error if this was the last resolution option.
      return null;
    }
    try {
      if (places.isEmpty) return null;
      // A "city" result's iata_city_code covers every airport in that
      // metro area, so it's preferred over one specific airport.
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
      // A city result with airports nested but no direct iata_city_code.
      for (final p in places) {
        final airports = p['airports'];
        if (airports is List && airports.isNotEmpty && airports.first is Map) {
          final code = _stringField(airports.first as Map, 'iata_code');
          if (code != null) return code;
        }
      }
      return null;
    } catch (_) {
      // Response shape didn't match what's documented — fall through to
      // resolveDestinationCode's own error rather than crashing.
      return null;
    }
  }

  /// Hotel search for [destinationQuery] between [checkIn] and
  /// [checkOut]. [destinationQuery] can be a free-text place name
  /// ("Tokyo, Japan") or an exact country name from [kCountries]
  /// ("Japan" — how a trip's own destination is always stored) — a bare
  /// country name is swapped for [CountryGateway.hotelPlaceQuery] first
  /// (e.g. "Japan" → "Tokyo, Japan"), since geocoding a whole country
  /// can land anywhere inside it, nowhere near a city with hotels.
  /// Geocodes the (possibly-swapped) destination via OpenStreetMap's
  /// free Nominatim service, since Duffel Stays search itself takes
  /// coordinates, not a place name.
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
      throw DuffelApiException('Could not reach Duffel: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DuffelApiException(_errorMessageFrom(res));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['data'] is Map) return (decoded['data'] as Map).cast<String, dynamic>();
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const DuffelApiException('Unexpected response from Duffel.');
  }

  /// Same idea as [_post], but for a Duffel endpoint whose `data` is a
  /// JSON array rather than an object (only `/places/suggestions` uses
  /// this right now — see [_resolveViaPlacesSuggestions]).
  Future<List<Map<String, dynamic>>> _get(String path, Map<String, String> query) async {
    http.Response res;
    try {
      res = await http
          .get(Uri.parse('$_base$path').replace(queryParameters: query), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw DuffelApiException('Could not reach Duffel: $e');
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
      // fall through to the generic message below
    }
    return 'Duffel request failed (${res.statusCode}).';
  }

  /// Free-text place → (latitude, longitude) via OpenStreetMap's
  /// Nominatim, which needs no API key. Kept private to this service —
  /// if another feature (e.g. real Places/attractions) also wants OSM
  /// geocoding later, promote this into its own `OsmGeocodingService`
  /// rather than duplicating it.
  Future<(double, double)?> _geocode(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
    });
    http.Response res;
    try {
      res = await http.get(uri, headers: {
        // Nominatim's usage policy requires a descriptive User-Agent.
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
