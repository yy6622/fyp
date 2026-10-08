import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_details.dart';
import '../models/day_plan_models.dart';
import '../models/plan_page_models.dart';
import 'notifications_repository.dart';

/// Thrown by [TripRepository.joinByInviteCode] for a blank/unparseable
/// invite link or code.
class InviteCodeInvalid implements Exception {}

/// Thrown by [TripRepository.joinByInviteCode] when the code doesn't
/// match a real, joinable trip.
class InviteTripNotFound implements Exception {}

/// Maps a short string key (stored in Firestore, since [IconData] can't be)
/// to the icon shown for a trip activity.
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

/// One flight kept on a trip (`trips/{tripId}.flights`) — either typed in
/// by hand (Add Flight dialog) or added from a real Stripe purchase/saved
/// search result/booking history pick. [id] is a unique key (generated
/// once, when the entry is first added) so a single array element can be
/// found again later to remove it or attach a document to it — Firestore
/// arrays have no built-in per-item id, so this is ours.
class TripFlight {
  final String id;
  final String airline, flightNumber, routeCode, routeCities, dateTime, terminal, bookingRef, status;
  // The flight's real arrival date + time ("5 June 2026 14:35"), same
  // shape as [dateTime] (which is departure) — added so the AI
  // itinerary assistant (see functions/itinerary.js's LOGISTICS section)
  // can avoid suggesting anything on day 1 before the flight actually
  // lands, instead of guessing. Blank for a manually-typed flight, or
  // one booked before this existed.
  final String arrivalTime;
  // Passenger full names collected at checkout (BookingPaymentPage) — empty
  // for a manually-typed flight, which never went through a checkout step.
  // Kept alongside [passengerDetails] below (rather than derived from it)
  // so a manually-typed flight that only has bare names still displays
  // fine without needing a full PassengerDetail per name.
  final List<String> passengers;
  // The full real-world booking record per passenger (DOB, nationality,
  // passport number + expiry) collected on FlightPassengerDetailsPage —
  // empty for a manually-typed flight or any flight booked before this
  // was added.
  final List<PassengerDetail> passengerDetails;
  // Contact details for the whole booking, collected once alongside the
  // passengers above.
  final String contactEmail;
  final String contactPhone;
  // Uploaded travel documents for this flight — docType (e.g. 'E-Ticket')
  // -> real Firebase Storage download URL. Empty until someone actually
  // uploads one from PlanFlightDetailPage's Documents tab.
  final Map<String, String> documents;
  // Which of the trip's members this flight is actually for — picked on
  // FlightPassengerDetailsPage at checkout (see MemberSelectSection) when
  // the trip has more than one member, so a group trip's Plan shows who a
  // booking applies to instead of leaving it ambiguous whether it was for
  // the whole group or just whoever paid. Empty means "not set" (a solo
  // trip, or a flight added before this existed) — PlanFlightDetailPage
  // treats that the same as "everyone".
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
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'airline': airline,
        'flightNumber': flightNumber,
        'routeCode': routeCode,
        'routeCities': routeCities,
        'dateTime': dateTime,
        'arrivalTime': arrivalTime,
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

/// One hotel stay kept on a trip (`trips/{tripId}.hotelStays`) — see
/// [TripFlight]'s doc comment for why it carries an [id].
class TripHotelStay {
  final String id;
  final String name, location, checkIn, checkOut;
  // The name booked under, collected at checkout — blank for a
  // manually-typed stay (same idea as [TripFlight.passengers]).
  final String guestName;
  // The rest of the real-world guest record collected on
  // HotelGuestDetailsPage — blank for a manually-typed stay or any stay
  // booked before this was added.
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  // Added alongside Flight's equivalent fields so a Plan hotel stay can
  // show a real booking reference/status (rather than none at all) and
  // have a Documents tab (setHotelDocument) and a Review tab (refId) —
  // previously missing entirely, which is why PlanHotelDetailPage had no
  // Guests/Documents tabs the way PlanFlightDetailPage does.
  final String bookingRef;
  final String status;
  // The `catalog_hotels` doc id this stay was booked from — blank for a
  // manually-typed stay. Lets the Plan viewer show real reviews, same as
  // HistoryHotelDetailPage's hotelId.
  final String refId;
  // Uploaded documents for this stay — docType -> Firebase Storage URL
  // (see TripRepository.setHotelDocument), same idea as TripFlight.documents.
  final Map<String, String> documents;
  // Which of the trip's members this stay is for — see
  // [TripFlight.forMemberUids]'s doc comment, same idea here.
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

/// The travel insurance plan bought for a trip (`trips/{tripId}.insurance`)
/// — a single denormalized snapshot of the [InsurancePlan] + policy number
/// picked at purchase time, same idea as [TripFlight]/[TripHotelStay].
/// Null on [Trip] until someone actually buys a plan for this trip.
class TripInsurance {
  final String planName;
  final String coverage;
  final String price;
  final String policyNumber;
  const TripInsurance({
    required this.planName,
    required this.coverage,
    required this.price,
    required this.policyNumber,
  });

  Map<String, dynamic> toMap() => {
        'planName': planName,
        'coverage': coverage,
        'price': price,
        'policyNumber': policyNumber,
      };

  factory TripInsurance.fromMap(Map<String, dynamic> m) => TripInsurance(
        planName: (m['planName'] as String?) ?? '',
        coverage: (m['coverage'] as String?) ?? '',
        price: (m['price'] as String?) ?? '',
        policyNumber: (m['policyNumber'] as String?) ?? '',
      );
}

/// A group trip — `trips/{tripId}`. Backs the Plan / Group Trip / Group Info
/// / Group Setting screens.
class Trip {
  final String id;
  final String name;
  final String destination;
  final String coverImage;
  final DateTime? startDate;
  final DateTime? endDate;
  final double budgetPerPerson;
  final List<String> interests;
  /// The three extra "preferences" fields alongside budget/interests —
  /// edited together on [TravelPreferencesPage] (reached from Group
  /// Setting). Empty string means "not set yet", shown as a placeholder
  /// rather than a fake default.
  final String travelStyle;
  final String accommodation;
  final String foodPreference;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String about;
  final bool muteChat;
  final bool pinChat;
  final bool realTimeLocation;
  final String notificationOption;
  final DateTime? createdAt;
  /// When this trip last had real activity (a plan/day edit, a vote cast,
  /// an expense added, a chat message) — bumped by [TripRepository] at
  /// each of those write points. Falls back to [createdAt] in [fromDoc] so
  /// a trip written before this field existed still gets a sensible value
  /// instead of null. Used by the Plan tab to decide when a group has gone
  /// quiet long enough to fold into "Past Plans".
  final DateTime? lastActivityAt;
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
    this.travelStyle = '',
    this.accommodation = '',
    this.foodPreference = '',
    required this.ownerId,
    required this.memberIds,
    required this.memberNames,
    required this.about,
    required this.muteChat,
    required this.pinChat,
    required this.realTimeLocation,
    this.notificationOption = 'All Messages',
    required this.createdAt,
    this.lastActivityAt,
    required this.days,
    required this.flights,
    required this.hotelStays,
    this.insurance,
  });

  /// True once the trip's own dates are over AND more than 30 days have
  /// passed since [lastActivityAt] (or [createdAt] if that's somehow
  /// still null too) — i.e. the group has gone quiet long enough to fold
  /// into the Plan tab's "Past Plans" section. Both conditions matter: a
  /// trip that's still upcoming shouldn't fold away just because nobody's
  /// touched it in a month (it's not "past" yet, there's nothing to do
  /// until closer to the date), and a trip whose dates just ended but is
  /// still being actively wrapped up (settling expenses, chatting) should
  /// stay visible until that activity actually quiets down too.
  ///
  /// A trip with no [endDate] (shouldn't happen — every trip is created
  /// with one) or no activity timestamp at all is treated as NOT
  /// inactive, so a data gap never silently hides a trip from its own
  /// members.
  bool get isInactive {
    final end = endDate;
    // [endDate] is stored as a date-only midnight timestamp (see
    // create_plan_wizard.dart / nice_pickers.dart's date pickers), so
    // comparing against it directly would call the trip "over" the
    // instant its last day begins, while that day is still ongoing.
    // Comparing against the start of the NEXT day instead means the
    // trip only counts as past once its last day has fully elapsed.
    if (end == null || !DateTime.now().isAfter(end.add(const Duration(days: 1)))) return false;
    final last = lastActivityAt ?? createdAt;
    if (last == null) return false;
    return DateTime.now().difference(last) > const Duration(days: 30);
  }

  String get dateRangeLabel {
    if (startDate == null || endDate == null) return '';
    return '$dateOnlyLabel  ·  $nightsLabel';
  }

  /// Just the date-range half of [dateRangeLabel] — split out so a narrow
  /// card (see HomePage's "Your Next Adventure") can put the "X days Y
  /// nights" part on its own line instead of squeezing both onto one line
  /// and losing the nights count to the ellipsis.
  String get dateOnlyLabel {
    if (startDate == null || endDate == null) return '';
    String fmt(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';
    return '${fmt(startDate!)} - ${fmt(endDate!)}';
  }

  /// Just the "X days Y nights" half of [dateRangeLabel].
  String get nightsLabel {
    if (startDate == null || endDate == null) return '';
    final nights = endDate!.difference(startDate!).inDays;
    return '${nights + 1} days $nights night${nights == 1 ? '' : 's'}';
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

  /// The calendar date for day [dayNumber] (1-indexed, matching
  /// [DayPlan.day]), spelled out in full — e.g. "12 June 2026" — for the
  /// Day tab's header. Falls back to null when the trip has no start date
  /// yet (shouldn't normally happen once a trip is created).
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
        );
      }).toList();
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
      travelStyle: (data['travelStyle'] as String?) ?? '',
      accommodation: (data['accommodation'] as String?) ?? '',
      foodPreference: (data['foodPreference'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      memberIds: memberIds,
      memberNames: memberNames,
      about: (data['about'] as String?) ?? '',
      muteChat: (data['muteChat'] as bool?) ?? false,
      pinChat: (data['pinChat'] as bool?) ?? false,
      realTimeLocation: (data['realTimeLocation'] as bool?) ?? false,
      notificationOption: (data['notificationOption'] as String?) ?? 'All Messages',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp?)?.toDate(),
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

/// A single vote/poll attached to a trip — `trips/{tripId}/votes/{voteId}`.
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
  /// When this poll closes — optional (null means "open indefinitely",
  /// the original behaviour). Past this moment [VoteTab] stops accepting
  /// new taps on an option, same as every other deadline in this app
  /// (never enforced server-side; see firestore.rules' general
  /// member-trust model for trips).
  final DateTime? deadline;
  const TripVote({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.allowAddOptions,
    required this.allowMultipleChoice,
    required this.options,
    required this.createdAt,
    this.deadline,
  });

  bool get isClosed => deadline != null && DateTime.now().isAfter(deadline!);

  int get totalVoters => options.expand((o) => o.votedBy).toSet().length;

  VoteOption? get leading =>
      options.isEmpty ? null : (options.toList()..sort((a, b) => b.votedBy.length.compareTo(a.votedBy.length))).first;

  static TripVote fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final optionsRaw = Map<String, dynamic>.from(data['options'] as Map? ?? const {});
    final options = optionsRaw.entries
        .map((e) => VoteOption(
              id: e.key,
              label: (Map<String, dynamic>.from(e.value as Map)['label'] as String?) ?? '',
              votedBy: List<String>.from(Map<String, dynamic>.from(e.value as Map)['votedBy'] as List? ?? const []),
            ))
        .toList();
    return TripVote(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? '',
      allowAddOptions: (data['allowAddOptions'] as bool?) ?? true,
      allowMultipleChoice: (data['allowMultipleChoice'] as bool?) ?? false,
      options: options,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
    );
  }
}

/// One participant's share of a [TripExpense].
class ExpenseParticipant {
  final String uid;
  final String name;
  final double share;
  final bool paid;
  const ExpenseParticipant({required this.uid, required this.name, required this.share, required this.paid});
}

/// One shared expense — `trips/{tripId}/expenses/{expenseId}`.
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
  // Download URL of the receipt photo, when this expense was added via
  // "Upload Receipt" (see ReceiptService) — blank for a manually-entered
  // expense with no photo.
  final String receiptImageUrl;

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
    );
  }
}

/// One chat message — `trips/{tripId}/messages/{messageId}`.
class TripMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;
  const TripMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  static TripMessage fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return TripMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Reads/writes the `trips` collection and its `votes` / `expenses` /
/// `messages` subcollections.
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

  /// One-shot fetch of a single trip (unlike [watchTrip], no live stream) —
  /// for a spot where only the current value is needed once, such as
  /// pulling a trip's destination into an insurance purchase record (see
  /// PaymentMethodPage._confirmPayment).
  Future<Trip?> getTrip(String tripId, String myUid) async {
    final doc = await _trips.doc(tripId).get();
    return doc.exists ? Trip.fromDoc(doc, myUid: myUid) : null;
  }

  // ---------------- Join by invite code / QR ----------------
  // The invite code shown on Group Info (InviteQrPage, as both a QR
  // code and plain text) and fed back in here from Join → Enter code /
  // Scan QR code. It's just the trip's own Firestore doc id, shown
  // as-is — this used to be dressed up as a fake https://voya.app/join/...
  // link, but there's no real hosted route behind it (this app has no
  // domain to serve that from), so it read like a broken/dead link for
  // no benefit. A bare code is honest about what it actually is, and
  // [parseInviteCode] below still accepts the old link shape too, for
  // anything pasted from before this change.

  /// The shareable invite code for [tripId] — currently just the id
  /// itself; kept as its own method (rather than passing `tripId`
  /// straight to [InviteQrPage]) so the "what does an invite actually
  /// encode" decision stays in one place if that ever changes.
  String inviteCodeFor(String tripId) => tripId;

  /// Pulls a trip id back out of whatever the person typed, pasted, or a
  /// QR code decoded to — a bare [inviteCodeFor] code, the old
  /// `https://voya.app/join/<id>` link shape, or a code with spaces/
  /// dashes added purely for on-screen readability (see
  /// InviteQrPage._groupedForDisplay) that a person retyped by hand.
  String parseInviteCode(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final slash = trimmed.lastIndexOf('/');
    trimmed = (slash == -1 ? trimmed : trimmed.substring(slash + 1)).trim();
    return trimmed.replaceAll(RegExp(r'[\s-]'), '');
  }

  /// Joins [uid] to the trip [rawCode] points at, recording [name] as
  /// their `memberNames` entry. This is the one write a non-member is
  /// allowed to make on a trip doc (see firestore.rules' isSelfJoin()) —
  /// it can only ever add their own uid, nothing else about the trip.
  /// Already being a member (e.g. re-scanning your own trip's code) is a
  /// harmless no-op that still resolves normally.
  ///
  /// Throws [InviteCodeInvalid] for an empty/unparseable [rawCode], and
  /// [InviteTripNotFound] when it doesn't match a real, joinable trip —
  /// Firestore's security rules can't tell a non-existent trip id apart
  /// from one that exists but was rejected for some other reason, so
  /// both surface as the same FirebaseException here and get folded into
  /// one friendly "couldn't join" case for the UI.
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
      // A non-existent trip id and a rules-rejected write both surface
      // the same way here (Firestore can't tell them apart from the
      // client side — see isSelfJoin() in firestore.rules), so both mean
      // "not a real/joinable trip". Anything else (offline, a transient
      // 'unavailable'/'deadline-exceeded') is a different problem and
      // shouldn't be mislabeled as a bad invite — let the caller's
      // generic error handling take it instead.
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
    // The photo to show for this group — a real destination photo fetched
    // by the wizard (see PlacesApiService.destinationPhoto) when the user
    // didn't upload their own, or left null the one time that lookup also
    // comes up empty (offline, or a destination string Wikipedia has
    // nothing for), in which case the old generic travel-stock photo is
    // still better than a blank cover.
    String? coverImage,
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
      'about': "Let's make amazing memories together!",
      'muteChat': false,
      'pinChat': false,
      'realTimeLocation': false,
      'notificationOption': 'All Messages',
      'flights': <Map<String, dynamic>>[],
      'hotelStays': <Map<String, dynamic>>[],
      'days': days,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateSettings(
    String tripId, {
    String? name,
    String? about,
    bool? muteChat,
    bool? pinChat,
    bool? realTimeLocation,
    String? notificationOption,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? budgetPerPerson,
    List<String>? interests,
    String? travelStyle,
    String? accommodation,
    String? foodPreference,
    String? coverImage,
    // See [addActivity] — who's doing this, for [_notifyMembers]. Only
    // the shared-plan fields below (not muteChat/pinChat/realTimeLocation/
    // notificationOption, which are this device's own chat prefs even
    // though they're stored on the trip doc) ever trigger a notification,
    // so passing this is harmless even when only a chat pref changed.
    String? actorUid,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (about != null) data['about'] = about;
    if (coverImage != null) data['coverImage'] = coverImage;
    if (muteChat != null) data['muteChat'] = muteChat;
    if (pinChat != null) data['pinChat'] = pinChat;
    if (realTimeLocation != null) data['realTimeLocation'] = realTimeLocation;
    if (notificationOption != null) data['notificationOption'] = notificationOption;
    if (destination != null) data['destination'] = destination;
    if (startDate != null) data['startDate'] = Timestamp.fromDate(startDate);
    if (endDate != null) data['endDate'] = Timestamp.fromDate(endDate);
    if (budgetPerPerson != null) data['budgetPerPerson'] = budgetPerPerson;
    if (interests != null) data['interests'] = interests;
    if (travelStyle != null) data['travelStyle'] = travelStyle;
    if (accommodation != null) data['accommodation'] = accommodation;
    if (foodPreference != null) data['foodPreference'] = foodPreference;
    if (data.isEmpty) return;
    // Only the trip-detail edits (destination/dates/budget/preferences)
    // count as real "planning" activity for the Past Plans fold — muting
    // chat or renaming the group isn't the kind of activity that should
    // keep a quiet trip out of that fold. The same list of fields is what
    // other members get notified about below — a renamed group or a new
    // cover photo is shared/visible enough to count too, so those two are
    // folded into the notified set even though they skip lastActivityAt.
    final planFieldsChanged = <String>[
      if (name != null) 'the trip name',
      if (coverImage != null) 'the cover photo',
      if (destination != null) 'the destination',
      if (startDate != null || endDate != null) 'the dates',
      if (budgetPerPerson != null) 'the budget',
      if (interests != null) 'the interests',
      if (travelStyle != null) 'the travel style',
      if (accommodation != null) 'the accommodation preference',
      if (foodPreference != null) 'the food preference',
    ];
    if (destination != null ||
        startDate != null ||
        endDate != null ||
        budgetPerPerson != null ||
        interests != null ||
        travelStyle != null ||
        accommodation != null ||
        foodPreference != null) {
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
        // The newcomer(s) hear it framed as "you" rather than being lumped
        // into the generic "X added Y to the trip" everyone else gets.
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
      // See _notifyMembers' doc comment — never mask the real write.
    }
  }

  /// Removes a member from the trip. Used by the trip owner to remove
  /// someone else (call sites must check `uid == trip.ownerId` and that the
  /// target isn't the owner themselves before calling this — the repository
  /// layer doesn't re-derive ownership here). Logic mirrors [leaveTrip];
  /// kept as a separate, clearly-named method since "an owner removing
  /// someone else" and "a member leaving on their own" are different
  /// actions even though they touch the same fields.
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

  Future<void> addActivity(
    String tripId,
    int dayIndex, {
    required String time,
    required String label,
    required String iconKey,
    String location = '',
    // Which members this activity is for — see ActivityItem.forMemberUids.
    // Empty (the default) means "everyone", same as leaving it unset.
    List<String> forMemberUids = const [],
    // Who's doing this — passed through to [_notifyMembers] so every other
    // member hears about it. Null (the default) skips notifying, for
    // callers that don't have a signed-in actor to attribute it to.
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
      },
      'lastActivityAt': FieldValue.serverTimestamp(),
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

  /// Moves an existing activity to a new time only — label/location/icon/
  /// votes are untouched. [time] is 24-hour "HH:MM", same format
  /// [addActivity] stores. The drag-to-reschedule timeline in Day edit
  /// mode (see `day_timeline_view.dart`) is the only caller today; before
  /// it existed there was no way to change an activity's time short of
  /// deleting and re-adding it.
  Future<void> updateActivityTime(String tripId, int dayIndex, String itemId, String time) {
    return _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId.time': time,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
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

  /// Firestore arrays have no per-item update/remove by id — `flights` is
  /// one, so removing a single entry means reading the whole array,
  /// dropping the one whose [TripFlight.id] matches, and writing the
  /// whole array back. Same approach [setFlightDocument] below uses to
  /// attach a document to one entry.
  Future<void> removeFlight(String tripId, String flightId) async {
    final snap = await _trips.doc(tripId).get();
    final flights = ((snap.data()?['flights'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => (m['id'] as String?) != flightId)
        .toList();
    await _trips.doc(tripId).update({'flights': flights, 'lastActivityAt': FieldValue.serverTimestamp()});
  }

  /// Attaches (or replaces) one uploaded document's download URL on a
  /// specific flight already on this trip — see [TripFlight.documents].
  /// A no-op if [flightId] isn't found (e.g. the flight was removed from
  /// under the page that's still open).
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

  /// Attaches (or replaces) one uploaded document's download URL on a
  /// specific hotel stay already on this trip — see
  /// [TripHotelStay.documents]. Mirrors [setFlightDocument] exactly; a
  /// no-op if [stayId] isn't found.
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

  /// Same idea as [removeFlight], for `hotelStays`.
  Future<void> removeHotelStay(String tripId, String stayId) async {
    final snap = await _trips.doc(tripId).get();
    final stays = ((snap.data()?['hotelStays'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => (m['id'] as String?) != stayId)
        .toList();
    await _trips.doc(tripId).update({'hotelStays': stays, 'lastActivityAt': FieldValue.serverTimestamp()});
  }

  /// Records the insurance plan bought for this trip — a single field
  /// (unlike `flights`/`hotelStays`, which are lists), since a trip only
  /// ever shows one active policy at a time on the Overview tab.
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

  /// Bumps the trip's `lastActivityAt` — used by write methods that don't
  /// already touch the trip document directly (votes/expenses/messages
  /// live in subcollections). Fire-and-forget: this is UI-only metadata
  /// (drives "Past Plans" folding on the Plan tab), not worth failing or
  /// delaying the write that triggered it.
  void _touchActivity(String tripId) {
    // Genuinely fire-and-forget: swallow any failure (offline, permission
    // denied, doc deleted mid-flight) so it can never surface as an
    // unrelated error on top of the real write that triggered this.
    _trips.doc(tripId).update({'lastActivityAt': FieldValue.serverTimestamp()}).catchError((_) {});
  }

  /// Notifies every *other* member of [tripId] (everyone but [actorUid])
  /// that something changed on the shared plan — a new activity, flight,
  /// hotel stay, poll, expense, a settings edit, or a membership change.
  /// Re-reads the trip doc rather than trusting a [Trip] object a caller
  /// might be holding (it could be seconds stale), so the member list and
  /// the actor's display name are always current. [buildBody] gets the
  /// actor's resolved name and the trip's name so each call site can write
  /// its own message ("X added an activity to Day 2") without needing a
  /// second round-trip to look either up itself. Best-effort: a caller
  /// passes `actorUid: null` to opt out entirely (e.g. the trip-creation
  /// wizard, where there's nobody else to notify yet), and any failure
  /// here (offline, a member's inbox write denied, trip deleted mid-flight)
  /// is swallowed so it never surfaces as an error on top of the write that
  /// triggered it.
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
      // See doc comment — never let this mask the real write's result.
    }
  }

  // ---------------- Votes ----------------
  Stream<List<TripVote>> watchVotes(String tripId) {
    return _votes(tripId).orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map(TripVote.fromDoc).toList());
  }

  Future<void> createVote(
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
    await _votes(tripId).add({
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
  }

  /// Casts/withdraws [uid]'s vote for [optionId]. For a single-choice poll
  /// this also withdraws any vote they had on the poll's other options.
  Future<void> castVote(String tripId, TripVote vote, String optionId, String uid) async {
    if (vote.isClosed) return;
    final alreadyVoted = vote.options.firstWhere((o) => o.id == optionId).votedBy.contains(uid);
    final update = <String, dynamic>{};
    if (!vote.allowMultipleChoice) {
      for (final o in vote.options) {
        if (o.id != optionId && o.votedBy.contains(uid)) {
          update['options.${o.id}.votedBy'] = FieldValue.arrayRemove([uid]);
        }
      }
    }
    update['options.$optionId.votedBy'] = alreadyVoted ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]);
    _touchActivity(tripId);
    await _votes(tripId).doc(vote.id).update(update);
  }

  // ---------------- Expenses ----------------
  Stream<List<TripExpense>> watchExpenses(String tripId) {
    return _expenses(tripId).orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map(TripExpense.fromDoc).toList());
  }

  /// All expenses across every trip that [uid] participates in. NOT used by
  /// the Expenses tab's "Personal" view anymore — that view is intentionally
  /// scoped to one trip only (a trip's "Personal" expenses must not
  /// interconnect with any other trip's), and derives its list client-side
  /// from [watchExpenses] instead. Left here, unused, in case a future
  /// cross-trip "all my expenses" dashboard wants it. Uses a
  /// collection-group query, so a brand-new Firebase project may need to
  /// create the suggested index the first time this runs (Firestore's error
  /// message links straight to it).
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

  Future<void> addExpense(
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
  }) async {
    final participantsMap = <String, dynamic>{
      for (final p in participants) p.uid: {'name': p.name, 'share': p.share, 'paid': p.paid}
    };
    _touchActivity(tripId);
    await _expenses(tripId).add({
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
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _notifyMembers(
      tripId,
      paidBy,
      (_, __) => '$paidByName added an expense: "$title" (RM${amount.toStringAsFixed(2)})',
      type: 'trip_expense_added',
    );
  }

  Future<void> setParticipantPaid(String tripId, String expenseId, String uid, bool paid) {
    _touchActivity(tripId);
    return _expenses(tripId).doc(expenseId).update({'participants.$uid.paid': paid});
  }

  // ---------------- Chat ----------------
  Stream<List<TripMessage>> watchMessages(String tripId) {
    return _messages(tripId).orderBy('createdAt').snapshots().map((snap) => snap.docs.map(TripMessage.fromDoc).toList());
  }

  Future<void> sendMessage(String tripId, {required String senderId, required String senderName, required String text}) {
    _touchActivity(tripId);
    return _messages(tripId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
