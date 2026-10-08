import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/popular_destinations.dart';
import '../models/duffel_models.dart';
import '../models/explore_models.dart';
import '../models/nearby_models.dart';
import '../models/review_models.dart';
import '../services/currency_service.dart';
import '../services/duffel_api_service.dart';
import '../services/format_utils.dart';
import '../services/places_api_service.dart';
import '../services/rollinggo_api_service.dart';
import 'review_helpers.dart';

/// Explore/Near By show a catalogue of flights, hotels, attractions and
/// nearby places. Flights/hotels come live from Duffel/RollingGo.
/// Attractions/restaurants/near-by-places come live from OpenStreetMap
/// (see [PlacesApiService] — Nominatim for geocoding a destination,
/// Overpass for the actual POIs), fetched into `catalog_attractions` /
/// `catalog_restaurants` / Near By's live query and read from there like
/// any other real data — this used to be a fixed seeded catalogue baked
/// into the app, which is exactly the "it's all the same hardcoded Tokyo
/// data regardless of what you search" problem a live source fixes.
/// Favoriting an item is a real, persisted action either way.
///
/// Saving ("favoriting") an item is scoped to whichever trip/plan is
/// selected on Explore when you tap the heart — not a single global
/// per-user list — because the whole point is "save this hotel for my Bali
/// trip" vs "save it for my Japan trip". Rather than reshaping
/// `favoritedBy` into a map keyed by tripId (which the existing
/// `hasOnly(['favoritedBy'])` security rule would have to be rewritten
/// for), each entry in that same array is just `"<uid>#<tripId>"`. So the
/// array-union/array-remove writes and the `favoritedBy: <key>` filter on
/// the watch methods below both keep working unchanged — only the string
/// stored in them changed shape.
class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  CollectionReference<Map<String, dynamic>> get _flights => FirebaseFirestore.instance.collection('catalog_flights');
  CollectionReference<Map<String, dynamic>> get _hotels => FirebaseFirestore.instance.collection('catalog_hotels');
  CollectionReference<Map<String, dynamic>> get _attractions =>
      FirebaseFirestore.instance.collection('catalog_attractions');
  CollectionReference<Map<String, dynamic>> get _restaurants =>
      FirebaseFirestore.instance.collection('catalog_restaurants');
  CollectionReference<Map<String, dynamic>> get _appCache => FirebaseFirestore.instance.collection('app_cache');
  // A pre-scraped, worldwide OSM-derived dataset — curated outside this
  // app (not written by any code here) with real Wikimedia Commons
  // photos (properly attributed) and a couple of pre-translated name
  // variants already filled in, which [refreshAttractions] now prefers
  // over hitting Overpass/Wikipedia live for every refresh. See that
  // method's doc comment for exactly how it's used and when it falls
  // back to the old live fetch instead.
  CollectionReference<Map<String, dynamic>> get _places => FirebaseFirestore.instance.collection('catalog_places');

  // ---------------- Short-lived per-user search cache ----------------
  // Separate from the `app_cache` Firestore doc above (that one is a
  // single shared "popular destinations" snapshot, refreshed every few
  // hours for everyone). This one is in-memory only, keyed by uid so one
  // person's search never answers from another's, and expires quickly —
  // it only exists to avoid re-hitting Duffel/RollingGo when the same
  // person repeats the same search within a short window (e.g. flipping
  // between Explore tabs), not to keep results fresh across a session.
  static const Duration _searchCacheTtl = Duration(minutes: 3);
  final Map<String, _CachedSearch<DuffelFlightOffer>> _flightSearchCache = {};
  final Map<String, _CachedSearch<DuffelStayResult>> _staySearchCache = {};
  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Called on sign-out (see `profile_page.dart`'s `_confirmLogout`). The
  /// cache keys already include uid, so a different account signing in
  /// afterwards could never read another account's entries anyway — this
  /// is just belt-and-suspenders so nothing from a finished session lingers
  /// in memory (and stops the maps from growing across every account that
  /// ever used this device) once nobody can act on it anymore.
  void clearSearchCache() {
    _flightSearchCache.clear();
    _staySearchCache.clear();
  }

  // ---------------- Flights ----------------
  // [favoritedBy], despite the name kept for symmetry with hotels/attractions,
  // is actually a "uid#tripId" composite key — see the class doc below for
  // why saves are scoped per trip instead of per user.
  Stream<List<CatalogFlight>> watchFlights({String? favoritedBy}) {
    return _flights.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .map((d) => CatalogFlight(
              id: d.id,
              favoritedBy: _favBy(d),
              depTime: (d.data()['depTime'] as String?) ?? '',
              arrTime: (d.data()['arrTime'] as String?) ?? '',
              duration: (d.data()['duration'] as String?) ?? '',
              from: (d.data()['from'] as String?) ?? '',
              to: (d.data()['to'] as String?) ?? '',
              stops: (d.data()['stops'] as String?) ?? '',
              price: (d.data()['price'] as String?) ?? '',
              fareType: (d.data()['fareType'] as String?) ?? '',
              airline: (d.data()['airline'] as String?) ?? '',
              priceAmount: (d.data()['priceAmount'] as num?)?.toDouble(),
              priceCurrency: d.data()['priceCurrency'] as String?,
              airlineLogoUrl: d.data()['airlineLogoUrl'] as String?,
            ))
        .toList());
  }

  Future<void> toggleFlightFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_flights, id, '$uid#$tripId', fav);

  /// A flight found via a live Duffel search isn't in the seeded
  /// catalogue yet — saving ("favoriting") one from a search result
  /// writes it into this same collection, tagged `source: 'duffel'`, so
  /// it immediately behaves like any other catalogue flight (shows in
  /// Saved Items, has a real detail page, etc.) without a second,
  /// parallel data model. Returns the new doc's id.
  Future<String> saveDuffelFlight(DuffelFlightOffer offer, {required String uid, required String tripId}) async {
    final doc = await _flights.add({
      'source': 'duffel',
      'duffelOfferId': offer.id,
      'depTime': _timeLabel(offer.departureAt),
      'arrTime': _timeLabel(offer.arrivalAt),
      'duration': offer.durationLabel,
      'from': offer.originCode,
      'to': offer.destinationCode,
      'stops': offer.stopsLabel,
      // 'price' stays the pre-formatted fallback shown if conversion
      // ever isn't possible (see CatalogFlight.displayPrice); the raw
      // amount/currency alongside it are what actually drive showing
      // this in the saver's own chosen currency rather than freezing it
      // in whatever currency Duffel quoted at save time.
      'price': '${offer.totalCurrency} ${offer.totalAmount.toStringAsFixed(0)}',
      'priceAmount': offer.totalAmount,
      'priceCurrency': offer.totalCurrency,
      'fareType': 'Economy',
      'airline': offer.airlineName,
      'airlineLogoUrl': offer.airlineLogoUrl,
      'favoritedBy': ['$uid#$tripId'],
    });
    return doc.id;
  }

  String _timeLabel(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// Runs a live one-way search for [origin]→[destination] on
  /// [departureDate] — used directly by an explicit search in Explore, or
  /// with [kDefaultHomeAirport] + a selected trip's destination/dates.
  /// Short-lived, per-user cache (see [_searchCacheTtl]): the same person
  /// repeating the same search within a few minutes (switching tabs back
  /// and forth, re-opening a trip) gets the cached result instead of
  /// re-hitting Duffel; a different [uid] or different search params
  /// always misses. See [getPopularFlights] for the separate, much
  /// longer-lived "nothing to search with yet" default.
  Future<List<DuffelFlightOffer>> searchFlights({
    required String uid,
    required String origin,
    required String destination,
    required DateTime departureDate,
  }) async {
    final key = 'f|$uid|$origin|$destination|${_dateKey(departureDate)}';
    final cached = _flightSearchCache[key];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _searchCacheTtl) {
      return cached.results;
    }
    final results =
        await DuffelApiService.instance.searchFlights(origin: origin, destination: destination, departureDate: departureDate);
    _flightSearchCache[key] = _CachedSearch(DateTime.now(), results);
    return results;
  }

  /// A small, fixed set of popular destinations, searched from
  /// [kDefaultHomeAirport] ~30 days out — the real-data default shown
  /// when Explore has no selected trip and nothing has been searched yet
  /// (see class doc: there is no placeholder/seeded flight data anymore).
  /// Cached in a single shared `app_cache` doc for [_popularCacheTtl] so
  /// opening Explore doesn't re-hit Duffel on every load — refreshed by
  /// whichever user's Explore next finds it stale.
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
        // One destination failing (no route available, sandbox gap,
        // temporary Duffel error, ...) shouldn't blank out the rest.
      }
    }
    await _writePopularCache(
      'popular_flights',
      results.map((e) => {'destinationLabel': e.key, ...e.value.toCacheMap()}).toList(),
    );
    return results;
  }

  // ---------------- Hotels ----------------
  Stream<List<CatalogHotel>> watchHotels({String? favoritedBy}) {
    return _hotels.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .map((d) => CatalogHotel(
              id: d.id,
              favoritedBy: _favBy(d),
              name: (d.data()['name'] as String?) ?? '',
              location: (d.data()['location'] as String?) ?? '',
              rating: _ratingLabel(d.data()),
              reviews: _reviewCountLabel(d.data()),
              price: (d.data()['price'] as String?) ?? '',
              image: (d.data()['image'] as String?) ?? '',
              amenities: List<String>.from(d.data()['amenities'] as List? ?? const []),
              priceAmount: (d.data()['priceAmount'] as num?)?.toDouble(),
              priceCurrency: d.data()['priceCurrency'] as String?,
            ))
        .toList());
  }

  Future<void> toggleHotelFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_hotels, id, '$uid#$tripId', fav);

  Stream<List<PlaceReview>> watchHotelReviews(String hotelId) => watchReviewsFor(_hotels.doc(hotelId));

  Future<void> addHotelReview(String hotelId, {required String authorId, required String authorName, required int rating, required String comment}) =>
      addReviewFor(_hotels.doc(hotelId), authorId: authorId, authorName: authorName, rating: rating, comment: comment);

  /// Same idea as [saveDuffelFlight] — persists a real hotel search
  /// result the user favorited into `catalog_hotels`, tagged
  /// `source: 'rollinggo'` (Hotels' real data source — see
  /// [searchStays]). `rating`/`reviews` are seeded from that search
  /// result's own review data when it has any, so the card shows
  /// something sensible even before this hotel gets its first in-app
  /// review (see [_ratingLabel]/[_reviewCountLabel]). RollingGo results
  /// never carry a guest `reviewScore` (only the official star
  /// classification in `rating`) — falling back to that keeps the stored
  /// rating real instead of always blank, while `reviews` (a *count*) has
  /// no such fallback and stays honestly empty.
  Future<String> saveDuffelStay(DuffelStayResult stay, {required String uid, required String tripId}) async {
    final ratingLabel = stay.reviewScore != null
        ? (stay.reviewScore! / 2).toStringAsFixed(1)
        : (stay.rating != null ? stay.rating!.toStringAsFixed(1) : '');
    final doc = await _hotels.add({
      'source': 'rollinggo',
      'hotelAccommodationId': stay.accommodationId,
      'hotelSearchResultId': stay.searchResultId,
      'name': stay.name,
      'location': stay.address,
      'rating': ratingLabel,
      'reviews': stay.reviewCount != null ? compactCount(stay.reviewCount!) : '',
      // Same "fallback string + raw amount/currency" split as
      // saveDuffelFlight above — see CatalogHotel.displayPrice.
      'price': '${stay.cheapestCurrency} ${stay.cheapestTotalAmount.toStringAsFixed(0)}',
      'priceAmount': stay.cheapestTotalAmount,
      'priceCurrency': stay.cheapestCurrency,
      'image': stay.photoUrl ?? '',
      'amenities': stay.amenities,
      'favoritedBy': ['$uid#$tripId'],
    });
    return doc.id;
  }

  /// Live hotel search for [destinationQuery] — used directly by an
  /// explicit search in Explore, or with a selected trip's
  /// destination/dates. Same short-lived per-user cache as [searchFlights]
  /// — see [_searchCacheTtl]. Backed by RollingGo, not Duffel — see
  /// [RollingGoApiService]'s doc comment for why Hotels and Flights use
  /// two different providers.
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

  /// Same pattern as [getPopularFlights], for hotels — a 4-night stay
  /// ~30 days out in each of [kPopularDestinations].
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
        // one destination failing shouldn't blank out the rest
      }
    }
    await _writePopularCache(
      'popular_hotels',
      results.map((e) => {'destinationLabel': e.key, ...e.value.toCacheMap()}).toList(),
    );
    return results;
  }

  static const Duration _popularCacheTtl = Duration(hours: 6);

  /// Returns the cached item list for [cacheKey] if it's fresh enough,
  /// else null (meaning: go fetch live and call [_writePopularCache]).
  /// Never throws — a cache read failing (offline, rules not deployed
  /// yet, permission hiccup, ...) should fall back to a live fetch, not
  /// blow up the whole popular-destinations search.
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

  /// Never throws — the live results were already fetched by the time
  /// this is called, so a failure to cache them (e.g. `app_cache`'s
  /// Firestore rule not deployed yet) shouldn't stop those results from
  /// being returned to the person; it just means next time re-fetches
  /// live too, instead of hitting the cache.
  Future<void> _writePopularCache(String cacheKey, List<Map<String, dynamic>> items) async {
    try {
      await _appCache.doc(cacheKey).set({'updatedAt': Timestamp.now(), 'items': items});
    } catch (_) {
      // see doc comment above
    }
  }

  // ---------------- Attractions ----------------
  // [destination] scopes results to whichever place they were fetched for
  // (see [refreshAttractions]) — needed now that this collection holds
  // real POIs for whatever city each trip/search actually asked about,
  // not one fixed Tokyo seed shown to everyone regardless of context.
  Stream<List<CatalogAttraction>> watchAttractions({String? favoritedBy, String? destination}) {
    return _attractions.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .where((d) => destination == null || (d.data()['destinationQuery'] as String?) == _normalizeDestination(destination))
        .map((d) => CatalogAttraction(
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
              rating: _ratingLabel(d.data()),
              reviews: _reviewCountLabel(d.data()),
              recommendedDuration: (d.data()['recommendedDuration'] as String?) ?? '',
              images: List<String>.from(d.data()['images'] as List? ?? const []),
              fees: _feesFrom(d.data()['fees'] as Map<String, dynamic>?),
              description: (d.data()['description'] as String?) ?? '',
            ))
        .toList());
  }

  AttractionFees _feesFrom(Map<String, dynamic>? m) {
    if (m == null) return const AttractionFees();
    return AttractionFees(
      adult: m['adult'] as String?,
      child: m['child'] as String?,
      senior: m['senior'] as String?,
    );
  }

  Future<void> toggleAttractionFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_attractions, id, '$uid#$tripId', fav);

  Stream<List<PlaceReview>> watchAttractionReviews(String attractionId) => watchReviewsFor(_attractions.doc(attractionId));

  Future<void> addAttractionReview(String attractionId, {required String authorId, required String authorName, required int rating, required String comment}) =>
      addReviewFor(_attractions.doc(attractionId), authorId: authorId, authorName: authorName, rating: rating, comment: comment);

  // ---------------- Restaurants ----------------
  Stream<List<CatalogRestaurant>> watchRestaurants({String? favoritedBy, String? destination}) {
    return _restaurants.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .where((d) => destination == null || (d.data()['destinationQuery'] as String?) == _normalizeDestination(destination))
        .map((d) => CatalogRestaurant(
              id: d.id,
              favoritedBy: _favBy(d),
              name: (d.data()['name'] as String?) ?? '',
              cuisineTags: List<String>.from(d.data()['cuisineTags'] as List? ?? const []),
              location: (d.data()['location'] as String?) ?? '',
              rating: _ratingLabel(d.data()),
              reviews: _reviewCountLabel(d.data()),
              priceRange: (d.data()['priceRange'] as String?) ?? '',
              image: (d.data()['image'] as String?) ?? '',
              openingHours: (d.data()['openingHours'] as String?) ?? 'Daily, 11:00 AM - 10:00 PM',
              address: (d.data()['address'] as String?) ?? '',
              phone: (d.data()['phone'] as String?) ?? '',
              website: (d.data()['website'] as String?) ?? '',
              description: (d.data()['description'] as String?) ?? '',
            ))
        .toList());
  }

  Future<void> toggleRestaurantFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_restaurants, id, '$uid#$tripId', fav);

  Stream<List<PlaceReview>> watchRestaurantReviews(String restaurantId) => watchReviewsFor(_restaurants.doc(restaurantId));

  Future<void> addRestaurantReview(String restaurantId, {required String authorId, required String authorName, required int rating, required String comment}) =>
      addReviewFor(_restaurants.doc(restaurantId), authorId: authorId, authorName: authorName, rating: rating, comment: comment);

  // ---------------- Near-by places ----------------
  // A one-shot live query (not a Firestore stream — there's nothing to
  // subscribe to) against real OpenStreetMap data around the device's
  // actual current position, replacing what used to be a fixed Tokyo
  // seed shown to every user everywhere regardless of where they really
  // were. Never throws: a geocoding/network failure from
  // [PlacesApiService] just means an empty list, which [NearByController]
  // already shows as "No places found nearby".
  Future<List<NearbyPlace>> fetchNearbyPlaces({required double lat, required double lon, required String category}) async {
    final filter = PlacesApiService.overpassFilterFor(category);
    final found = await PlacesApiService.instance.searchNearby(lat: lat, lon: lon, filter: filter);
    final withDistance = found.map((p) {
      final km = _distanceKm(lat, lon, p.lat, p.lon);
      return (place: p, km: km);
    }).toList()
      ..sort((a, b) => a.km.compareTo(b.km));
    // A real photo per place, not a blank box — tries the OSM tags
    // themselves first, then Wikipedia (see PlacesApiService.resolveImage;
    // all free/keyless). Run in parallel rather than one-by-one so a
    // list of ~20 places doesn't serialize ~20 network round-trips; a
    // single slow/failed lookup still can't block the rest since
    // resolveImage never throws.
    final images = await Future.wait(withDistance.map((e) => PlacesApiService.instance.resolveImage(e.place.tags)));
    return [
      for (var i = 0; i < withDistance.length; i++)
        NearbyPlace(
          id: withDistance[i].place.id,
          name: withDistance[i].place.name,
          category: category,
          categoryLabel: _osmCategoryLabel(withDistance[i].place, category),
          // OSM has no rating/review data — 'New' is honest (zero
          // in-app reviews so far) rather than a made-up number.
          rating: 'New',
          distance: withDistance[i].km < 1 ? '${(withDistance[i].km * 1000).round()} m' : '${withDistance[i].km.toStringAsFixed(1)} km',
          image: images[i] ?? '',
          lat: withDistance[i].place.lat,
          lon: withDistance[i].place.lon,
        ),
    ];
  }

  /// A short, readable subtitle built from whatever OSM tags this POI
  /// actually has (cuisine for a restaurant, shop type for a shop, ...),
  /// falling back to just the category chip name when OSM has nothing
  /// more specific tagged.
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

  List<String> _favBy(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      List<String>.from(d.data()['favoritedBy'] as List? ?? const []);

  /// The rating shown in list cards and detail-page headers. Once real
  /// reviews exist (`ratingCount` > 0, bumped by [addReviewFor] every time
  /// someone submits one), this is the true average of those reviews —
  /// otherwise it falls back to the seeded placeholder `rating` string so
  /// items with no reviews yet still show something reasonable.
  String _ratingLabel(Map<String, dynamic> data) {
    final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final sum = (data['ratingSum'] as num?)?.toDouble() ?? 0;
    if (count > 0) return (sum / count).toStringAsFixed(1);
    return (data['rating'] as String?) ?? '';
  }

  /// Same idea as [_ratingLabel] for the review-count half of the summary
  /// (e.g. the "(1.2k)" in "4.8 (1.2k)") — real count once there are real
  /// reviews, seeded placeholder otherwise.
  String _reviewCountLabel(Map<String, dynamic> data) {
    final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
    if (count > 0) return compactCount(count);
    return (data['reviews'] as String?) ?? '';
  }

  /// [key] is the composite "uid#tripId" saved-for-trip key (see class doc).
  Future<void> _toggleFav(CollectionReference<Map<String, dynamic>> col, String id, String key, bool fav) {
    return col.doc(id).update({
      'favoritedBy': fav ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key]),
    });
  }

  // How long a destination's attractions/restaurants stay fresh before
  // [refreshAttractions]/[refreshRestaurants] will hit Overpass again for
  // it — short-lived, same idea as the flight/hotel search cache above,
  // just to stop every rebuild (or every person browsing the same trip)
  // from re-querying the same city repeatedly.
  static const Duration _placesRefreshTtl = Duration(minutes: 20);
  final Map<String, DateTime> _attractionsRefreshedAt = {};
  final Map<String, DateTime> _restaurantsRefreshedAt = {};

  /// Firestore-safe, comparison-stable key for a free-text destination
  /// string ("Tokyo", "Tokyo, Japan", " tokyo ") — trimmed/lowercased so
  /// the same place always matches the same stored docs regardless of
  /// how it was typed/capitalised.
  String _normalizeDestination(String destination) => destination.trim().toLowerCase();

  /// Fetches real attractions for [destination] from OpenStreetMap (see
  /// [PlacesApiService]) and upserts them into `catalog_attractions`,
  /// each tagged with `destinationQuery` so [watchAttractions] can scope
  /// to just this place. Upserts by a stable id derived from the OSM
  /// element (`set(..., merge: true)`) so calling this again for the
  /// same destination refreshes details instead of duplicating rows, and
  /// never touches `favoritedBy`/`ratingSum`/`ratingCount` on an existing
  /// doc (those are real user activity, not something a re-fetch should
  /// reset). A no-op within [_placesRefreshTtl] of the last successful
  /// fetch for the same destination, and silently does nothing if
  /// geocoding/Overpass fails (the UI just keeps whatever it already has
  /// — same "flaky network means stale, not broken" behaviour as the
  /// flight/hotel search cache).
  Future<void> refreshAttractions(String destination) async {
    final key = _normalizeDestination(destination);
    if (key.isEmpty) return;
    final last = _attractionsRefreshedAt[key];
    if (last != null && DateTime.now().difference(last) < _placesRefreshTtl) return;
    final point = await PlacesApiService.instance.geocode(destination);
    if (point == null) return;
    _attractionsRefreshedAt[key] = DateTime.now();
    // Prefer the pre-scraped `catalog_places` collection (see the [_places]
    // getter's doc comment) — it already has a real, properly-attributed
    // photo and doesn't need a live Overpass+Wikipedia round trip per
    // place. Only falls back to the old live-OSM fetch below when
    // [point] has no resolvable country code, or `catalog_places` simply has no
    // rows for that country yet (the scrape is still country-by-country,
    // not worldwide from day one) — so a destination not covered yet
    // still shows *something* instead of an empty Attractions tab.
    final fromPlaces = point.countryCode == null
        ? false
        : await _refreshAttractionsFromPlacesCollection(destination, key, point.countryCode!, point);
    if (fromPlaces) return;
    await _refreshAttractionsFromOsm(destination, key, point);
  }

  /// Fills `catalog_attractions` for [destination] from the curated
  /// `catalog_places` collection instead of a live OSM fetch — see
  /// [refreshAttractions]'s doc comment for why this is tried first.
  /// `catalog_places` is scoped by country (not by city/geohash — see the class
  /// doc on the [_places] getter), so this pulls every row for
  /// [countryCode] (every row is attraction-type for now — see the
  /// query's own comment for why `category` isn't filtered on) and keeps
  /// the 20 physically closest to [destination]'s geocoded point; for a
  /// city-level search
  /// that's effectively "this city's attractions", since anything in the
  /// same country but a different city is necessarily farther away.
  /// Returns false (writing nothing) when `catalog_places` has no rows for this
  /// country yet, so the caller knows to fall back to the live fetch.
  Future<bool> _refreshAttractionsFromPlacesCollection(
    String destination,
    String key,
    String countryCode,
    ({double lat, double lon, String? countryCode}) point,
  ) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      // `category` here is the specific OSM tourism-tag value this row
      // was scraped under (e.g. "viewpoint", "zoo", "museum" — only
      // sometimes the literal "attraction"), not a generic
      // attraction/restaurant split, so it's not filtered on at all —
      // `catalog_places` only has attraction-type rows so far anyway. If/when
      // restaurant rows are added to this same collection, they'll need
      // their own real way to tell the two apart (e.g. a dedicated
      // `type: 'attraction'|'restaurant'` field from the scraper) before
      // this can also source `refreshRestaurants`.
      snap = await _places.where('country', isEqualTo: countryCode).get();
    } catch (_) {
      // A rules/network failure (or, if `catalog_places` ever grows enough rows
      // per country to need one, a missing-index error — a single
      // equality filter never needs a composite index, so that's not a
      // concern today): fall back rather than leave Attractions blank.
      return false;
    }
    if (snap.docs.isEmpty) return false;
    final withDistance = <({QueryDocumentSnapshot<Map<String, dynamic>> doc, Map<String, dynamic> data, double km})>[];
    for (final d in snap.docs) {
      final data = d.data();
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      withDistance.add((doc: d, data: data, km: _distanceKm(point.lat, point.lon, lat, lng)));
    }
    withDistance.sort((a, b) => a.km.compareTo(b.km));
    final nearest = withDistance.take(20).toList();
    // `catalog_places` has no `description` field (the scrape only covers
    // name/photo/translation, not a text summary) — but it does give an
    // exact `wikipedia` reference ("en:Amorium"), so this reuses
    // [PlacesApiService.resolveDescription] exactly as the live-OSM path
    // below does, just fed that one tag instead of a whole OSM tag map.
    // Strictly more reliable than a name-guess lookup, since there's no
    // "is this really the same place" ambiguity to guard against.
    final descriptions = await Future.wait(nearest.map((e) async {
      final wikipedia = (e.data['wikipedia'] as String?) ?? '';
      if (wikipedia.isEmpty) return null;
      return PlacesApiService.instance.resolveDescription({'wikipedia': wikipedia});
    }));
    for (var i = 0; i < nearest.length; i++) {
      final data = nearest[i].data;
      final category = (data['category'] as String?) ?? '';
      final nameEn = (data['nameEn'] as String?)?.trim();
      final name = (nameEn != null && nameEn.isNotEmpty) ? nameEn : ((data['name'] as String?) ?? '');
      final imageUrl = data['imageUrl'] as String?;
      try {
        await _attractions.doc('place_${nearest[i].doc.id}').set({
          'name': name,
          'category': category.isEmpty ? 'Attraction' : _titleCase(category.replaceAll('_', ' ')),
          'categories': [if (category.isNotEmpty) _titleCase(category.replaceAll('_', ' '))],
          'price': '',
          if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
          // Kept even though no detail page reads them yet — a Commons
          // CC BY-SA photo (see the `catalog_places` sample doc) is only
          // properly used with its author/license kept alongside it, and
          // writing them now means showing a credit line later is a UI
          // change only, not another backfill.
          if (data['imageAuthor'] != null) 'imageAuthor': data['imageAuthor'],
          if (data['imageLicense'] != null) 'imageLicense': data['imageLicense'],
          'location': destination.trim(),
          'destinationQuery': key,
          'openingHours': '',
          'address': '',
          'phone': '',
          'website': (data['website'] as String?) ?? '',
          'description': descriptions[i] ?? '',
          'rating': 'New',
          'reviews': '0',
        }, SetOptions(merge: true));
      } catch (_) {
        // One row failing (rules hiccup, transient Firestore error)
        // shouldn't stop the rest of the batch — same best-effort
        // handling as the live-OSM path below.
      }
    }
    return true;
  }

  /// The original live fetch (Nominatim + Overpass + Wikipedia/website
  /// fallbacks) — now only reached by [refreshAttractions] when `catalog_places`
  /// has nothing for this destination's country yet. See that method's
  /// doc comment.
  Future<void> _refreshAttractionsFromOsm(String destination, String key, ({double lat, double lon, String? countryCode}) point) async {
    final found = await PlacesApiService.instance.searchNearby(
      lat: point.lat,
      lon: point.lon,
      filter: PlacesApiService.overpassFilterFor('Attractions'),
      radiusMeters: 15000,
      limit: 20,
    );
    // Resolved in parallel, same reason fetchNearbyPlaces resolves images
    // in parallel — one Wikipedia round-trip per POI, sequentially, would
    // make a 20-attraction refresh noticeably slow for no benefit. This
    // used to just write 'image': '' unconditionally and never actually
    // call resolveImage here at all — Near By's fetchNearbyPlaces already
    // did (see its own doc comment), but Explore's Attractions/
    // Restaurants never got the same treatment, so every attraction/
    // restaurant card showed a blank image regardless of whether OSM/
    // Wikipedia actually had a real photo for that place.
    final tagDescriptions = await Future.wait(found.map((p) => PlacesApiService.instance.resolveDescription(p.tags)));
    final tagImages = await Future.wait(found.map((p) => PlacesApiService.instance.resolveImage(p.tags)));
    // Most OSM attraction nodes were never tagged with an image/wikipedia
    // reference at all — a real gap in OSM's own data, not something a
    // smarter tag lookup can fix. For whichever ones came back null,
    // _fillGaps tries the place's own website (if OSM has one tagged)
    // and then a Wikipedia search by name — see its own doc comment for
    // the order and why name-lookup is attractions-only. Without this,
    // every attraction OSM had nothing tagged for fell back to the exact
    // same generic category sentence as every other one in that category.
    final filled = await Future.wait([
      for (var i = 0; i < found.length; i++) _fillGaps(found[i], tagImages[i], tagDescriptions[i], allowNameLookup: true),
    ]);
    final images = [for (final f in filled) f.image];
    final descriptions = [for (final f in filled) f.description];
    for (var i = 0; i < found.length; i++) {
      final p = found[i];
      final tourism = p.tags['tourism'] ?? '';
      try {
        await _attractions.doc('osm_${p.id}').set({
          'name': p.name,
          'category': tourism.isEmpty ? 'Attraction' : _titleCase(tourism.replaceAll('_', ' ')),
          'categories': [if (tourism.isNotEmpty) _titleCase(tourism.replaceAll('_', ' '))],
          'price': p.tags['fee'] == 'no' ? 'Free entry' : '',
          // Only written when actually resolved — a transient failure on
          // this particular refresh shouldn't blank out an image this
          // same place already got from an earlier successful refresh.
          if (images[i] != null) 'image': images[i],
          'location': destination.trim(),
          'destinationQuery': key,
          'openingHours': p.tags['opening_hours'] ?? '',
          'address': p.address,
          'phone': p.tags['phone'] ?? p.tags['contact:phone'] ?? '',
          'website': p.tags['website'] ?? p.tags['contact:website'] ?? '',
          'description': descriptions[i] ?? '',
          // No reviews yet — 'New' is an honest placeholder (real, if
          // empty, rather than a fabricated rating/review count); once
          // someone actually reviews it in-app, ratingCount/ratingSum
          // (bumped by addAttractionReview) take over (see _ratingLabel).
          'rating': 'New',
          'reviews': '0',
        }, SetOptions(merge: true));
      } catch (_) {
        // One POI's write failing (a rules hiccup, a transient Firestore
        // error) shouldn't stop the rest of the batch from landing —
        // this is a best-effort background refresh, not something the
        // person is waiting on with a spinner.
      }
    }
  }

  /// Same idea as [refreshAttractions], for `catalog_restaurants`.
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
    // See refreshAttractions above — same bug (resolveImage existed but
    // was never actually called here), same fix.
    final tagDescriptions = await Future.wait(found.map((p) => PlacesApiService.instance.resolveDescription(p.tags)));
    final tagImages = await Future.wait(found.map((p) => PlacesApiService.instance.resolveImage(p.tags)));
    // Most small restaurants have no Wikipedia page, so unlike Attractions
    // this doesn't fall back to a name search (too likely to collide with
    // an unrelated article) — but a real restaurant's own website
    // (`website`/`contact:website`, when OSM has it) is tied to that exact
    // business, so _fillGaps tries that one extra source here too
    // (allowNameLookup: false keeps the Wikipedia-by-name step off).
    final filled = await Future.wait([
      for (var i = 0; i < found.length; i++) _fillGaps(found[i], tagImages[i], tagDescriptions[i], allowNameLookup: false),
    ]);
    final images = [for (final f in filled) f.image];
    final descriptions = [for (final f in filled) f.description];
    for (var i = 0; i < found.length; i++) {
      final p = found[i];
      final cuisine = p.tags['cuisine'] ?? '';
      final cuisineTags = cuisine.isEmpty
          ? const <String>['Restaurant']
          : cuisine.split(';').map((s) => _titleCase(s.trim().replaceAll('_', ' '))).where((s) => s.isNotEmpty).toList();
      try {
        await _restaurants.doc('osm_${p.id}').set({
          'name': p.name,
          'cuisineTags': cuisineTags,
          'location': destination.trim(),
          'destinationQuery': key,
          'priceRange': '',
          if (images[i] != null) 'image': images[i],
          'openingHours': p.tags['opening_hours'] ?? '',
          'address': p.address,
          'phone': p.tags['phone'] ?? p.tags['contact:phone'] ?? '',
          'website': p.tags['website'] ?? p.tags['contact:website'] ?? '',
          'description': descriptions[i] ?? '',
          'rating': 'New',
          'reviews': '0',
        }, SetOptions(merge: true));
      } catch (_) {
        // see refreshAttractions — best-effort, one failure shouldn't
        // stop the rest of the batch.
      }
    }
  }

  /// Fills in whichever of [tagImage]/[tagDescription] came back null
  /// from the OSM tags directly — tried in order of how trustworthy each
  /// extra source is:
  /// 1. the place's own `website`/`contact:website` OSM tag, via
  ///    [PlacesApiService.resolveFromWebsite] — a real source tied to
  ///    this *exact* business, so trusted for Restaurants too, not just
  ///    Attractions (see that method's own doc comment);
  /// 2. only when [allowNameLookup] is true (Attractions only — a small
  ///    restaurant's name is too likely to collide with an unrelated
  ///    Wikipedia article, see [PlacesApiService.resolveImageByName]'s
  ///    doc comment), a Wikipedia search by the place's plain name.
  /// Either step is skipped once both fields are already filled, and the
  /// website lookup only runs once per place even when both an image and
  /// a description are missing (one fetch covers both).
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

  String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// [HotelData] doesn't carry an id or favorited-by list, both of which
/// Explore needs now that hotels are real Firestore docs — so this small
/// subclass adds them without disturbing every other place [HotelData] is
/// used (e.g. the still-static `AttractionData`/`FlightData` shapes).
class CatalogHotel extends HotelData {
  final String id;
  final List<String> favoritedBy;
  /// The original amount/currency Duffel/RollingGo quoted this at when
  /// it was saved — null for anything seeded before this existed, or
  /// not provided by its source. See [displayPrice].
  final double? priceAmount;
  final String? priceCurrency;
  const CatalogHotel({
    required this.id,
    required this.favoritedBy,
    required super.name,
    required super.location,
    required super.rating,
    required super.reviews,
    required super.price,
    required super.image,
    super.amenities,
    this.priceAmount,
    this.priceCurrency,
  });

  /// Whether [uid] saved this hotel for [tripId] (see class doc — saves are
  /// per trip, not just per user).
  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');

  /// [price] converted into [userCurrency] (typically
  /// [CurrencyService.lastKnownUserCurrency]) when there's a raw
  /// amount/currency to convert from and live rates are loaded —
  /// otherwise just the plain stored [price] string, same as every
  /// screen showed before currency conversion existed. Safe to call with
  /// a null [userCurrency] (no preference set / signed out).
  String displayPrice([String? userCurrency]) {
    if (priceAmount == null || priceCurrency == null) return price;
    return CurrencyService.instance.format(priceAmount!, priceCurrency!, userCurrency);
  }
}

/// Same idea as [CatalogHotel], for attractions.
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
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}

/// Same idea again, for restaurants.
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
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}

/// Same idea again, for flights — [FlightData] itself stays a plain,
/// id-less shape since nothing else constructs it directly.
class CatalogFlight extends FlightData {
  final String id;
  final List<String> favoritedBy;
  /// Same idea as [CatalogHotel.priceAmount]/[priceCurrency] — the raw
  /// amount Duffel quoted this at when it was saved. See [displayPrice].
  final double? priceAmount;
  final String? priceCurrency;
  /// Duffel's real carrier logo URL (SVG) for this flight's airline —
  /// null for anything saved before this existed. See
  /// [DuffelFlightOffer.airlineLogoUrl] / detail_widgets.dart's
  /// `DetailHeader`.
  final String? airlineLogoUrl;
  const CatalogFlight({
    required this.id,
    required this.favoritedBy,
    required super.depTime,
    required super.arrTime,
    required super.duration,
    required super.from,
    required super.to,
    required super.stops,
    required super.price,
    required super.fareType,
    super.airline,
    this.priceAmount,
    this.priceCurrency,
    this.airlineLogoUrl,
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');

  /// See [CatalogHotel.displayPrice] — same fallback behavior.
  String displayPrice([String? userCurrency]) {
    if (priceAmount == null || priceCurrency == null) return price;
    return CurrencyService.instance.format(priceAmount!, priceCurrency!, userCurrency);
  }
}

/// One cached search result for [CatalogRepository]'s short-lived
/// flight/hotel search cache — see its doc comment above.
class _CachedSearch<T> {
  final DateTime fetchedAt;
  final List<T> results;
  _CachedSearch(this.fetchedAt, this.results);
}
