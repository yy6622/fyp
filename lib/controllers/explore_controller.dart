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
        _hasLoadedProfile = true;
        if (!_hasRunInitialSearch) {
          _maybeRunInitialSearch();
        } else if (changed && selectedTrip != null) {
          _runDefaultSearches();
        }
      });
      _tripsSub = TripRepository.instance.watchMyTrips(_uid).listen((v) {
        final previousSignature = _tripSignature(selectedTrip);
        // Past plans only live on the Plan tab -- hide them here.
        trips = v.where((t) => !t.isInactive).toList();
        if (selectedTripIndex >= trips.length) selectedTripIndex = 0;
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

  String get homeAirportCode => _homeAirportCode;

  String? lastFlightOrigin;
  String? lastFlightDestinationQuery;
  String? lastFlightDestinationLabel;

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

  /// Always shows the price converted to MYR (RM). The app no longer lets
  /// the traveller pick a personal display currency -- every price is
  /// normalized to MYR so flight/hotel cards are consistent app-wide.
  String formatPrice(double amount, String providerCurrency) {
    final myr = CurrencyService.instance.convert(amount, from: providerCurrency, to: 'MYR');
    return 'RM ${(myr ?? amount).toStringAsFixed(0)}';
  }

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
      flightResults = [];
      hotelResults = [];
      flightResultsLabel = query;
      hotelResultsLabel = query;
      notifyListeners();
    }
    unawaited(_searchPlacesByKeyword(query));
    unawaited(_loadBannerImage(query));
  }

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
