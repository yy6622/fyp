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
  // Real city name for the origin/destination place Duffel returned
  // (`city_name`, falling back to the place's own `name` when Duffel
  // didn't send a separate city name) — null whenever neither was
  // present, same "don't fabricate" rule as the fields below; the
  // detail page falls back to the bare IATA code rather than ever
  // showing a fixed placeholder city.
  final String? originCityName;
  final String? destinationCityName;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final int stops;
  final double totalAmount;
  final String totalCurrency;
  // Real per-offer detail from Duffel's first segment/`conditions` block —
  // null/empty whenever Duffel's own response didn't have it, same
  // "don't fabricate" rule as DuffelStayResult.amenities. Detail page
  // hides each row rather than ever showing a fixed placeholder value.
  final String? aircraftName;
  final String? cabinClass;
  final String? originTerminal;
  final String? destinationTerminal;
  final int? checkedBagQuantity;
  final int? carryOnBagQuantity;
  // Duffel's conditions.change_before_departure / refund_before_departure
  // — `allowed` is nullable because Duffel itself sometimes doesn't know
  // (airline didn't return fare-rule data for this offer), which is a
  // real third state, not the same as "not allowed".
  final bool? changeAllowed;
  final String? changePenaltyAmount;
  final String? changePenaltyCurrency;
  final bool? refundAllowed;
  final String? refundPenaltyAmount;
  final String? refundPenaltyCurrency;

  const DuffelFlightOffer({
    required this.id,
    required this.airlineName,
    this.airlineLogoUrl,
    required this.flightNumber,
    required this.originCode,
    required this.destinationCode,
    this.originCityName,
    this.destinationCityName,
    required this.departureAt,
    required this.arrivalAt,
    required this.stops,
    required this.totalAmount,
    required this.totalCurrency,
    this.aircraftName,
    this.cabinClass,
    this.originTerminal,
    this.destinationTerminal,
    this.checkedBagQuantity,
    this.carryOnBagQuantity,
    this.changeAllowed,
    this.changePenaltyAmount,
    this.changePenaltyCurrency,
    this.refundAllowed,
    this.refundPenaltyAmount,
    this.refundPenaltyCurrency,
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

    // Same place object, but its human-readable city name — Duffel
    // sends `city_name` directly on airport places; `name` is the
    // fallback for place shapes that only carry a plain name. A bare
    // IATA-code string (no nested object) has no name to read, so this
    // returns null rather than inventing one.
    String? cityNameOf(dynamic place) {
      if (place is! Map) return null;
      final city = place['city_name'] as String?;
      if (city != null && city.isNotEmpty) return city;
      final name = place['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
      return null;
    }

    // Duffel puts per-passenger fare detail (cabin, baggage allowance) on
    // the segment under `passengers`, keyed by passenger id — the first
    // entry is enough for a single-traveller display; a real seatmap/
    // multi-passenger breakdown is out of scope here.
    final segPassengers = (firstSeg['passengers'] as List?) ?? const [];
    final segPassenger = segPassengers.isNotEmpty ? segPassengers.first as Map<String, dynamic> : <String, dynamic>{};
    final baggages = (segPassenger['baggages'] as List?) ?? const [];
    int? baggageQtyOf(String type) {
      for (final b in baggages) {
        if (b is Map && b['type'] == type) return (b['quantity'] as num?)?.toInt();
      }
      return null;
    }

    final aircraft = (firstSeg['aircraft'] as Map?)?.cast<String, dynamic>();
    final conditions = (json['conditions'] as Map?)?.cast<String, dynamic>() ?? const {};
    final changeCond = (conditions['change_before_departure'] as Map?)?.cast<String, dynamic>();
    final refundCond = (conditions['refund_before_departure'] as Map?)?.cast<String, dynamic>();

    String? cabinLabel() {
      final marketing = segPassenger['cabin_class_marketing_name'] as String?;
      if (marketing != null && marketing.isNotEmpty) return marketing;
      final raw = segPassenger['cabin_class'] as String?;
      if (raw == null || raw.isEmpty) return null;
      return raw[0].toUpperCase() + raw.substring(1).replaceAll('_', ' ');
    }

    return DuffelFlightOffer(
      id: (json['id'] as String?) ?? '',
      airlineName: (carrier['name'] as String?) ?? 'Unknown Airline',
      airlineLogoUrl: carrier['logo_symbol_url'] as String? ?? carrier['logo_lockup_url'] as String?,
      flightNumber: (firstSeg['marketing_carrier_flight_number'] as String?) ?? '',
      originCode: iataOf(firstSlice['origin']) ?? iataOf(firstSeg['origin']) ?? '',
      destinationCode: iataOf(firstSlice['destination']) ?? iataOf(lastSeg['destination']) ?? '',
      originCityName: cityNameOf(firstSlice['origin']) ?? cityNameOf(firstSeg['origin']),
      destinationCityName: cityNameOf(firstSlice['destination']) ?? cityNameOf(lastSeg['destination']),
      departureAt: parseDt(firstSeg['departing_at']),
      arrivalAt: parseDt(lastSeg['arriving_at']),
      stops: segments.isEmpty ? 0 : segments.length - 1,
      totalAmount: double.tryParse((json['total_amount'] as String?) ?? '') ?? 0,
      totalCurrency: (json['total_currency'] as String?) ?? '',
      aircraftName: aircraft?['name'] as String?,
      cabinClass: cabinLabel(),
      originTerminal: firstSeg['origin_terminal'] as String?,
      destinationTerminal: lastSeg['destination_terminal'] as String?,
      checkedBagQuantity: baggageQtyOf('checked'),
      carryOnBagQuantity: baggageQtyOf('carry_on'),
      changeAllowed: changeCond?['allowed'] as bool?,
      changePenaltyAmount: changeCond?['penalty_amount'] as String?,
      changePenaltyCurrency: changeCond?['penalty_currency'] as String?,
      refundAllowed: refundCond?['allowed'] as bool?,
      refundPenaltyAmount: refundCond?['penalty_amount'] as String?,
      refundPenaltyCurrency: refundCond?['penalty_currency'] as String?,
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
        'originCityName': originCityName,
        'destinationCityName': destinationCityName,
        'departureAt': departureAt.toIso8601String(),
        'arrivalAt': arrivalAt.toIso8601String(),
        'stops': stops,
        'totalAmount': totalAmount,
        'totalCurrency': totalCurrency,
        'aircraftName': aircraftName,
        'cabinClass': cabinClass,
        'originTerminal': originTerminal,
        'destinationTerminal': destinationTerminal,
        'checkedBagQuantity': checkedBagQuantity,
        'carryOnBagQuantity': carryOnBagQuantity,
        'changeAllowed': changeAllowed,
        'changePenaltyAmount': changePenaltyAmount,
        'changePenaltyCurrency': changePenaltyCurrency,
        'refundAllowed': refundAllowed,
        'refundPenaltyAmount': refundPenaltyAmount,
        'refundPenaltyCurrency': refundPenaltyCurrency,
      };

  factory DuffelFlightOffer.fromCacheMap(Map<String, dynamic> m) => DuffelFlightOffer(
        id: (m['id'] as String?) ?? '',
        airlineName: (m['airlineName'] as String?) ?? 'Unknown Airline',
        airlineLogoUrl: m['airlineLogoUrl'] as String?,
        flightNumber: (m['flightNumber'] as String?) ?? '',
        originCode: (m['originCode'] as String?) ?? '',
        destinationCode: (m['destinationCode'] as String?) ?? '',
        originCityName: m['originCityName'] as String?,
        destinationCityName: m['destinationCityName'] as String?,
        departureAt: DateTime.tryParse((m['departureAt'] as String?) ?? '') ?? DateTime.now(),
        arrivalAt: DateTime.tryParse((m['arrivalAt'] as String?) ?? '') ?? DateTime.now(),
        stops: (m['stops'] as num?)?.toInt() ?? 0,
        totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
        totalCurrency: (m['totalCurrency'] as String?) ?? '',
        aircraftName: m['aircraftName'] as String?,
        cabinClass: m['cabinClass'] as String?,
        originTerminal: m['originTerminal'] as String?,
        destinationTerminal: m['destinationTerminal'] as String?,
        checkedBagQuantity: (m['checkedBagQuantity'] as num?)?.toInt(),
        carryOnBagQuantity: (m['carryOnBagQuantity'] as num?)?.toInt(),
        changeAllowed: m['changeAllowed'] as bool?,
        changePenaltyAmount: m['changePenaltyAmount'] as String?,
        changePenaltyCurrency: m['changePenaltyCurrency'] as String?,
        refundAllowed: m['refundAllowed'] as bool?,
        refundPenaltyAmount: m['refundPenaltyAmount'] as String?,
        refundPenaltyCurrency: m['refundPenaltyCurrency'] as String?,
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
  /// Real per-hotel amenity names — Duffel's `accommodation.amenities`
  /// (each entry's `description`, falling back to `type`) or RollingGo's
  /// `hotelAmenities` (already plain strings). Empty when the source
  /// result just didn't have any, same "don't fabricate" rule as
  /// [reviewScore]/[reviewCount].
  final List<String> amenities;
  // The accommodation's own check-in/check-out policy times (e.g.
  // "3:00 PM") — Duffel's `accommodation.check_in_information` block,
  // read defensively across a few plausible key names since Duffel's
  // public docs don't pin the exact shape down (same caveat as this
  // file's other nested-field parsing). Not the stay's own dates
  // ([checkInDate]/[checkOutDate] above) — this is the hotel's
  // standing policy, the same for every booking. Null whenever Duffel
  // didn't send it, or for a RollingGo result (no equivalent field in
  // its documented response) — the detail page hides that row rather
  // than ever showing a fixed placeholder time. There is no real
  // cancellation-policy data available from either source at the
  // search stage (Duffel only returns that once you fetch a specific
  // rate/quote, which this app doesn't currently call), so there's no
  // field for it here — the detail page simply has no cancellation row.
  final String? checkInPolicyTime;
  final String? checkOutPolicyTime;

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
    this.amenities = const [],
    this.checkInPolicyTime,
    this.checkOutPolicyTime,
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

    // Duffel's check-in/check-out policy time, read defensively: the
    // nested block's own key name isn't confirmed against a live
    // response, so a few plausible candidates are tried, and a raw
    // "HH:mm[:ss]" value is reformatted to "3:00 PM"-style; anything
    // that doesn't parse as a time is shown exactly as Duffel sent it
    // rather than dropped.
    final checkInInfo = (accommodation['check_in_information'] as Map?)?.cast<String, dynamic>() ?? const {};
    String? formatPolicyTime(dynamic raw) {
      if (raw is! String || raw.isEmpty) return null;
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
      if (match == null) return raw;
      final hour24 = int.parse(match.group(1)!);
      final minute = match.group(2)!;
      final period = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      return '$hour12:$minute $period';
    }

    final checkInPolicyTime = formatPolicyTime(checkInInfo['check_in_after_time'] ??
        checkInInfo['check_in_from_time'] ??
        checkInInfo['check_in_time'] ??
        accommodation['check_in_time']);
    final checkOutPolicyTime = formatPolicyTime(checkInInfo['check_out_before_time'] ??
        checkInInfo['check_out_time'] ??
        accommodation['check_out_time']);

    // Duffel's accommodation.amenities is a list of {type, description}
    // objects (e.g. {"type": "wifi", "description": "WiFi"}) — prefer the
    // human-readable description, fall back to the type code, and drop
    // anything that ends up with neither rather than showing a blank chip.
    final amenitiesField = accommodation['amenities'];
    final amenities = <String>[];
    if (amenitiesField is List) {
      for (final entry in amenitiesField) {
        if (entry is Map) {
          final label = (entry['description'] as String?)?.trim();
          final type = (entry['type'] as String?)?.trim();
          final value = (label != null && label.isNotEmpty) ? label : type;
          if (value != null && value.isNotEmpty) amenities.add(value);
        } else if (entry is String && entry.trim().isNotEmpty) {
          amenities.add(entry.trim());
        }
      }
    }

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
      amenities: amenities,
      checkInPolicyTime: checkInPolicyTime,
      checkOutPolicyTime: checkOutPolicyTime,
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
        'amenities': amenities,
        'checkInPolicyTime': checkInPolicyTime,
        'checkOutPolicyTime': checkOutPolicyTime,
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
        amenities: List<String>.from(m['amenities'] as List? ?? const []),
        checkInPolicyTime: m['checkInPolicyTime'] as String?,
        checkOutPolicyTime: m['checkOutPolicyTime'] as String?,
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
    // RollingGo's searchHotels response carries `hotelAmenities` as a
    // sibling field on each hotel object, already a plain list of strings
    // (e.g. ["Bar", "Gym", "Pool", "SPA", "Parking", "WIFI"]) — no
    // {type, description} unwrapping needed the way Duffel's shape does.
    final amenitiesField = json['hotelAmenities'];
    final amenities = amenitiesField is List
        ? amenitiesField.map((e) => _rgString(e)).whereType<String>().toList()
        : <String>[];

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
      amenities: amenities,
      // RollingGo's documented searchHotels response has no check-in/
      // check-out policy time field — left null, same "don't fabricate"
      // rule as [reviewScore] above; the detail page hides those rows.
      checkInPolicyTime: null,
      checkOutPolicyTime: null,
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
