import 'dart:async';

import 'package:flutter/material.dart';

import '../data/popular_destinations.dart';
import '../models/duffel_models.dart';
import '../models/explore_models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/places_api_service.dart';

/// Controller for [ExplorePage]. Attractions/restaurants stream from
/// Firestore, same as flights/hotels — but, like flights/hotels, what's
/// actually in Firestore is kept fresh by a live search
/// ([CatalogRepository.refreshAttractions]/[refreshRestaurants], backed
/// by OpenStreetMap) for whichever destination is relevant, not a fixed
/// seeded catalogue. Every flight/hotel shown here comes from a live
/// Duffel search:
///  - a trip is selected (has a destination) → search that destination,
///    using the trip's own dates when it has them
///  - otherwise, nothing has been searched yet → [CatalogRepository]'s
///    cached "popular destinations" search (see [kPopularDestinations])
///  - the person explicitly searches → that search's results, until
///    they search again or the selected trip changes
class ExploreController extends ChangeNotifier {
  ExploreController() {
    // Rates aren't needed for the very first frame (prices just show in
    // the provider's own currency, exactly as before this existed,
    // until this resolves), so this doesn't block/delay anything else
    // in the constructor — it just notifies once real rates are in so
    // already-rendered prices switch over to the person's currency.
    unawaited(CurrencyService.instance.ensureRatesLoaded().then((_) {
      if (!_disposed) notifyListeners();
    }));
    // Attractions/Restaurants start scoped to the same default
    // destination flights/hotels' "popular" fallback uses, so the
    // category pages aren't empty before a trip/search picks a real one.
    _resubscribePlaces(kPopularDestinations.first.hotelPlaceQuery);
    // Same idea for the top banner's photo — it has something real to
    // show immediately rather than sitting on the neutral fallback until
    // the first trip/profile snapshot resolves.
    unawaited(_loadBannerImage(kPopularDestinations.first.label));
    if (_uid.isNotEmpty) {
      // Home Airport (from the profile stream below) affects the very
      // first flight search, so the initial search has to wait for
      // BOTH the first profile snapshot and the first trips snapshot —
      // not just trips, as it did before this only used a hardcoded
      // KUL. Firestore doesn't guarantee which of two independent
      // streams resolves first, and running the initial search off
      // trips alone risked a visible flash of wrong-origin (KUL)
      // results for someone who already had a different home airport
      // saved, immediately corrected by a second, wasted search once
      // the profile snapshot caught up. _maybeRunInitialSearch() below
      // is what the *second* of the two snapshots to arrive calls.
      _profileSub = UserRepository.instance.watchProfile(_uid).listen((profile) {
        final code = (profile?.homeAirportCode.isNotEmpty ?? false) ? profile!.homeAirportCode : kDefaultHomeAirport;
        final changed = code != _homeAirportCode;
        _homeAirportCode = code;
        // Every Flights/Hotels price on Explore is shown converted into
        // this currency (see formatPrice) — just a re-render, not a
        // re-search, so it's applied outside the `changed`/re-search
        // branches below.
        final newCurrency = profile?.currencyCode ?? '';
        if (newCurrency != userCurrencyCode) {
          userCurrencyCode = newCurrency;
          notifyListeners();
        }
        _hasLoadedProfile = true;
        if (!_hasRunInitialSearch) {
          _maybeRunInitialSearch();
          // Home Airport only feeds a trip-driven/manual search's
          // origin — the shared "popular destinations" browse feed
          // (no trip selected) is a fixed-KUL cache doc regardless
          // (see _loadPopularFlights), so re-searching it here would
          // just be a wasted Firestore read for a section this change
          // can never actually affect.
        } else if (changed && selectedTrip != null) {
          _runDefaultSearches();
        }
      });
      // Don't also search here in the constructor — that would race
      // the first trips/profile snapshots below (whichever set
      // finishes last wins, and "popular destinations" finishing after
      // a trip-driven search has shown stale/wrong content more than
      // once while testing this). Wait for both first snapshots and
      // let them decide instead, even when trips turns out to be an
      // empty list.
      _tripsSub = TripRepository.instance.watchMyTrips(_uid).listen((v) {
        // Compare the whole trip, not just its id — editing the selected
        // trip's destination or dates (in Group Setting / trip info) is
        // the same doc, same id, but the search should still refresh to
        // match, since that's the whole point of driving it off the
        // trip's own destination/dates in the first place.
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
    } else {
      _hasRunInitialSearch = true;
      _runDefaultSearches();
    }
  }

  bool _hasRunInitialSearch = false;
  bool _hasLoadedProfile = false;
  bool _hasLoadedTrips = false;

  /// Runs the one-time initial search once both the first profile
  /// snapshot (which decides [_homeAirportCode]) and the first trips
  /// snapshot (which decides [selectedTrip]) have arrived — see the
  /// comment where this is called from in the constructor. A no-op
  /// once [_hasRunInitialSearch] is set, or while either is still
  /// outstanding.
  void _maybeRunInitialSearch() {
    if (_hasRunInitialSearch || !_hasLoadedProfile || !_hasLoadedTrips) return;
    _hasRunInitialSearch = true;
    _runDefaultSearches();
  }

  /// The person's chosen departure airport (Account Setting's Home
  /// Airport, backed by [LocationService]'s nearest-airport suggestion)
  /// — defaults to [kDefaultHomeAirport] (KUL) until they set one or
  /// for a signed-out session. Used for trip-driven and manual
  /// (top-search-bar) flight searches; the shared "popular destinations"
  /// browse feed (see [_loadPopularFlights]) deliberately stays on the
  /// fixed [kDefaultHomeAirport] regardless, since that result is cached
  /// once and shared across every user, not personalized per origin.
  String _homeAirportCode = kDefaultHomeAirport;
  StreamSubscription<AppUser?>? _profileSub;

  /// The person's chosen display currency (Account Setting > Currency,
  /// [AppUser.currencyCode]) — empty for a signed-out session or before
  /// their profile has loaded, in which case [formatPrice] just shows
  /// each price in whatever currency its provider quoted it in (Duffel
  /// for flights, RollingGo for hotels), same as before currency
  /// conversion existed.
  String userCurrencyCode = '';

  /// The one call-site every flight/hotel price label on Explore should
  /// go through — converts [amount] (in [providerCurrency], whatever
  /// Duffel/RollingGo quoted) into [userCurrencyCode] using
  /// [CurrencyService]'s live rates, falling back to the original
  /// provider currency when rates aren't loaded yet or don't cover one
  /// of the two currencies.
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

  // ---------------- Top banner (destination photo) ----------------
  /// The destination name shown in the top banner's "Explore {name}"
  /// title — the selected trip's destination, or (no trip selected) the
  /// same popular-destination fallback flights/hotels' "popular" search
  /// defaults to. Kept separate from [selectedTrip] so the banner has a
  /// sensible destination even for a signed-out session / before trips
  /// have loaded.
  String bannerDestination = kPopularDestinations.first.label;

  /// A real photo for [bannerDestination] — Wikipedia's lead image (see
  /// [PlacesApiService.destinationPhoto], the same free, no-API-key
  /// lookup create_plan_wizard_controller.dart already uses for a new
  /// trip's cover photo). Null while loading, or when no photo was
  /// found, in which case the banner falls back to a neutral travel
  /// photo instead of showing nothing.
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
    // Stale guard — a second destination change can race ahead of this
    // one while its own lookup is still in flight (same pattern as
    // _resubscribePlaces' subscription swap, just for a plain Future
    // instead of a stream).
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

  /// Kicks off a live OpenStreetMap fetch for [destination] (see
  /// [CatalogRepository.refreshAttractions]/[refreshRestaurants]) and
  /// re-points the Firestore streams to just that destination's results
  /// — called whenever the thing Attractions/Restaurants should be
  /// "for" changes (trip selected, trip's destination edited, manual
  /// search), same trigger points that already re-run the flight/hotel
  /// search above. A no-op if [destination] is the same one already
  /// subscribed to (nothing to re-point).
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
      loadingPlaces = false;
      notifyListeners();
    });
    _restaurantsSub = CatalogRepository.instance.watchRestaurants(destination: trimmed).listen((v) {
      restaurants = v;
      loadingPlaces = false;
      notifyListeners();
    });
    unawaited(CatalogRepository.instance.refreshAttractions(trimmed));
    unawaited(CatalogRepository.instance.refreshRestaurants(trimmed));
  }

  // ---------------- Flights/hotels — real Duffel results ----------------
  List<DuffelFlightOffer> flightResults = [];
  List<DuffelStayResult> hotelResults = [];
  bool loadingFlights = false;
  bool loadingHotels = false;
  String? flightError;
  String? hotelError;

  /// What's currently backing [flightResults]/[hotelResults] — shown as
  /// a small label above the list ("Popular destinations", the trip's
  /// destination, or the person's own manual search) so it's clear
  /// what's being shown and why.
  String flightResultsLabel = 'Popular destinations';
  String hotelResultsLabel = 'Popular destinations';

  /// True once the person has run a manual top-bar search ([searchFromTopBar])
  /// and nothing has restored the default view since. Explore has no
  /// separate "search results" screen — a manual search overwrites
  /// [flightResults]/[hotelResults]/[attractions]/[restaurants] in place,
  /// on the same "All" page the person started on, with nothing that used
  /// to say so or offer a way back. [ExplorePage] shows a "Showing
  /// results for '…' · Clear" bar whenever this is true, and
  /// [clearManualSearch] is that way back.
  bool isManualSearch = false;

  /// The query currently backing a manual search — '' once
  /// [clearManualSearch] (or a trip switch, which also re-runs
  /// [_runDefaultSearches]) restores the default view. Only used for the
  /// "Showing results for '…'" bar's label.
  String lastSearchQuery = '';

  /// Duffel offer/search-result ids saved this session, so a card can
  /// show "Saved" and stop offering to save again without having to
  /// re-derive that from the catalogue stream.
  final Set<String> savedFlightIds = {};
  final Set<String> savedStayIds = {};

  Future<void> _runDefaultSearches() async {
    // Every call site here (initial load, a trip switch, the trip's own
    // destination/dates being edited) means "go back to the default
    // view" — including clearManualSearch's own call — so this is the
    // one place that needs to turn isManualSearch back off.
    isManualSearch = false;
    lastSearchQuery = '';
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

  /// An explicit search — from the trip-driven default above, or from
  /// the person filling in the search sheet themselves.
  Future<void> searchFlights({
    required String origin,
    required String destination,
    required DateTime departureDate,
    required String label,
  }) async {
    loadingFlights = true;
    flightError = null;
    flightResultsLabel = label;
    notifyListeners();
    try {
      flightResults = await CatalogRepository.instance.searchFlights(
        uid: _uid,
        origin: origin,
        destination: destination,
        departureDate: departureDate,
      );
    } catch (e) {
      flightError = '$e';
      flightResults = [];
    }
    loadingFlights = false;
    notifyListeners();
  }

  /// The dates actually used for the most recent hotel search — kept so a
  /// result tapped into its detail page can carry real check-in/check-out
  /// dates into the trip's hotel-stay record if it gets paid for (see
  /// ExplorePage._hotelDetailFor), instead of leaving them blank.
  DateTime? lastHotelCheckIn;
  DateTime? lastHotelCheckOut;

  Future<void> searchHotels({
    required String destinationQuery,
    required DateTime checkIn,
    required DateTime checkOut,
    required String label,
  }) async {
    loadingHotels = true;
    hotelError = null;
    hotelResultsLabel = label;
    lastHotelCheckIn = checkIn;
    lastHotelCheckOut = checkOut;
    notifyListeners();
    try {
      hotelResults = await CatalogRepository.instance.searchStays(
        uid: _uid,
        destinationQuery: destinationQuery,
        checkIn: checkIn,
        checkOut: checkOut,
      );
    } catch (e) {
      hotelError = '$e';
      hotelResults = [];
    }
    loadingHotels = false;
    notifyListeners();
  }

  /// Saving is scoped to whichever trip is selected on Explore (see
  /// [CatalogRepository]'s class doc) — with no trip selected there's
  /// nothing to save "for", so these are no-ops.
  Future<void> saveFlightResult(DuffelFlightOffer offer) async {
    final tripId = selectedTrip?.id;
    if (tripId == null || _uid.isEmpty || savedFlightIds.contains(offer.id)) return;
    savedFlightIds.add(offer.id);
    notifyListeners();
    await CatalogRepository.instance.saveDuffelFlight(offer, uid: _uid, tripId: tripId);
  }

  /// Backs Explore's own top search bar — the person types a destination
  /// there instead of a dedicated per-section search form. Runs whichever
  /// of flights/hotels is relevant to [selectedCategory] (both, on the
  /// "All" tab), with a sensible default date (~30 days out, a 4-night
  /// stay) since the bar itself has no date field.
  void searchFromTopBar(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    isManualSearch = true;
    lastSearchQuery = query;
    notifyListeners();
    final departureDate = DateTime.now().add(const Duration(days: 30));
    if (_selectedCategory == ExploreCategory.flights || _selectedCategory == ExploreCategory.all) {
      searchFlights(origin: _homeAirportCode, destination: query, departureDate: departureDate, label: query);
    }
    if (_selectedCategory == ExploreCategory.accommodation || _selectedCategory == ExploreCategory.all) {
      searchHotels(destinationQuery: query, checkIn: departureDate, checkOut: departureDate.add(const Duration(days: 4)), label: query);
    }
    if (_selectedCategory == ExploreCategory.attractions ||
        _selectedCategory == ExploreCategory.restaurants ||
        _selectedCategory == ExploreCategory.all) {
      _resubscribePlaces(query);
    }
    // A manual search is "for" that one destination regardless of which
    // category triggered it — the banner photo follows along too, same
    // as a trip switch already does.
    unawaited(_loadBannerImage(query));
  }

  /// The way back from a manual search (see [isManualSearch]) — restores
  /// whichever default view was showing before it (the selected trip's
  /// destination, or the shared "popular destinations" browse feed).
  /// Nothing here remembers the actual pre-search results to restore
  /// them directly, so this just re-runs the same default search any
  /// other "back to default" trigger (a trip switch) already goes
  /// through.
  void clearManualSearch() {
    if (!isManualSearch) return;
    _runDefaultSearches();
  }

  Future<void> saveHotelResult(DuffelStayResult stay) async {
    final tripId = selectedTrip?.id;
    if (tripId == null || _uid.isEmpty || savedStayIds.contains(stay.searchResultId)) return;
    savedStayIds.add(stay.searchResultId);
    notifyListeners();
    await CatalogRepository.instance.saveDuffelStay(stay, uid: _uid, tripId: tripId);
  }

  Future<void> toggleAttractionFavorite(CatalogAttraction attraction) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance
        .toggleAttractionFavorite(attraction.id, _uid, tripId, !attraction.isSavedForTrip(_uid, tripId));
  }

  Future<void> toggleRestaurantFavorite(CatalogRestaurant restaurant) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance
        .toggleRestaurantFavorite(restaurant.id, _uid, tripId, !restaurant.isSavedForTrip(_uid, tripId));
  }

  /// Guards the `CurrencyService.instance.ensureRatesLoaded().then(...)`
  /// callback in the constructor — that HTTP call can take several
  /// seconds (up to its own timeout), and if this controller is
  /// disposed before it resolves (navigating off Explore), calling
  /// `notifyListeners()` on an already-disposed `ChangeNotifier` would
  /// throw. Caught by a fresh-eyes review before this shipped.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _attractionsSub?.cancel();
    _restaurantsSub?.cancel();
    _tripsSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
