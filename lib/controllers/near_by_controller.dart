import 'dart:async';

import 'package:flutter/material.dart';

import '../models/nearby_models.dart';
import '../repositories/catalog_repository.dart';
import '../services/location_service.dart';
import '../services/places_api_service.dart';

class NearByController extends ChangeNotifier {
  NearByController() {
    _init();
  }

  String _selectedCategory = 'Restaurants';
  String get selectedCategory => _selectedCategory;

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _reload();
    notifyListeners();
  }

  List<NearbyPlace> places = [];
  bool loading = true;

  String? error;

  LocationLookupStatus? locationStatus;

  double? _lat;
  double? _lon;

  double? get myLat => _lat;
  double? get myLon => _lon;

  Future<void> _init() async {
    final position = await LocationService.instance.getCurrentPosition();
    if (position == null) {
      locationStatus = LocationLookupStatus.failed;
      loading = false;
      notifyListeners();
      return;
    }
    _lat = position.latitude;
    _lon = position.longitude;
    locationStatus = LocationLookupStatus.success;
    await _reload();
  }

  Future<void> _reload() async {
    if (_lat == null || _lon == null) return;
    loading = true;
    notifyListeners();
    places = await CatalogRepository.instance.fetchNearbyPlaces(lat: _lat!, lon: _lon!, category: _selectedCategory);
    error = places.isEmpty ? _describeError(PlacesApiService.instance.lastSearchNearbyError) : null;
    loading = false;
    notifyListeners();
  }

  String? _describeError(Object? e) {
    if (e == null) return null;
    final s = e.toString();
    if (s.contains('TimeoutException')) return "Timed out reaching OpenStreetMap's servers.";
    if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('Connection')) {
      return "Couldn't connect to OpenStreetMap's servers — the network may be blocking this host.";
    }
    return "Couldn't load nearby places ($s).";
  }

  Future<void> retryLocation() => _init();

  Future<void> retry() => _reload();

  @override
  void dispose() {
    super.dispose();
  }
}
