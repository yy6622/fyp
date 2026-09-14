import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/day_plan_models.dart';
import '../models/plan_page_models.dart';

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

/// One manually-added flight kept on a trip (`trips/{tripId}.flights`).
class TripFlight {
  final String airline, flightNumber, routeCode, routeCities, dateTime, terminal, bookingRef, status;
  const TripFlight({
    required this.airline,
    required this.flightNumber,
    required this.routeCode,
    required this.routeCities,
    required this.dateTime,
    required this.terminal,
    required this.bookingRef,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'airline': airline,
        'flightNumber': flightNumber,
        'routeCode': routeCode,
        'routeCities': routeCities,
        'dateTime': dateTime,
        'terminal': terminal,
        'bookingRef': bookingRef,
        'status': status,
      };

  factory TripFlight.fromMap(Map<String, dynamic> m) => TripFlight(
        airline: (m['airline'] as String?) ?? '',
        flightNumber: (m['flightNumber'] as String?) ?? '',
        routeCode: (m['routeCode'] as String?) ?? '',
        routeCities: (m['routeCities'] as String?) ?? '',
        dateTime: (m['dateTime'] as String?) ?? '',
        terminal: (m['terminal'] as String?) ?? '',
        bookingRef: (m['bookingRef'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'Confirmed',
      );
}

/// One manually-added hotel stay kept on a trip (`trips/{tripId}.hotelStays`).
class TripHotelStay {
  final String name, location, checkIn, checkOut;
  const TripHotelStay({required this.name, required this.location, required this.checkIn, required this.checkOut});

  Map<String, dynamic> toMap() => {'name': name, 'location': location, 'checkIn': checkIn, 'checkOut': checkOut};

  factory TripHotelStay.fromMap(Map<String, dynamic> m) => TripHotelStay(
        name: (m['name'] as String?) ?? '',
        location: (m['location'] as String?) ?? '',
        checkIn: (m['checkIn'] as String?) ?? '',
        checkOut: (m['checkOut'] as String?) ?? '',
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
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String about;
  final bool muteChat;
  final bool pinChat;
  final bool realTimeLocation;
  final DateTime? createdAt;
  final List<DayPlan> days;
  final List<TripFlight> flights;
  final List<TripHotelStay> hotelStays;

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
    required this.muteChat,
    required this.pinChat,
    required this.realTimeLocation,
    required this.createdAt,
    required this.days,
    required this.flights,
    required this.hotelStays,
  });

  String get dateRangeLabel {
    if (startDate == null || endDate == null) return '';
    String fmt(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';
    final nights = endDate!.difference(startDate!).inDays;
    return '${fmt(startDate!)} - ${fmt(endDate!)}  ·  ${nights + 1} days $nights night${nights == 1 ? '' : 's'}';
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
          icon: iconForKey((it['icon'] as String?) ?? ''),
          voted: votedBy.length,
          total: memberIds.isEmpty ? 1 : memberIds.length,
          votedByMe: votedBy.contains(myUid),
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
      ownerId: (data['ownerId'] as String?) ?? '',
      memberIds: memberIds,
      memberNames: memberNames,
      about: (data['about'] as String?) ?? '',
      muteChat: (data['muteChat'] as bool?) ?? false,
      pinChat: (data['pinChat'] as bool?) ?? false,
      realTimeLocation: (data['realTimeLocation'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      days: days,
      flights: (data['flights'] as List? ?? const [])
          .map((f) => TripFlight.fromMap(Map<String, dynamic>.from(f as Map)))
          .toList(),
      hotelStays: (data['hotelStays'] as List? ?? const [])
          .map((h) => TripHotelStay.fromMap(Map<String, dynamic>.from(h as Map)))
          .toList(),
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
  const TripVote({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.allowAddOptions,
    required this.allowMultipleChoice,
    required this.options,
    required this.createdAt,
  });

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
      'coverImage': 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800',
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
      'flights': <Map<String, dynamic>>[],
      'hotelStays': <Map<String, dynamic>>[],
      'days': days,
      'createdAt': FieldValue.serverTimestamp(),
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
  }) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (about != null) data['about'] = about;
    if (muteChat != null) data['muteChat'] = muteChat;
    if (pinChat != null) data['pinChat'] = pinChat;
    if (realTimeLocation != null) data['realTimeLocation'] = realTimeLocation;
    if (data.isEmpty) return Future.value();
    return _trips.doc(tripId).update(data);
  }

  Future<void> addMembers(String tripId, Map<String, String> uidToName) async {
    if (uidToName.isEmpty) return;
    final data = <String, dynamic>{
      'memberIds': FieldValue.arrayUnion(uidToName.keys.toList()),
    };
    for (final e in uidToName.entries) {
      data['memberNames.${e.key}'] = e.value;
    }
    await _trips.doc(tripId).update(data);
  }

  Future<void> leaveTrip(String tripId, String uid) {
    return _trips.doc(tripId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'memberNames.$uid': FieldValue.delete(),
    });
  }

  Future<void> addActivity(String tripId, int dayIndex, {required String time, required String label, required String iconKey}) {
    final itemId = '${DateTime.now().microsecondsSinceEpoch}';
    return _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId': {
        'time': time,
        'label': label,
        'icon': iconKey,
        'votedBy': <String>[],
      },
    });
  }

  Future<void> toggleActivityVote(String tripId, int dayIndex, String itemId, String uid, bool voted) {
    return _trips.doc(tripId).update({
      'days.$dayIndex.items.$itemId.votedBy':
          voted ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> addFlight(String tripId, TripFlight flight) {
    return _trips.doc(tripId).update({
      'flights': FieldValue.arrayUnion([flight.toMap()]),
    });
  }

  Future<void> addHotelStay(String tripId, TripHotelStay stay) {
    return _trips.doc(tripId).update({
      'hotelStays': FieldValue.arrayUnion([stay.toMap()]),
    });
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
  }) {
    final optionsMap = <String, dynamic>{};
    for (var i = 0; i < options.length; i++) {
      optionsMap['opt${i}_${DateTime.now().microsecondsSinceEpoch}'] = {'label': options[i], 'votedBy': <String>[]};
    }
    return _votes(tripId).add({
      'title': title,
      'createdBy': createdBy,
      'allowAddOptions': allowAddOptions,
      'allowMultipleChoice': allowMultipleChoice,
      'options': optionsMap,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Casts/withdraws [uid]'s vote for [optionId]. For a single-choice poll
  /// this also withdraws any vote they had on the poll's other options.
  Future<void> castVote(String tripId, TripVote vote, String optionId, String uid) async {
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
    await _votes(tripId).doc(vote.id).update(update);
  }

  // ---------------- Expenses ----------------
  Stream<List<TripExpense>> watchExpenses(String tripId) {
    return _expenses(tripId).orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map(TripExpense.fromDoc).toList());
  }

  /// All expenses across every trip that [uid] participates in — powers the
  /// Expenses tab's "Personal" view. Uses a collection-group query, so a
  /// brand-new Firebase project may need to create the suggested index the
  /// first time this runs (Firestore's error message links straight to it).
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
  }) {
    final participantsMap = <String, dynamic>{
      for (final p in participants) p.uid: {'name': p.name, 'share': p.share, 'paid': p.paid}
    };
    return _expenses(tripId).add({
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setParticipantPaid(String tripId, String expenseId, String uid, bool paid) {
    return _expenses(tripId).doc(expenseId).update({'participants.$uid.paid': paid});
  }

  // ---------------- Chat ----------------
  Stream<List<TripMessage>> watchMessages(String tripId) {
    return _messages(tripId).orderBy('createdAt').snapshots().map((snap) => snap.docs.map(TripMessage.fromDoc).toList());
  }

  Future<void> sendMessage(String tripId, {required String senderId, required String senderName, required String text}) {
    return _messages(tripId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
