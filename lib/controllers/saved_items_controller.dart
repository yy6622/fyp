import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/catalog_repository.dart';
import '../services/auth_service.dart';

class SavedItemsController extends ChangeNotifier {
  final String tripId;

  SavedItemsController({required this.tripId}) {
    final key = '$_uid#$tripId';
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

  List<CatalogAttraction> attractions = [];
  List<CatalogRestaurant> restaurants = [];

  bool loadingAttractions = true;
  bool loadingRestaurants = true;

  Future<void> unsaveAttraction(CatalogAttraction attraction) =>
      CatalogRepository.instance.toggleAttractionFavorite(attraction.id, _uid, tripId, false);

  Future<void> unsaveRestaurant(CatalogRestaurant restaurant) =>
      CatalogRepository.instance.toggleRestaurantFavorite(restaurant.id, _uid, tripId, false);

  StreamSubscription<List<CatalogAttraction>>? _attractionsSub;
  StreamSubscription<List<CatalogRestaurant>>? _restaurantsSub;

  @override
  void dispose() {
    _attractionsSub?.cancel();
    _restaurantsSub?.cancel();
    super.dispose();
  }
}
