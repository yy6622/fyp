import 'dart:async';

import 'package:flutter/material.dart';

import '../models/nearby_models.dart';
import '../repositories/catalog_repository.dart';
import '../services/location_service.dart';

/// Controller for [NearByPage]. Streamed from a fixed Firestore seed
/// before — now a live, one-shot-per-selection query against real
/// OpenStreetMap data around the device's actual current position (see
/// [CatalogRepository.fetchNearbyPlaces]), same idea as how flights/
/// hotels never showed placeholder data: "near by" only means something
/// when it reflects where the device really is right now.
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

  /// Set once a position has been obtained (or failed to be obtained) so
  /// the page can tell "still getting your location" apart from "got
  /// your location, found nothing nearby" apart from "couldn't get your
  /// location at all" (location services off, permission declined).
  LocationLookupStatus? locationStatus;

  double? _lat;
  double? _lon;

  Future<void> _init() async {
    final position = await LocationService.instance.getCurrentPosition();
    if (position == null) {
      // getCurrentPosition already folds "service disabled" and
      // "permission denied" into one null — good enough here since
      // either way the page just needs to say "can't find your
      // location" with one message, not distinguish the exact reason
      // the way Account Setting's Home Airport picker does.
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
    loading = false;
    notifyListeners();
  }

  /// Re-tries getting the device's location — offered on the page when
  /// [locationStatus] isn't success (e.g. the person just turned location
  /// services on and wants to try again without leaving the page).
  Future<void> retryLocation() => _init();

  @override
  void dispose() {
    super.dispose();
  }
}
