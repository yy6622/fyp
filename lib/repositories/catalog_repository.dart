import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/popular_destinations.dart';
import '../models/duffel_models.dart';
import '../models/explore_models.dart';
import '../models/nearby_models.dart';
import '../services/duffel_api_service.dart';
import '../services/name_translation_service.dart';
import '../services/places_api_service.dart';
import '../services/rollinggo_api_service.dart';

class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  CollectionReference<Map<String, dynamic>> get _attractions =>
      FirebaseFirestore.instance.collection('catalog_attractions');
  CollectionReference<Map<String, dynamic>> get _attractionReports =>
      FirebaseFirestore.instance.collection('attraction_reports');
  CollectionReference<Map<String, dynamic>> get _restaurants =>
      FirebaseFirestore.instance.collection('catalog_restaurants');
  CollectionReference<Map<String, dynamic>> get _appCache => FirebaseFirestore.instance.collection('app_cache');

  static const Duration _searchCacheTtl = Duration(minutes: 3);
  final Map<String, _CachedSearch<DuffelFlightOffer>> _flightSearchCache = {};
  final Map<String, _CachedSearch<DuffelStayResult>> _staySearchCache = {};
  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void clearSearchCache() {
    _flightSearchCache.clear();
    _staySearchCache.clear();
  }

  Future<List<DuffelFlightOffer>> searchFlights({
    required String uid,
    required String origin,
    required String destination,
    required DateTime departureDate,
    int adults = 1,
    List<int> childAges = const [],
    String cabinClass = 'economy',
  }) async {
    final key = 'f|$uid|$origin|$destination|${_dateKey(departureDate)}|$adults|${childAges.join(",")}|$cabinClass';
    final cached = _flightSearchCache[key];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _searchCacheTtl) {
      return cached.results;
    }
    final results = await DuffelApiService.instance.searchFlights(
      origin: origin,
      destination: destination,
      departureDate: departureDate,
      adults: adults,
      childAges: childAges,
      cabinClass: cabinClass,
    );
    _flightSearchCache[key] = _CachedSearch(DateTime.now(), results);
    return results;
  }

  Future<List<MapEntry<String, DuffelFlightOffer>>> getPopularFlights() async {
    final cached = await _readPopularCache('popular_flights');
    if (cached != null) {
      return cached.map((m) => MapEntry(m['destinationLabel'] as String, DuffelFlightOffer.fromCacheMap(m))).toList();
    }

    final departureDate = DateTime.now().add(const Duration(days: 30));
    final results = <MapEntry<String, DuffelFlightOffer>>[];
    for (final dest in kPopularDestinations) {
      try {
        final offers = await DuffelApiService.instance
            .searchFlights(origin: kDefaultHomeAirport, destination: dest.flightIataCode, departureDate: departureDate);
        if (offers.isNotEmpty) results.add(MapEntry(dest.label, offers.first));
      } catch (_) {
      }
    }
    await _writePopularCache(
      'popular_flights',
      results.map((e) => {'destinationLabel': e.key, ...e.value.toCacheMap()}).toList(),
    );
    return results;
  }

  // ---------------- Hotels ----------------
  Future<List<DuffelStayResult>> searchStays({
    required String uid,
    required String destinationQuery,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final key = 'h|$uid|$destinationQuery|${_dateKey(checkIn)}|${_dateKey(checkOut)}';
    final cached = _staySearchCache[key];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _searchCacheTtl) {
      return cached.results;
    }
    final results =
        await RollingGoApiService.instance.searchStays(destinationQuery: destinationQuery, checkIn: checkIn, checkOut: checkOut);
    _staySearchCache[key] = _CachedSearch(DateTime.now(), results);
    return results;
  }

  Future<List<MapEntry<String, DuffelStayResult>>> getPopularStays() async {
    final cached = await _readPopularCache('popular_hotels');
    if (cached != null) {
      return cached.map((m) => MapEntry(m['destinationLabel'] as String, DuffelStayResult.fromCacheMap(m))).toList();
    }

    final checkIn = DateTime.now().add(const Duration(days: 30));
    final checkOut = checkIn.add(const Duration(days: 4));
    final results = <MapEntry<String, DuffelStayResult>>[];
    for (final dest in kPopularDestinations) {
      try {
        final stays = await RollingGoApiService.instance
            .searchStays(destinationQuery: dest.hotelPlaceQuery, checkIn: checkIn, checkOut: checkOut);
        if (stays.isNotEmpty) results.add(MapEntry(dest.label, stays.first));
      } catch (_) {
      }
    }
    await _writePopularCache(
      'popular_hotels',
      results.map((e) => {'destinationLabel': e.key, ...e.value.toCacheMap()}).toList(),
    );
    return results;
  }

  static const Duration _popularCacheTtl = Duration(hours: 6);

  Future<List<Map<String, dynamic>>?> _readPopularCache(String cacheKey) async {
    try {
      final doc = await _appCache.doc(cacheKey).get();
      if (!doc.exists) return null;
      final data = doc.data();
      final updatedAt = (data?['updatedAt'] as Timestamp?)?.toDate();
      if (updatedAt == null || DateTime.now().difference(updatedAt) > _popularCacheTtl) return null;
      final items = (data?['items'] as List?) ?? const [];
      return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePopularCache(String cacheKey, List<Map<String, dynamic>> items) async {
    try {
      await _appCache.doc(cacheKey).set({'updatedAt': Timestamp.now(), 'items': items});
    } catch (_) {
      // see doc comment above
    }
  }

  bool _isVisibleStatus(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final status = d.data()['status'] as String?;
    return status == null || status == 'active';
  }

  CatalogAttraction _attractionFrom(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    return CatalogAttraction(
      id: d.id,
      favoritedBy: _favBy(d),
      name: (d.data()['name'] as String?) ?? '',
      category: (d.data()['category'] as String?) ?? '',
      price: (d.data()['price'] as String?) ?? '',
      image: (d.data()['image'] as String?) ?? '',
      location: (d.data()['location'] as String?) ?? '',
      openingHours: (d.data()['openingHours'] as String?) ?? 'Daily, 9:00 AM - 6:00 PM',
      address: (d.data()['address'] as String?) ?? '',
      categories: List<String>.from(d.data()['categories'] as List? ?? const []),
      openingHoursByDay: Map<String, String>.from(d.data()['openingHoursByDay'] as Map? ?? const {}),
      facilities: List<String>.from(d.data()['facilities'] as List? ?? const []),
      highlights: List<String>.from(d.data()['highlights'] as List? ?? const []),
      phone: (d.data()['phone'] as String?) ?? '',
      website: (d.data()['website'] as String?) ?? '',
      rating: '',
      reviews: '',
      recommendedDuration: (d.data()['recommendedDuration'] as String?) ?? '',
      images: List<String>.from(d.data()['images'] as List? ?? const []),
      fees: _feesFrom(d.data()['fees'] as Map<String, dynamic>?),
      description: (d.data()['description'] as String?) ?? '',
      distanceKm: (d.data()['distanceKm'] as num?)?.toDouble(),
      lat: (d.data()['lat'] as num?)?.toDouble(),
      lng: (d.data()['lng'] as num?)?.toDouble(),
    );
  }

  Stream<List<CatalogAttraction>> watchAttractions({String? favoritedBy, String? destination}) {
    Query<Map<String, dynamic>> query = _attractions;
    if (destination != null) {
      query = query.where('destinationQuery', isEqualTo: _normalizeDestination(destination));
    } else if (favoritedBy != null) {
      query = query.where('favoritedBy', arrayContains: favoritedBy);
    }
    return query.snapshots().map((snap) => snap.docs
        .where(_isVisibleStatus)
        .map(_attractionFrom)
        .toList());
  }

  Future<List<CatalogAttraction>> searchAttractionsByName(String query, {int limit = 60}) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return [];
    final snap = await _attractions.get();
    final matches = snap.docs
        .where(_isVisibleStatus)
        .where((d) => ((d.data()['name'] as String?) ?? '').toLowerCase().contains(needle))
        .map(_attractionFrom)
        .toList();
    return matches.length > limit ? matches.sublist(0, limit) : matches;
  }

  AttractionFees _feesFrom(Map<String, dynamic>? m) {
    if (m == null) return const AttractionFees();
    return AttractionFees(
      adult: m['adult'] as String?,
      child: m['child'] as String?,
      senior: m['senior'] as String?,
    );
  }

  Future<void> toggleAttractionFavorite(String id, String uid, String tripId, bool fav, {List<String> categories = const []}) {
    if (fav && categories.isNotEmpty) {
      unawaited(_bumpAffinity(uid, 'attractionCategoryAffinity', categories, _favoriteAffinityWeight));
    }
    return _toggleFav(_attractions, id, '$uid#$tripId', fav);
  }

  Future<void> submitAttractionReport({
    required String authorId,
    required String authorName,
    required String name,
    required String location,
    String description = '',
    String photoUrl = '',
  }) {
    return _attractionReports.add({
      'authorId': authorId,
      'authorName': authorName,
      'name': name,
      'location': location,
      'description': description,
      'photoUrl': photoUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  CatalogRestaurant _restaurantFrom(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    return CatalogRestaurant(
      id: d.id,
      favoritedBy: _favBy(d),
      name: (d.data()['name'] as String?) ?? '',
      cuisineTags: _restaurantCuisineTags(d.data()),
      location: _restaurantLocationLabel(d.data()),
      rating: '',
      reviews: '',
      priceRange: (d.data()['priceRange'] as String?) ?? (d.data()['price_range'] as String?) ?? '',
      image: (d.data()['image'] as String?) ?? (d.data()['image_url'] as String?) ?? '',
      openingHours: (d.data()['openingHours'] as String?) ?? (d.data()['opening_hours'] as String?) ?? '',
      address: (d.data()['address'] as String?) ?? '',
      phone: (d.data()['phone'] as String?) ?? '',
      website: (d.data()['website'] as String?) ?? '',
      description: (d.data()['description'] as String?) ?? (d.data()['about'] as String?) ?? '',
      lat: (d.data()['lat'] as num?)?.toDouble(),
      lng: (d.data()['lng'] as num?)?.toDouble(),
      distanceKm: (d.data()['distanceKm'] as num?)?.toDouble(),
    );
  }

  Stream<List<CatalogRestaurant>> watchRestaurants({String? favoritedBy, String? destination}) {
    Query<Map<String, dynamic>> query = _restaurants;
    if (destination != null) {
      query = query.where('destinationQuery', isEqualTo: _normalizeDestination(destination));
    } else if (favoritedBy != null) {
      query = query.where('favoritedBy', arrayContains: favoritedBy);
    }
    return query.snapshots().map((snap) => snap.docs
        .where(_isVisibleStatus)
        .map(_restaurantFrom)
        .toList());
  }

  // Same reasoning as [searchAttractionsByName] — a keyword search box
  // means the restaurant's actual name, not its city/destination field.
  Future<List<CatalogRestaurant>> searchRestaurantsByName(String query, {int limit = 60}) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return [];
    final snap = await _restaurants.get();
    final matches = snap.docs
        .where((d) => ((d.data()['name'] as String?) ?? '').toLowerCase().contains(needle))
        .map(_restaurantFrom)
        .toList();
    return matches.length > limit ? matches.sublist(0, limit) : matches;
  }

  String _restaurantLocationLabel(Map<String, dynamic> data) {
    final raw = data['location'];
    if (raw is String && raw.isNotEmpty) return raw;
    final city = data['city'] as String?;
    final country = data['country'] as String?;
    if (city != null && city.isNotEmpty && country != null && country.isNotEmpty) return '$city, $country';
    return city ?? country ?? '';
  }

  List<String> _restaurantCuisineTags(Map<String, dynamic> data) {
    final tags = data['cuisineTags'] as List?;
    if (tags != null && tags.isNotEmpty) return List<String>.from(tags);
    final cuisine = data['cuisine'];
    if (cuisine is List) return List<String>.from(cuisine);
    if (cuisine is String && cuisine.isNotEmpty) return [cuisine];
    return const [];
  }

  Future<void> toggleRestaurantFavorite(String id, String uid, String tripId, bool fav, {List<String> cuisineTags = const []}) {
    if (fav && cuisineTags.isNotEmpty) {
      unawaited(_bumpAffinity(uid, 'restaurantCuisineAffinity', cuisineTags, _favoriteAffinityWeight));
    }
    return _toggleFav(_restaurants, id, '$uid#$tripId', fav);
  }

  Future<List<NearbyPlace>> fetchNearbyPlaces({required double lat, required double lon, required String category}) async {
    final found = await PlacesApiService.instance.searchNearbyStable(lat: lat, lon: lon, category: category);
    final withDistance = found.map((p) {
      final km = _distanceKm(lat, lon, p.lat, p.lon);
      return (place: p, km: km);
    }).toList()
      ..sort((a, b) => a.km.compareTo(b.km));
    final images = await Future.wait(withDistance.map((e) => PlacesApiService.instance.resolveImage(e.place.tags)));
    return [
      for (var i = 0; i < withDistance.length; i++)
        NearbyPlace(
          id: withDistance[i].place.id,
          name: withDistance[i].place.name,
          category: category,
          categoryLabel: _osmCategoryLabel(withDistance[i].place, category),
          rating: 'New',
          distance: withDistance[i].km < 1 ? '${(withDistance[i].km * 1000).round()} m' : '${withDistance[i].km.toStringAsFixed(1)} km',
          image: images[i] ?? '',
          lat: withDistance[i].place.lat,
          lon: withDistance[i].place.lon,
        ),
    ];
  }

  String _osmCategoryLabel(OsmPlace p, String category) {
    final cuisine = p.tags['cuisine'];
    if (category == 'Restaurants' || category == 'Cafes') {
      if (cuisine != null && cuisine.isNotEmpty) {
        return cuisine.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).take(2).join(' • ');
      }
    }
    if (category == 'Shopping') {
      final shop = p.tags['shop'];
      if (shop != null && shop.isNotEmpty) return shop.replaceAll('_', ' ');
    }
    final tourism = p.tags['tourism'];
    if (category == 'Attractions' && tourism != null && tourism.isNotEmpty) {
      return tourism.replaceAll('_', ' ');
    }
    return category;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    double degToRad(double deg) => deg * (pi / 180);
    final dLat = degToRad(lat2 - lat1);
    final dLon = degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(degToRad(lat1)) * cos(degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  Future<({String name, String? nameLocal})> _resolveName(String rawName, Map<String, dynamic>? existing) async {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty || !NameTranslationService.looksNonEnglish(trimmed)) {
      return (name: trimmed, nameLocal: null);
    }
    final existingLocal = existing?['nameLocal'] as String?;
    final existingName = existing?['name'] as String?;
    if (existingLocal == trimmed && existingName != null && existingName.isNotEmpty) {
      return (name: existingName, nameLocal: existingLocal);
    }
    final translated = await NameTranslationService.instance.translateToEnglish(trimmed);
    if (translated == null || translated.isEmpty) {
      return (name: trimmed, nameLocal: null);
    }
    return (name: translated, nameLocal: trimmed);
  }

  Future<String> _areaLabel(OsmPlace p, String destLabel) async {
    final raw = (p.tags['addr:suburb'] ??
            p.tags['addr:neighbourhood'] ??
            p.tags['addr:district'] ??
            p.tags['addr:quarter'] ??
            '')
        .trim();
    if (raw.isEmpty) return destLabel;
    var area = raw;
    if (NameTranslationService.looksNonEnglish(raw)) {
      final translated = await NameTranslationService.instance.translateToEnglish(raw);
      if (translated != null && translated.isNotEmpty) area = translated;
    }
    return destLabel.isEmpty ? area : '$area, $destLabel';
  }

  List<String> _favBy(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      List<String>.from(d.data()['favoritedBy'] as List? ?? const []);

  Future<void> _toggleFav(CollectionReference<Map<String, dynamic>> col, String id, String key, bool fav) {
    return col.doc(id).update({
      'favoritedBy': fav ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key]),
    });
  }


  static const int _favoriteAffinityWeight = 5;

  Future<void> _bumpAffinity(String uid, String field, List<String> tags, int weight) async {
    if (uid.isEmpty || tags.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        field: {for (final t in tags) t: FieldValue.increment(weight)},
      }, SetOptions(merge: true));
    } catch (_) {
    }
  }

  Future<void> recordAttractionView(String attractionId, String uid, List<String> categories) async {
    if (uid.isEmpty || attractionId.isEmpty || categories.isEmpty) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final viewed = List<String>.from(snap.data()?['viewedAttractionIds'] as List? ?? const []);
        if (viewed.contains(attractionId)) return;
        tx.set(userRef, {
          'viewedAttractionIds': FieldValue.arrayUnion([attractionId]),
          'attractionCategoryAffinity': {for (final c in categories) c: FieldValue.increment(1)},
        }, SetOptions(merge: true));
      });
    } catch (_) {
    }
  }

  Future<void> recordRestaurantView(String restaurantId, String uid, List<String> cuisineTags) async {
    if (uid.isEmpty || restaurantId.isEmpty || cuisineTags.isEmpty) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final viewed = List<String>.from(snap.data()?['viewedRestaurantIds'] as List? ?? const []);
        if (viewed.contains(restaurantId)) return;
        tx.set(userRef, {
          'viewedRestaurantIds': FieldValue.arrayUnion([restaurantId]),
          'restaurantCuisineAffinity': {for (final c in cuisineTags) c: FieldValue.increment(1)},
        }, SetOptions(merge: true));
      });
    } catch (_) {
    }
  }

  Future<void> recordHotelView(String hotelId, String uid, List<String> amenities) async {
    if (uid.isEmpty || hotelId.isEmpty || amenities.isEmpty) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final viewed = List<String>.from(snap.data()?['viewedHotelIds'] as List? ?? const []);
        if (viewed.contains(hotelId)) return;
        tx.set(userRef, {
          'viewedHotelIds': FieldValue.arrayUnion([hotelId]),
          'hotelAmenityAffinity': {for (final a in amenities) a: FieldValue.increment(1)},
        }, SetOptions(merge: true));
      });
    } catch (_) {
    }
  }

  Stream<Map<String, int>> watchAttractionCategoryAffinity(String uid) {
    if (uid.isEmpty) return Stream.value(const {});
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['attractionCategoryAffinity'] as Map? ?? const {};
      return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
  }

  Stream<Map<String, int>> watchRestaurantCuisineAffinity(String uid) {
    if (uid.isEmpty) return Stream.value(const {});
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['restaurantCuisineAffinity'] as Map? ?? const {};
      return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
  }

  Stream<Map<String, int>> watchHotelAmenityAffinity(String uid) {
    if (uid.isEmpty) return Stream.value(const {});
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['hotelAmenityAffinity'] as Map? ?? const {};
      return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
  }

  static const Duration _placesRefreshTtl = Duration(minutes: 20);
  final Map<String, DateTime> _attractionsRefreshedAt = {};
  final Map<String, DateTime> _restaurantsRefreshedAt = {};

  String _normalizeDestination(String destination) => destination.trim().toLowerCase();

  /// Given [areas] (bare city names like 'Kuala Lumpur') inside a [country],
  /// returns the subset that already have at least one `catalog_attractions`
  /// doc cached under the exact "$area, $country" key the destination
  /// picker would eventually write via [refreshAttractions]. Used to avoid
  /// offering an area in the picker that's likely to come back empty.
  /// One tiny limit-1 existence query per area, in parallel; any Firestore
  /// error for a given area is treated as "unknown" (excluded), not fatal.
  Future<Set<String>> areasWithAttractions(String country, List<String> areas) async {
    if (areas.isEmpty) return {};
    final results = await Future.wait(areas.map((area) async {
      try {
        final snap = await _attractions
            .where('destinationQuery', isEqualTo: _normalizeDestination('$area, $country'))
            .limit(1)
            .get();
        return snap.docs.isNotEmpty ? area : null;
      } catch (_) {
        return null;
      }
    }));
    return results.whereType<String>().toSet();
  }

  Future<void> refreshAttractions(String destination) async {
    final key = _normalizeDestination(destination);
    if (key.isEmpty) return;
    final last = _attractionsRefreshedAt[key];
    if (last != null && DateTime.now().difference(last) < _placesRefreshTtl) return;
    final point = await PlacesApiService.instance.geocode(destination);
    if (point == null) return;
    _attractionsRefreshedAt[key] = DateTime.now();
    await _refreshAttractionsFromOsm(destination, key, point);
  }

  Future<void> _refreshAttractionsFromOsm(String destination, String key, ({double lat, double lon, String? countryCode, String? label}) point) async {
    final found = await PlacesApiService.instance.searchNearby(
      lat: point.lat,
      lon: point.lon,
      filter: PlacesApiService.overpassFilterFor('Attractions'),
      radiusMeters: 15000,
      limit: 20,
    );
    final tagDescriptions = await Future.wait(found.map((p) => PlacesApiService.instance.resolveDescription(p.tags)));
    final tagImages = await Future.wait(found.map((p) => PlacesApiService.instance.resolveImage(p.tags)));
    final filled = await Future.wait([
      for (var i = 0; i < found.length; i++) _fillGaps(found[i], tagImages[i], tagDescriptions[i], allowNameLookup: true),
    ]);
    final images = _withoutSharedDuplicates([for (final f in filled) f.image]);
    final descriptions = [for (final f in filled) f.description];
    final existingDocs = await Future.wait(found.map((p) => _attractions.doc('osm_${p.id}').get()));
    final resolvedNames = await Future.wait([
      for (var i = 0; i < found.length; i++) _resolveName(found[i].name, existingDocs[i].data()),
    ]);
    final destLabel = point.label ?? destination.trim();
    final areaLabels = await Future.wait([for (final p in found) _areaLabel(p, destLabel)]);
    for (var i = 0; i < found.length; i++) {
      final p = found[i];
      final tourism = p.tags['tourism'] ?? '';
      try {
        await _attractions.doc('osm_${p.id}').set({
          'name': resolvedNames[i].name,
          if (resolvedNames[i].nameLocal != null) 'nameLocal': resolvedNames[i].nameLocal,
          'category': tourism.isEmpty ? 'Attraction' : _titleCase(tourism.replaceAll('_', ' ')),
          'categories': [if (tourism.isNotEmpty) _titleCase(tourism.replaceAll('_', ' '))],
          'price': p.tags['fee'] == 'no' ? 'Free entry' : '',
          if (images[i] != null) 'image': images[i],
          'location': areaLabels[i],
          'destinationQuery': key,
          if (point.countryCode != null) 'country': point.countryCode,
          'openingHours': p.tags['opening_hours'] ?? '',
          'address': p.address,
          'phone': p.tags['phone'] ?? p.tags['contact:phone'] ?? '',
          'website': p.tags['website'] ?? p.tags['contact:website'] ?? '',
          'description': descriptions[i] ?? '',
          'rating': 'New',
          'reviews': '0',
          'lat': p.lat, 'lng': p.lon,
          'distanceKm': _distanceKm(point.lat, point.lon, p.lat, p.lon),
          'facilities': [
            if (p.tags['wheelchair'] == 'yes') 'Wheelchair accessible',
          ],
        }, SetOptions(merge: true));
      } catch (_) {
      }
    }
  }

  Future<void> refreshRestaurants(String destination) async {
    final key = _normalizeDestination(destination);
    if (key.isEmpty) return;
    final last = _restaurantsRefreshedAt[key];
    if (last != null && DateTime.now().difference(last) < _placesRefreshTtl) return;
    final point = await PlacesApiService.instance.geocode(destination);
    if (point == null) return;
    final found = await PlacesApiService.instance.searchNearby(
      lat: point.lat,
      lon: point.lon,
      filter: PlacesApiService.overpassFilterFor('Restaurants'),
      radiusMeters: 15000,
      limit: 20,
    );
    _restaurantsRefreshedAt[key] = DateTime.now();
    final tagDescriptions = await Future.wait(found.map((p) => PlacesApiService.instance.resolveDescription(p.tags)));
    final tagImages = await Future.wait(found.map((p) => PlacesApiService.instance.resolveImage(p.tags)));
    final filled = await Future.wait([
      for (var i = 0; i < found.length; i++) _fillGaps(found[i], tagImages[i], tagDescriptions[i], allowNameLookup: false),
    ]);
    final images = _withoutSharedDuplicates([for (final f in filled) f.image]);
    final descriptions = [for (final f in filled) f.description];
    final existingDocs = await Future.wait(found.map((p) => _restaurants.doc('osm_${p.id}').get()));
    final resolvedNames = await Future.wait([
      for (var i = 0; i < found.length; i++) _resolveName(found[i].name, existingDocs[i].data()),
    ]);
    final destLabel = point.label ?? destination.trim();
    final areaLabels = await Future.wait([for (final p in found) _areaLabel(p, destLabel)]);
    for (var i = 0; i < found.length; i++) {
      final p = found[i];
      final cuisine = p.tags['cuisine'] ?? '';
      const junkCuisineValues = {'restaurant'};
      final cuisineTags = cuisine.isEmpty
          ? const <String>[]
          : cuisine
              .split(';')
              .map((s) => _titleCase(s.trim().replaceAll('_', ' ')))
              .where((s) => s.isNotEmpty && !junkCuisineValues.contains(s.toLowerCase()))
              .toList();
      try {
        await _restaurants.doc('osm_${p.id}').set({
          'name': resolvedNames[i].name,
          if (resolvedNames[i].nameLocal != null) 'nameLocal': resolvedNames[i].nameLocal,
          'cuisineTags': cuisineTags,
          'location': areaLabels[i],
          'destinationQuery': key,
          if (point.countryCode != null) 'country': point.countryCode,
          'priceRange': '',
          if (images[i] != null) 'image': images[i],
          'openingHours': p.tags['opening_hours'] ?? '',
          'address': p.address,
          'phone': p.tags['phone'] ?? p.tags['contact:phone'] ?? '',
          'website': p.tags['website'] ?? p.tags['contact:website'] ?? '',
          'description': descriptions[i] ?? '',
          'rating': 'New',
          'reviews': '0',
          'lat': p.lat, 'lng': p.lon,
          'distanceKm': _distanceKm(point.lat, point.lon, p.lat, p.lon),
        }, SetOptions(merge: true));
      } catch (_) {
      }
    }
  }

  Future<({String? image, String? description})> _fillGaps(
    OsmPlace p,
    String? tagImage,
    String? tagDescription, {
    required bool allowNameLookup,
  }) async {
    String? image = tagImage;
    String? description = tagDescription;
    if (image == null || description == null) {
      final website = p.tags['website'] ?? p.tags['contact:website'] ?? '';
      if (website.isNotEmpty) {
        final web = await PlacesApiService.instance.resolveFromWebsite(website);
        image ??= web?.image;
        description ??= web?.description;
      }
    }
    if (allowNameLookup) {
      image ??= await PlacesApiService.instance.resolveImageByName(p.name);
      description ??= await PlacesApiService.instance.resolveDescriptionByName(p.name);
    }
    return (image: image, description: description);
  }

  List<String?> _withoutSharedDuplicates(List<String?> images) {
    final counts = <String, int>{};
    for (final url in images) {
      if (url == null || url.isEmpty) continue;
      counts[url] = (counts[url] ?? 0) + 1;
    }
    return [for (final url in images) (url != null && (counts[url] ?? 0) > 1) ? null : url];
  }

  String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class CatalogAttraction extends AttractionData {
  final String id;
  final List<String> favoritedBy;
  const CatalogAttraction({
    required this.id,
    required this.favoritedBy,
    required super.name,
    required super.category,
    required super.rating,
    required super.reviews,
    required super.price,
    required super.image,
    super.location,
    super.openingHours,
    super.address,
    super.categories,
    super.openingHoursByDay,
    super.facilities,
    super.highlights,
    super.phone,
    super.website,
    super.recommendedDuration,
    super.images,
    super.fees,
    super.description,
    super.distanceKm,
    super.lat,
    super.lng,
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}

class CatalogRestaurant extends RestaurantData {
  final String id;
  final List<String> favoritedBy;
  const CatalogRestaurant({
    required this.id,
    required this.favoritedBy,
    required super.name,
    required super.cuisineTags,
    required super.location,
    required super.rating,
    required super.reviews,
    required super.priceRange,
    required super.image,
    super.openingHours,
    super.address,
    super.phone,
    super.website,
    super.description,
    super.lat,
    super.lng,
    super.distanceKm,
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}

class _CachedSearch<T> {
  final DateTime fetchedAt;
  final List<T> results;
  _CachedSearch(this.fetchedAt, this.results);
}
