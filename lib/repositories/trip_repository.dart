import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_details.dart';
import '../models/day_plan_models.dart';
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
  // Real exact timestamps (DateTime.toIso8601String(), no forced UTC
  // conversion so this stays the destination's plain wall-clock time, same
  // "no timezone concept" convention as every other time in this app) —
  // only ever set when this flight was booked straight from a live Duffel
  // search result (see explore_page.dart's _flightDetailFor, which has the
  // real DateTime on hand; a flight added from Saved or typed in by hand
  // has no such DateTime, so these stay blank). [dateTime]/[arrivalTime]
  // above are display strings shown to a person (or pasted into the AI
  // prompt as text); these are what functions/logistics.js uses to do
  // actual time arithmetic (is this before/after that), which a free-text
  // display string can't be trusted to parse back out correctly.
  final String departureAtIso;
  final String arrivalAtIso;
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
  // Links back to the real `insurance_transactions` doc (the id
  // InsuranceRepository.recordPurchase returns) so Group Trip's insurance
  // card can open the same real Claim/Refund flow History's insurance
  // detail page does, against the actual purchase — empty for a trip
  // whose insurance was bought before this field existed.
  final String transactionId;
  const TripInsurance({
    required this.planName,
    required this.coverage,
    required this.price,
    required this.policyNumber,
    this.transactionId = '',
  });

  Map<String, dynamic> toMap() => {
        'planName': planName,
        'coverage': coverage,
        'price': price,
        'policyNumber': policyNumber,
        'transactionId': transactionId,
      };

  factory TripInsurance.fromMap(Map<String, dynamic> m) => TripInsurance(
        planName: (m['planName'] as String?) ?? '',
        coverage: (m['coverage'] as String?) ?? '',
        price: (m['price'] as String?) ?? '',
        policyNumber: (m['policyNumber'] as String?) ?? '',
        transactionId: (m['transactionId'] as String?) ?? '',
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
  // Per-member chat preferences — `{uid: value}`. Used to be single flat
  // fields shared by the whole trip doc, which meant one member flipping
  // "Pin Chat" (or changing the notification level) silently did the same
  // for every OTHER member too. [pinChatFor]/[notificationOptionFor] read
  // the signed-in person's own entry.
  final Map<String, bool> pinChat;
  final bool realTimeLocation;
  final Map<String, String> notificationOption;
  final DateTime? createdAt;
  /// When this trip last had real activity (a plan/day edit, a vote cast,
  /// an expense added, a chat message) — bumped by [TripRepository] at
  /// each of those write points. Falls back to [createdAt] in [fromDoc] so
  /// a trip written before this field existed still gets a sensible value
  /// instead of null. Used by the Plan tab to decide when a group has gone
  /// quiet long enough to fold into "Past Plans".
  final DateTime? lastActivityAt;
  /// When the itinerary (day/activity) content last changed — a NARROWER
  /// timestamp than [lastActivityAt] (which also counts votes/expenses/
  /// chat), bumped only by [TripRepository.addActivity]/[removeActivity]/
  /// [updateActivityTime]. Paired with [planSeenAt] to decide whether the
  /// Plan tab's "Plan Updated" tag should show for the signed-in user —
  /// see [planUnseenFor].
  final DateTime? planUpdatedAt;
  /// Per-member "I've opened the Plan tab since [planUpdatedAt]" marker —
  /// `{uid: lastOpenedAt}`, written by [TripRepository.markPlanSeen]
  /// (called whenever [GroupTripController] switches to [GroupTab.plan]).
  /// Whoever makes a plan edit has that same write also mark themselves
  /// as having seen it (see [TripRepository.addActivity] etc.), so the
  /// tag only ever appears for members who didn't make the change AND
  /// haven't opened the tab since.
  final Map<String, DateTime> planSeenAt;
  /// Same idea as [planUpdatedAt], but for the expenses subcollection —
  /// bumped by [TripRepository.addExpense]/[updateExpense]/
  /// [setParticipantPaid].
  final DateTime? expensesUpdatedAt;
  /// Same idea as [planSeenAt], but for the Expenses tab.
  final Map<String, DateTime> expensesSeenAt;
  /// Per-member unread chat-message count — `{uid: count}`, incremented
  /// for every OTHER member each time [sendMessage] writes a message, and
  /// zeroed for [uid] by [markChatSeen] (called whenever
  /// [GroupTripController] switches to [GroupTab.chat]). Drives the red
  /// number badge on the Plan tab's group card (`PlanGroup.unread`) —
  /// that badge used to be hardcoded to 0 for every trip, so it could
  /// never show anything no matter how many unread messages there were.
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
    this.travelStyle = '',
    this.accommodation = '',
    this.foodPreference = '',
    required this.ownerId,
    required this.memberIds,
    required this.memberNames,
    required this.about,
    this.pinChat = const {},
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

  /// True when [uid] should see the Plan tab's "Plan Updated" tag for
  /// this trip — there's been a real itinerary edit AND [uid] either
  /// hasn't opened the Plan tab since, or never has. Whoever made the
  /// edit has their own [planSeenAt] entry bumped to the same write (see
  /// [TripRepository.addActivity] etc.), so this is naturally false for
  /// the person who just made the change themselves.
  bool planUnseenFor(String uid) {
    final updated = planUpdatedAt;
    if (updated == null) return false;
    final seen = planSeenAt[uid];
    return seen == null || updated.isAfter(seen);
  }

  /// Same idea as [planUnseenFor], for the Expenses tab / "Expenses
  /// Updated" tag.
  bool expensesUnseenFor(String uid) {
    final updated = expensesUpdatedAt;
    if (updated == null) return false;
    final seen = expensesSeenAt[uid];
    return seen == null || updated.isAfter(seen);
  }

  /// [uid]'s own Pin Chat / Notification preference for this trip — see
  /// [pinChat]'s doc comment on why these are per-member maps rather than
  /// single shared fields.
  bool pinChatFor(String uid) => pinChat[uid] ?? false;
  String notificationOptionFor(String uid) => notificationOption[uid] ?? 'All Messages';

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

  /// A short "Oct 2026"-style label — for tight spaces (the Plan tab's
  /// small voting-card corner badge) where the full [dateRangeLabel]
  /// ("23 Sep 2026 - 27 Sep 2026  ·  5 days 4 nights") is too long and
  /// spills out past the badge/card.
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
    // {uid: Timestamp} map fields (planSeenAt/expensesSeenAt) -> {uid: DateTime} —
    // a value could theoretically still be mid-write as a server-timestamp
    // sentinel on a snapshot from the local cache, hence the `is Timestamp` guard.
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
      // Sorted by itemId first just to make the *input* to the time-sort
      // below deterministic (so two items sharing an identical time always
      // land in the same order), not because itemId order means anything.
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
      }).toList()
        // Always chronological (morning -> night) regardless of how these
        // items got here - a manual add, an applied AI Summarise change, or
        // an applied Optimise re-time all just write a new `time` onto an
        // item without reordering the Firestore map, so without this sort
        // the list stayed in whatever order the items happened to be
        // added/keyed in. "HH:mm" (zero-padded 24h, enforced wherever a
        // time is written) sorts correctly as a plain string compare. Ties
        // (rare - the model or a manual add can repeat a time) fall back to
        // itemId so the order is fully deterministic either way.
        ..sort((a, b) {
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
      travelStyle: (data['travelStyle'] as String?) ?? '',
      accommodation: (data['accommodation'] as String?) ?? '',
      foodPreference: (data['foodPreference'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      memberIds: memberIds,
      memberNames: memberNames,
      about: (data['about'] as String?) ?? '',
      // Both the new per-member map shape and, defensively, a still-bool
      // value left over from a trip written before this change (so an
      // old trip doc doesn't crash on read — it just starts with nobody
      // having pinned yet, which is the same as before).
      pinChat: data['pinChat'] is Map
          ? Map<String, bool>.from((data['pinChat'] as Map).map((k, v) => MapEntry(k.toString(), v == true)))
          : const {},
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

  /// Every member who has voted on at least one option, deduplicated —
  /// e.g. for a Plan Home voting-card's avatar stack (who's voted so far),
  /// as opposed to [leading]'s option-specific list.
  List<String> get voterUids => options.expand((o) => o.votedBy).toSet().toList();

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

/// What an expense is called in lists and headings. There is no separate title field in the
/// Add Expenses form any more: the note describes it (older expenses still have a title).
String expenseLabel(TripExpense e) {
  if (e.title.trim().isNotEmpty) return e.title.trim();
  if (e.note.trim().isNotEmpty) return e.note.trim();
  return e.category;
}

/// Shared-Expense Distribution Algorithm (FYP documentation).
///
/// Every amount is converted to the smallest currency unit (cents) before
/// any division happens (step 1), so the shares that come out always sum
/// back to exactly the original amount — plain `double` division does not
/// have that guarantee (e.g. RM10.00 / 3 rounded to 2dp per person gives
/// RM3.33 x 3 = RM9.99, one cent short). [_expenseToCents]/[_expenseFromCents]
/// are the conversion; everything below only ever divides in cents.
int _expenseToCents(double amount) => (amount * 100).round();
double _expenseFromCents(int cents) => cents / 100.0;

/// Step 2: validates totalAmount is positive and at least one member/uid
/// is present. Throws [ArgumentError] (the algorithm's "return an error").
void _validateExpenseSplitInputs(double totalAmount, int memberCount) {
  if (totalAmount <= 0) {
    throw ArgumentError('totalAmount must be positive.');
  }
  if (memberCount < 1) {
    throw ArgumentError('At least one member must be selected.');
  }
}

/// Step 3 — EQUAL split: baseShare = floor(totalAmount / memberCount),
/// remainder = totalAmount mod memberCount (both in cents); every member
/// gets baseShare, and the first `remainder` members (in [memberUids]'s
/// order) get one extra cent each, so the shares sum to exactly
/// totalAmount with nothing lost or gained to rounding.
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

/// Step 4 — CUSTOM split: validates every share is non-negative and that
/// the shares sum exactly to totalAmount (both checked in cents, so a
/// display-rounded input like RM3.33 + RM3.33 + RM3.34 = RM10.00 still
/// passes), then returns the confirmed shares unchanged. Throws
/// [ArgumentError] on either failed check.
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

/// This app's CUSTOM split is itemized (an uploaded receipt's line items,
/// each assigned to whichever members shared that item) rather than one
/// manually-typed share per member — so each item is its own EQUAL split
/// (step 3's rule, applied per item) among its assignees, and a member's
/// final share is the sum of what they owe across every item. Validates
/// every item has at least one assignee first (an unassigned item's cost
/// would otherwise vanish from the total instead of landing on anyone).
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
    final baseShare = itemCents ~/ n;
    final remainder = itemCents % n;
    for (var i = 0; i < n; i++) {
      final cents = baseShare + (i < remainder ? 1 : 0);
      totalsCents[uids[i]] = (totalsCents[uids[i]] ?? 0) + cents;
    }
  }
  return totalsCents.map((uid, cents) => MapEntry(uid, _expenseFromCents(cents)));
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

  /// 'text' (default — every message before this field existed, and
  /// every plain typed message since), 'image' (a Camera/Gallery
  /// attachment — [text] is empty, [imageUrl] holds the uploaded photo),
  /// or 'location' (a shared-location attachment — [text] is empty,
  /// [lat]/[lng] hold the coordinates).
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
      'pinChat': <String, bool>{},
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

  /// Per-member chat prefs — [uid]'s own entry only, never anyone else's.
  /// Separate from [updateSettings] (which only ever touches shared-plan
  /// fields now) since this was the one part of that method that wasn't
  /// really "this trip's settings" so much as "this device's own
  /// settings for this trip" — see [pinChat]'s doc comment.
  void setPinChatFor(String tripId, String uid, bool value) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'pinChat.$uid': value}).catchError((_) {});
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
    String? travelStyle,
    String? accommodation,
    String? foodPreference,
    String? coverImage,
    // See [addActivity] — who's doing this, for [_notifyMembers].
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

  /// FR12 — permanently deletes the whole travel group. Only the owner may
  /// call this (also enforced server-side: firestore.rules' `trips/
  /// {tripId}` delete rule, and the `isTripOwner` cascade clause on each
  /// subcollection below). Firestore never deletes a document's
  /// subcollections automatically, so votes/expenses/messages are batch-
  /// deleted first — while the trip doc (and the `isTripOwner` get() those
  /// rules rely on) still exists — and the trip doc itself is deleted
  /// last. Irreversible; the calling UI must confirm with the person
  /// first.
  Future<void> deleteTrip(String tripId, String ownerUid) async {
    final snap = await _trips.doc(tripId).get();
    if (!snap.exists) return;
    if ((snap.data()?['ownerId'] as String?) != ownerUid) {
      throw Exception('Only the trip owner can delete this group.');
    }
    for (final sub in [_votes(tripId), _expenses(tripId), _messages(tripId)]) {
      final docs = await sub.get();
      // Firestore batches cap at 500 writes — chunk defensively even
      // though a single trip's votes/expenses/messages are very unlikely
      // to ever reach that.
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

  /// Moves an existing activity to a new time only — label/location/icon/
  /// votes are untouched. [time] is 24-hour "HH:MM", same format
  /// [addActivity] stores. The drag-to-reschedule timeline in Day edit
  /// mode (see `day_timeline_view.dart`) is the only caller today; before
  /// it existed there was no way to change an activity's time short of
  /// deleting and re-adding it.
  Future<void> updateActivityTime(String tripId, int dayIndex, String itemId, String time, {String? actorUid}) {
    return _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId.time': time,
      'lastActivityAt': FieldValue.serverTimestamp(),
      ..._planUpdateFields(actorUid: actorUid),
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

  /// Fields to merge into a trip-doc update when itinerary content
  /// changes — bumps [Trip.planUpdatedAt] and, when [actorUid] is known,
  /// marks that same write as already "seen" by whoever made the edit
  /// (see [Trip.planUnseenFor]), so the Plan tab's "Plan Updated" tag
  /// never shows for the person who just made the change.
  Map<String, dynamic> _planUpdateFields({String? actorUid}) => {
        'planUpdatedAt': FieldValue.serverTimestamp(),
        if (actorUid != null && actorUid.isNotEmpty) 'planSeenAt.$actorUid': FieldValue.serverTimestamp(),
      };

  /// Bumps the trip's `lastActivityAt` — used by write methods that don't
  /// already touch the trip document directly (votes/expenses/messages
  /// live in subcollections). Fire-and-forget: this is UI-only metadata
  /// (drives "Past Plans" folding on the Plan tab), not worth failing or
  /// delaying the write that triggered it.
  ///
  /// [category] additionally bumps that category's own "updated at" +
  /// (when [actorUid] is known) marks it seen for the actor — see
  /// [Trip.expensesUnseenFor]/[planUnseenFor]. Only `'expenses'` is used
  /// today (votes/chat don't have their own "unseen" tag — see
  /// [PlanPageController.planGroups]'s "Poll Ongoing" tag, which checks
  /// each poll's own open/voted state directly instead of a seen marker).
  void _touchActivity(String tripId, {String? category, String? actorUid}) {
    final update = <String, dynamic>{'lastActivityAt': FieldValue.serverTimestamp()};
    if (category == 'expenses') {
      update['expensesUpdatedAt'] = FieldValue.serverTimestamp();
      if (actorUid != null && actorUid.isNotEmpty) {
        update['expensesSeenAt.$actorUid'] = FieldValue.serverTimestamp();
      }
    }
    // Genuinely fire-and-forget: swallow any failure (offline, permission
    // denied, doc deleted mid-flight) so it can never surface as an
    // unrelated error on top of the real write that triggered this.
    _trips.doc(tripId).update(update).catchError((_) {});
  }

  /// Records that [uid] has opened the Plan tab just now — called by
  /// [GroupTripController] whenever it switches to (or opens directly
  /// into) [GroupTab.plan]. Fire-and-forget, same reasoning as
  /// [_touchActivity]: this is UI-only "have they seen it" metadata, not
  /// worth surfacing an error over.
  void markPlanSeen(String tripId, String uid) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'planSeenAt.$uid': FieldValue.serverTimestamp()}).catchError((_) {});
  }

  /// Same idea as [markPlanSeen], for [GroupTab.expenses].
  void markExpensesSeen(String tripId, String uid) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'expensesSeenAt.$uid': FieldValue.serverTimestamp()}).catchError((_) {});
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

  /// Group Voting Algorithm (FYP documentation), steps 1-9 all inside one
  /// Firestore transaction — so two simultaneous casts from the same
  /// member, or two casts landing at the same instant on the same option,
  /// can never both succeed (one retries and sees the other's write).
  /// [vote] is only used to know which poll to open; every check below
  /// re-reads the LIVE session and trip membership inside the transaction,
  /// never the possibly-stale [vote] object the caller passed in (step 2).
  ///
  /// Throws [StateError] ("return an error") when: the poll doesn't exist
  /// or is closed (step 3); [uid] isn't an active member of the trip
  /// (step 4); [optionId] doesn't exist on this poll (step 5); or [uid]
  /// already has a vote on this poll (step 6) — for a single-choice poll
  /// that means any option, for a multiple-choice poll it means this same
  /// option (voting for several different options is the point of that
  /// mode, so only an exact repeat counts as a duplicate). There is no
  /// "withdraw my vote" path any more: once cast, a vote stands, matching
  /// the documented algorithm exactly — [VoteTab] disables the tap target
  /// once [uid] has voted so this isn't hit from the normal UI.
  Future<void> castVote(String tripId, TripVote vote, String optionId, String uid) async {
    final tripRef = _trips.doc(tripId);
    final voteRef = _votes(tripId).doc(vote.id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      // Steps 1-2: transaction started; re-read the session and the trip's membership.
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
      final alreadyVotedAnyOption = live.options.any((o) => o.votedBy.contains(uid));
      if (live.allowMultipleChoice ? alreadyVotedThisOption : alreadyVotedAnyOption) {
        throw StateError('You have already voted.');
      }
      // Steps 7-8: store the vote and increment the option's vote count
      // (votedBy is kept too — it's what [VoteTabController.votedByMe] and
      // the avatar-stack UI read; voteCount is the documented algorithm's
      // explicit counter, redundant with votedBy.length but literal to the
      // spec and immune to ever reading a half-written votedBy array).
      tx.update(voteRef, {
        'options.$optionId.votedBy': FieldValue.arrayUnion([uid]),
        'options.$optionId.voteCount': FieldValue.increment(1),
      });
      // Step 9: committing happens when this callback returns without throwing.
    });
    _touchActivity(tripId);
    // Step 10: watchVotes()'s stream (every screen showing this poll
    // already listens to it) picks up the transaction's write and
    // recalculates totals/leading option on its own.
  }

  /// Adds one more option to an already-created poll — what
  /// [TripVote.allowAddOptions] actually turning it on enables (the
  /// toggle existed on the create screen before but had nothing in the
  /// app that read it back, so it did nothing for anyone but the
  /// creator). [VoteTab] only shows the control that calls this when
  /// that flag is true and the poll isn't closed; this just performs the
  /// write, with dot-notation so it can never clobber another member's
  /// concurrent vote or add on the same poll.
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

  /// Steps 5-7 of the Shared-Expense Distribution Algorithm. [participants]
  /// must already carry the confirmed per-member shares (step 3's EQUAL or
  /// step 4's CUSTOM split — see [splitExpenseEqual]/[splitExpenseCustom]/
  /// [splitExpenseItemized] — run by the caller before this is reached);
  /// this re-validates them (step 2, defense in depth) and creates a
  /// payment-status record per member (step 5 — the `paid` flag nested in
  /// each participant entry, true only for whoever already paid, i.e. the
  /// payer), then stores the expense and every member's share in one
  /// Firestore write (step 6 — a single document create is atomic by
  /// construction: the shares live inside the same doc as the expense, so
  /// there is no multi-document write to desynchronise). Returns the
  /// stored memberShares (step 7).
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
    // FR60 — when true, every non-payer participant gets an immediate
    // payment-reminder notification right after the expense is created
    // (see [sendPaymentReminder]), same as the Add Expense form's
    // "Reminder" switch asks for. False (the default) matches every
    // existing caller/test that doesn't pass it.
    bool sendReminder = false,
  }) async {
    _validateExpenseSplitInputs(amount, participants.length);
    // Step 2's "shares sum to totalAmount" is implicitly true here because
    // every caller builds [participants] from splitExpenseEqual/Custom/
    // Itemized, all of which already guarantee it in cents — this re-checks
    // it rather than trusting that blindly, since a future caller might not.
    final sumCents = participants.fold<int>(0, (n, p) => n + _expenseToCents(p.share));
    if (sumCents != _expenseToCents(amount)) {
      throw ArgumentError('Member shares (${_expenseFromCents(sumCents)}) must sum to amount ($amount).');
    }
    final participantsMap = <String, dynamic>{
      // Step 5: a payment-status record per assigned member (paid starts
      // true only for the payer, who has implicitly "paid" their own share).
      for (final p in participants) p.uid: {'name': p.name, 'share': p.share, 'paid': p.paid}
    };
    _touchActivity(tripId, category: 'expenses', actorUid: paidBy);
    // Step 6: one atomic Firestore write for the expense + every member's share.
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

  /// FR60 — notifies every participant who hasn't marked their own share
  /// paid yet (never the payer, whose share is implicitly settled already
  /// — see [TripExpense.isSettled]). Used both right after [addExpense]
  /// (when its `sendReminder` is true) and from Transaction Detail's
  /// "Remind to Pay" button for a later follow-up nudge. Returns how many
  /// people were actually notified, so the caller can say "Reminded 2
  /// people" rather than just "Done" — or tell the payer everyone's
  /// already settled up.
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

  /// The payer edits their own expense (Transaction detail -> Edit). When the amount changes the
  /// split follows: an equal split stays equal, an uneven (itemized) split keeps its proportions.
  /// Who has already paid is kept. Firestore rules only let [TripExpense.paidBy] do this.
  /// Re-splits an edited expense's amount the same cents-safe way as
  /// [addExpense] (EQUAL via [splitExpenseEqual] when every participant
  /// currently has the same share; otherwise a cents-safe proportional
  /// re-split that keeps each member's existing ratio of the total, using
  /// the same floor + largest-remainder rule as the documented algorithm's
  /// EQUAL split so the new shares still sum to exactly the new amount —
  /// not the old per-row `.toStringAsFixed(2)` that could lose a cent).
  Future<void> updateExpense(
    TripExpense expense, {
    required String title,
    required double amount,
    required String category,
    required String note,
    String? receiptImageUrl,
  }) {
    final ps = expense.participants;
    // Someone besides the payer already paid their share: the amount is locked (the edit sheet
    // explains this; this stops it from being bypassed).
    if ((amount - expense.amount).abs() > 0.001 && ps.any((p) => p.paid && p.uid != expense.paidBy)) {
      throw StateError('The amount can\'t change after someone has paid their share.');
    }
    final equal = ps.isNotEmpty && ps.every((p) => (p.share - ps.first.share).abs() < 0.011);
    Map<String, double> newShares;
    if (ps.isEmpty) {
      newShares = const {};
    } else if (equal || expense.amount <= 0) {
      newShares = splitExpenseEqual(amount, ps.map((p) => p.uid).toList());
    } else {
      // Proportional re-split: each member's raw new share in cents, floored,
      // then the leftover cents go to whichever members had the largest
      // fractional remainder — the standard cents-safe way to keep ratios
      // while still landing on an exact total (step 3's floor + remainder
      // rule, generalised from "equal shares" to "proportional shares").
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

    _touchActivity(expense.tripId, category: 'expenses', actorUid: expense.paidBy);
    return _expenses(expense.tripId).doc(expense.id).update({
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      if (receiptImageUrl != null) 'receiptImageUrl': receiptImageUrl,
      if ((amount - expense.amount).abs() > 0.001)
        'participants': {
          for (final p in ps) p.uid: {'name': p.name, 'share': newShares[p.uid] ?? 0, 'paid': p.paid},
        },
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setParticipantPaid(String tripId, String expenseId, String uid, bool paid) {
    _touchActivity(tripId, category: 'expenses', actorUid: uid);
    return _expenses(tripId).doc(expenseId).update({'participants.$uid.paid': paid});
  }

  // ---------------- Chat ----------------
  Stream<List<TripMessage>> watchMessages(String tripId) {
    return _messages(tripId).orderBy('createdAt').snapshots().map((snap) => snap.docs.map(TripMessage.fromDoc).toList());
  }

  /// [type] is 'text' (default — pass just [text]), 'image' (pass
  /// [imageUrl], leave [text] empty), or 'location' (pass [lat]/[lng],
  /// leave [text] empty) — see [TripMessage]'s doc comment.
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
    // Bump every OTHER member's unread badge (see [Trip.unreadCounts]).
    // Fire-and-forget like [_touchActivity] — a dropped badge increment
    // is a cosmetic miss, not worth failing the message send over.
    final others = memberIds.where((uid) => uid != senderId && uid.isNotEmpty);
    if (others.isNotEmpty) {
      final update = <String, dynamic>{};
      for (final uid in others) {
        update['unreadCounts.$uid'] = FieldValue.increment(1);
      }
      _trips.doc(tripId).update(update).catchError((_) {});
    }
  }

  /// Same idea as [markPlanSeen], for [GroupTab.chat] — zeroes [uid]'s own
  /// unread-message badge (see [Trip.unreadCounts]) the moment they open
  /// the Chat tab.
  void markChatSeen(String tripId, String uid) {
    if (uid.isEmpty) return;
    _trips.doc(tripId).update({'unreadCounts.$uid': 0}).catchError((_) {});
  }

  /// FR15 — edits a text message's own content. Only ever called for a
  /// message the signed-in person sent themselves; the server-side rule
  /// (firestore.rules' `messages/{messageId}` update) enforces that too,
  /// and also enforces that only `text`/`edited`/`editedAt` ever change —
  /// an edit can't quietly turn into a different sender or a different
  /// message type. [TripMessage] doesn't yet expose `edited`, so the UI
  /// can't show an "edited" label from this alone; that's a smaller,
  /// separate follow-up if it's ever wanted.
  Future<void> editMessage(String tripId, String messageId, String newText) {
    return _messages(tripId).doc(messageId).update({
      'text': newText,
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// FR17 — deletes one of your own messages. The trip owner can also
  /// delete any message, but only as part of [deleteTrip]'s cascade
  /// cleanup when the whole group is being removed — there's no "owner
  /// moderates chat" feature here.
  Future<void> deleteMessage(String tripId, String messageId) {
    return _messages(tripId).doc(messageId).delete();
  }
}
