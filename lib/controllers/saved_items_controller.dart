import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/catalog_repository.dart';
import '../services/auth_service.dart';

/// Controller for [SavedItemsPage] — streams the
/// flights/hotels/attractions/restaurants the signed-in user saved *for one
/// specific trip* (see
/// [CatalogRepository]'s class doc on why saves are trip-scoped rather than
/// one global list).
class SavedItemsController extends ChangeNotifier {
  final String tripId;

  SavedItemsController({required this.tripId}) {
    final key = '$_uid#$tripId';
    _flightsSub = CatalogRepository.instance.watchFlights(favoritedBy: key).listen((v) {
      flights = v;
      loadingFlights = false;
      notifyListeners();
    });
    _hotelsSub = CatalogRepository.instance.watchHotels(favoritedBy: key).listen((v) {
      hotels = v;
      loadingHotels = false;
      notifyListeners();
    });
    _attractionsSub = CatalogRepository.instance.watchAttractions(favoritedBy: key).listen((v) {
      attractions = v;
      loadingAttractions = false;
      notifyListeners();
    });
    _restaurantsSub = CatalogRepository.instance.watchRestaurants(favoritedBy: key).listen((v) {
      restaurants = v;
      loadingRestaurants = false;
      notifyListeners();
    });
  }

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  List<CatalogFlight> flights = [];
  List<CatalogHotel> hotels = [];
  List<CatalogAttraction> attractions = [];
  List<CatalogRestaurant> restaurants = [];

  bool loadingFlights = true;
  bool loadingHotels = true;
  bool loadingAttractions = true;
  bool loadingRestaurants = true;

  Future<void> unsaveFlight(CatalogFlight flight) =>
      CatalogRepository.instance.toggleFlightFavorite(flight.id, _uid, tripId, false);

  Future<void> unsaveHotel(CatalogHotel hotel) =>
      CatalogRepository.instance.toggleHotelFavorite(hotel.id, _uid, tripId, false);

  Future<void> unsaveAttraction(CatalogAttraction attraction) =>
      CatalogRepository.instance.toggleAttractionFavorite(attraction.id, _uid, tripId, false);

  Future<void> unsaveRestaurant(CatalogRestaurant restaurant) =>
      CatalogRepository.instance.toggleRestaurantFavorite(restaurant.id, _uid, tripId, false);

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
    super.dispose();
  }
}
