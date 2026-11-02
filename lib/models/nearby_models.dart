class NearbyPlace {
  final String id;
  final String name, category, categoryLabel, rating, distance, image;
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
