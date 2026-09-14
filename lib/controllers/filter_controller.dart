import 'package:flutter/material.dart';

/// Controller backing [FilterPage]. Holds every filter field across all
/// [FilterType]s — only the ones relevant to the current type get read by
/// the view, matching the original single-State-class design.
class FilterController extends ChangeNotifier {
  RangeValues priceRange = const RangeValues(100, 1500);
  RangeValues durationRange = const RangeValues(1, 12);
  double distanceKm = 5;
  double tripDays = 5;
  bool openNow = false;

  final Set<String> departureTimes = {};
  final Set<String> stops = {'Direct'};
  final Set<String> airlines = {};

  final Set<String> starRatings = {};
  final Set<String> propertyTypes = {};
  final Set<String> amenities = {};
  String guestRating = 'Any';

  final Set<String> attractionCategories = {};
  String attractionPrice = 'Any';
  String attractionDuration = 'Any';

  final Set<String> restaurantCuisines = {};
  String restaurantPrice = 'Any';

  final Set<String> nearbyCategories = {};
  String nearbyRating = 'Any';

  final Set<String> tripTypes = {};
  final Set<String> seasons = {};
  String pace = 'Balanced';

  int ratingStars = 0;

  void setPriceRange(RangeValues v) {
    priceRange = v;
    notifyListeners();
  }

  void setDurationRange(RangeValues v) {
    durationRange = v;
    notifyListeners();
  }

  void setDistanceKm(double v) {
    distanceKm = v;
    notifyListeners();
  }

  void setTripDays(double v) {
    tripDays = v;
    notifyListeners();
  }

  void setOpenNow(bool v) {
    openNow = v;
    notifyListeners();
  }

  void setGuestRating(String v) {
    guestRating = v;
    notifyListeners();
  }

  void setAttractionPrice(String v) {
    attractionPrice = v;
    notifyListeners();
  }

  void setAttractionDuration(String v) {
    attractionDuration = v;
    notifyListeners();
  }

  void setRestaurantPrice(String v) {
    restaurantPrice = v;
    notifyListeners();
  }

  void setNearbyRating(String v) {
    nearbyRating = v;
    notifyListeners();
  }

  void setPace(String v) {
    pace = v;
    notifyListeners();
  }

  void setRatingStars(int v) {
    ratingStars = v;
    notifyListeners();
  }

  /// Shared toggle logic for every chip group. If [singleSelect] is true,
  /// acts like a radio group (only one chip can be active at a time).
  void toggleInSet(Set<String> set, String label, {bool singleSelect = false}) {
    if (singleSelect) {
      set
        ..clear()
        ..add(label);
    } else {
      if (set.contains(label)) {
        set.remove(label);
      } else {
        set.add(label);
      }
    }
    notifyListeners();
  }

  void resetFilters() {
    priceRange = const RangeValues(100, 1500);
    durationRange = const RangeValues(1, 12);
    distanceKm = 5;
    tripDays = 5;
    openNow = false;
    departureTimes.clear();
    stops
      ..clear()
      ..add('Direct');
    airlines.clear();
    starRatings.clear();
    propertyTypes.clear();
    amenities.clear();
    guestRating = 'Any';
    attractionCategories.clear();
    attractionPrice = 'Any';
    attractionDuration = 'Any';
    restaurantCuisines.clear();
    restaurantPrice = 'Any';
    nearbyCategories.clear();
    nearbyRating = 'Any';
    tripTypes.clear();
    seasons.clear();
    pace = 'Balanced';
    notifyListeners();
  }
}
