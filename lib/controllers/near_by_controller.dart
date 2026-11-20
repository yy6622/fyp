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
  }

  int _radiusMeters = 3000;
  int get radiusMeters => _radiusMeters;
  void selectRadius(int value) {
    if (_radiusMeters == value) return;
    _radiusMeters = value;
    _reload();
  }

  int _requestToken = 0;
  bool _disposed = false;

  List<NearbyPlace> places = [];
  bool loading = true;

  String? error;

  LocationLookupStatus? locationStatus;

  double? _lat;
  double? _lon;

  double? get myLat => _lat;
  double? get myLon => _lon;

  Future<void> _init() async {
    final token = ++_requestToken;
    loading = true;
    error = null;
    notifyListeners();
    final position = await LocationService.instance.getCurrentPosition();
    if (_disposed || token != _requestToken) return;
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

  Future<void> _reload({bool forceRefresh = false}) async {
    if (_lat == null || _lon == null) return;
    final token = ++_requestToken;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await CatalogRepository.instance.fetchNearbyPlaces(
        lat: _lat!, lon: _lon!, category: _selectedCategory,
        radiusMeters: _radiusMeters, forceRefresh: forceRefresh,
      );
      if (_disposed || token != _requestToken) return;
      places = results;
      error = results.isEmpty
          ? _describeError(PlacesApiService.instance.lastSearchNearbyError) ??
              'No places found within ${_radiusMeters ~/ 1000} km. Try a larger distance.'
          : null;
    } catch (_) {
      if (_disposed || token != _requestToken) return;
      places = [];
      error = 'Could not load nearby places. Check your connection and try again.';
    } finally {
      if (!_disposed && token == _requestToken) {
        loading = false;
        notifyListeners();
      }
    }
  }

  String? _describeError(Object? e) {
    if (e == null) return null;
    // The source can now be Geoapify (preferred, when configured) or the
    // Overpass mirror chain (fallback) -- see PlacesApiService.searchNearbyStable
    // -- so this stays source-agnostic instead of naming one of them.
    final s = e.toString();
    if (s.contains('TimeoutException')) return "Timed out reaching the places service.";
    if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('Connection')) {
      return "Couldn't connect to the places service — the network may be blocking it.";
    }
    return "Couldn't load nearby places ($s).";
  }

  Future<void> retryLocation() => _init();

  Future<void> retry() => _reload(forceRefresh: true);

  @override
  void dispose() {
    _disposed = true;
    _requestToken++;
    super.dispose();
  }
}
