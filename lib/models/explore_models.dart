import 'package:flutter/material.dart';

import 'filter_models.dart';

/// The category currently selected in the Explore chip row. Drives which
/// list renders below the chips.
///
/// Insurance used to be one of these categories, but it now lives on the
/// Home page instead — Explore is for flights, hotels, places to visit and
/// (now) places to eat.
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

  /// Maps this category to the matching filter sheet content.
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
  // Defaults to '' rather than being required — the seeded mock flights
  // predate this field, and CatalogRepository.watchFlights() falls back
  // to a default label for those, but a bare '' here keeps any other
  // FlightData construction (tests, future call sites) compiling without
  // having to know about airline.
  final String airline;
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
  });
}

class HotelData {
  final String name, location, rating, reviews, price, image;
  // Real per-hotel amenity names (e.g. "WiFi", "Pool", "Parking") — from
  // Duffel's `accommodation.amenities` (Flights' stays product) or
  // RollingGo's `hotelAmenities` (Hotels' real data source — see
  // DuffelStayResult.fromRollingGo/fromJson). '' when the source result
  // just doesn't have any for that particular hotel; the detail page
  // hides the Amenities row entirely rather than showing a fixed list
  // that isn't actually about this hotel.
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

/// Entry fees broken down by age tier (adult/child/senior all often differ)
/// — every tier is optional, so an attraction that's free or only has one
/// flat price just leaves all of these unset and the detail page falls
/// back to showing the plain [AttractionData.price] instead. (A
/// resident-vs-tourist split, like some real listings also have, isn't
/// modelled here — every trip in this app is a Malaysian traveller
/// visiting somewhere else, so there's no "local" tier that would ever
/// actually apply.)
class AttractionFees {
  final String? adult, child, senior;
  const AttractionFees({this.adult, this.child, this.senior});

  bool get isEmpty => adult == null && child == null && senior == null;
}

class AttractionData {
  final String name, category, rating, reviews, price, image;
  // Location/openingHours were missing before — an attraction's page had no
  // way to tell the user *where* it is or *when* it's open, both of which
  // matter more for a real visit than the entry price does.
  final String location, openingHours;
  // Fuller detail-page content, closer to what a real listing (e.g. a
  // Google Places-backed one) shows: full street address, more than one
  // category tag, a proper day-by-day opening schedule, amenities on site,
  // trip-planning highlights, contact info, how long to budget for a
  // visit, more than one photo, and tiered entry pricing. Every field
  // defaults to "not set" so older/simpler seed data keeps working — the
  // detail page only shows a section when it actually has content for it.
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
  // A real, place-specific summary — OSM's own `description` tag or that
  // place's Wikipedia lead paragraph (see
  // PlacesApiService.resolveDescription) when either exists, '' when
  // neither does. The detail page only falls back to its generic
  // category sentence when this is empty, rather than always showing
  // the same templated text for every place in a category.
  final String description;

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
  });

  /// Every category tag to show as its own chip — falls back to the single
  /// [category] when no extra tags were seeded.
  List<String> get categoryTags => categories.isNotEmpty ? categories : [category];

  /// Every photo for the detail page's gallery strip — falls back to just
  /// [image] when no extra photos were seeded.
  List<String> get gallery => images.isNotEmpty ? images : [image];
}

class RestaurantData {
  final String name, location, rating, reviews, priceRange, openingHours, image;
  // Separate tags (e.g. ['Japanese', 'Ramen']) rendered as their own small
  // chips — not one string joined with a "•" dot, which read as a single
  // odd label instead of two distinct, scannable tags.
  final List<String> cuisineTags;
  // Real street address/phone/website from OpenStreetMap (see
  // CatalogRepository.refreshRestaurants) — same contact-info shape
  // AttractionData already has, added here so a restaurant's detail page
  // can show (and let someone tap) the same Contact section an
  // attraction's does, instead of having nowhere to put this data.
  // Default '' for older/simpler construction sites and for a POI OSM
  // just doesn't have this field for.
  final String address, phone, website;
  // Same idea as AttractionData.description — a real, place-specific
  // summary when OSM or Wikipedia has one, '' otherwise.
  final String description;
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
  });

  /// One plain string for places that just want a short description
  /// (e.g. "a popular X spot") rather than separate tag chips.
  String get cuisineLabel => cuisineTags.join(' ');
}
