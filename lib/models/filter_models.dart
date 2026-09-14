/// Each tab in Explore (and a few other screens) has its own kind of filter.
enum FilterType { flight, hotel, attraction, restaurant, nearby, plan }

extension FilterTypeLabel on FilterType {
  String get label {
    switch (this) {
      case FilterType.flight:
        return 'Flight Filters';
      case FilterType.hotel:
        return 'Hotel Filters';
      case FilterType.attraction:
        return 'Attraction Filters';
      case FilterType.restaurant:
        return 'Restaurant Filters';
      case FilterType.nearby:
        return 'Nearby Filters';
      case FilterType.plan:
        return 'Plan Filters';
    }
  }
}
