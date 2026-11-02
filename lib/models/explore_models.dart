import 'package:flutter/material.dart';

import 'filter_models.dart';

enum ExploreCategory { all, flights, accommodation, attractions, restaurants }

extension ExploreCategoryMeta on ExploreCategory {
  String get label {
    switch (this) {
      case ExploreCategory.all:
        return 'All';
      case ExploreCategory.flights:
        return 'Flights';
      case ExploreCategory.accommodation:
        return 'Hotels';
      case ExploreCategory.attractions:
        return 'Attractions';
      case ExploreCategory.restaurants:
        return 'Restaurants';
    }
  }

  IconData get icon {
    switch (this) {
      case ExploreCategory.all:
        return Icons.grid_view_rounded;
      case ExploreCategory.flights:
        return Icons.flight_takeoff;
      case ExploreCategory.accommodation:
        return Icons.hotel_outlined;
      case ExploreCategory.attractions:
        return Icons.attractions_outlined;
      case ExploreCategory.restaurants:
        return Icons.restaurant_outlined;
    }
  }

  FilterType get filterType {
    switch (this) {
      case ExploreCategory.all:
      case ExploreCategory.flights:
        return FilterType.flight;
      case ExploreCategory.accommodation:
        return FilterType.hotel;
      case ExploreCategory.attractions:
        return FilterType.attraction;
      case ExploreCategory.restaurants:
        return FilterType.restaurant;
    }
  }
}

class FlightData {
  final String depTime, arrTime, duration, from, to, stops, price, fareType;
  final String airline;
  final String flightNo;
  final String date;
  const FlightData({
    required this.depTime,
    required this.arrTime,
    required this.duration,
    required this.from,
    required this.to,
    required this.stops,
    required this.price,
    required this.fareType,
    this.airline = '',
    this.flightNo = '',
    this.date = '',
  });
}

class HotelData {
  final String name, location, rating, reviews, price, image;
  final List<String> amenities;
  const HotelData({
    required this.name,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.image,
    this.amenities = const [],
  });
}

class AttractionFees {
  final String? adult, child, senior;
  const AttractionFees({this.adult, this.child, this.senior});

  bool get isEmpty => adult == null && child == null && senior == null;
}

class AttractionData {
  final String name, category, rating, reviews, price, image;
  final String location, openingHours;
  final String address;
  final List<String> categories;
  final Map<String, String> openingHoursByDay;
  final List<String> facilities;
  final List<String> highlights;
  final String phone;
  final String website;
  final String recommendedDuration;
  final List<String> images;
  final AttractionFees fees;
  final String description;

  final double? distanceKm;

  final double? lat;
  final double? lng;

  const AttractionData({
    required this.name,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.image,
    this.location = '',
    this.openingHours = 'Daily, 9:00 AM - 6:00 PM',
    this.address = '',
    this.categories = const [],
    this.openingHoursByDay = const {},
    this.facilities = const [],
    this.highlights = const [],
    this.phone = '',
    this.website = '',
    this.recommendedDuration = '',
    this.description = '',
    this.images = const [],
    this.fees = const AttractionFees(),
    this.distanceKm,
    this.lat,
    this.lng,
  });

  List<String> get categoryTags => categories.isNotEmpty ? categories : [category];

  List<String> get gallery => images.isNotEmpty ? images : [image];
}

class RestaurantData {
  final String name, location, rating, reviews, priceRange, openingHours, image;
  final List<String> cuisineTags;
  final String address, phone, website;
  final String description;
  final double? lat;
  final double? lng;
  const RestaurantData({
    required this.name,
    required this.cuisineTags,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.priceRange,
    required this.image,
    this.openingHours = 'Daily, 11:00 AM - 10:00 PM',
    this.address = '',
    this.phone = '',
    this.website = '',
    this.description = '',
    this.lat,
    this.lng,
  });

  String get cuisineLabel => cuisineTags.join(' ');
}
