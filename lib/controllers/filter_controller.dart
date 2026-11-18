import 'package:flutter/material.dart';

class FilterController extends ChangeNotifier {
  RangeValues flightPriceRange = const RangeValues(0, 5000);
  RangeValues hotelPriceRange = const RangeValues(0, 3000);
  RangeValues durationRange = const RangeValues(0, 24);
  bool openNow = false;
  bool accessibleOnly = false;

  final Set<String> departureTimes = {};
  final Set<String> stops = {};
  final Set<String> airlines = {};

  final Set<String> starRatings = {};

  final Set<String> attractionCategories = {};

  final Set<String> restaurantCuisines = {};

  void setFlightPriceRange(RangeValues v) {
    flightPriceRange = v;
    notifyListeners();
  }

  void setHotelPriceRange(RangeValues v) {
    hotelPriceRange = v;
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
    flightPriceRange = const RangeValues(0, 5000);
    hotelPriceRange = const RangeValues(0, 3000);
    durationRange = const RangeValues(0, 24);
    openNow = false;
    accessibleOnly = false;
    departureTimes.clear();
    stops.clear();
    airlines.clear();
    starRatings.clear();
    attractionCategories.clear();
    restaurantCuisines.clear();
    notifyListeners();
  }
}
