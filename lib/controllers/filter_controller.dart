import 'package:flutter/material.dart';

class FilterController extends ChangeNotifier {
  RangeValues priceRange = const RangeValues(100, 1500);
  RangeValues durationRange = const RangeValues(1, 12);
  bool openNow = false;
  bool accessibleOnly = false;

  final Set<String> departureTimes = {};
  final Set<String> stops = {'Direct'};
  final Set<String> airlines = {};

  final Set<String> starRatings = {};
  String guestRating = 'Any';

  final Set<String> attractionCategories = {};
  String attractionPrice = 'Any';

  final Set<String> restaurantCuisines = {};
  String restaurantPrice = 'Any';

  void setPriceRange(RangeValues v) {
    priceRange = v;
    notifyListeners();
  }

  void setDurationRange(RangeValues v) {
    durationRange = v;
    notifyListeners();
  }

  void setOpenNow(bool v) {
    openNow = v;
    notifyListeners();
  }

  void setAccessibleOnly(bool v) {
    accessibleOnly = v;
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

  void setRestaurantPrice(String v) {
    restaurantPrice = v;
    notifyListeners();
  }

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
    openNow = false;
    accessibleOnly = false;
    departureTimes.clear();
    stops
      ..clear()
      ..add('Direct');
    airlines.clear();
    starRatings.clear();
    guestRating = 'Any';
    attractionCategories.clear();
    attractionPrice = 'Any';
    restaurantCuisines.clear();
    restaurantPrice = 'Any';
    notifyListeners();
  }
}
