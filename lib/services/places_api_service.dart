import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------
// Real points-of-interest data — OpenStreetMap (Nominatim geocoding +
// Overpass POI search). Free, keyless, no billing account to configure,
// which is why this (rather than Google Places) is what backs Explore's
// Attractions/Restaurants and Near By: those three used to be a fixed
// seeded catalogue baked into the app (see the removed
// CatalogRepository._seedAttractions/_seedRestaurants/_seedPlaces) —
// this is what replaced it with something that actually reflects a real
// place on a real map, the same way flights/hotels come from Duffel/
// RollingGo instead of a hardcoded list.
// ---------------------------------------------------------------------

/// One POI as returned by Overpass, before it's mapped into this app's
/// own models (CatalogAttraction/CatalogRestaurant/NearbyPlace all shape
/// this differently, so the mapping happens at the call site).
class OsmPlace {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final Map<String, String> tags;

  const OsmPlace({required this.id, required this.name, required this.lat, required this.lon, required this.tags});

  /// Street address built from whatever `addr:*` tags OSM has for this
  /// node — often partial or missing entirely (OSM coverage varies a lot
  /// by region), in which case this is just empty and callers fall back
  /// to the search area's own name instead of inventing one.
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

  // Nominatim/Overpass both ask every client to send a real identifying
  // User-Agent — required by Nominatim's usage policy, and politeness
  // for Overpass's shared public instance.
  static const _userAgent = 'VoyaTravelApp/1.0 (student FYP project; contact: teohyongyun90@gmail.com)';

  /// The reason the most recent [searchNearby] call came back empty, or
  /// null when it genuinely found zero matching places (a real "nothing
  /// nearby", not a failure). [searchNearby] itself still never throws —
  /// every existing caller (Explore's background refresh) keeps working
  /// exactly as before — but Near By's page reads this afterward to tell
  /// "nothing here" apart from "the request to OpenStreetMap failed" and
  /// show the real reason instead of always saying the same generic
  /// "No places found nearby" either way. Cleared to null at the start of
  /// every call, so a later success after an earlier failure clears it.
  Object? lastSearchNearbyError;

  /// Resolves a free-text destination ("Tokyo, Japan", "Bali") to a real
  /// lat/lng (plus, when Nominatim's reverse-geocoded address includes
  /// one, the destination's ISO 3166-1 alpha-2 country code — e.g. "TR"
  /// for anywhere in Turkey) via Nominatim's search endpoint — the
  /// first/best match. [countryCode] is upper-cased here so it compares
  /// directly against the `country` field CatalogRepository's `places`
  /// collection stores ("TR", not "tr"); null when Nominatim's result had
  /// no `address.country_code` (rare, but not guaranteed for every hit).
  /// Returns null when nothing matched (typo, a place too obscure for
  /// OSM) or the request failed (offline, endpoint down); callers treat
  /// that as "couldn't look this destination up right now", not an
  /// error to surface loudly.
  Future<({double lat, double lon, String? countryCode})?> geocode(String query) async {
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
      return (lat: lat, lon: lon, countryCode: countryCode);
    } catch (_) {
      return null;
    }
  }

  /// The Overpass QL element filter for each Near By / Explore category
  /// chip — shared by both callers so "Attractions" means the same OSM
  /// tags whether it's Near By's chip row or Explore's category.
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

  /// Real nodes/ways matching [filter] (an Overpass tag filter, e.g.
  /// `["amenity"="restaurant"]` — see [overpassFilterFor]) within
  /// [radiusMeters] of ([lat], [lon]). Unnamed POIs are dropped — OSM has
  /// plenty of untagged benches/bins/etc. that would otherwise show up
  /// as blank rows. Returns an empty list (never throws) on any network
  /// or parse failure, so a flaky request just means "nothing found
  /// right now" instead of crashing the page.
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
      // Real reason captured here — a TimeoutException (request never
      // got a response), a SocketException (DNS/connection failure, the
      // usual shape of a network that blocks this host outright), or
      // something else — rather than this just going silently empty.
      lastSearchNearbyError = e;
      return const [];
    }
  }

  /// A real photo URL for [tags] when OSM (or something it links to) has
  /// one — tried in order of how directly usable each is, so a cheap
  /// check always runs before a network round-trip:
  /// 1. an `image` tag that's already a direct http(s) URL (some POIs,
  ///    mostly ones edited via iD/StreetComplete, have this outright);
  /// 2. a `wikimedia_commons` tag naming a file directly (`File:...`) —
  ///    Commons' own `Special:FilePath` redirect serves that file's
  ///    actual image bytes with no API call needed;
  /// 3. a `wikipedia` tag (`"en:Tokyo Tower"`) — asks Wikipedia's REST
  ///    summary endpoint for that page's lead photo.
  /// All three are free and keyless. Returns null (never throws) when
  /// none of these are present or the one network call in step 3 fails —
  /// callers fall back to a category icon rather than a blank box.
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
          // Fall through to null — see doc comment.
        }
      }
    }
    return null;
  }

  /// A fallback photo looked up by the place's plain [name], for when
  /// [resolveImage] found nothing on the OSM tags themselves — most OSM
  /// nodes (the vast majority of real-world restaurants/cafes/shops, and
  /// even plenty of attractions) were never tagged with an `image`/
  /// `wikimedia_commons`/`wikipedia` reference at all; that's a genuine
  /// data-coverage gap in OpenStreetMap, not a bug, and most of those
  /// places simply have no free photo available anywhere. This recovers
  /// the subset that DO have a Wikipedia article but whose OSM node was
  /// never linked to it — common for well-known landmarks/museums, which
  /// is why this is only used for Attractions (see
  /// CatalogRepository.refreshAttractions), not Restaurants: a small
  /// local eatery's name is far more likely to collide with an unrelated
  /// Wikipedia article of the same/similar name than an actual named
  /// landmark is, and showing the wrong place's photo is worse than
  /// showing no photo. [_looksLikeSamePlace] is the guard against that.
  /// Returns null (never throws) when nothing matches closely enough or
  /// the request fails.
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

  /// A deliberately strict "same place" check for [resolveImageByName] —
  /// one name has to fully contain the other (case-insensitive) — so a
  /// generic query (e.g. a shop simply named "Garden") can't pull in an
  /// unrelated Wikipedia article that merely shares a common word.
  bool _looksLikeSamePlace(String query, String title) {
    final q = query.toLowerCase().trim();
    final t = title.toLowerCase().trim();
    if (q.isEmpty || t.isEmpty) return false;
    return q == t || q.contains(t) || t.contains(q);
  }

  /// A real, place-specific "About" description for [tags] — an OSM
  /// `description` tag when present (rare, but some POIs are tagged with
  /// one directly), otherwise the opening extract of that place's own
  /// Wikipedia page (same `wikipedia` tag [resolveImage] already reads).
  /// This is what backs Attraction/Restaurant detail pages' About
  /// section: without it every place in the same category/cuisine showed
  /// the *exact* same one-size-fits-all sentence (e.g. every museum
  /// reading "One of the popular museum spots..."), which read as
  /// obviously fake/templated once you saw two of them back to back.
  /// Returns null (never throws) when neither source has anything —
  /// callers keep their own generic sentence for that case rather than
  /// leaving the section blank.
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
          // Fall through to null — see doc comment.
        }
      }
    }
    return null;
  }

  /// Fallback "About" text looked up by the place's plain [name], for
  /// when [resolveDescription] found nothing on the OSM tags — same idea,
  /// and same attractions-only reasoning, as [resolveImageByName]: most
  /// OSM nodes were never tagged with a `wikipedia` reference at all, so
  /// without this every attraction that lacked one fell back to the same
  /// generic category sentence (every museum reading "One of the popular
  /// museum spots...") regardless of how different two places actually
  /// are. Guarded by the same [_looksLikeSamePlace] check so a generic
  /// name can't pull in an unrelated article's description.
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

  /// A real photo + description straight from the place's own `website`/
  /// `contact:website` OSM tag — most real restaurant/shop/attraction
  /// websites (even a plain Wix/Squarespace/WordPress one) set Open
  /// Graph meta tags (`og:image`, `og:description`) for link previews,
  /// and that preview is exactly a usable summary of the real place.
  /// This is the one source here that's directly tied to the specific
  /// business rather than matched by name, so it's trusted for
  /// Restaurants too (unlike [resolveImageByName]/
  /// [resolveDescriptionByName], which only run for Attractions because
  /// a name match can be wrong) — a business's own URL, tagged on its
  /// own OSM node, genuinely is that business. Returns null for both
  /// fields (never throws) when the site has neither tag, doesn't
  /// respond, or isn't reachable (some small-business sites are slow,
  /// expired, or HTTP-only with a broken cert — any of that just means
  /// no extra data from this source, not an error to surface).
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

  /// Pulls a `<meta ... content="...">` tag's value by its `property` or
  /// `name` attribute ([key], e.g. `"og:image"`) — handles either
  /// attribute order (some site builders emit `content` before
  /// `property`), case-insensitively, with single or double quotes. A
  /// deliberately simple regex rather than a full HTML parser: Open
  /// Graph tags are always single, self-contained `<meta>` elements in
  /// the page `<head>`, never nested or multi-line, so this is reliable
  /// for exactly what it's used for without adding an HTML-parsing
  /// dependency for one narrow job.
  String? _metaContent(String html, String key) {
    final keyPattern = RegExp.escape(key);
    final afterKey = RegExp('<meta[^>]*(?:property|name)\\s*=\\s*["\']$keyPattern["\'][^>]*content\\s*=\\s*["\']([^"\']*)["\']', caseSensitive: false);
    final afterKeyMatch = afterKey.firstMatch(html);
    if (afterKeyMatch != null) return afterKeyMatch.group(1);
    final beforeKey = RegExp('<meta[^>]*content\\s*=\\s*["\']([^"\']*)["\'][^>]*(?:property|name)\\s*=\\s*["\']$keyPattern["\']', caseSensitive: false);
    return beforeKey.firstMatch(html)?.group(1);
  }

  /// Decodes the handful of HTML entities actually likely to show up in
  /// a meta description (not a full HTML-entity table) — numeric
  /// entities plus the common named ones.
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

  /// Cuts [text] down to roughly [maxLength] characters without stopping
  /// mid-word/mid-sentence — a full Wikipedia extract can run to several
  /// paragraphs, too long for a detail page's About card. Breaks at the
  /// last sentence end before the limit when there is one, else the last
  /// whole word, and appends "…" whenever that means real text was cut.
  String _trimToSentence(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final slice = text.substring(0, maxLength);
    final lastStop = [slice.lastIndexOf('. '), slice.lastIndexOf('.\n')].reduce((a, b) => a > b ? a : b);
    if (lastStop > maxLength ~/ 2) return slice.substring(0, lastStop + 1);
    final lastSpace = slice.lastIndexOf(' ');
    return '${slice.substring(0, lastSpace > 0 ? lastSpace : slice.length)}…';
  }

  /// A representative photo for a whole destination ("Kyoto, Japan",
  /// "Bali", just "Japan") — used as a new group's cover photo when the
  /// person creating the trip didn't upload their own. Free and keyless,
  /// same Wikipedia REST summary endpoint as [resolveImage]'s step 3, just
  /// looked up by place name directly instead of via an OSM tag: most
  /// destinations worth planning a trip to have a plain Wikipedia page
  /// (city, region or country), and that page's lead photo is a
  /// reasonable real photo of the place. Tries the destination string as
  /// typed first, then — for a "City, Country" value — falls back to just
  /// the city and then just the country, so a city with no dedicated page
  /// still resolves to something. Returns null (never throws) when none
  /// of those resolve or every request fails; the caller already has its
  /// own generic fallback photo for that case.
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
      // A disambiguation page ("Georgia" the country vs the US state) has
      // no useful single photo — skip it rather than show a wrong one.
      if (decoded['type'] == 'disambiguation') return null;
      final thumb = decoded['thumbnail'] as Map<String, dynamic>?;
      final source = thumb?['source'] as String?;
      return (source != null && source.isNotEmpty) ? source : null;
    } catch (_) {
      return null;
    }
  }

  /// Great-circle distance in km, formatted the way the app's distance
  /// labels already read ("250 m" under 1km, "1.2 km" above).
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
