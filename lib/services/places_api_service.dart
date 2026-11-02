import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;


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
    try {
      final res = await http
          .post(
            Uri.https('overpass-api.de', '/api/interpreter'),
            headers: {'User-Agent': _userAgent, 'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        lastSearchNearbyError = 'Overpass returned HTTP ${res.statusCode}';
        return const [];
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
      return out;
    } catch (e) {
      lastSearchNearbyError = e;
      return const [];
    }
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
