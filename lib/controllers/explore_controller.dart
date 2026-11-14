import 'dart:async';

import 'package:flutter/material.dart';

import '../data/countries.dart';
import '../data/country_areas.dart';
import '../data/popular_destinations.dart';
import '../models/duffel_models.dart';
import '../models/explore_models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/interest_mapping.dart';
import '../services/places_api_service.dart';

class ExploreController extends ChangeNotifier {
  ExploreController() {
    unawaited(CurrencyService.instance.ensureRatesLoaded().then((_) {
      if (!_disposed) notifyListeners();
    }));
    _resubscribePlaces(kPopularDestinations.first.hotelPlaceQuery);
    unawaited(_loadBannerImage(kPopularDestinations.first.label));
    if (_uid.isNotEmpty) {
      _profileSub = UserRepository.instance.watchProfile(_uid).listen((profile) {
        final code = (profile?.homeAirportCode.isNotEmpty ?? false) ? profile!.homeAirportCode : kDefaultHomeAirport;
        final changed = code != _homeAirportCode;
        _homeAirportCode = code;
        final newCurrency = profile?.currencyCode ?? '';
        if (newCurrency != userCurrencyCode) {
          userCurrencyCode = newCurrency;
          notifyListeners();
        }
        _hasLoadedProfile = true;
        if (!_hasRunInitialSearch) {
          _maybeRunInitialSearch();
        } else if (changed && selectedTrip != null) {
          _runDefaultSearches();
        }
      });
      _tripsSub = TripRepository.instance.watchMyTrips(_uid).listen((v) {
        final previousSignature = _tripSignature(selectedTrip);
        trips = v;
        if (selectedTripIndex >= v.length) selectedTripIndex = 0;
        notifyListeners();
        _hasLoadedTrips = true;
        if (!_hasRunInitialSearch) {
          _maybeRunInitialSearch();
        } else if (_tripSignature(selectedTrip) != previousSignature) {
          _runDefaultSearches();
        }
      });
      _attractionAffinitySub = CatalogRepository.instance.watchAttractionCategoryAffinity(_uid).listen((v) {
        _attractionAffinity = v;
        _reorderByAffinity<CatalogAttraction>(attractions, (a) => a.categoryTags, _attractionAffinity);
        notifyListeners();
      });
      _restaurantAffinitySub = CatalogRepository.instance.watchRestaurantCuisineAffinity(_uid).listen((v) {
        _restaurantAffinity = v;
        _reorderByAffinity<CatalogRestaurant>(restaurants, (r) => r.cuisineTags, _restaurantAffinity);
        notifyListeners();
      });
      _hotelAffinitySub = CatalogRepository.instance.watchHotelAmenityAffinity(_uid).listen((v) {
        _hotelAmenityAffinity = v;
        notifyListeners();
      });
    } else {
      _hasRunInitialSearch = true;
      _runDefaultSearches();
    }
  }

  bool _hasRunInitialSearch = false;
  bool _hasLoadedProfile = false;
  bool _hasLoadedTrips = false;

  void _maybeRunInitialSearch() {
    if (_hasRunInitialSearch || !_hasLoadedProfile || !_hasLoadedTrips) return;
    _hasRunInitialSearch = true;
    _runDefaultSearches();
  }

  String _homeAirportCode = kDefaultHomeAirport;
  StreamSubscription<AppUser?>? _profileSub;

  /// The traveller's saved departure airport (Account Settings > Home
  /// Airport), or [kDefaultHomeAirport] if they never set one. Read-only
  /// here -- changing it goes through UserRepository.updateProfile, the
  /// same as the settings page itself does.
  String get homeAirportCode => _homeAirportCode;

  /// What the current flight results are actually a search for -- set by
  /// every successful [searchFlights] call, including the automatic ones
  /// (trip selection, a typed keyword). Lets the Filter sheet's route
  /// search (filter_page.dart) default its From/To fields to "whatever
  /// produced the results you're looking at right now" instead of always
  /// resetting to the home airport + no destination.
  String? lastFlightOrigin;
  String? lastFlightDestinationQuery;
  String? lastFlightDestinationLabel;

  /// Traveller counts/cabin for every flight search this controller runs
  /// -- previously hardcoded (1 adult, economy) inside
  /// DuffelApiService.searchFlights itself; now a real, user-changeable
  /// setting (Filter sheet's Travelers & Cabin picker, filter_page.dart)
  /// that persists across searches the same way [_homeAirportCode] does,
  /// rather than resetting every time a new search runs.
  int flightAdults = 1;
  List<int> flightChildAges = const [];
  String flightCabinClass = 'economy';

  void setTravelersAndCabin({required int adults, required List<int> childAges, required String cabinClass}) {
    flightAdults = adults;
    flightChildAges = childAges;
    flightCabinClass = cabinClass;
    notifyListeners();
  }

  /// Same default [_runDefaultSearches] already applies when a trip has
  /// no start date -- exposed so the Filter sheet's route search can
  /// reuse it exactly rather than guessing a different one.
  DateTime get defaultDepartureDate => selectedTrip?.startDate ?? DateTime.now().add(const Duration(days: 30));

  String userCurrencyCode = '';

  String formatPrice(double amount, String providerCurrency) =>
      CurrencyService.instance.format(amount, providerCurrency, userCurrencyCode.isNotEmpty ? userCurrencyCode : null);

  String? _tripSignature(Trip? t) => t == null ? null : '${t.id}|${t.destination}|${t.startDate}|${t.endDate}';

  List<Trip> trips = [];
  int selectedTripIndex = 0;
  Trip? get selectedTrip => trips.isEmpty ? null : trips[selectedTripIndex.clamp(0, trips.length - 1)];
  void selectTrip(int index) {
    selectedTripIndex = index;
    _showTripSwitcher = false;
    notifyListeners();
    _runDefaultSearches();
  }

  StreamSubscription<List<Trip>>? _tripsSub;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  ExploreCategory _selectedCategory = ExploreCategory.all;
  ExploreCategory get selectedCategory => _selectedCategory;
  void setSelectedCategory(ExploreCategory value) {
    _selectedCategory = value;
    notifyListeners();
  }

  bool _showTripSwitcher = false;
  bool get showTripSwitcher => _showTripSwitcher;
  void toggleTripSwitcher() {
    _showTripSwitcher = !_showTripSwitcher;
    notifyListeners();
  }

  void closeTripSwitcher() {
    if (_showTripSwitcher) {
      _showTripSwitcher = false;
      notifyListeners();
    }
  }

  String bannerDestination = kPopularDestinations.first.label;

  String? bannerImageUrl;
  String? _bannerPhotoFetchedFor;

  Future<void> _loadBannerImage(String destination) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return;
    bannerDestination = trimmed;
    if (_bannerPhotoFetchedFor == trimmed) {
      notifyListeners();
      return;
    }
    _bannerPhotoFetchedFor = trimmed;
    bannerImageUrl = null;
    notifyListeners();
    final photo = await PlacesApiService.instance.destinationPhoto(trimmed);
    if (_disposed || _bannerPhotoFetchedFor != trimmed) return;
    bannerImageUrl = photo;
    notifyListeners();
  }

  List<CatalogAttraction> attractions = [];
  List<CatalogRestaurant> restaurants = [];
  bool loadingPlaces = false;

  StreamSubscription<List<CatalogAttraction>>? _attractionsSub;
  StreamSubscription<List<CatalogRestaurant>>? _restaurantsSub;
  String? _placesDestination;

  Map<String, int> _attractionAffinity = {};
  Map<String, int> _restaurantAffinity = {};
  Map<String, int> _hotelAmenityAffinity = {};
  StreamSubscription<Map<String, int>>? _attractionAffinitySub;
  StreamSubscription<Map<String, int>>? _restaurantAffinitySub;
  StreamSubscription<Map<String, int>>? _hotelAffinitySub;

  Map<String, int> get attractionAffinity => _attractionAffinity;
  Map<String, int> get restaurantAffinity => _restaurantAffinity;
  Map<String, int> get hotelAmenityAffinity => _hotelAmenityAffinity;

  /// [attractionAffinity] blended with the selected trip's declared
  /// interest points (see interest_mapping.dart) -- what
  /// AttractionRecommendation should actually rank by, so the interests
  /// picked when the trip was created keep nudging results even before
  /// any real save/view behaviour exists, and keep nudging afterwards
  /// rather than being forgotten once real behaviour takes over.
  Map<String, int> get attractionAffinityForRanking =>
      blendInterestsIntoAffinity(_attractionAffinity, selectedTrip?.interests ?? const []);

  void _reorderByAffinity<T>(List<T> items, List<String> Function(T) tagsOf, Map<String, int> affinity) {
    if (affinity.isEmpty || items.isEmpty) return;
    int scoreOf(T item) {
      var score = 0;
      for (final tag in tagsOf(item)) {
        score += affinity[tag] ?? 0;
      }
      return score;
    }

    final indexed = items.asMap().entries.toList()
      ..sort((a, b) {
        final cmp = scoreOf(b.value).compareTo(scoreOf(a.value));
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    items
      ..clear()
      ..addAll(indexed.map((e) => e.value));
  }

  void _resubscribePlaces(String destination) {
    final trimmed = destination.trim();
    if (trimmed.isEmpty || trimmed == _placesDestination) return;
    _placesDestination = trimmed;
    _attractionsSub?.cancel();
    _restaurantsSub?.cancel();
    loadingPlaces = true;
    notifyListeners();
    _attractionsSub = CatalogRepository.instance.watchAttractions(destination: trimmed).listen((v) {
      attractions = v;
      _reorderByAffinity<CatalogAttraction>(attractions, (a) => a.categoryTags, _attractionAffinity);
      loadingPlaces = false;
      notifyListeners();
    });
    _restaurantsSub = CatalogRepository.instance.watchRestaurants(destination: trimmed).listen((v) {
      restaurants = v;
      _reorderByAffinity<CatalogRestaurant>(restaurants, (r) => r.cuisineTags, _restaurantAffinity);
      loadingPlaces = false;
      notifyListeners();
    });
    unawaited(CatalogRepository.instance.refreshAttractions(trimmed));
    unawaited(CatalogRepository.instance.refreshRestaurants(trimmed));
  }

  List<DuffelFlightOffer> flightResults = [];
  List<DuffelStayResult> hotelResults = [];
  bool loadingFlights = false;
  bool loadingHotels = false;
  String? flightError;
  String? hotelError;

  String flightResultsLabel = 'Popular destinations';
  String hotelResultsLabel = 'Popular destinations';

  bool isManualSearch = false;


  // Maps the search result's own id (offer.id / searchResultId) to the
  // Firestore doc created for it by saveDuffelFlight/saveDuffelStay, so a
  // second tap on the same heart icon (toggleFlightSaved/toggleHotelSaved)
  // knows which doc to delete again instead of only ever being able to
  // create a new one.
  final Map<String, String> savedFlightIds = {};
  final Map<String, String> savedStayIds = {};

  Future<void> _runDefaultSearches() async {
    isManualSearch = false;
    final trip = selectedTrip;
    if (trip != null && trip.destination.isNotEmpty) {
      final departureDate = trip.startDate ?? DateTime.now().add(const Duration(days: 30));
      final checkIn = trip.startDate ?? DateTime.now().add(const Duration(days: 30));
      final checkOut = trip.endDate ?? checkIn.add(const Duration(days: 4));
      unawaited(searchFlights(origin: _homeAirportCode, destination: trip.destination, departureDate: departureDate, label: trip.destination));
      unawaited(searchHotels(destinationQuery: trip.destination, checkIn: checkIn, checkOut: checkOut, label: trip.destination));
      _resubscribePlaces(trip.destination);
      unawaited(_loadBannerImage(trip.destination));
    } else {
      _resubscribePlaces(kPopularDestinations.first.hotelPlaceQuery);
      unawaited(_loadPopularFlights());
      unawaited(_loadPopularHotels());
      unawaited(_loadBannerImage(kPopularDestinations.first.label));
    }
  }

  Future<void> _loadPopularFlights() async {
    loadingFlights = true;
    flightError = null;
    flightResultsLabel = 'Popular destinations';
    notifyListeners();
    try {
      final popular = await CatalogRepository.instance.getPopularFlights();
      flightResults = popular.map((e) => e.value).toList();
    } catch (e) {
      flightError = '$e';
      flightResults = [];
    }
    loadingFlights = false;
    notifyListeners();
  }

  Future<void> _loadPopularHotels() async {
    loadingHotels = true;
    hotelError = null;
    hotelResultsLabel = 'Popular destinations';
    notifyListeners();
    try {
      final popular = await CatalogRepository.instance.getPopularStays();
      hotelResults = popular.map((e) => e.value).toList();
    } catch (e) {
      hotelError = '$e';
      hotelResults = [];
    }
    loadingHotels = false;
    notifyListeners();
  }

  Future<void> searchFlights({
    required String origin,
    required String destination,
    required DateTime departureDate,
    required String label,
  }) async {
    loadingFlights = true;
    flightError = null;
    flightResultsLabel = label;
    lastFlightOrigin = origin;
    lastFlightDestinationQuery = destination;
    lastFlightDestinationLabel = label;
    notifyListeners();
    try {
      flightResults = await CatalogRepository.instance.searchFlights(
        uid: _uid,
        origin: origin,
        destination: destination,
        departureDate: departureDate,
        adults: flightAdults,
        childAges: flightChildAges,
        cabinClass: flightCabinClass,
      );
    } catch (e) {
      flightError = '$e';
      flightResults = [];
    }
    loadingFlights = false;
    notifyListeners();
  }

  DateTime? lastHotelCheckIn;
  DateTime? lastHotelCheckOut;

  /// [filterQuery], when given, keeps only results that actually relate to
  /// what was typed — RollingGo only ever searches by city/place
  /// (`placeType: 'City'`), so a typed keyword that isn't really a place
  /// (a hotel's own name, a random word) still gets "resolved" to *some*
  /// unrelated city instead of correctly finding nothing, and every hotel
  /// it hands back belongs to that wrong city. Rather than trying to
  /// predict that before calling RollingGo, we call it as normal and then
  /// check its own results: a hotel's `address` almost always contains the
  /// city/place name it's actually in, so a genuine destination search
  /// (e.g. "Paris") keeps matching hotels, while a mis-resolved one is
  /// left with nothing whose address *or name* mentions the typed text,
  /// and correctly comes back empty. `name` is checked too so a search for
  /// a specific hotel's own name still matches it when it's in the
  /// (correctly or incorrectly resolved) result set.
  Future<void> searchHotels({
    required String destinationQuery,
    required DateTime checkIn,
    required DateTime checkOut,
    required String label,
    String? filterQuery,
  }) async {
    loadingHotels = true;
    hotelError = null;
    hotelResultsLabel = label;
    lastHotelCheckIn = checkIn;
    lastHotelCheckOut = checkOut;
    notifyListeners();
    try {
      final results = await CatalogRepository.instance.searchStays(
        uid: _uid,
        destinationQuery: destinationQuery,
        checkIn: checkIn,
        checkOut: checkOut,
      );
      final needle = filterQuery?.trim().toLowerCase();
      hotelResults = (needle == null || needle.isEmpty)
          ? results
          : results
              .where((h) =>
                  h.address.toLowerCase().contains(needle) ||
                  h.name.toLowerCase().contains(needle))
              .toList();
    } catch (e) {
      hotelError = '$e';
      hotelResults = [];
    }
    loadingHotels = false;
    notifyListeners();
  }

  Future<void> toggleFlightSaved(DuffelFlightOffer offer) async {
    final tripId = selectedTrip?.id;
    if (tripId == null || _uid.isEmpty) return;
    final existingDocId = savedFlightIds[offer.id];
    if (existingDocId != null) {
      savedFlightIds.remove(offer.id);
      notifyListeners();
      await CatalogRepository.instance.removeSavedFlight(existingDocId);
      return;
    }
    // Optimistic placeholder so a second rapid tap (before the add()
    // round-trip resolves) is still read as "already saved" rather than
    // firing a duplicate save; replaced with the real doc id below.
    savedFlightIds[offer.id] = '';
    notifyListeners();
    final docId = await CatalogRepository.instance.saveDuffelFlight(offer, uid: _uid, tripId: tripId);
    if (savedFlightIds.containsKey(offer.id)) {
      savedFlightIds[offer.id] = docId;
      notifyListeners();
    }
  }

  // True when [query] is a real place Duffel/RollingGo could actually be
  // searched by — a country from kCountries, or an area/city inside one
  // from kCountryAreas (matches the exact set the traveller's own
  // destination pickers, e.g. InsuranceQuotePage, offer) — case
  // insensitive, and also matching "Area, Country" as typed by some
  // pickers. Flights/hotels have no "search by name" mode on either API,
  // so a query that ISN'T a real destination (a restaurant's name, say)
  // can only ever produce unrelated results there; this is checked before
  // running that search at all, regardless of which category tab is
  // selected, so the fix isn't "don't search flights/hotels on this tab"
  // but "don't search flights/hotels with a query that isn't a
  // destination, full stop."
  bool _looksLikeKnownDestination(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    final country = q.contains(',') ? q.split(',').last.trim() : q;
    if (kCountries.any((c) => c.name.toLowerCase() == country)) return true;
    for (final areas in kCountryAreas.values) {
      if (areas.any((a) => a.toLowerCase() == q)) return true;
    }
    return false;
  }

  void searchFromTopBar(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    isManualSearch = true;
    notifyListeners();
    if (_looksLikeKnownDestination(query)) {
      unawaited(_searchDestinationBoundCategories(query));
    } else {
      // Not a real destination -- flights/hotels have nothing meaningful
      // to show for this query (see _looksLikeKnownDestination's doc
      // comment), so clear out whatever they were last showing instead
      // of leaving an unrelated, stale result list on screen.
      flightResults = [];
      hotelResults = [];
      flightResultsLabel = query;
      hotelResultsLabel = query;
      notifyListeners();
    }
    unawaited(_searchPlacesByKeyword(query));
    unawaited(_loadBannerImage(query));
  }

  /// Flights and hotels can only ever be searched by destination — there's
  /// no "find a hotel by its own name" mode on either API — so a typed
  /// keyword is handed to both as-is, the same as picking a real
  /// destination. [searchHotels] post-filters whatever RollingGo actually
  /// returns against the typed text (see its own doc comment) so a keyword
  /// that isn't really a place doesn't surface unrelated hotels.
  Future<void> _searchDestinationBoundCategories(String query) async {
    final wantFlights = _selectedCategory == ExploreCategory.flights || _selectedCategory == ExploreCategory.all;
    final wantHotels = _selectedCategory == ExploreCategory.accommodation || _selectedCategory == ExploreCategory.all;
    final departureDate = DateTime.now().add(const Duration(days: 30));
    if (wantFlights) {
      unawaited(searchFlights(origin: _homeAirportCode, destination: query, departureDate: departureDate, label: query));
    }
    if (wantHotels) {
      unawaited(searchHotels(
        destinationQuery: query,
        checkIn: departureDate,
        checkOut: departureDate.add(const Duration(days: 4)),
        label: query,
        filterQuery: query,
      ));
    }
  }

  /// A typed keyword almost always means an attraction/restaurant's actual
  /// NAME ("Petronas Towers", "KFC"), not the city/country it's filed
  /// under — [_resubscribePlaces] only ever matched the latter, which is
  /// why manual-search results used to look completely unrelated to what
  /// was typed. One-shot name search (see
  /// [CatalogRepository.searchAttractionsByName]) replaces the live
  /// destination subscription for the duration of a manual search.
  Future<void> _searchPlacesByKeyword(String query) async {
    _attractionsSub?.cancel();
    _restaurantsSub?.cancel();
    // Not a real destination any more — forces a genuine resubscribe (not
    // a same-destination no-op) once the search is cleared.
    _placesDestination = null;
    loadingPlaces = true;
    notifyListeners();
    try {
      attractions = await CatalogRepository.instance.searchAttractionsByName(query);
    } catch (_) {
      attractions = [];
    }
    try {
      restaurants = await CatalogRepository.instance.searchRestaurantsByName(query);
    } catch (_) {
      restaurants = [];
    }
    _reorderByAffinity<CatalogAttraction>(attractions, (a) => a.categoryTags, _attractionAffinity);
    _reorderByAffinity<CatalogRestaurant>(restaurants, (r) => r.cuisineTags, _restaurantAffinity);
    loadingPlaces = false;
    notifyListeners();
  }

  void clearManualSearch() {
    if (!isManualSearch) return;
    _runDefaultSearches();
  }

  Future<void> toggleHotelSaved(DuffelStayResult stay) async {
    final tripId = selectedTrip?.id;
    if (tripId == null || _uid.isEmpty) return;
    final existingDocId = savedStayIds[stay.searchResultId];
    if (existingDocId != null) {
      savedStayIds.remove(stay.searchResultId);
      notifyListeners();
      await CatalogRepository.instance.removeSavedStay(existingDocId);
      return;
    }
    savedStayIds[stay.searchResultId] = '';
    notifyListeners();
    final docId = await CatalogRepository.instance.saveDuffelStay(stay, uid: _uid, tripId: tripId);
    if (savedStayIds.containsKey(stay.searchResultId)) {
      savedStayIds[stay.searchResultId] = docId;
      notifyListeners();
    }
  }

  Future<void> toggleAttractionFavorite(CatalogAttraction attraction) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance.toggleAttractionFavorite(
      attraction.id,
      _uid,
      tripId,
      !attraction.isSavedForTrip(_uid, tripId),
      categories: attraction.categoryTags,
    );
  }

  Future<void> toggleRestaurantFavorite(CatalogRestaurant restaurant) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance.toggleRestaurantFavorite(
      restaurant.id,
      _uid,
      tripId,
      !restaurant.isSavedForTrip(_uid, tripId),
      cuisineTags: restaurant.cuisineTags,
    );
  }

  bool _disposed = false;

  // Searches (flights, hotels, places) can finish after the page has closed;
  // ignore their updates instead of notifying a disposed controller.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _attractionsSub?.cancel();
    _restaurantsSub?.cancel();
    _attractionAffinitySub?.cancel();
    _restaurantAffinitySub?.cancel();
    _hotelAffinitySub?.cancel();
    _tripsSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
