import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';


class OsmPlace {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final Map<String, String> tags;

  const OsmPlace({required this.id, required this.name, required this.lat, required this.lon, required this.tags});

  String get address {
    final parts = [
      if ((tags['addr:housenumber'] ?? '').isNotEmpty || (tags['addr:street'] ?? '').isNotEmpty)
        '${tags['addr:housenumber'] ?? ''} ${tags['addr:street'] ?? ''}'.trim(),
      tags['addr:city'],
      tags['addr:postcode'],
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }
}

class PlacesApiService {
  PlacesApiService._();
  static final PlacesApiService instance = PlacesApiService._();

  static const _userAgent = 'VoyaTravelApp/1.0 (student FYP project; contact: teohyongyun90@gmail.com)';

  Object? lastSearchNearbyError;

  Future<({double lat, double lon, String? countryCode, String? label})?> geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'json',
        'limit': '1',
        'addressdetails': '1',
        'accept-language': 'en',
      });
      final res = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List;
      if (list.isEmpty) return null;
      final hit = list.first as Map<String, dynamic>;
      final lat = double.tryParse('${hit['lat']}');
      final lon = double.tryParse('${hit['lon']}');
      if (lat == null || lon == null) return null;
      final address = hit['address'] as Map<String, dynamic>?;
      final rawCountryCode = address?['country_code'] as String?;
      final countryCode = (rawCountryCode != null && rawCountryCode.trim().isNotEmpty) ? rawCountryCode.trim().toUpperCase() : null;
      final city = (address?['city'] ?? address?['town'] ?? address?['village'] ?? address?['municipality'] ?? address?['county']) as String?;
      final country = address?['country'] as String?;
      final labelParts = [
        if (city != null && city.trim().isNotEmpty) city.trim(),
        if (country != null && country.trim().isNotEmpty) country.trim(),
      ];
      final label = labelParts.isEmpty ? null : labelParts.join(', ');
      return (lat: lat, lon: lon, countryCode: countryCode, label: label);
    } catch (_) {
      return null;
    }
  }

  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lon',
        'format': 'json',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'en',
      });
      final res = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final hit = jsonDecode(res.body) as Map<String, dynamic>;
      final displayName = hit['display_name'] as String?;
      if (displayName != null && displayName.trim().isNotEmpty) return displayName.trim();
      final address = hit['address'] as Map<String, dynamic>?;
      final city = (address?['city'] ?? address?['town'] ?? address?['village'] ?? address?['municipality'] ?? address?['county']) as String?;
      final country = address?['country'] as String?;
      final labelParts = [
        if (city != null && city.trim().isNotEmpty) city.trim(),
        if (country != null && country.trim().isNotEmpty) country.trim(),
      ];
      return labelParts.isEmpty ? null : labelParts.join(', ');
    } catch (_) {
      return null;
    }
  }

  static String overpassFilterFor(String category) {
    switch (category) {
      case 'Restaurants':
        return '["amenity"="restaurant"]';
      case 'Cafes':
        return '["amenity"="cafe"]';
      case 'Attractions':
        return '["tourism"~"attraction|museum|viewpoint|gallery|zoo|theme_park|artwork"]';
      case 'Shopping':
        return '["shop"]';
      case 'ATM':
        return '["amenity"="atm"]';
      case 'Pharmacy':
        return '["amenity"="pharmacy"]';
      default:
        return '["amenity"="restaurant"]';
    }
  }

  // The official overpass-api.de instance is a single, free, volunteer-run
  // server -- well known for frequent slow responses, 504 timeouts and
  // temporary outages under load, with no uptime guarantee at all. Rather
  // than depend on that one host, this tries a short list of independently
  // run Overpass mirrors in order and uses the first one that actually
  // answers. They all speak the exact same Overpass QL/response format (no
  // API key needed on any of them), so this is a pure reliability swap --
  // nothing else in the app needs to change. (host, path) pairs, since not
  // every mirror uses the same path as the main instance (VK Maps' is
  // nested under /osm/tools/overpass/). Sourced from the OSM wiki's
  // current, documented, no-API-key, global-coverage endpoints:
  // https://wiki.openstreetmap.org/wiki/Overpass_API
  static const List<(String, String)> _overpassHosts = [
    ('overpass-api.de', '/api/interpreter'),
    ('maps.mail.ru', '/osm/tools/overpass/api/interpreter'),
    ('overpass.private.coffee', '/api/interpreter'),
  ];

  bool get _geoapifyConfigured => geoapifyApiKey.isNotEmpty && geoapifyApiKey != 'YOUR_GEOAPIFY_API_KEY_HERE';

  /// Maps an app-level nearby category to Geoapify's hierarchical category
  /// keys (geoapify.com/docs/places) -- comma-separating a few top-level
  /// groups pulls in every sub-category under them (e.g. "entertainment"
  /// covers entertainment.museum, entertainment.zoo, etc. without having to
  /// enumerate each one).
  static String geoapifyCategoriesFor(String category) {
    switch (category) {
      case 'Restaurants':
        return 'catering.restaurant';
      case 'Cafes':
        return 'catering.cafe';
      case 'Attractions':
        return 'tourism,entertainment';
      case 'Shopping':
        return 'commercial';
      case 'ATM':
        return 'service.financial.atm';
      case 'Pharmacy':
        return 'healthcare.pharmacy';
      default:
        return 'catering.restaurant';
    }
  }

  /// Entry point for the "Nearby" page: tries Geoapify -- a stable,
  /// commercially hosted places API, not a volunteer-run OSM mirror -- when
  /// a key is configured, falling back to [searchNearby]'s existing
  /// Overpass-mirror chain if Geoapify isn't configured or its request
  /// fails for any reason (bad key, network, quota). Geoapify's basic
  /// Places search doesn't return the rich OSM tags (opening_hours, phone,
  /// website, wheelchair, fee) that catalog_repository.dart's
  /// destination-level attraction/restaurant population relies on, so that
  /// code keeps calling [searchNearby] directly and is unaffected either
  /// way -- this stable path is only for the user-facing "Nearby" page,
  /// which just needs a name, location, and a rough category label.
  Future<List<OsmPlace>> searchNearbyStable({
    required double lat,
    required double lon,
    required String category,
    int radiusMeters = 4000,
    int limit = 25,
  }) async {
    lastSearchNearbyError = null;
    if (_geoapifyConfigured) {
      final viaGeoapify = await _searchNearbyGeoapify(lat: lat, lon: lon, category: category, radiusMeters: radiusMeters, limit: limit);
      if (viaGeoapify != null) return viaGeoapify;
      // Geoapify itself failed -- fall through to Overpass rather than
      // showing the traveller an error when there's still a chance of
      // getting real results another way.
    }
    return searchNearby(lat: lat, lon: lon, filter: overpassFilterFor(category), radiusMeters: radiusMeters, limit: limit);
  }

  /// Returns null (not an empty list) on any request failure, so
  /// [searchNearbyStable] can tell "Geoapify answered with zero nearby
  /// places" (a real, valid empty result -- don't fall back) apart from
  /// "Geoapify couldn't be reached at all" (fall back to Overpass).
  Future<List<OsmPlace>?> _searchNearbyGeoapify({
    required double lat,
    required double lon,
    required String category,
    required int radiusMeters,
    required int limit,
  }) async {
    try {
      final uri = Uri.https('api.geoapify.com', '/v2/places', {
        'categories': geoapifyCategoriesFor(category),
        'filter': 'circle:$lon,$lat,$radiusMeters',
        'bias': 'proximity:$lon,$lat',
        'limit': '$limit',
        'apiKey': geoapifyApiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        lastSearchNearbyError = 'Geoapify returned HTTP ${res.statusCode}';
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? const [];
      final out = <OsmPlace>[];
      for (final raw in features) {
        final f = raw as Map<String, dynamic>;
        final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
        final name = (props['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final placeLat = (props['lat'] as num?)?.toDouble();
        final placeLon = (props['lon'] as num?)?.toDouble();
        if (placeLat == null || placeLon == null) continue;
        final categories = ((props['categories'] as List?) ?? const []).map((c) => '$c').toList();

        String? firstAfter(String prefix) {
          for (final c in categories) {
            if (c.startsWith(prefix) && c.length > prefix.length) return c.substring(prefix.length).split('.').first.replaceAll('_', ' ');
          }
          return null;
        }

        final tags = <String, String>{
          if (((props['housenumber'] as String?) ?? '').isNotEmpty) 'addr:housenumber': props['housenumber'] as String,
          if (((props['street'] as String?) ?? '').isNotEmpty) 'addr:street': props['street'] as String,
          if (((props['city'] as String?) ?? '').isNotEmpty) 'addr:city': props['city'] as String,
          if (((props['postcode'] as String?) ?? '').isNotEmpty) 'addr:postcode': props['postcode'] as String,
        };
        // Best-effort equivalents of the OSM tags _osmCategoryLabel reads,
        // so the "Nearby" page's category subtitle (a cuisine, a shop
        // type, ...) still shows something meaningful from Geoapify's own
        // category tree instead of just the generic category name.
        final cuisine = firstAfter('catering.restaurant.') ?? firstAfter('catering.cafe.');
        if (cuisine != null) tags['cuisine'] = cuisine;
        final shop = firstAfter('commercial.');
        if (shop != null) tags['shop'] = shop;
        final tourism = firstAfter('tourism.') ?? firstAfter('entertainment.');
        if (tourism != null) tags['tourism'] = tourism;

        final placeId = (props['place_id'] as String?) ?? '$placeLat,$placeLon';
        out.add(OsmPlace(id: 'geoapify_$placeId', name: name, lat: placeLat, lon: placeLon, tags: tags));
      }
      lastSearchNearbyError = null;
      return out;
    } catch (e) {
      lastSearchNearbyError = 'Geoapify failed: $e';
      return null;
    }
  }

  Future<List<OsmPlace>> searchNearby({
    required double lat,
    required double lon,
    required String filter,
    int radiusMeters = 4000,
    int limit = 25,
  }) async {
    lastSearchNearbyError = null;
    final query = '[out:json][timeout:25];'
        '(node$filter(around:$radiusMeters,$lat,$lon);'
        'way$filter(around:$radiusMeters,$lat,$lon);'
        ');'
        'out center $limit;';

    for (final (host, path) in _overpassHosts) {
      try {
        final res = await http
            .post(
              Uri.https(host, path),
              headers: {'User-Agent': _userAgent, 'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) {
          lastSearchNearbyError = 'Overpass ($host) returned HTTP ${res.statusCode}';
          continue; // try the next mirror instead of giving up
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List?) ?? const [];
        final out = <OsmPlace>[];
        for (final raw in elements) {
          final el = raw as Map<String, dynamic>;
          final tags = Map<String, String>.from((el['tags'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {});
          final name = tags['name'];
          if (name == null || name.trim().isEmpty) continue;
          double? elLat = (el['lat'] as num?)?.toDouble();
          double? elLon = (el['lon'] as num?)?.toDouble();
          if (elLat == null || elLon == null) {
            final center = el['center'] as Map<String, dynamic>?;
            elLat = (center?['lat'] as num?)?.toDouble();
            elLon = (center?['lon'] as num?)?.toDouble();
          }
          if (elLat == null || elLon == null) continue;
          out.add(OsmPlace(id: '${el['type']}${el['id']}', name: name.trim(), lat: elLat, lon: elLon, tags: tags));
        }
        lastSearchNearbyError = null;
        return out;
      } catch (e) {
        lastSearchNearbyError = 'Overpass ($host) failed: $e';
        continue; // network error / timeout on this mirror -- try the next
      }
    }
    return const [];
  }

  Future<String?> resolveImage(Map<String, String> tags) async {
    final direct = tags['image'];
    if (direct != null && (direct.startsWith('http://') || direct.startsWith('https://'))) {
      return direct;
    }
    final commons = tags['wikimedia_commons'];
    if (commons != null && commons.startsWith('File:')) {
      return 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(commons.substring(5))}?width=480';
    }
    final wikipedia = tags['wikipedia'];
    if (wikipedia != null && wikipedia.contains(':')) {
      final parts = wikipedia.split(':');
      final lang = parts.first.trim();
      final title = parts.sublist(1).join(':').trim();
      if (lang.isNotEmpty && title.isNotEmpty) {
        try {
          final uri = Uri.https('$lang.wikipedia.org', '/api/rest_v1/page/summary/${Uri.encodeComponent(title)}');
          final res = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body) as Map<String, dynamic>;
            final thumb = decoded['thumbnail'] as Map<String, dynamic>?;
            final source = thumb?['source'] as String?;
            if (source != null && source.isNotEmpty) return source;
          }
        } catch (_) {
        }
      }
    }
    return null;
  }

  Future<String?> resolveImageByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    try {
      final uri = Uri.https('en.wikipedia.org', '/w/rest.php/v1/search/page', {'q': trimmed, 'limit': '1'});
      final res = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final pages = (decoded['pages'] as List?) ?? const [];
      if (pages.isEmpty) return null;
      final page = pages.first as Map<String, dynamic>;
      final title = (page['title'] as String?) ?? '';
      if (!_looksLikeSamePlace(trimmed, title)) return null;
      final thumb = page['thumbnail'] as Map<String, dynamic>?;
      final url = thumb?['url'] as String?;
      if (url == null || url.isEmpty) return null;
      return url.startsWith('http') ? url : 'https:$url';
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeSamePlace(String query, String title) {
    final q = query.toLowerCase().trim();
    final t = title.toLowerCase().trim();
    if (q.isEmpty || t.isEmpty) return false;
    return q == t || q.contains(t) || t.contains(q);
  }

  Future<String?> resolveDescription(Map<String, String> tags) async {
    final direct = tags['description']?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final wikipedia = tags['wikipedia'];
    if (wikipedia != null && wikipedia.contains(':')) {
      final parts = wikipedia.split(':');
      final lang = parts.first.trim();
      final title = parts.sublist(1).join(':').trim();
      if (lang.isNotEmpty && title.isNotEmpty) {
        try {
          final uri = Uri.https('$lang.wikipedia.org', '/api/rest_v1/page/summary/${Uri.encodeComponent(title)}');
          final res = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body) as Map<String, dynamic>;
            final extract = (decoded['extract'] as String?)?.trim();
            if (extract != null && extract.isNotEmpty) return _trimToSentence(extract, 280);
          }
        } catch (_) {
        }
      }
    }
    return null;
  }

  Future<String?> resolveDescriptionByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    try {
      final searchUri = Uri.https('en.wikipedia.org', '/w/rest.php/v1/search/page', {'q': trimmed, 'limit': '1'});
      final searchRes = await http.get(searchUri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
      if (searchRes.statusCode != 200) return null;
      final decoded = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final pages = (decoded['pages'] as List?) ?? const [];
      if (pages.isEmpty) return null;
      final page = pages.first as Map<String, dynamic>;
      final title = (page['title'] as String?) ?? '';
      if (!_looksLikeSamePlace(trimmed, title)) return null;
      final summaryUri = Uri.https('en.wikipedia.org', '/api/rest_v1/page/summary/${Uri.encodeComponent(title)}');
      final summaryRes = await http.get(summaryUri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
      if (summaryRes.statusCode != 200) return null;
      final summary = jsonDecode(summaryRes.body) as Map<String, dynamic>;
      final extract = (summary['extract'] as String?)?.trim();
      if (extract == null || extract.isEmpty) return null;
      return _trimToSentence(extract, 280);
    } catch (_) {
      return null;
    }
  }

  Future<({String? image, String? description})?> resolveFromWebsite(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri == null) return null;
    try {
      final res = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final html = res.body;
      final rawImage = _metaContent(html, 'og:image') ?? _metaContent(html, 'twitter:image');
      final rawDescription = _metaContent(html, 'og:description') ?? _metaContent(html, 'description') ?? _metaContent(html, 'twitter:description');
      String? image;
      if (rawImage != null && rawImage.isNotEmpty) {
        final resolved = Uri.tryParse(rawImage);
        if (resolved != null) image = (resolved.hasScheme ? resolved : uri.resolveUri(resolved)).toString();
      }
      final description = rawDescription != null && rawDescription.isNotEmpty ? _trimToSentence(_decodeHtmlEntities(rawDescription), 280) : null;
      if (image == null && description == null) return null;
      return (image: image, description: description);
    } catch (_) {
      return null;
    }
  }

  String? _metaContent(String html, String key) {
    final keyPattern = RegExp.escape(key);
    final afterKey = RegExp('<meta[^>]*(?:property|name)\\s*=\\s*["\']$keyPattern["\'][^>]*content\\s*=\\s*["\']([^"\']*)["\']', caseSensitive: false);
    final afterKeyMatch = afterKey.firstMatch(html);
    if (afterKeyMatch != null) return afterKeyMatch.group(1);
    final beforeKey = RegExp('<meta[^>]*content\\s*=\\s*["\']([^"\']*)["\'][^>]*(?:property|name)\\s*=\\s*["\']$keyPattern["\']', caseSensitive: false);
    return beforeKey.firstMatch(html)?.group(1);
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .trim();
  }

  String _trimToSentence(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final slice = text.substring(0, maxLength);
    final lastStop = [slice.lastIndexOf('. '), slice.lastIndexOf('.\n')].reduce((a, b) => a > b ? a : b);
    if (lastStop > maxLength ~/ 2) return slice.substring(0, lastStop + 1);
    final lastSpace = slice.lastIndexOf(' ');
    return '${slice.substring(0, lastSpace > 0 ? lastSpace : slice.length)}…';
  }

  Future<String?> destinationPhoto(String destination) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final candidates = <String>{
      trimmed,
      if (parts.isNotEmpty) parts.first,
      if (parts.length > 1) parts.last,
    }.toList();
    for (final title in candidates) {
      final photo = await _wikipediaLeadPhoto(title);
      if (photo != null) return photo;
    }
    return null;
  }

  Future<String?> _wikipediaLeadPhoto(String title) async {
    try {
      final uri = Uri.https('en.wikipedia.org', '/api/rest_v1/page/summary/${Uri.encodeComponent(title)}');
      final res = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (decoded['type'] == 'disambiguation') return null;
      final thumb = decoded['thumbnail'] as Map<String, dynamic>?;
      final source = thumb?['source'] as String?;
      return (source != null && source.isNotEmpty) ? source : null;
    } catch (_) {
      return null;
    }
  }

  static String formatDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    double degToRad(double deg) => deg * (pi / 180);
    final dLat = degToRad(lat2 - lat1);
    final dLon = degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(degToRad(lat1)) * cos(degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final km = earthRadiusKm * c;
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
