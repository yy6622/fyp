/// Result shapes for the real Flights/Hotels data source — Duffel's
/// Flights (air/offer_requests) and Stays (stays/search) REST APIs. See
/// [DuffelApiService] for the calls that produce these.
///
/// A couple of nested fields (accommodation address shape, photo list
/// shape) are parsed defensively with fallbacks, since Duffel's public
/// docs describe them at a high level without pinning down every nested
/// key — if a field ever comes back empty where you'd expect a value,
/// check the raw response shape against what's parsed below and adjust.
library;

class DuffelFlightOffer {
  final String id;
  final String airlineName;
  final String? airlineLogoUrl;
  final String flightNumber;
  final String originCode;
  final String destinationCode;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final int stops;
  final double totalAmount;
  final String totalCurrency;

  const DuffelFlightOffer({
    required this.id,
    required this.airlineName,
    this.airlineLogoUrl,
    required this.flightNumber,
    required this.originCode,
    required this.destinationCode,
    required this.departureAt,
    required this.arrivalAt,
    required this.stops,
    required this.totalAmount,
    required this.totalCurrency,
  });

  Duration get flightDuration => arrivalAt.difference(departureAt);

  String get durationLabel {
    final d = flightDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  String get stopsLabel => stops == 0 ? 'Direct' : (stops == 1 ? '1 stop' : '$stops stops');

  factory DuffelFlightOffer.fromJson(Map<String, dynamic> json) {
    final slices = (json['slices'] as List?) ?? const [];
    final firstSlice = slices.isNotEmpty ? slices.first as Map<String, dynamic> : <String, dynamic>{};
    final segments = (firstSlice['segments'] as List?) ?? const [];
    final firstSeg = segments.isNotEmpty ? segments.first as Map<String, dynamic> : <String, dynamic>{};
    final lastSeg = segments.isNotEmpty ? segments.last as Map<String, dynamic> : <String, dynamic>{};
    final carrier = (firstSeg['marketing_carrier'] as Map?)?.cast<String, dynamic>() ?? const {};

    DateTime parseDt(dynamic v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();
    // A "place" field (slice/segment origin/destination) may come back as
    // either a plain IATA-code string or a richer {iata_code, name, ...}
    // object depending on the endpoint — handle both.
    String? iataOf(dynamic place) {
      if (place is String) return place;
      if (place is Map) return place['iata_code'] as String?;
      return null;
    }

    return DuffelFlightOffer(
      id: (json['id'] as String?) ?? '',
      airlineName: (carrier['name'] as String?) ?? 'Unknown Airline',
      airlineLogoUrl: carrier['logo_symbol_url'] as String? ?? carrier['logo_lockup_url'] as String?,
      flightNumber: (firstSeg['marketing_carrier_flight_number'] as String?) ?? '',
      originCode: iataOf(firstSlice['origin']) ?? iataOf(firstSeg['origin']) ?? '',
      destinationCode: iataOf(firstSlice['destination']) ?? iataOf(lastSeg['destination']) ?? '',
      departureAt: parseDt(firstSeg['departing_at']),
      arrivalAt: parseDt(lastSeg['arriving_at']),
      stops: segments.isEmpty ? 0 : segments.length - 1,
      totalAmount: double.tryParse((json['total_amount'] as String?) ?? '') ?? 0,
      totalCurrency: (json['total_currency'] as String?) ?? '',
    );
  }

  /// A plain, flat serialization for [CatalogRepository]'s "popular
  /// flights" Firestore cache — deliberately its own simple format
  /// rather than reusing [fromJson]'s raw-Duffel-response shape, so
  /// caching doesn't depend on faking a realistic-looking API response.
  Map<String, dynamic> toCacheMap() => {
        'id': id,
        'airlineName': airlineName,
        'airlineLogoUrl': airlineLogoUrl,
        'flightNumber': flightNumber,
        'originCode': originCode,
        'destinationCode': destinationCode,
        'departureAt': departureAt.toIso8601String(),
        'arrivalAt': arrivalAt.toIso8601String(),
        'stops': stops,
        'totalAmount': totalAmount,
        'totalCurrency': totalCurrency,
      };

  factory DuffelFlightOffer.fromCacheMap(Map<String, dynamic> m) => DuffelFlightOffer(
        id: (m['id'] as String?) ?? '',
        airlineName: (m['airlineName'] as String?) ?? 'Unknown Airline',
        airlineLogoUrl: m['airlineLogoUrl'] as String?,
        flightNumber: (m['flightNumber'] as String?) ?? '',
        originCode: (m['originCode'] as String?) ?? '',
        destinationCode: (m['destinationCode'] as String?) ?? '',
        departureAt: DateTime.tryParse((m['departureAt'] as String?) ?? '') ?? DateTime.now(),
        arrivalAt: DateTime.tryParse((m['arrivalAt'] as String?) ?? '') ?? DateTime.now(),
        stops: (m['stops'] as num?)?.toInt() ?? 0,
        totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
        totalCurrency: (m['totalCurrency'] as String?) ?? '',
      );
}

class DuffelStayResult {
  /// The *search result* id — what you'd pass along to fetch full rates /
  /// start a booking. Not the same as [accommodationId].
  final String searchResultId;
  final String accommodationId;
  final String name;
  final String address;
  final double? rating;
  final double? reviewScore;
  final int? reviewCount;
  final String? photoUrl;
  final double cheapestTotalAmount;
  final String cheapestCurrency;
  final DateTime checkInDate;
  final DateTime checkOutDate;

  const DuffelStayResult({
    required this.searchResultId,
    required this.accommodationId,
    required this.name,
    required this.address,
    this.rating,
    this.reviewScore,
    this.reviewCount,
    this.photoUrl,
    required this.cheapestTotalAmount,
    required this.cheapestCurrency,
    required this.checkInDate,
    required this.checkOutDate,
  });

  factory DuffelStayResult.fromJson(Map<String, dynamic> json) {
    final accommodation = (json['accommodation'] as Map?)?.cast<String, dynamic>() ?? const {};
    final location = (accommodation['location'] as Map?)?.cast<String, dynamic>() ?? const {};
    final addressField = location['address'];
    String address = '';
    if (addressField is String) {
      address = addressField;
    } else if (addressField is Map) {
      address = [
        addressField['line_one'],
        addressField['city_name'],
        addressField['country_code'],
      ].where((v) => v != null && (v as String).isNotEmpty).join(', ');
    }
    final photos = (accommodation['photos'] as List?) ?? const [];
    String? photoUrl;
    if (photos.isNotEmpty) {
      final first = photos.first;
      photoUrl = first is Map ? first['url'] as String? : (first is String ? first : null);
    }

    DateTime parseDate(dynamic v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();

    return DuffelStayResult(
      searchResultId: (json['id'] as String?) ?? '',
      accommodationId: (accommodation['id'] as String?) ?? '',
      name: (accommodation['name'] as String?) ?? 'Unnamed Hotel',
      address: address,
      rating: (accommodation['rating'] as num?)?.toDouble(),
      reviewScore: (accommodation['review_score'] as num?)?.toDouble(),
      reviewCount: (accommodation['review_count'] as num?)?.toInt(),
      photoUrl: photoUrl,
      cheapestTotalAmount: double.tryParse((json['cheapest_rate_total_amount'] as String?) ?? '') ?? 0,
      cheapestCurrency: (json['cheapest_rate_currency'] as String?) ?? '',
      checkInDate: parseDate(json['check_in_date']),
      checkOutDate: parseDate(json['check_out_date']),
    );
  }

  /// Same reasoning as [DuffelFlightOffer.toCacheMap] — a plain, flat
  /// shape dedicated to [CatalogRepository]'s "popular hotels" cache.
  Map<String, dynamic> toCacheMap() => {
        'searchResultId': searchResultId,
        'accommodationId': accommodationId,
        'name': name,
        'address': address,
        'rating': rating,
        'reviewScore': reviewScore,
        'reviewCount': reviewCount,
        'photoUrl': photoUrl,
        'cheapestTotalAmount': cheapestTotalAmount,
        'cheapestCurrency': cheapestCurrency,
        'checkInDate': checkInDate.toIso8601String(),
        'checkOutDate': checkOutDate.toIso8601String(),
      };

  factory DuffelStayResult.fromCacheMap(Map<String, dynamic> m) => DuffelStayResult(
        searchResultId: (m['searchResultId'] as String?) ?? '',
        accommodationId: (m['accommodationId'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'Unnamed Hotel',
        address: (m['address'] as String?) ?? '',
        rating: (m['rating'] as num?)?.toDouble(),
        reviewScore: (m['reviewScore'] as num?)?.toDouble(),
        reviewCount: (m['reviewCount'] as num?)?.toInt(),
        photoUrl: m['photoUrl'] as String?,
        cheapestTotalAmount: (m['cheapestTotalAmount'] as num?)?.toDouble() ?? 0,
        cheapestCurrency: (m['cheapestCurrency'] as String?) ?? '',
        checkInDate: DateTime.tryParse((m['checkInDate'] as String?) ?? '') ?? DateTime.now(),
        checkOutDate: DateTime.tryParse((m['checkOutDate'] as String?) ?? '') ?? DateTime.now(),
      );

  /// Same shape, sourced from [RollingGoApiService.searchStays]'s
  /// `searchHotels` tool result instead of Duffel's `/stays/search`.
  /// RollingGo's documented hotel object doesn't carry a separate
  /// "search result id" vs "accommodation id" the way Duffel's two-tier
  /// scheme does, so [hotelId] fills both — every other field this app
  /// reads off a [DuffelStayResult] (saving, display, caching) only
  /// needs *some* stable id, not Duffel's specific split. Field names
  /// are read defensively (multiple candidates tried where RollingGo's
  /// docs were ambiguous, e.g. the photo field) since this mapping
  /// hasn't been verified against a live response yet — see
  /// RollingGoApiService's doc comment.
  factory DuffelStayResult.fromRollingGo(
    Map<String, dynamic> json, {
    required DateTime checkIn,
    required DateTime checkOut,
  }) {
    final hotelId = _rgId(json['hotelId']) ?? _rgId(json['id']) ?? '';
    final priceField = json['price'];
    final price = priceField is Map ? priceField.cast<String, dynamic>() : const <String, dynamic>{};
    String? photoUrl;
    for (final key in ['imageUrl', 'image', 'coverImage', 'thumbnail']) {
      final v = _rgString(json[key]);
      if (v != null) {
        photoUrl = v;
        break;
      }
    }
    if (photoUrl == null) {
      final images = json['images'];
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        photoUrl = first is String ? first : (first is Map ? _rgString(first['url']) : null);
      }
    }
    return DuffelStayResult(
      searchResultId: hotelId,
      accommodationId: hotelId,
      name: _rgString(json['name']) ?? 'Unnamed Hotel',
      address: _rgString(json['address']) ?? '',
      rating: _rgNum(json['starRating']),
      // RollingGo's documented searchHotels response has no separate
      // guest-review score/count field (only the star classification
      // above) — left null rather than guessed, same "don't fabricate"
      // rule as everywhere else in this app; the UI already hides the
      // review row whenever reviewScore is null.
      reviewScore: null,
      reviewCount: null,
      photoUrl: photoUrl,
      cheapestTotalAmount: _rgNum(price['lowestPrice']) ?? 0,
      cheapestCurrency: _rgString(price['currency']) ?? '',
      checkInDate: checkIn,
      checkOutDate: checkOut,
    );
  }

  /// [fromRollingGo] reads every field through these helpers rather than
  /// a hard `as` cast — accepting whichever of the plausible JSON types
  /// (a number sent as a JSON number vs. as a numeric string, same
  /// inconsistency Duffel itself has between its own endpoints) shows
  /// up, instead of throwing and losing that whole search result over
  /// one unexpected type.
  static String? _rgString(dynamic v) => v is String && v.isNotEmpty ? v : null;
  static double? _rgNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Same idea as [_rgString], specifically for an id field — RollingGo's
  /// own published example has `hotelId` as a JSON *number* (`43615`),
  /// not a string, so [_rgString] alone would silently return null and
  /// leave [searchResultId]/[accommodationId] empty for every real
  /// result (breaking save/detail navigation/caching, anything keyed on
  /// that id) — caught by a fresh-eyes review before this ever shipped.
  static String? _rgId(dynamic v) {
    if (v is String && v.isNotEmpty) return v;
    if (v is num) return v.toString();
    return null;
  }
}

/// Thrown by [DuffelApiService] on a non-2xx response or a request that
/// couldn't be made at all (network error, timeout).
class DuffelApiException implements Exception {
  final String message;
  const DuffelApiException(this.message);
  @override
  String toString() => message;
}
