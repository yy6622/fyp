enum FilterType { flight, hotel, attraction, restaurant }

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
    }
  }
}
