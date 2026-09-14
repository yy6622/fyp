import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/explore_models.dart';
import '../models/nearby_models.dart';

/// Explore/Near By show a catalogue of flights, hotels, attractions and
/// nearby places. A real app would pull this from a travel-inventory or
/// maps API; this project doesn't have one wired up, so the catalogue is
/// instead seeded once into Firestore (`catalog_flights` / `catalog_hotels`
/// / `catalog_attractions` / `catalog_places`) and read from there like any
/// other real data — nothing is hardcoded in the app itself, and favoriting
/// an item is a real, persisted action. (`catalog_restaurants` joined the
/// same pattern once Explore grew a Restaurants category.)
///
/// Saving ("favoriting") an item is scoped to whichever trip/plan is
/// selected on Explore when you tap the heart — not a single global
/// per-user list — because the whole point is "save this hotel for my Bali
/// trip" vs "save it for my Japan trip". Rather than reshaping
/// `favoritedBy` into a map keyed by tripId (which the existing
/// `hasOnly(['favoritedBy'])` security rule would have to be rewritten
/// for), each entry in that same array is just `"<uid>#<tripId>"`. So the
/// array-union/array-remove writes and the `favoritedBy: <key>` filter on
/// the watch methods below both keep working unchanged — only the string
/// stored in them changed shape.
class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  CollectionReference<Map<String, dynamic>> get _flights => FirebaseFirestore.instance.collection('catalog_flights');
  CollectionReference<Map<String, dynamic>> get _hotels => FirebaseFirestore.instance.collection('catalog_hotels');
  CollectionReference<Map<String, dynamic>> get _attractions =>
      FirebaseFirestore.instance.collection('catalog_attractions');
  CollectionReference<Map<String, dynamic>> get _restaurants =>
      FirebaseFirestore.instance.collection('catalog_restaurants');
  CollectionReference<Map<String, dynamic>> get _places => FirebaseFirestore.instance.collection('catalog_places');

  // ---------------- Flights ----------------
  // [favoritedBy], despite the name kept for symmetry with hotels/attractions,
  // is actually a "uid#tripId" composite key — see the class doc below for
  // why saves are scoped per trip instead of per user.
  Stream<List<CatalogFlight>> watchFlights({String? favoritedBy}) {
    return _flights.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .map((d) => CatalogFlight(
              id: d.id,
              favoritedBy: _favBy(d),
              depTime: (d.data()['depTime'] as String?) ?? '',
              arrTime: (d.data()['arrTime'] as String?) ?? '',
              duration: (d.data()['duration'] as String?) ?? '',
              from: (d.data()['from'] as String?) ?? '',
              to: (d.data()['to'] as String?) ?? '',
              stops: (d.data()['stops'] as String?) ?? '',
              price: (d.data()['price'] as String?) ?? '',
              fareType: (d.data()['fareType'] as String?) ?? '',
            ))
        .toList());
  }

  Future<void> toggleFlightFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_flights, id, '$uid#$tripId', fav);

  // ---------------- Hotels ----------------
  Stream<List<CatalogHotel>> watchHotels({String? favoritedBy}) {
    return _hotels.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .map((d) => CatalogHotel(
              id: d.id,
              favoritedBy: _favBy(d),
              name: (d.data()['name'] as String?) ?? '',
              location: (d.data()['location'] as String?) ?? '',
              rating: (d.data()['rating'] as String?) ?? '',
              reviews: (d.data()['reviews'] as String?) ?? '',
              price: (d.data()['price'] as String?) ?? '',
              image: (d.data()['image'] as String?) ?? '',
            ))
        .toList());
  }

  Future<void> toggleHotelFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_hotels, id, '$uid#$tripId', fav);

  // ---------------- Attractions ----------------
  Stream<List<CatalogAttraction>> watchAttractions({String? favoritedBy}) {
    return _attractions.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .map((d) => CatalogAttraction(
              id: d.id,
              favoritedBy: _favBy(d),
              name: (d.data()['name'] as String?) ?? '',
              category: (d.data()['category'] as String?) ?? '',
              rating: (d.data()['rating'] as String?) ?? '',
              reviews: (d.data()['reviews'] as String?) ?? '',
              price: (d.data()['price'] as String?) ?? '',
              image: (d.data()['image'] as String?) ?? '',
              location: (d.data()['location'] as String?) ?? '',
              openingHours: (d.data()['openingHours'] as String?) ?? 'Daily, 9:00 AM - 6:00 PM',
              address: (d.data()['address'] as String?) ?? '',
              categories: List<String>.from(d.data()['categories'] as List? ?? const []),
              openingHoursByDay: Map<String, String>.from(d.data()['openingHoursByDay'] as Map? ?? const {}),
              facilities: List<String>.from(d.data()['facilities'] as List? ?? const []),
              highlights: List<String>.from(d.data()['highlights'] as List? ?? const []),
              phone: (d.data()['phone'] as String?) ?? '',
              website: (d.data()['website'] as String?) ?? '',
              recommendedDuration: (d.data()['recommendedDuration'] as String?) ?? '',
              images: List<String>.from(d.data()['images'] as List? ?? const []),
              fees: _feesFrom(d.data()['fees'] as Map<String, dynamic>?),
            ))
        .toList());
  }

  AttractionFees _feesFrom(Map<String, dynamic>? m) {
    if (m == null) return const AttractionFees();
    return AttractionFees(
      adult: m['adult'] as String?,
      child: m['child'] as String?,
      senior: m['senior'] as String?,
    );
  }

  Future<void> toggleAttractionFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_attractions, id, '$uid#$tripId', fav);

  // ---------------- Restaurants ----------------
  Stream<List<CatalogRestaurant>> watchRestaurants({String? favoritedBy}) {
    return _restaurants.snapshots().map((snap) => snap.docs
        .where((d) => favoritedBy == null || _favBy(d).contains(favoritedBy))
        .map((d) => CatalogRestaurant(
              id: d.id,
              favoritedBy: _favBy(d),
              name: (d.data()['name'] as String?) ?? '',
              cuisineTags: List<String>.from(d.data()['cuisineTags'] as List? ?? const []),
              location: (d.data()['location'] as String?) ?? '',
              rating: (d.data()['rating'] as String?) ?? '',
              reviews: (d.data()['reviews'] as String?) ?? '',
              priceRange: (d.data()['priceRange'] as String?) ?? '',
              image: (d.data()['image'] as String?) ?? '',
              openingHours: (d.data()['openingHours'] as String?) ?? 'Daily, 11:00 AM - 10:00 PM',
            ))
        .toList());
  }

  Future<void> toggleRestaurantFavorite(String id, String uid, String tripId, bool fav) =>
      _toggleFav(_restaurants, id, '$uid#$tripId', fav);

  // ---------------- Near-by places ----------------
  Stream<List<NearbyPlace>> watchPlaces({String? category}) {
    return _places.snapshots().map((snap) => snap.docs
        .where((d) => category == null || (d.data()['category'] as String?) == category)
        .map((d) => NearbyPlace(
              id: d.id,
              name: (d.data()['name'] as String?) ?? '',
              category: (d.data()['category'] as String?) ?? '',
              categoryLabel: (d.data()['categoryLabel'] as String?) ?? (d.data()['category'] as String?) ?? '',
              rating: (d.data()['rating'] as String?) ?? '',
              distance: (d.data()['distance'] as String?) ?? '',
              image: (d.data()['image'] as String?) ?? '',
            ))
        .toList());
  }

  List<String> _favBy(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      List<String>.from(d.data()['favoritedBy'] as List? ?? const []);

  /// [key] is the composite "uid#tripId" saved-for-trip key (see class doc).
  Future<void> _toggleFav(CollectionReference<Map<String, dynamic>> col, String id, String key, bool fav) {
    return col.doc(id).update({
      'favoritedBy': fav ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key]),
    });
  }

  /// Writes the starter catalogue once, so a brand-new Firebase project
  /// isn't empty. No-ops once there's any data in each collection.
  Future<void> seedIfEmpty() async {
    await Future.wait([
      _seedFlights(),
      _seedHotels(),
      _seedAttractions(),
      _seedRestaurants(),
      _seedPlaces(),
    ]);
  }

  Future<void> _seedFlights() async {
    if ((await _flights.limit(1).get()).docs.isNotEmpty) return;
    for (var i = 0; i < 6; i++) {
      await _flights.add(const {
        'depTime': '9:20',
        'arrTime': '17:25',
        'duration': '7h 5m',
        'from': 'KUL',
        'to': 'NRT',
        'stops': 'Non-stop',
        'price': 'RM 899',
        'fareType': 'One Way',
        'favoritedBy': <String>[],
      });
    }
  }

  Future<void> _seedHotels() async {
    if ((await _hotels.limit(1).get()).docs.isNotEmpty) return;
    for (var i = 0; i < 6; i++) {
      await _hotels.add({
        'name': 'L Hotel',
        'location': 'Shinjoku, Tokyo',
        'rating': '4.8',
        'reviews': '1.2k',
        'price': 'RM 899',
        'image': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400',
        'favoritedBy': <String>[],
      });
    }
  }

  Future<void> _seedAttractions() async {
    if ((await _attractions.limit(1).get()).docs.isNotEmpty) return;
    final seed = [
      {
        'name': 'Senso-ji Temple',
        'category': 'Cultural',
        'rating': '4.7',
        'reviews': '3.4k',
        'price': 'Free entry',
        'image': 'https://images.unsplash.com/photo-1478436127897-769e1b3f0f36?w=400',
        'location': 'Asakusa, Tokyo',
        'openingHours': 'Daily, 6:00 AM - 5:00 PM',
        'address': '2 Chome-3-1 Asakusa, Taito City, Tokyo 111-0032, Japan',
        'categories': const ['Cultural', 'Historic Site', 'Temple'],
        'openingHoursByDay': _dailyHours('6:00 AM - 5:00 PM'),
        'facilities': const ['Souvenir Shop', 'Public Toilet', 'Food & Beverage'],
        'highlights': const [
          'Iconic Kaminarimon Thunder Gate and giant lantern',
          'Nakamise shopping street lined with traditional snacks',
          "Tokyo's oldest and most visited Buddhist temple",
        ],
        'phone': '+81 3-3842-0181',
        'website': 'https://www.senso-ji.jp',
        'recommendedDuration': '1 - 2 hours',
      },
      {
        'name': 'TeamLab Planets',
        'category': 'Museum',
        'rating': '4.9',
        'reviews': '2.1k',
        'price': 'RM 120',
        'image': 'https://images.unsplash.com/photo-1554797589-7241bb691973?w=400',
        'location': 'Toyosu, Tokyo',
        'openingHours': 'Daily, 9:00 AM - 9:00 PM',
        'address': '6-1-16 Toyosu, Koto City, Tokyo 135-0061, Japan',
        'categories': const ['Museum', 'Art & Culture', 'Entertainment'],
        'openingHoursByDay': _dailyHours('9:00 AM - 9:00 PM'),
        'facilities': const ['Locker Room', 'Gift Shop', 'Cafe'],
        'highlights': const [
          'Wade through water and light installations barefoot',
          'Instagram-famous infinity mirror rooms',
          "One of Tokyo's most popular digital art museums",
        ],
        'phone': '+81 3-6812-6428',
        'website': 'https://www.teamlab.art/e/planets/',
        'recommendedDuration': '2 - 3 hours',
        'fees': const {'adult': 'RM 120', 'child': 'RM 80', 'senior': 'RM 100'},
      },
      {
        'name': 'Shibuya Crossing',
        'category': 'Nature',
        'rating': '4.6',
        'reviews': '5.0k',
        'price': 'Free entry',
        'image': 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=400',
        'location': 'Shibuya, Tokyo',
        'openingHours': 'Open 24 hours',
        'address': 'Shibuya City, Tokyo 150-0043, Japan',
        'categories': const ['Landmark', 'Photography Spot'],
        'openingHoursByDay': _dailyHours('Open 24 hours'),
        'facilities': const ['Public Toilet (Shibuya Station)'],
        'highlights': const [
          "World's busiest pedestrian scramble crossing",
          'Great photo spot from the Starbucks second floor',
          'Surrounded by shopping and nightlife',
        ],
        'recommendedDuration': '30 mins - 1 hour',
      },
      {
        'name': 'Mount Fuji Viewpoint',
        'category': 'Adventure',
        'rating': '4.8',
        'reviews': '1.8k',
        'price': 'RM 60',
        'image': 'https://images.unsplash.com/photo-1570459027562-4a916cc6113f?w=400',
        'location': 'Fujiyoshida, Yamanashi',
        'openingHours': 'Daily, 8:00 AM - 6:00 PM',
        'address': 'Fujiyoshida, Yamanashi 403-0005, Japan',
        'categories': const ['Adventure', 'Nature', 'Scenic Viewpoint'],
        'openingHoursByDay': _dailyHours('8:00 AM - 6:00 PM'),
        'facilities': const ['Parking', 'Public Toilet', 'Souvenir Shop'],
        'highlights': const [
          'Unobstructed panoramic views of Mount Fuji',
          'Popular sunrise and sunset photography spot',
          'Short walk from the nearest car park',
        ],
        'recommendedDuration': '1 - 2 hours',
        'fees': const {'adult': 'RM 60', 'child': 'RM 30', 'senior': 'RM 45'},
      },
    ];
    for (final a in seed) {
      await _attractions.add({...a, 'favoritedBy': <String>[]});
    }
  }

  /// Same hours string repeated for every day of the week — the sample
  /// attractions here all keep flat hours (no different Sunday schedule
  /// etc.), but the model still stores a real per-weekday map so a future
  /// attraction with an actual varying schedule is just different seed
  /// data, not a data-model change.
  static Map<String, String> _dailyHours(String hours) => {
        'Monday': hours,
        'Tuesday': hours,
        'Wednesday': hours,
        'Thursday': hours,
        'Friday': hours,
        'Saturday': hours,
        'Sunday': hours,
      };

  Future<void> _seedRestaurants() async {
    if ((await _restaurants.limit(1).get()).docs.isNotEmpty) return;
    const seed = [
      {
        'name': 'Ichiran Ramen',
        'cuisineTags': ['Japanese', 'Ramen'],
        'location': 'Shibuya, Tokyo',
        'rating': '4.7',
        'reviews': '9.2k',
        'priceRange': 'RM 20 - 40',
        'image': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400',
      },
      {
        'name': 'Sushi Dai',
        'cuisineTags': ['Japanese', 'Sushi'],
        'location': 'Tsukiji, Tokyo',
        'rating': '4.9',
        'reviews': '4.6k',
        'priceRange': 'RM 80 - 150',
        'image': 'https://images.unsplash.com/photo-1553621042-f6e147245754?w=400',
      },
      {
        'name': 'Gyukatsu Motomura',
        'cuisineTags': ['Japanese', 'Beef Cutlet'],
        'location': 'Shibuya, Tokyo',
        'rating': '4.8',
        'reviews': '3.1k',
        'priceRange': 'RM 40 - 70',
        'image': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
      },
      {
        'name': 'Blue Bottle Coffee',
        'cuisineTags': ['Cafe', 'Coffee'],
        'location': 'Aoyama, Tokyo',
        'rating': '4.6',
        'reviews': '2.0k',
        'priceRange': 'RM 15 - 30',
        'image': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400',
      },
      {
        'name': 'Ippudo',
        'cuisineTags': ['Japanese', 'Ramen'],
        'location': 'Shinjuku, Tokyo',
        'rating': '4.6',
        'reviews': '6.5k',
        'priceRange': 'RM 25 - 45',
        'image': 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=400',
      },
    ];
    for (final r in seed) {
      await _restaurants.add({...r, 'favoritedBy': <String>[]});
    }
  }

  // Backfills per category rather than a single "collection already has
  // something, skip everything" check: this collection originally only
  // ever seeded 'Restaurants', so on an existing project the other five
  // categories (Cafes/Attractions/Shopping/ATM/Pharmacy) would otherwise
  // never get created and those chips would stay empty forever.
  Future<void> _seedPlaces() async {
    const seed = [
      {
        'name': 'Ichiran Ramen',
        'category': 'Restaurants',
        'categoryLabel': 'Japanese • Ramen',
        'rating': '4.7',
        'distance': '250 m',
        'image': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400',
      },
      {
        'name': 'Sushi Dai',
        'category': 'Restaurants',
        'categoryLabel': 'Japanese • Sushi',
        'rating': '4.9',
        'distance': '400 m',
        'image': 'https://images.unsplash.com/photo-1553621042-f6e147245754?w=400',
      },
      {
        'name': 'Ippudo',
        'category': 'Restaurants',
        'categoryLabel': 'Japanese • Ramen',
        'rating': '4.6',
        'distance': '650 m',
        'image': 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=400',
      },
      {
        'name': 'Gyukatsu Motomura',
        'category': 'Restaurants',
        'categoryLabel': 'Japanese • Beef Cutlet',
        'rating': '4.8',
        'distance': '900 m',
        'image': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
      },
      {
        'name': 'Blue Bottle Coffee',
        'category': 'Cafes',
        'categoryLabel': 'Cafe • Coffee',
        'rating': '4.6',
        'distance': '180 m',
        'image': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400',
      },
      {
        'name': '% Arabica',
        'category': 'Cafes',
        'categoryLabel': 'Cafe • Coffee',
        'rating': '4.8',
        'distance': '520 m',
        'image': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400',
      },
      {
        'name': 'Ueno Park',
        'category': 'Attractions',
        'categoryLabel': 'Park • Sightseeing',
        'rating': '4.7',
        'distance': '1.1 km',
        'image': 'https://images.unsplash.com/photo-1522383225653-ed111181a951?w=400',
      },
      {
        'name': 'Tokyo Tower',
        'category': 'Attractions',
        'categoryLabel': 'Landmark • Sightseeing',
        'rating': '4.8',
        'distance': '2.3 km',
        'image': 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=400',
      },
      {
        'name': 'Don Quijote',
        'category': 'Shopping',
        'categoryLabel': 'Department Store',
        'rating': '4.5',
        'distance': '300 m',
        'image': 'https://images.unsplash.com/photo-1555529771-835f59fc5efe?w=400',
      },
      {
        'name': 'Takeshita Street',
        'category': 'Shopping',
        'categoryLabel': 'Shopping Street',
        'rating': '4.6',
        'distance': '1.4 km',
        'image': 'https://images.unsplash.com/photo-1567958451986-2de427a4a0be?w=400',
      },
      {
        'name': '7-Eleven ATM',
        'category': 'ATM',
        'categoryLabel': 'ATM • 24 Hours',
        'rating': '4.3',
        'distance': '120 m',
        'image': 'https://images.unsplash.com/photo-1601597111158-2fceff292cdc?w=400',
      },
      {
        'name': 'Seven Bank ATM',
        'category': 'ATM',
        'categoryLabel': 'ATM • 24 Hours',
        'rating': '4.2',
        'distance': '480 m',
        'image': 'https://images.unsplash.com/photo-1601597111158-2fceff292cdc?w=400',
      },
      {
        'name': 'Matsumoto Kiyoshi',
        'category': 'Pharmacy',
        'categoryLabel': 'Pharmacy • Drugstore',
        'rating': '4.5',
        'distance': '350 m',
        'image': 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400',
      },
      {
        'name': 'Sugi Pharmacy',
        'category': 'Pharmacy',
        'categoryLabel': 'Pharmacy • Drugstore',
        'rating': '4.4',
        'distance': '760 m',
        'image': 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400',
      },
    ];
    final byCategory = <String, List<Map<String, String>>>{};
    for (final p in seed) {
      byCategory.putIfAbsent(p['category']!, () => []).add(p);
    }
    for (final entry in byCategory.entries) {
      final existing = await _places.where('category', isEqualTo: entry.key).limit(1).get();
      if (existing.docs.isNotEmpty) continue;
      for (final p in entry.value) {
        await _places.add(p);
      }
    }
  }
}

/// [HotelData] doesn't carry an id or favorited-by list, both of which
/// Explore needs now that hotels are real Firestore docs — so this small
/// subclass adds them without disturbing every other place [HotelData] is
/// used (e.g. the still-static `AttractionData`/`FlightData` shapes).
class CatalogHotel extends HotelData {
  final String id;
  final List<String> favoritedBy;
  const CatalogHotel({
    required this.id,
    required this.favoritedBy,
    required super.name,
    required super.location,
    required super.rating,
    required super.reviews,
    required super.price,
    required super.image,
  });

  /// Whether [uid] saved this hotel for [tripId] (see class doc — saves are
  /// per trip, not just per user).
  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}

/// Same idea as [CatalogHotel], for attractions.
class CatalogAttraction extends AttractionData {
  final String id;
  final List<String> favoritedBy;
  const CatalogAttraction({
    required this.id,
    required this.favoritedBy,
    required super.name,
    required super.category,
    required super.rating,
    required super.reviews,
    required super.price,
    required super.image,
    super.location,
    super.openingHours,
    super.address,
    super.categories,
    super.openingHoursByDay,
    super.facilities,
    super.highlights,
    super.phone,
    super.website,
    super.recommendedDuration,
    super.images,
    super.fees,
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}

/// Same idea again, for restaurants.
class CatalogRestaurant extends RestaurantData {
  final String id;
  final List<String> favoritedBy;
  const CatalogRestaurant({
    required this.id,
    required this.favoritedBy,
    required super.name,
    required super.cuisineTags,
    required super.location,
    required super.rating,
    required super.reviews,
    required super.priceRange,
    required super.image,
    super.openingHours,
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}

/// Same idea again, for flights — [FlightData] itself stays a plain,
/// id-less shape since nothing else constructs it directly.
class CatalogFlight extends FlightData {
  final String id;
  final List<String> favoritedBy;
  const CatalogFlight({
    required this.id,
    required this.favoritedBy,
    required super.depTime,
    required super.arrTime,
    required super.duration,
    required super.from,
    required super.to,
    required super.stops,
    required super.price,
    required super.fareType,
  });

  bool isSavedForTrip(String uid, String? tripId) =>
      tripId != null && favoritedBy.contains('$uid#$tripId');
}
