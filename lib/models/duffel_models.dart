library;

class DuffelFlightOffer {
  final String id;
  final String airlineName;
  final String? airlineLogoUrl;
  final String flightNumber;
  final String originCode;
  final String destinationCode;
  final String? originCityName;
  final String? destinationCityName;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final int stops;
  final double totalAmount;
  final String totalCurrency;
  final String? aircraftName;
  final String? cabinClass;
  final String? originTerminal;
  final String? destinationTerminal;
  final int? checkedBagQuantity;
  final int? carryOnBagQuantity;
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
    String? iataOf(dynamic place) {
      if (place is String) return place;
      if (place is Map) return place['iata_code'] as String?;
      return null;
    }

    String? cityNameOf(dynamic place) {
      if (place is! Map) return null;
      final city = place['city_name'] as String?;
      if (city != null && city.isNotEmpty) return city;
      final name = place['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
      return null;
    }

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
  final List<String> amenities;
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
      reviewScore: null,
      reviewCount: null,
      photoUrl: photoUrl,
      cheapestTotalAmount: _rgNum(price['lowestPrice']) ?? 0,
      cheapestCurrency: _rgString(price['currency']) ?? '',
      checkInDate: checkIn,
      checkOutDate: checkOut,
      amenities: amenities,
      checkInPolicyTime: null,
      checkOutPolicyTime: null,
    );
  }

  static String? _rgString(dynamic v) => v is String && v.isNotEmpty ? v : null;
  static double? _rgNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String? _rgId(dynamic v) {
    if (v is String && v.isNotEmpty) return v;
    if (v is num) return v.toString();
    return null;
  }
}

class DuffelApiException implements Exception {
  final String message;
  const DuffelApiException(this.message);
  @override
  String toString() => message;
}
