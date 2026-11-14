import 'package:flutter/material.dart';

class FilterController extends ChangeNotifier {
  // Flight and hotel price sliders cover different scales (RM0-5000
  // total fare vs. RM0-3000 per night) -- they used to share one
  // `priceRange` field, which not only let picking a hotel price filter
  // silently constrain flights (and vice versa), it also meant this
  // field's *default* value had to pick one scale and could be
  // completely wrong for the other. Separate fields, one per tab.
  //
  // All three of these ranges/sets used to default to an arbitrarily
  // narrow slice (RM100-1500, 1-12 hours, direct-only) instead of "no
  // filter at all" -- so a route with real fares/durations outside that
  // slice (a short, cheap domestic hop, or anything with a layover)
  // showed zero results from the very first load, before the traveller
  // ever touched the Filter sheet, and "Reset" just put them right back
  // into that same narrow slice instead of actually clearing it. Every
  // default below now matches its slider's own full min..max (or an
  // empty set) so the unfiltered state really means "show everything".
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
  String attractionPrice = 'Any';

  final Set<String> restaurantCuisines = {};
  String restaurantPrice = 'Any';

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
    attractionPrice = 'Any';
    restaurantCuisines.clear();
    restaurantPrice = 'Any';
    notifyListeners();
  }
}
