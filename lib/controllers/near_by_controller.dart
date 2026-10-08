import 'dart:async';

import 'package:flutter/material.dart';

import '../models/nearby_models.dart';
import '../repositories/catalog_repository.dart';
import '../services/location_service.dart';
import '../services/places_api_service.dart';

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

  /// Set when the last reload came back empty *because the OpenStreetMap
  /// request actually failed* (see PlacesApiService.lastSearchNearbyError)
  /// — null when the location genuinely has no matches for this category.
  /// Lets the page show the real reason (a timeout, a non-200 response, a
  /// DNS/connection failure — often what a network that blocks this host
  /// outright looks like) instead of always showing the same "No places
  /// found nearby" regardless of which of those actually happened.
  String? error;

  /// Set once a position has been obtained (or failed to be obtained) so
  /// the page can tell "still getting your location" apart from "got
  /// your location, found nothing nearby" apart from "couldn't get your
  /// location at all" (location services off, permission declined).
  LocationLookupStatus? locationStatus;

  double? _lat;
  double? _lon;

  /// The device's own real current position — exposed so NearByPage can
  /// center a real embedded map on it (see MemberLocationPage's
  /// _StaticMapPreview for the same no-API-key OpenStreetMap approach).
  /// Null until [locationStatus] is success.
  double? get myLat => _lat;
  double? get myLon => _lon;

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

  /// Re-tries getting the device's location — offered on the page when
  /// [locationStatus] isn't success (e.g. the person just turned location
  /// services on and wants to try again without leaving the page).
  Future<void> retryLocation() => _init();

  /// Re-runs the search for the currently selected category, without
  /// re-asking for location — offered on the page when a reload came back
  /// empty with a real [error] (location is already known good; only the
  /// OpenStreetMap request needs retrying).
  Future<void> retry() => _reload();

  @override
  void dispose() {
    super.dispose();
  }
}
