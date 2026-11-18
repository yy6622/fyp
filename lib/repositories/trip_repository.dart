import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_details.dart';
import '../models/day_plan_models.dart';
import 'notifications_repository.dart';

class InviteCodeInvalid implements Exception {}

class InviteTripNotFound implements Exception {}

const Map<String, IconData> activityIcons = {
  'flight': Icons.flight_land,
  'hotel': Icons.hotel_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'food': Icons.restaurant_outlined,
  'place': Icons.place_outlined,
  'activity': Icons.local_activity_outlined,
};

String iconKeyFor(IconData icon) {
  for (final e in activityIcons.entries) {
    if (e.value == icon) return e.key;
  }
  return 'activity';
}

IconData iconForKey(String key) => activityIcons[key] ?? Icons.local_activity_outlined;

class TripFlight {
  final String id;
  final String airline, flightNumber, routeCode, routeCities, dateTime, terminal, bookingRef, status;
  final String arrivalTime;
  final String departureAtIso;
  final String arrivalAtIso;
  final List<String> passengers;
  final List<PassengerDetail> passengerDetails;
  final String contactEmail;
  final String contactPhone;
  final Map<String, String> documents;
  final List<String> forMemberUids;
  const TripFlight({
    this.id = '',
    required this.airline,
    required this.flightNumber,
    required this.routeCode,
    required this.routeCities,
    required this.dateTime,
    required this.terminal,
    required this.bookingRef,
    required this.status,
    this.passengers = const [],
    this.passengerDetails = const [],
    this.contactEmail = '',
    this.contactPhone = '',
    this.documents = const {},
    this.forMemberUids = const [],
    this.arrivalTime = '',
    this.departureAtIso = '',
    this.arrivalAtIso = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'airline': airline,
        'flightNumber': flightNumber,
        'routeCode': routeCode,
        'routeCities': routeCities,
        'dateTime': dateTime,
        'arrivalTime': arrivalTime,
        'departureAtIso': departureAtIso,
        'arrivalAtIso': arrivalAtIso,
        'terminal': terminal,
        'bookingRef': bookingRef,
        'status': status,
        'passengers': passengers,
        'passengerDetails': passengerDetails.map((p) => p.toMap()).toList(),
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'documents': documents,
        'forMemberUids': forMemberUids,
      };

  factory TripFlight.fromMap(Map<String, dynamic> m) => TripFlight(
        id: (m['id'] as String?) ?? '',
        airline: (m['airline'] as String?) ?? '',
        flightNumber: (m['flightNumber'] as String?) ?? '',
        routeCode: (m['routeCode'] as String?) ?? '',
        routeCities: (m['routeCities'] as String?) ?? '',
        dateTime: (m['dateTime'] as String?) ?? '',
        departureAtIso: (m['departureAtIso'] as String?) ?? '',
        arrivalAtIso: (m['arrivalAtIso'] as String?) ?? '',
        arrivalTime: (m['arrivalTime'] as String?) ?? '',
        terminal: (m['terminal'] as String?) ?? '',
        bookingRef: (m['bookingRef'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'Confirmed',
        passengers: ((m['passengers'] as List?) ?? const []).map((e) => '$e').toList(),
        passengerDetails: ((m['passengerDetails'] as List?) ?? const [])
            .map((e) => PassengerDetail.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        contactEmail: (m['contactEmail'] as String?) ?? '',
        contactPhone: (m['contactPhone'] as String?) ?? '',
        documents: Map<String, String>.from((m['documents'] as Map?) ?? const {}),
        forMemberUids: ((m['forMemberUids'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

class TripHotelStay {
  final String id;
  final String name, location, checkIn, checkOut;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  final String bookingRef;
  final String status;
  final String refId;
  final Map<String, String> documents;
  final List<String> forMemberUids;
  const TripHotelStay({
    this.id = '',
    required this.name,
    required this.location,
    required this.checkIn,
    required this.checkOut,
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.specialRequests = '',
    this.bookingRef = '',
    this.status = 'Confirmed',
    this.refId = '',
    this.documents = const {},
    this.forMemberUids = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'guestName': guestName,
        'guestEmail': guestEmail,
        'guestPhone': guestPhone,
        'guestIdNumber': guestIdNumber,
        'specialRequests': specialRequests,
        'bookingRef': bookingRef,
        'status': status,
        'refId': refId,
        'documents': documents,
        'forMemberUids': forMemberUids,
      };

  factory TripHotelStay.fromMap(Map<String, dynamic> m) => TripHotelStay(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        location: (m['location'] as String?) ?? '',
        checkIn: (m['checkIn'] as String?) ?? '',
        checkOut: (m['checkOut'] as String?) ?? '',
        guestName: (m['guestName'] as String?) ?? '',
        guestEmail: (m['guestEmail'] as String?) ?? '',
        guestPhone: (m['guestPhone'] as String?) ?? '',
        guestIdNumber: (m['guestIdNumber'] as String?) ?? '',
        specialRequests: (m['specialRequests'] as String?) ?? '',
        bookingRef: (m['bookingRef'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'Confirmed',
        refId: (m['refId'] as String?) ?? '',
        documents: Map<String, String>.from((m['documents'] as Map?) ?? const {}),
        forMemberUids: ((m['forMemberUids'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

class TripInsurance {
  final String planName;
  final String coverage;
  final String price;
  final String policyNumber;
  final String transactionId;
  final String travellerName;
  final String bookingId;
  final DateTime? purchasedAt;
  final String partnerId;
  final String providerName;
  final DateTime? travelStart;
  final DateTime? travelEnd;
  final String travellerIdNumber;
  final String travellerEmail;
  final String travellerPhone;
  const TripInsurance({
    required this.planName,
    required this.coverage,
    required this.price,
    required this.policyNumber,
    this.transactionId = '',
    this.travellerName = '',
    this.bookingId = '',
    this.purchasedAt,
    this.partnerId = '',
    this.providerName = '',
    this.travelStart,
    this.travelEnd,
    this.travellerIdNumber = '',
    this.travellerEmail = '',
    this.travellerPhone = '',
  });

  Map<String, dynamic> toMap() => {
        'planName': planName,
        'coverage': coverage,
        'price': price,
        'policyNumber': policyNumber,
        'transactionId': transactionId,
        'travellerName': travellerName,
        'bookingId': bookingId,
        if (purchasedAt != null) 'purchasedAt': Timestamp.fromDate(purchasedAt!),
        if (partnerId.isNotEmpty) 'partnerId': partnerId,
        if (providerName.isNotEmpty) 'providerName': providerName,
        if (travelStart != null) 'travelStart': Timestamp.fromDate(travelStart!),
        if (travelEnd != null) 'travelEnd': Timestamp.fromDate(travelEnd!),
        if (travellerIdNumber.isNotEmpty) 'travellerIdNumber': travellerIdNumber,
        if (travellerEmail.isNotEmpty) 'travellerEmail': travellerEmail,
        if (travellerPhone.isNotEmpty) 'travellerPhone': travellerPhone,
      };

  factory TripInsurance.fromMap(Map<String, dynamic> m) => TripInsurance(
        planName: (m['planName'] as String?) ?? '',
        coverage: (m['coverage'] as String?) ?? '',
        price: (m['price'] as String?) ?? '',
        policyNumber: (m['policyNumber'] as String?) ?? '',
        transactionId: (m['transactionId'] as String?) ?? '',
        travellerName: (m['travellerName'] as String?) ?? '',
        bookingId: (m['bookingId'] as String?) ?? '',
        purchasedAt: (m['purchasedAt'] as Timestamp?)?.toDate(),
        partnerId: (m['partnerId'] as String?) ?? '',
        providerName: (m['providerName'] as String?) ?? '',
        travelStart: (m['travelStart'] as Timestamp?)?.toDate(),
        travelEnd: (m['travelEnd'] as Timestamp?)?.toDate(),
        travellerIdNumber: (m['travellerIdNumber'] as String?) ?? '',
        travellerEmail: (m['travellerEmail'] as String?) ?? '',
        travellerPhone: (m['travellerPhone'] as String?) ?? '',
      );
}

class Trip {
  final String id;
  final String name;
  final String destination;
  final String coverImage;
  final DateTime? startDate;
  final DateTime? endDate;
  final double budgetPerPerson;
  final List<String> interests;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String about;
  final bool realTimeLocation;
  final Map<String, String> notificationOption;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final DateTime? planUpdatedAt;
  final Map<String, DateTime> planSeenAt;
  final DateTime? expensesUpdatedAt;
  final Map<String, DateTime> expensesSeenAt;
  final Map<String, int> unreadCounts;
  final List<DayPlan> days;
  final List<TripFlight> flights;
  final List<TripHotelStay> hotelStays;
  final TripInsurance? insurance;

  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.coverImage,
    required this.startDate,
    required this.endDate,
    required this.budgetPerPerson,
    required this.interests,
    required this.ownerId,
    required this.memberIds,
    required this.memberNames,
    required this.about,
    required this.realTimeLocation,
    this.notificationOption = const {},
    required this.createdAt,
    this.lastActivityAt,
    this.planUpdatedAt,
    this.planSeenAt = const {},
    this.expensesUpdatedAt,
    this.expensesSeenAt = const {},
    this.unreadCounts = const {},
    required this.days,
    required this.flights,
    required this.hotelStays,
    this.insurance,
  });

  bool get isInactive {
    final end = endDate;
    if (end == null || !DateTime.now().isAfter(end.add(const Duration(days: 1)))) return false;
    final last = lastActivityAt ?? createdAt;
    if (last == null) return false;
    return DateTime.now().difference(last) > const Duration(days: 30);
  }

  /// True once the whole trip is over (today is after the last day) — live
  /// weather/traffic conditions stop being shown once this is true.
  bool get hasEnded {
    final end = endDate;
    if (end == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final endStart = DateTime(end.year, end.month, end.day);
    return todayStart.isAfter(endStart);
  }

  bool planUnseenFor(String uid) {
    final updated = planUpdatedAt;
    if (updated == null) return false;
    final seen = planSeenAt[uid];
    return seen == null || updated.isAfter(seen);
  }

  bool expensesUnseenFor(String uid) {
    final updated = expensesUpdatedAt;
    if (updated == null) return false;
    final seen = expensesSeenAt[uid];
    return seen == null || updated.isAfter(seen);
  }

  String notificationOptionFor(String uid) => notificationOption[uid] ?? 'All Messages';

  String get dateRangeLabel {
    if (startDate == null || endDate == null) return '';
    return '$dateOnlyLabel  ·  $nightsLabel';
  }

  String get dateOnlyLabel {
    if (startDate == null || endDate == null) return '';
    String fmt(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';
    return '${fmt(startDate!)} - ${fmt(endDate!)}';
  }

  String get nightsLabel {
    if (startDate == null || endDate == null) return '';
    final nights = endDate!.difference(startDate!).inDays;
    return '${nights + 1} days $nights night${nights == 1 ? '' : 's'}';
  }

  String get shortDateLabel {
    if (startDate == null) return '';
    return '${_month(startDate!.month)} ${startDate!.year}';
  }

  static String _month(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];

  static const _fullMonths = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  DateTime? dateForDay(int dayNumber) => startDate?.add(Duration(days: dayNumber - 1));

  String fullDateLabelForDay(int dayNumber) {
    final d = dateForDay(dayNumber);
    if (d == null) return '';
    return '${d.day} ${_fullMonths[d.month]} ${d.year}';
  }

  static Trip fromDoc(DocumentSnapshot<Map<String, dynamic>> doc, {required String myUid}) {
    final data = doc.data() ?? const {};
    final memberIds = List<String>.from(data['memberIds'] as List? ?? const []);
    final memberNames = Map<String, String>.from(
        (data['memberNames'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const {});
    Map<String, DateTime> timestampMap(dynamic raw) {
      final map = raw is Map ? raw : const {};
      final out = <String, DateTime>{};
      for (final entry in map.entries) {
        final v = entry.value;
        if (v is Timestamp) out[entry.key.toString()] = v.toDate();
      }
      return out;
    }
    final daysRaw = Map<String, dynamic>.from(data['days'] as Map? ?? const {});
    final dayKeys = daysRaw.keys.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    final days = dayKeys.map((key) {
      final d = Map<String, dynamic>.from(daysRaw[key] as Map);
      final itemsRaw = Map<String, dynamic>.from(d['items'] as Map? ?? const {});
      final itemIds = itemsRaw.keys.toList()..sort();
      final items = itemIds.map((itemId) {
        final it = Map<String, dynamic>.from(itemsRaw[itemId] as Map);
        final votedBy = List<String>.from(it['votedBy'] as List? ?? const []);
        return ActivityItem(
          id: itemId,
          time: (it['time'] as String?) ?? '',
          label: (it['label'] as String?) ?? '',
          location: (it['location'] as String?) ?? '',
          icon: iconForKey((it['icon'] as String?) ?? ''),
          voted: votedBy.length,
          total: memberIds.isEmpty ? 1 : memberIds.length,
          votedByMe: votedBy.contains(myUid),
          forMemberUids: List<String>.from(it['forMemberUids'] as List? ?? const []),
          sourceRef: (it['sourceRef'] as String?) ?? '',
        );
      }).toList()
        ..sort((a, b) {
          if (a.time.isEmpty != b.time.isEmpty) return a.time.isEmpty ? 1 : -1;
          final byTime = a.time.compareTo(b.time);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
      return DayPlan(
        day: (d['day'] as num?)?.toInt() ?? (int.tryParse(key) ?? 0) + 1,
        weekday: (d['weekday'] as String?) ?? '',
        date: (d['date'] as String?) ?? '',
        items: items,
      );
    }).toList();

    return Trip(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Trip',
      destination: (data['destination'] as String?) ?? '',
      coverImage: (data['coverImage'] as String?) ??
          'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800',
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      budgetPerPerson: (data['budgetPerPerson'] as num?)?.toDouble() ?? 0,
      interests: List<String>.from(data['interests'] as List? ?? const []),
      ownerId: (data['ownerId'] as String?) ?? '',
      memberIds: memberIds,
      memberNames: memberNames,
      about: (data['about'] as String?) ?? '',
      realTimeLocation: (data['realTimeLocation'] as bool?) ?? false,
      notificationOption: data['notificationOption'] is Map
          ? Map<String, String>.from((data['notificationOption'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
          : const {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp?)?.toDate(),
      planUpdatedAt: (data['planUpdatedAt'] as Timestamp?)?.toDate(),
      planSeenAt: timestampMap(data['planSeenAt']),
      expensesUpdatedAt: (data['expensesUpdatedAt'] as Timestamp?)?.toDate(),
      expensesSeenAt: timestampMap(data['expensesSeenAt']),
      unreadCounts: Map<String, int>.from(
        (data['unreadCounts'] as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
      ),
      days: days,
      flights: (data['flights'] as List? ?? const [])
          .map((f) => TripFlight.fromMap(Map<String, dynamic>.from(f as Map)))
          .toList(),
      hotelStays: (data['hotelStays'] as List? ?? const [])
          .map((h) => TripHotelStay.fromMap(Map<String, dynamic>.from(h as Map)))
          .toList(),
      insurance: data['insurance'] == null ? null : TripInsurance.fromMap(Map<String, dynamic>.from(data['insurance'] as Map)),
    );
  }
}

class VoteOption {
  final String id;
  final String label;
  final List<String> votedBy;
  const VoteOption({required this.id, required this.label, required this.votedBy});
}

class TripVote {
  final String id;
  final String title;
  final String createdBy;
  final bool allowAddOptions;
  final bool allowMultipleChoice;
  final List<VoteOption> options;
  final DateTime? createdAt;
  final DateTime? deadline;

  /// Set when the group settled a tie directly (see [TripRepository.decideVote])
  /// instead of it needing another single-choice ballot. Once set, this
  /// option is the decisive answer regardless of vote counts.
  final String? decidedOptionId;
  const TripVote({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.allowAddOptions,
    required this.allowMultipleChoice,
    required this.options,
    required this.createdAt,
    this.deadline,
    this.decidedOptionId,
  });

  bool get isClosed => deadline != null && DateTime.now().isAfter(deadline!);

  VoteOption? get decidedOption =>
      decidedOptionId == null ? null : _firstWhereOrNullOption(options, (o) => o.id == decidedOptionId);

  int get totalVoters => options.expand((o) => o.votedBy).toSet().length;

  List<String> get voterUids => options.expand((o) => o.votedBy).toSet().toList();

  VoteOption? get leading =>
      decidedOption ??
      (options.isEmpty ? null : (options.toList()..sort((a, b) => b.votedBy.length.compareTo(a.votedBy.length))).first);

  /// All options tied for the most votes (only meaningful once at least one
  /// vote has been cast — with zero votes every option "ties" at 0, which
  /// isn't a real tie, so callers should check [hasAnyVotes] first).
  List<VoteOption> get leaders {
    if (options.isEmpty) return const [];
    final top = options.map((o) => o.votedBy.length).reduce((a, b) => a > b ? a : b);
    return options.where((o) => o.votedBy.length == top).toList();
  }

  bool get hasAnyVotes => options.any((o) => o.votedBy.isNotEmpty);

  /// True when two or more options are tied for first place, after at least
  /// one vote has been cast.
  bool get isTie => decidedOptionId == null && hasAnyVotes && leaders.length > 1;

  static TripVote fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final optionsRaw = Map<String, dynamic>.from(data['options'] as Map? ?? const {});
    int creationMicros(String id) {
      final tail = id.split('_').last;
      return int.tryParse(tail) ?? 0;
    }

    final options = optionsRaw.entries
        .map((e) => VoteOption(
              id: e.key,
              label: (Map<String, dynamic>.from(e.value as Map)['label'] as String?) ?? '',
              votedBy: List<String>.from(Map<String, dynamic>.from(e.value as Map)['votedBy'] as List? ?? const []),
            ))
        .toList()
      ..sort((a, b) => creationMicros(a.id).compareTo(creationMicros(b.id)));
    return TripVote(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? '',
      allowAddOptions: (data['allowAddOptions'] as bool?) ?? true,
      allowMultipleChoice: (data['allowMultipleChoice'] as bool?) ?? false,
      options: options,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      decidedOptionId: data['decidedOptionId'] as String?,
    );
  }
}

VoteOption? _firstWhereOrNullOption(List<VoteOption> list, bool Function(VoteOption) test) {
  for (final item in list) {
    if (test(item)) return item;
  }
  return null;
}

class ExpenseParticipant {
  final String uid;
  final String name;
  final double share;
  final bool paid;
  const ExpenseParticipant({required this.uid, required this.name, required this.share, required this.paid});
}

class ExpenseLineItem {
  final String label;
  final double price;
  final List<String> assigneeUids;
  const ExpenseLineItem({required this.label, required this.price, required this.assigneeUids});
}

String expenseLabel(TripExpense e) {
  if (e.title.trim().isNotEmpty) return e.title.trim();
  if (e.note.trim().isNotEmpty) return e.note.trim();
  return e.category;
}

int _expenseToCents(double amount) => (amount * 100).round();
double _expenseFromCents(int cents) => cents / 100.0;

void _validateExpenseSplitInputs(double totalAmount, int memberCount) {
  if (totalAmount <= 0) {
    throw ArgumentError('totalAmount must be positive.');
  }
  if (memberCount < 1) {
    throw ArgumentError('At least one member must be selected.');
  }
}

Map<String, double> splitExpenseEqual(double totalAmount, List<String> memberUids) {
  _validateExpenseSplitInputs(totalAmount, memberUids.length);
  final totalCents = _expenseToCents(totalAmount);
  final n = memberUids.length;
  final baseShare = totalCents ~/ n;
  final remainder = totalCents % n;
  final shares = <String, double>{};
  for (var i = 0; i < n; i++) {
    final cents = baseShare + (i < remainder ? 1 : 0);
    shares[memberUids[i]] = _expenseFromCents(cents);
  }
  return shares;
}

Map<String, double> splitExpenseCustom(double totalAmount, Map<String, double> customShares) {
  _validateExpenseSplitInputs(totalAmount, customShares.length);
  final totalCents = _expenseToCents(totalAmount);
  var sumCents = 0;
  for (final entry in customShares.entries) {
    if (entry.value < 0) {
      throw ArgumentError('Custom share for ${entry.key} must be non-negative.');
    }
    sumCents += _expenseToCents(entry.value);
  }
  if (sumCents != totalCents) {
    throw ArgumentError(
      'Custom shares (${_expenseFromCents(sumCents)}) must sum to totalAmount (${_expenseFromCents(totalCents)}).',
    );
  }
  return Map.of(customShares);
}

Map<String, double> splitExpenseItemized(List<({double price, Set<String> assigneeUids})> items) {
  if (items.isEmpty) {
    throw ArgumentError('At least one item is required.');
  }
  if (items.any((item) => item.assigneeUids.isEmpty)) {
    throw ArgumentError('Every item must have at least one assignee.');
  }
  final totalsCents = <String, int>{};
  for (final item in items) {
    final uids = item.assigneeUids.toList();
    final itemCents = _expenseToCents(item.price);
    final n = uids.length;
    // A NEGATIVE itemCents (a voucher/loyalty discount split as its own
    // line -- see ReceiptOcrService.discount) breaks the usual
    // `~/` + `%` pairing: Dart's `%` is Euclidean (always 0 <= remainder
    // < n, whatever the dividend's sign), but `~/` truncates toward zero
    // rather than flooring, so for a negative dividend the two no longer
    // add back up to itemCents. Deriving baseShare FROM the (always
    // correct) remainder instead -- rather than from a separate `~/` that
    // can disagree with it -- keeps `baseShare*n + distributed remainder
    // == itemCents` true for a negative price exactly as it already was
    // for a positive one.
    final remainder = itemCents % n;
    final baseShare = (itemCents - remainder) ~/ n;
    for (var i = 0; i < n; i++) {
      final cents = baseShare + (i < remainder ? 1 : 0);
      totalsCents[uids[i]] = (totalsCents[uids[i]] ?? 0) + cents;
    }
  }
  return totalsCents.map((uid, cents) => MapEntry(uid, _expenseFromCents(cents)));
}

class TripExpense {
  final String id;
  final String tripId;
  final String tripName;
  final String title;
  final double amount;
  final String category;
  final String note;
  final String location;
  final String paidBy;
  final String paidByName;
  final DateTime? date;
  final List<ExpenseParticipant> participants;
  final String receiptImageUrl;
  final List<ExpenseLineItem> items;

  const TripExpense({
    required this.id,
    required this.tripId,
    required this.tripName,
    required this.title,
    required this.amount,
    required this.category,
    required this.note,
    required this.location,
    required this.paidBy,
    required this.paidByName,
    required this.date,
    required this.participants,
    this.receiptImageUrl = '',
    this.items = const [],
  });

  double shareFor(String uid) => participants.where((p) => p.uid == uid).fold(0.0, (s, p) => s + p.share);
  bool isSettled(String uid) => participants.where((p) => p.uid == uid).every((p) => p.paid);

  static TripExpense fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final participantsRaw = Map<String, dynamic>.from(data['participants'] as Map? ?? const {});
    final participants = participantsRaw.entries
        .map((e) {
          final v = Map<String, dynamic>.from(e.value as Map);
          return ExpenseParticipant(
            uid: e.key,
            name: (v['name'] as String?) ?? '',
            share: (v['share'] as num?)?.toDouble() ?? 0,
            paid: (v['paid'] as bool?) ?? false,
          );
        })
        .toList();
    return TripExpense(
      id: doc.id,
      tripId: (data['tripId'] as String?) ?? '',
      tripName: (data['tripName'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: (data['category'] as String?) ?? 'Other',
      note: (data['note'] as String?) ?? '',
      location: (data['location'] as String?) ?? '',
      paidBy: (data['paidBy'] as String?) ?? '',
      paidByName: (data['paidByName'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate(),
      participants: participants,
      receiptImageUrl: (data['receiptImageUrl'] as String?) ?? '',
      items: (data['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((e) => ExpenseLineItem(
                label: (e['label'] as String?) ?? '',
                price: (e['price'] as num?)?.toDouble() ?? 0,
                assigneeUids: List<String>.from(e['assigneeUids'] as List? ?? const []),
              ))
          .toList(),
    );
  }
}

class TripMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  final String type;
  final String imageUrl;
  final double? lat;
  final double? lng;

  const TripMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.type = 'text',
    this.imageUrl = '',
    this.lat,
    this.lng,
  });

  bool get isImage => type == 'image' && imageUrl.isNotEmpty;
  bool get isLocation => type == 'location' && lat != null && lng != null;

  static TripMessage fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return TripMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      type: (data['type'] as String?) ?? 'text',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
    );
  }
}

class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  CollectionReference<Map<String, dynamic>> get _trips => FirebaseFirestore.instance.collection('trips');
  CollectionReference<Map<String, dynamic>> _votes(String tripId) => _trips.doc(tripId).collection('votes');
  CollectionReference<Map<String, dynamic>> _expenses(String tripId) => _trips.doc(tripId).collection('expenses');
  CollectionReference<Map<String, dynamic>> _messages(String tripId) => _trips.doc(tripId).collection('messages');

  // ---------------- Trips ----------------
  Stream<List<Trip>> watchMyTrips(String uid) {
    return _trips.where('memberIds', arrayContains: uid).snapshots().map((snap) {
      final trips = snap.docs.map((d) => Trip.fromDoc(d, myUid: uid)).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return trips;
    });
  }

  Stream<Trip?> watchTrip(String tripId, String myUid) {
    return _trips.doc(tripId).snapshots().map((doc) => doc.exists ? Trip.fromDoc(doc, myUid: myUid) : null);
  }

  Future<Trip?> getTrip(String tripId, String myUid) async {
    final doc = await _trips.doc(tripId).get();
    return doc.exists ? Trip.fromDoc(doc, myUid: myUid) : null;
  }


  String inviteCodeFor(String tripId) => tripId;

  String parseInviteCode(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final slash = trimmed.lastIndexOf('/');
    trimmed = (slash == -1 ? trimmed : trimmed.substring(slash + 1)).trim();
    return trimmed.replaceAll(RegExp(r'[\s-]'), '');
  }

  Future<Trip> joinByInviteCode(String rawCode, {required String uid, required String name}) async {
    final tripId = parseInviteCode(rawCode);
    if (tripId.isEmpty) throw InviteCodeInvalid();
    final doc = _trips.doc(tripId);
    try {
      await doc.update({
        'memberIds': FieldValue.arrayUnion([uid]),
        'memberNames.$uid': name,
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        throw InviteTripNotFound();
      }
      rethrow;
    }
    final snap = await doc.get();
    if (!snap.exists) throw InviteTripNotFound();
    return Trip.fromDoc(snap, myUid: uid);
  }

  Future<String> createTrip({
    required String ownerId,
    required String ownerName,
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetPerPerson,
    required List<String> interests,
    Map<String, String> extraMembers = const {},
    String? coverImage,
    String? about,
  }) async {
    final nights = endDate.difference(startDate).inDays;
    final dayCount = (nights + 1).clamp(1, 60);
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = <String, dynamic>{};
    for (var i = 0; i < dayCount; i++) {
      final date = startDate.add(Duration(days: i));
      days['$i'] = {
        'day': i + 1,
        'weekday': weekdayNames[(date.weekday - 1) % 7],
        'date': '${date.day} ${Trip._month(date.month)}',
        'items': <String, dynamic>{},
      };
    }
    final memberNames = {ownerId: ownerName, ...extraMembers};
    final doc = await _trips.add({
      'name': name.isEmpty ? 'New Trip' : name,
      'destination': destination,
      'coverImage': (coverImage != null && coverImage.isNotEmpty)
          ? coverImage
          : 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800',
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'budgetPerPerson': budgetPerPerson,
      'interests': interests,
      'ownerId': ownerId,
      'memberIds': memberNames.keys.toList(),
      'memberNames': memberNames,
      'about': (about != null && about.trim().isNotEmpty) ? about.trim() : "Let's make amazing memories together!",
      'realTimeLocation': false,
      'notificationOption': <String, String>{},
      'flights': <Map<String, dynamic>>[],
      'hotelStays': <Map<String, dynamic>>[],
      'days': days,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  void setNotificationOptionFor(String tripId, String uid, String value) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'notificationOption.$uid': value}).catchError((_) {});
  }

  Future<void> updateSettings(
    String tripId, {
    String? name,
    String? about,
    bool? realTimeLocation,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? budgetPerPerson,
    List<String>? interests,
    String? coverImage,
    String? actorUid,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (about != null) data['about'] = about;
    if (coverImage != null) data['coverImage'] = coverImage;
    if (realTimeLocation != null) data['realTimeLocation'] = realTimeLocation;
    if (destination != null) data['destination'] = destination;
    if (startDate != null) data['startDate'] = Timestamp.fromDate(startDate);
    if (endDate != null) data['endDate'] = Timestamp.fromDate(endDate);
    if (budgetPerPerson != null) data['budgetPerPerson'] = budgetPerPerson;
    if (interests != null) data['interests'] = interests;
    if (data.isEmpty) return;
    final planFieldsChanged = <String>[
      if (name != null) 'the trip name',
      if (coverImage != null) 'the cover photo',
      if (destination != null) 'the destination',
      if (startDate != null || endDate != null) 'the dates',
      if (budgetPerPerson != null) 'the budget',
      if (interests != null) 'the interests',
    ];
    if (destination != null ||
        startDate != null ||
        endDate != null ||
        budgetPerPerson != null ||
        interests != null) {
      data['lastActivityAt'] = FieldValue.serverTimestamp();
    }
    await _trips.doc(tripId).update(data);
    if (actorUid != null && planFieldsChanged.isNotEmpty) {
      final summary = planFieldsChanged.length == 1
          ? planFieldsChanged.first
          : '${planFieldsChanged.sublist(0, planFieldsChanged.length - 1).join(', ')} and ${planFieldsChanged.last}';
      await _notifyMembers(
        tripId,
        actorUid,
        (actorName, _) => '$actorName updated $summary',
        type: 'trip_settings_updated',
      );
    }
  }

  Future<void> addMembers(String tripId, Map<String, String> uidToName, {String? actorUid}) async {
    if (uidToName.isEmpty) return;
    final data = <String, dynamic>{
      'memberIds': FieldValue.arrayUnion(uidToName.keys.toList()),
    };
    for (final e in uidToName.entries) {
      data['memberNames.${e.key}'] = e.value;
    }
    await _trips.doc(tripId).update(data);
    if (actorUid == null) return;
    try {
      final snap = await _trips.doc(tripId).get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final tripName = (d['name'] as String?) ?? 'the trip';
      final names = Map<String, dynamic>.from((d['memberNames'] as Map?) ?? const {});
      final actorName = (names[actorUid] as String?) ?? 'Someone';
      final memberIds = List<String>.from((d['memberIds'] as List?) ?? const []);
      final joinedNames = uidToName.values.join(', ');
      for (final uid in memberIds) {
        if (uid == actorUid) continue;
        final isNewcomer = uidToName.containsKey(uid);
        await NotificationsRepository.instance.send(
          toUid: uid,
          type: 'trip_member_added',
          title: tripName,
          body: isNewcomer ? '$actorName added you to the trip "$tripName"' : '$actorName added $joinedNames to the trip',
          data: {'tripId': tripId},
        );
      }
    } catch (_) {
    }
  }

  Future<void> removeMember(String tripId, String uid, {String? actorUid}) async {
    var removedName = 'A member';
    if (actorUid != null) {
      final snap = await _trips.doc(tripId).get();
      final names = Map<String, dynamic>.from((snap.data()?['memberNames'] as Map?) ?? const {});
      removedName = (names[uid] as String?) ?? removedName;
    }
    await _trips.doc(tripId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'memberNames.$uid': FieldValue.delete(),
    });
    if (actorUid != null) {
      await _notifyMembers(tripId, actorUid, (_, __) => '$removedName was removed from the trip', type: 'trip_member_removed');
    }
  }

  Future<void> leaveTrip(String tripId, String uid) async {
    final snap = await _trips.doc(tripId).get();
    final names = Map<String, dynamic>.from((snap.data()?['memberNames'] as Map?) ?? const {});
    final leavingName = (names[uid] as String?) ?? 'A member';
    await _trips.doc(tripId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'memberNames.$uid': FieldValue.delete(),
    });
    await _notifyMembers(tripId, uid, (_, __) => '$leavingName left the trip', type: 'trip_member_left');
  }

  Future<void> deleteTrip(String tripId, String ownerUid) async {
    final snap = await _trips.doc(tripId).get();
    if (!snap.exists) return;
    if ((snap.data()?['ownerId'] as String?) != ownerUid) {
      throw Exception('Only the trip owner can delete this group.');
    }
    for (final sub in [_votes(tripId), _expenses(tripId), _messages(tripId)]) {
      final docs = await sub.get();
      for (var i = 0; i < docs.docs.length; i += 450) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in docs.docs.skip(i).take(450)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _trips.doc(tripId).delete();
  }

  Future<void> addActivity(
    String tripId,
    int dayIndex, {
    required String time,
    required String label,
    required String iconKey,
    String location = '',
    List<String> forMemberUids = const [],
    String sourceRef = '',
    String? actorUid,
  }) async {
    final itemId = '${DateTime.now().microsecondsSinceEpoch}';
    await _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId': {
        'time': time,
        'label': label,
        'icon': iconKey,
        'location': location,
        'votedBy': <String>[],
        'forMemberUids': forMemberUids,
        if (sourceRef.isNotEmpty) 'sourceRef': sourceRef,
      },
      'lastActivityAt': FieldValue.serverTimestamp(),
      ..._planUpdateFields(actorUid: actorUid),
    });
    if (actorUid != null) {
      await _notifyMembers(
        tripId,
        actorUid,
        (name, _) => '$name added "$label" to Day ${dayIndex + 1}',
        type: 'trip_activity_added',
        data: {'dayIndex': dayIndex},
      );
    }
  }

  Future<void> removeActivity(String tripId, int dayIndex, String itemId, {String? actorUid}) async {
    await _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId': FieldValue.delete(),
      'lastActivityAt': FieldValue.serverTimestamp(),
      ..._planUpdateFields(actorUid: actorUid),
    });
    if (actorUid != null) {
      await _notifyMembers(
        tripId,
        actorUid,
        (name, _) => '$name removed an activity from Day ${dayIndex + 1}',
        type: 'trip_activity_removed',
        data: {'dayIndex': dayIndex},
      );
    }
  }

  Future<void> updateActivityTime(String tripId, int dayIndex, String itemId, String time, {String? actorUid}) {
    return _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId.time': time,
      'lastActivityAt': FieldValue.serverTimestamp(),
      ..._planUpdateFields(actorUid: actorUid),
    });
  }

  Future<void> moveActivityToDay(
    String tripId,
    int fromDayIndex,
    String itemId,
    int toDayIndex,
    String time, {
    String? actorUid,
  }) async {
    if (fromDayIndex == toDayIndex) {
      await updateActivityTime(tripId, fromDayIndex, itemId, time, actorUid: actorUid);
      return;
    }
    final docRef = _trips.doc(tripId);
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null) return;
    final days = Map<String, dynamic>.from(data['days'] as Map? ?? const {});
    final fromDay = Map<String, dynamic>.from(days['$fromDayIndex'] as Map? ?? const {});
    final items = Map<String, dynamic>.from(fromDay['items'] as Map? ?? const {});
    final raw = items[itemId];
    if (raw == null) return;
    final movedItem = Map<String, dynamic>.from(raw as Map)..['time'] = time;
    await docRef.update({
      'days.$fromDayIndex.items.$itemId': FieldValue.delete(),
      'days.$toDayIndex.items.$itemId': movedItem,
      'lastActivityAt': FieldValue.serverTimestamp(),
      ..._planUpdateFields(actorUid: actorUid),
    });
    if (actorUid != null) {
      await _notifyMembers(
        tripId,
        actorUid,
        (name, _) => '$name moved "${movedItem['label'] ?? 'an activity'}" to Day ${toDayIndex + 1}',
        type: 'trip_activity_moved',
        data: {'dayIndex': toDayIndex},
      );
    }
  }

  Future<void> toggleActivityVote(String tripId, int dayIndex, String itemId, String uid, bool voted) {
    return _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId.votedBy':
          voted ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addFlight(String tripId, TripFlight flight, {String? actorUid}) async {
    await _trips.doc(tripId).update({
      'flights': FieldValue.arrayUnion([flight.toMap()]),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    if (actorUid != null) {
      await _notifyMembers(
        tripId,
        actorUid,
        (name, _) => '$name added a flight (${flight.airline} ${flight.flightNumber}) to the trip',
        type: 'trip_flight_added',
      );
    }
  }

  Future<void> removeFlight(String tripId, String flightId) async {
    final snap = await _trips.doc(tripId).get();
    final flights = ((snap.data()?['flights'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => (m['id'] as String?) != flightId)
        .toList();
    await _trips.doc(tripId).update({'flights': flights, 'lastActivityAt': FieldValue.serverTimestamp()});
  }

  Future<void> setFlightDocument(String tripId, String flightId, String docType, String url) async {
    final snap = await _trips.doc(tripId).get();
    final flights = ((snap.data()?['flights'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final idx = flights.indexWhere((m) => (m['id'] as String?) == flightId);
    if (idx == -1) return;
    final docs = Map<String, dynamic>.from((flights[idx]['documents'] as Map?) ?? const {});
    docs[docType] = url;
    flights[idx] = {...flights[idx], 'documents': docs};
    await _trips.doc(tripId).update({'flights': flights, 'lastActivityAt': FieldValue.serverTimestamp()});
  }

  Future<void> addHotelStay(String tripId, TripHotelStay stay, {String? actorUid}) async {
    await _trips.doc(tripId).update({
      'hotelStays': FieldValue.arrayUnion([stay.toMap()]),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    if (actorUid != null) {
      await _notifyMembers(
        tripId,
        actorUid,
        (name, _) => '$name added a hotel stay (${stay.name}) to the trip',
        type: 'trip_hotel_added',
      );
    }
  }

  Future<void> setHotelDocument(String tripId, String stayId, String docType, String url) async {
    final snap = await _trips.doc(tripId).get();
    final stays = ((snap.data()?['hotelStays'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final idx = stays.indexWhere((m) => (m['id'] as String?) == stayId);
    if (idx == -1) return;
    final docs = Map<String, dynamic>.from((stays[idx]['documents'] as Map?) ?? const {});
    docs[docType] = url;
    stays[idx] = {...stays[idx], 'documents': docs};
    await _trips.doc(tripId).update({'hotelStays': stays, 'lastActivityAt': FieldValue.serverTimestamp()});
  }

  Future<void> removeHotelStay(String tripId, String stayId) async {
    final snap = await _trips.doc(tripId).get();
    final stays = ((snap.data()?['hotelStays'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => (m['id'] as String?) != stayId)
        .toList();
    await _trips.doc(tripId).update({'hotelStays': stays, 'lastActivityAt': FieldValue.serverTimestamp()});
  }

  Future<void> setInsurance(String tripId, TripInsurance insurance, {String? actorUid}) async {
    await _trips.doc(tripId).update({
      'insurance': insurance.toMap(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    if (actorUid != null) {
      await _notifyMembers(
        tripId,
        actorUid,
        (name, _) => '$name added trip insurance (${insurance.planName}) for the trip',
        type: 'trip_insurance_added',
      );
    }
  }

  Map<String, dynamic> _planUpdateFields({String? actorUid}) => {
        'planUpdatedAt': FieldValue.serverTimestamp(),
        if (actorUid != null && actorUid.isNotEmpty) 'planSeenAt.$actorUid': FieldValue.serverTimestamp(),
      };

  void _touchActivity(String tripId, {String? category, String? actorUid}) {
    final update = <String, dynamic>{'lastActivityAt': FieldValue.serverTimestamp()};
    if (category == 'expenses') {
      update['expensesUpdatedAt'] = FieldValue.serverTimestamp();
      if (actorUid != null && actorUid.isNotEmpty) {
        update['expensesSeenAt.$actorUid'] = FieldValue.serverTimestamp();
      }
    }
    _trips.doc(tripId).update(update).catchError((_) {});
  }

  void markPlanSeen(String tripId, String uid) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'planSeenAt.$uid': FieldValue.serverTimestamp()}).catchError((_) {});
  }

  void markExpensesSeen(String tripId, String uid) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'expensesSeenAt.$uid': FieldValue.serverTimestamp()}).catchError((_) {});
  }

  Future<void> _notifyMembers(
    String tripId,
    String actorUid,
    String Function(String actorName, String tripName) buildBody, {
    String type = 'trip_update',
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final snap = await _trips.doc(tripId).get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final memberIds = List<String>.from((d['memberIds'] as List?) ?? const []);
      final names = Map<String, dynamic>.from((d['memberNames'] as Map?) ?? const {});
      final tripName = (d['name'] as String?) ?? 'Your trip';
      final actorName = (names[actorUid] as String?) ?? 'Someone';
      final body = buildBody(actorName, tripName);
      for (final uid in memberIds) {
        if (uid == actorUid) continue;
        await NotificationsRepository.instance.send(
          toUid: uid,
          type: type,
          title: tripName,
          body: body,
          data: {'tripId': tripId, ...data},
        );
      }
    } catch (_) {
    }
  }

  // ---------------- Votes ----------------
  Stream<List<TripVote>> watchVotes(String tripId) {
    return _votes(tripId).orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map(TripVote.fromDoc).toList());
  }

  /// Returns the new poll's doc id, so callers (e.g. decide_now_sheet's
  /// "Vote" action) can remember which poll a discussion decision is
  /// waiting on and read its result back later.
  Future<String> createVote(
    String tripId, {
    required String title,
    required List<String> options,
    required bool allowAddOptions,
    required bool allowMultipleChoice,
    required String createdBy,
    DateTime? deadline,
  }) async {
    final optionsMap = <String, dynamic>{};
    for (var i = 0; i < options.length; i++) {
      optionsMap['opt${i}_${DateTime.now().microsecondsSinceEpoch}'] = {'label': options[i], 'votedBy': <String>[]};
    }
    _touchActivity(tripId);
    final ref = await _votes(tripId).add({
      'title': title,
      'createdBy': createdBy,
      'allowAddOptions': allowAddOptions,
      'allowMultipleChoice': allowMultipleChoice,
      'options': optionsMap,
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': deadline == null ? null : Timestamp.fromDate(deadline),
    });
    await _notifyMembers(
      tripId,
      createdBy,
      (name, _) => '$name started a new poll: "$title"',
      type: 'trip_poll_created',
    );
    return ref.id;
  }

  /// Live-reads a single poll by id, for a discussion decision that's
  /// waiting on it (see decide_now_sheet.dart's conflict check).
  Stream<TripVote?> watchVoteById(String tripId, String voteId) {
    return _votes(tripId).doc(voteId).snapshots().map((doc) => doc.exists ? TripVote.fromDoc(doc) : null);
  }

  /// Settles a tie directly, as a group decision -- NOT another ballot. Used
  /// by the AI Summarise sheet's tie-break buttons: the person tapping
  /// almost always already voted in this exact poll (that's often how the
  /// tie happened), so routing this through [castVote] would just hit its
  /// "you have already voted" guard. This bypasses per-member voting rules
  /// entirely and writes the decided option onto the vote doc, where
  /// [TripVote.leading]/[TripVote.isTie] (and the Cloud Function engine's
  /// own copy of this same rule) treat it as the decisive answer regardless
  /// of ballot counts. Any trip member may decide it, not just whoever is
  /// leading.
  Future<void> decideVote(String tripId, String voteId, String optionId, String uid) async {
    final voteRef = _votes(tripId).doc(voteId);
    final tripRef = _trips.doc(tripId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final tripSnap = await tx.get(tripRef);
      if (!voteSnap.exists) {
        throw StateError('This poll no longer exists.');
      }
      final live = TripVote.fromDoc(voteSnap);
      final memberIds = List<String>.from((tripSnap.data()?['memberIds'] as List?) ?? const []);
      if (!tripSnap.exists || !memberIds.contains(uid)) {
        throw StateError('You are not a member of this trip.');
      }
      if (!live.options.any((o) => o.id == optionId)) {
        throw StateError('That option no longer exists.');
      }
      tx.update(voteRef, {
        'decidedOptionId': optionId,
        'decidedBy': uid,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    });
    _touchActivity(tripId);
  }

  Future<void> castVote(String tripId, TripVote vote, String optionId, String uid) async {
    final tripRef = _trips.doc(tripId);
    final voteRef = _votes(tripId).doc(vote.id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final tripSnap = await tx.get(tripRef);
      // Step 3.
      if (!voteSnap.exists) {
        throw StateError('This poll no longer exists.');
      }
      final live = TripVote.fromDoc(voteSnap);
      if (live.isClosed) {
        throw StateError('This poll is closed.');
      }
      // Step 4.
      final memberIds = List<String>.from((tripSnap.data()?['memberIds'] as List?) ?? const []);
      if (!tripSnap.exists || !memberIds.contains(uid)) {
        throw StateError('You are not a member of this trip.');
      }
      // Step 5.
      VoteOption? option;
      for (final o in live.options) {
        if (o.id == optionId) {
          option = o;
          break;
        }
      }
      if (option == null) {
        throw StateError('That option no longer exists.');
      }
      // Step 6.
      final alreadyVotedThisOption = option.votedBy.contains(uid);
      if (alreadyVotedThisOption) {
        // Tapping your own already-picked option casts nothing new -- the
        // UI routes that tap to retractVote instead. Guard here too in
        // case of a stale/duplicate tap.
        throw StateError('You have already voted for this option.');
      }
      final updates = <String, dynamic>{
        'options.$optionId.votedBy': FieldValue.arrayUnion([uid]),
        'options.$optionId.voteCount': FieldValue.increment(1),
      };
      if (!live.allowMultipleChoice) {
        // Single-choice: casting a new pick switches the member's vote --
        // clear whatever other option(s) they'd picked before, atomically
        // with adding the new one, so they're never left double-counted.
        for (final o in live.options) {
          if (o.id != optionId && o.votedBy.contains(uid)) {
            updates['options.${o.id}.votedBy'] = FieldValue.arrayRemove([uid]);
            updates['options.${o.id}.voteCount'] = FieldValue.increment(-1);
          }
        }
      }
      tx.update(voteRef, updates);
    });
    _touchActivity(tripId);
  }

  Future<void> retractVote(String tripId, TripVote vote, String optionId, String uid) async {
    final voteRef = _votes(tripId).doc(vote.id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      if (!voteSnap.exists) {
        throw StateError('This poll no longer exists.');
      }
      final live = TripVote.fromDoc(voteSnap);
      if (live.isClosed) {
        throw StateError('This poll is closed.');
      }
      // Retracting your own vote is allowed for single-choice polls too
      // (tap your picked option again to clear it) -- only switching to a
      // DIFFERENT option goes through castVote's switch-in-place logic
      // above, since a poll can't be left with two simultaneous picks for
      // one member mid-transaction.
      VoteOption? option;
      for (final o in live.options) {
        if (o.id == optionId) {
          option = o;
          break;
        }
      }
      if (option == null) {
        throw StateError('That option no longer exists.');
      }
      if (!option.votedBy.contains(uid)) {
        throw StateError("You haven't voted for this option.");
      }
      tx.update(voteRef, {
        'options.$optionId.votedBy': FieldValue.arrayRemove([uid]),
        'options.$optionId.voteCount': FieldValue.increment(-1),
      });
    });
    _touchActivity(tripId);
  }

  Future<void> addVoteOption(String tripId, String voteId, String label) async {
    final optionId = 'opt_${DateTime.now().microsecondsSinceEpoch}';
    _touchActivity(tripId);
    await _votes(tripId).doc(voteId).update({
      'options.$optionId': {'label': label, 'votedBy': <String>[]},
    });
  }

  // ---------------- Expenses ----------------
  Stream<List<TripExpense>> watchExpenses(String tripId) {
    return _expenses(tripId).orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map(TripExpense.fromDoc).toList());
  }

  Stream<List<TripExpense>> watchMyExpenses(String uid) {
    return FirebaseFirestore.instance
        .collectionGroup('expenses')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(TripExpense.fromDoc).toList()
        ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      return list;
    });
  }

  Future<Map<String, double>> addExpense(
    String tripId, {
    required String tripName,
    required String title,
    required double amount,
    required String category,
    required String note,
    required String location,
    required String paidBy,
    required String paidByName,
    required List<ExpenseParticipant> participants,
    String receiptImageUrl = '',
    List<ExpenseLineItem> items = const [],
    bool sendReminder = false,
  }) async {
    _validateExpenseSplitInputs(amount, participants.length);
    final sumCents = participants.fold<int>(0, (n, p) => n + _expenseToCents(p.share));
    if (sumCents != _expenseToCents(amount)) {
      throw ArgumentError('Member shares (${_expenseFromCents(sumCents)}) must sum to amount ($amount).');
    }
    final participantsMap = <String, dynamic>{
      for (final p in participants) p.uid: {'name': p.name, 'share': p.share, 'paid': p.paid}
    };
    _touchActivity(tripId, category: 'expenses', actorUid: paidBy);
    final docRef = _expenses(tripId).doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, {
      'tripId': tripId,
      'tripName': tripName,
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      'location': location,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'date': FieldValue.serverTimestamp(),
      'participants': participantsMap,
      'participantIds': participants.map((p) => p.uid).toList(),
      'receiptImageUrl': receiptImageUrl,
      'items': items.map((i) => {'label': i.label, 'price': i.price, 'assigneeUids': i.assigneeUids}).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _notifyMembers(
      tripId,
      paidBy,
      (_, __) => '$paidByName added an expense: "${title.isNotEmpty ? title : category}" (RM${amount.toStringAsFixed(2)})',
      type: 'trip_expense_added',
    );
    if (sendReminder) {
      await sendPaymentReminder(tripId, docRef.id);
    }
    // Step 7: return memberShares.
    return {for (final p in participants) p.uid: p.share};
  }

  Future<int> sendPaymentReminder(String tripId, String expenseId) async {
    final snap = await _expenses(tripId).doc(expenseId).get();
    if (!snap.exists) return 0;
    final expense = TripExpense.fromDoc(snap);
    final unpaid = expense.participants.where((p) => !p.paid && p.uid != expense.paidBy).toList();
    for (final p in unpaid) {
      await NotificationsRepository.instance.send(
        toUid: p.uid,
        type: 'trip_expense_payment_reminder',
        title: 'Payment reminder',
        body: '${expense.paidByName} reminds you to pay your RM ${p.share.toStringAsFixed(2)} share for "${expenseLabel(expense)}".',
        data: {'tripId': tripId, 'expenseId': expenseId},
      );
    }
    return unpaid.length;
  }

  ExpenseParticipant? _findParticipant(List<ExpenseParticipant> list, String uid) {
    for (final p in list) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  /// [items] is only non-null when the owner edited the itemized
  /// breakdown itself (label/price, or reassigning an item to a
  /// different member) -- see transaction_detail_page.dart's items
  /// editor. [memberNames] is used to name a participant this edit
  /// introduces for the first time (reassigned onto someone who wasn't
  /// previously split into this expense at all); existing participants
  /// keep their own recorded name and paid status.
  Future<void> updateExpense(
    TripExpense expense, {
    required String title,
    required double amount,
    required String category,
    required String note,
    String? receiptImageUrl,
    List<ExpenseLineItem>? items,
    Map<String, String> memberNames = const {},
  }) {
    final ps = expense.participants;
    final itemsChanged = items != null;
    if (itemsChanged && (items.isEmpty || items.any((i) => i.assigneeUids.isEmpty))) {
      throw ArgumentError('Every item must have at least one assignee.');
    }
    if ((amount - expense.amount).abs() > 0.001 && ps.any((p) => p.paid && p.uid != expense.paidBy)) {
      throw StateError('The amount can\'t change after someone has paid their share.');
    }
    if (itemsChanged && ps.any((p) => p.paid && p.uid != expense.paidBy)) {
      throw StateError("Items can't be changed after someone has paid their share.");
    }

    Map<String, dynamic> participantsUpdate = const {};
    if (itemsChanged) {
      final newShares = splitExpenseItemized([for (final i in items) (price: i.price, assigneeUids: i.assigneeUids.toSet())]);
      participantsUpdate = {
        for (final entry in newShares.entries)
          entry.key: {
            'name': _findParticipant(ps, entry.key)?.name ?? memberNames[entry.key] ?? 'Member',
            'share': entry.value,
            'paid': _findParticipant(ps, entry.key)?.paid ?? (entry.key == expense.paidBy),
          },
      };
    } else if ((amount - expense.amount).abs() > 0.001) {
      final equal = ps.isNotEmpty && ps.every((p) => (p.share - ps.first.share).abs() < 0.011);
      Map<String, double> newShares;
      if (ps.isEmpty) {
        newShares = const {};
      } else if (equal || expense.amount <= 0) {
        newShares = splitExpenseEqual(amount, ps.map((p) => p.uid).toList());
      } else {
        final totalCents = _expenseToCents(amount);
        final oldTotalCents = _expenseToCents(expense.amount);
        final raw = <String, double>{
          for (final p in ps) p.uid: _expenseToCents(p.share) * totalCents / oldTotalCents,
        };
        final floors = raw.map((uid, v) => MapEntry(uid, v.floor()));
        final used = floors.values.fold<int>(0, (n, v) => n + v);
        final remainder = totalCents - used;
        final byFraction = ps.map((p) => p.uid).toList()
          ..sort((a, b) => (raw[b]! - floors[b]!).compareTo(raw[a]! - floors[a]!));
        final cents = Map.of(floors);
        for (var i = 0; i < remainder && i < byFraction.length; i++) {
          cents[byFraction[i]] = cents[byFraction[i]]! + 1;
        }
        newShares = cents.map((uid, c) => MapEntry(uid, _expenseFromCents(c)));
      }
      participantsUpdate = {
        for (final p in ps) p.uid: {'name': p.name, 'share': newShares[p.uid] ?? 0, 'paid': p.paid},
      };
    }

    _touchActivity(expense.tripId, category: 'expenses', actorUid: expense.paidBy);
    return _expenses(expense.tripId).doc(expense.id).update({
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      if (receiptImageUrl != null) 'receiptImageUrl': receiptImageUrl,
      if (itemsChanged)
        'items': items.map((i) => {'label': i.label, 'price': i.price, 'assigneeUids': i.assigneeUids}).toList(),
      if (participantsUpdate.isNotEmpty) 'participants': participantsUpdate,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setParticipantPaid(String tripId, String expenseId, String uid, bool paid) {
    _touchActivity(tripId, category: 'expenses', actorUid: uid);
    return _expenses(tripId).doc(expenseId).update({'participants.$uid.paid': paid});
  }

  // Owner-only.
  Future<void> deleteExpense(String tripId, String expenseId, {required String actorUid}) async {
    final snap = await _expenses(tripId).doc(expenseId).get();
    if (!snap.exists) return;
    final expense = TripExpense.fromDoc(snap);
    if (expense.paidBy != actorUid) {
      throw StateError('Only the expense owner can delete this expense.');
    }
    _touchActivity(tripId, category: 'expenses', actorUid: actorUid);
    await _expenses(tripId).doc(expenseId).delete();
    await _notifyMembers(
      tripId,
      actorUid,
      (_, __) => '${expense.paidByName} deleted an expense: "${expenseLabel(expense)}" (RM${expense.amount.toStringAsFixed(2)})',
      type: 'trip_expense_deleted',
    );
  }

  // ---------------- Chat ----------------
  Stream<List<TripMessage>> watchMessages(String tripId) {
    return _messages(tripId).orderBy('createdAt').snapshots().map((snap) => snap.docs.map(TripMessage.fromDoc).toList());
  }

  Future<void> sendMessage(
    String tripId, {
    required String senderId,
    required String senderName,
    List<String> memberIds = const [],
    String text = '',
    String type = 'text',
    String imageUrl = '',
    double? lat,
    double? lng,
  }) async {
    _touchActivity(tripId);
    await _messages(tripId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type,
      if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final others = memberIds.where((uid) => uid != senderId && uid.isNotEmpty);
    if (others.isNotEmpty) {
      final update = <String, dynamic>{};
      for (final uid in others) {
        update['unreadCounts.$uid'] = FieldValue.increment(1);
      }
      _trips.doc(tripId).update(update).catchError((_) {});
    }
  }

  void markChatSeen(String tripId, String uid) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'unreadCounts.$uid': 0}).catchError((_) {});
  }

  Future<void> editMessage(String tripId, String messageId, String newText) {
    return _messages(tripId).doc(messageId).update({
      'text': newText,
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String tripId, String messageId) {
    return _messages(tripId).doc(messageId).delete();
  }
}
