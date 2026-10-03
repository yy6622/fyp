class NearbyPlace {
  final String id;
  final String name, category, categoryLabel, rating, distance, image;
  // The place's real coordinates (from the OSM node/way CatalogRepository.
  // fetchNearbyPlaces found it from) — needed to open real turn-by-turn
  // directions to it (see DetailPagePlace/near_by_page.dart's "Get
  // Directions" button, which opens Google Maps at this exact point
  // rather than just searching its name).
  final double lat;
  final double lon;
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.rating,
    required this.distance,
    required this.image,
    required this.lat,
    required this.lon,
  });
}
