import 'dart:async';

import 'package:flutter/material.dart';

import '../models/explore_models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';

/// Controller for [ExplorePage]. Streams the flight/hotel/attraction
/// catalogue from Firestore (seeded once — see [CatalogRepository]) instead
/// of a hardcoded list, and favoriting is a real, persisted action. Also
/// streams the user's real trips, to back the "Japan Trip" card/switcher
/// that used to show one fixed fake trip.
class ExploreController extends ChangeNotifier {
  ExploreController() {
    CatalogRepository.instance.seedIfEmpty();
    _flightsSub = CatalogRepository.instance.watchFlights().listen((v) {
      flights = v;
      notifyListeners();
    });
    _hotelsSub = CatalogRepository.instance.watchHotels().listen((v) {
      hotels = v;
      notifyListeners();
    });
    _attractionsSub = CatalogRepository.instance.watchAttractions().listen((v) {
      attractions = v;
      notifyListeners();
    });
    _restaurantsSub = CatalogRepository.instance.watchRestaurants().listen((v) {
      restaurants = v;
      notifyListeners();
    });
    if (_uid.isNotEmpty) {
      _tripsSub = TripRepository.instance.watchMyTrips(_uid).listen((v) {
        trips = v;
        if (selectedTripIndex >= v.length) selectedTripIndex = 0;
        notifyListeners();
      });
    }
  }

  List<Trip> trips = [];
  int selectedTripIndex = 0;
  Trip? get selectedTrip => trips.isEmpty ? null : trips[selectedTripIndex.clamp(0, trips.length - 1)];
  void selectTrip(int index) {
    selectedTripIndex = index;
    _showTripSwitcher = false;
    notifyListeners();
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

  List<CatalogFlight> flights = [];
  List<CatalogHotel> hotels = [];
  List<CatalogAttraction> attractions = [];
  List<CatalogRestaurant> restaurants = [];

  /// Saving is scoped to whichever trip is selected on Explore (see
  /// [CatalogRepository]'s class doc) — with no trip selected there's
  /// nothing to save "for", so these are no-ops.
  Future<void> toggleHotelFavorite(CatalogHotel hotel) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance.toggleHotelFavorite(hotel.id, _uid, tripId, !hotel.isSavedForTrip(_uid, tripId));
  }

  Future<void> toggleAttractionFavorite(CatalogAttraction attraction) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance
        .toggleAttractionFavorite(attraction.id, _uid, tripId, !attraction.isSavedForTrip(_uid, tripId));
  }

  Future<void> toggleFlightFavorite(CatalogFlight flight) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance.toggleFlightFavorite(flight.id, _uid, tripId, !flight.isSavedForTrip(_uid, tripId));
  }

  Future<void> toggleRestaurantFavorite(CatalogRestaurant restaurant) {
    final tripId = selectedTrip?.id;
    if (tripId == null) return Future.value();
    return CatalogRepository.instance
        .toggleRestaurantFavorite(restaurant.id, _uid, tripId, !restaurant.isSavedForTrip(_uid, tripId));
  }

  StreamSubscription<List<CatalogFlight>>? _flightsSub;
  StreamSubscription<List<CatalogHotel>>? _hotelsSub;
  StreamSubscription<List<CatalogAttraction>>? _attractionsSub;
  StreamSubscription<List<CatalogRestaurant>>? _restaurantsSub;

  @override
  void dispose() {
    _flightsSub?.cancel();
    _hotelsSub?.cancel();
    _attractionsSub?.cancel();
    _restaurantsSub?.cancel();
    _tripsSub?.cancel();
    super.dispose();
  }
}
