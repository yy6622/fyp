import 'package:cloud_firestore/cloud_firestore.dart';

/// TEMPORARY debug utility — writes a batch of realistic fake data (one
/// trip with activities/a vote/expenses/chat messages, two community
/// posts, two friends, two insurance bookings, and a couple of favorited
/// Explore items) under the signed-in user's own account, purely so the
/// app has something to demo.
///
/// Every doc this writes is either tracked by id in a small registry doc
/// (`dev_seed_registry/{uid}`) or tagged `isFakeSeed: true` (the trip
/// itself, and each booking), so [clearAll] can remove exactly what
/// [seedAll] created and nothing else — no real user data is ever touched.
///
/// DELETE ME: when this is no longer needed, remove this file,
/// `lib/views/profile/dev_seed_page.dart`, the "Debug: Seed Test Data"
/// menu item in `lib/views/profile/profile_page.dart`, and the
/// isFakeSeed-gated delete rules + `dev_seed_registry` block added to
/// `firestore.rules` for this feature — they're all one unit.
class DevSeedService {
  DevSeedService._();
  static final DevSeedService instance = DevSeedService._();

  static const _fakeMembers = {
    'dev_fake_sarah': 'Sarah Lim',
    'dev_fake_weijie': 'Wei Jie Tan',
  };

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _registryDoc(String uid) =>
      _db.collection('dev_seed_registry').doc(uid);

  Future<bool> hasSeedData(String uid) async {
    final doc = await _registryDoc(uid).get();
    return doc.exists;
  }

  Future<void> seedAll({required String uid, required String myName}) async {
    final tripId = await _seedTrip(uid, myName);
    final postIds = await _seedPosts(uid, myName);
    final friendIds = await _seedFriends(uid);
    final bookingIds = await _seedBookings(uid);
    final favorites = await _seedFavorites(uid);

    await _registryDoc(uid).set({
      'tripId': tripId,
      'postIds': postIds,
      'friendIds': friendIds,
      'bookingIds': bookingIds,
      'favoritedHotelIds': favorites['hotels'],
      'favoritedAttractionIds': favorites['attractions'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearAll(String uid) async {
    final doc = await _registryDoc(uid).get();
    if (!doc.exists) return;
    final data = doc.data() ?? const {};

    final tripId = data['tripId'] as String?;
    if (tripId != null) {
      final tripRef = _db.collection('trips').doc(tripId);
      // The trip doc still exists (and is still tagged isFakeSeed: true) at
      // this point, which is what the security rules check to allow
      // deleting its votes/expenses/messages — so subcollections must be
      // cleared out before the trip doc itself.
      for (final sub in ['votes', 'expenses', 'messages']) {
        final snap = await tripRef.collection(sub).get();
        for (final d in snap.docs) {
          await d.reference.delete();
        }
      }
      await tripRef.delete();
    }

    for (final id in List<String>.from(data['postIds'] as List? ?? const [])) {
      await _db.collection('posts').doc(id).delete();
    }
    for (final id in List<String>.from(data['friendIds'] as List? ?? const [])) {
      await _db.collection('users').doc(uid).collection('friends').doc(id).delete();
    }
    for (final id in List<String>.from(data['bookingIds'] as List? ?? const [])) {
      await _db.collection('users').doc(uid).collection('bookings').doc(id).delete();
    }
    for (final id in List<String>.from(data['favoritedHotelIds'] as List? ?? const [])) {
      await _db.collection('catalog_hotels').doc(id).update({
        'favoritedBy': FieldValue.arrayRemove([uid]),
      });
    }
    for (final id in List<String>.from(data['favoritedAttractionIds'] as List? ?? const [])) {
      await _db.collection('catalog_attractions').doc(id).update({
        'favoritedBy': FieldValue.arrayRemove([uid]),
      });
    }

    await _registryDoc(uid).delete();
  }

  // ---------------- Trip (activities, vote, expenses, chat) ----------------
  Future<String> _seedTrip(String uid, String myName) async {
    final start = DateTime.now().add(const Duration(days: 7));
    final memberNames = {uid: myName, ..._fakeMembers};
    final memberIds = memberNames.keys.toList();

    final days = <String, dynamic>{};
    for (var i = 0; i < 5; i++) {
      final date = start.add(Duration(days: i));
      days['$i'] = {
        'day': i + 1,
        'weekday': const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][(date.weekday - 1) % 7],
        'date': '${date.day}/${date.month}',
        'items': <String, dynamic>{},
      };
    }
    (days['0'] as Map)['items']['dev_item_1'] = {
      'time': '09:00', 'label': 'Check in at hotel', 'icon': 'hotel', 'votedBy': [uid],
    };
    (days['0'] as Map)['items']['dev_item_2'] = {
      'time': '13:00', 'label': 'Beach lunch', 'icon': 'food', 'votedBy': [uid, 'dev_fake_sarah'],
    };
    (days['1'] as Map)['items']['dev_item_3'] = {
      'time': '10:00', 'label': 'Snorkeling trip', 'icon': 'activity', 'votedBy': <String>[],
    };

    final tripRef = await _db.collection('trips').add({
      'name': 'Bali Getaway',
      'destination': 'Bali, Indonesia',
      'coverImage': 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800',
      'startDate': Timestamp.fromDate(start),
      'endDate': Timestamp.fromDate(start.add(const Duration(days: 4))),
      'budgetPerPerson': 800.0,
      'interests': ['Beach', 'Food', 'Culture'],
      'ownerId': uid,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'about': "Let's make amazing memories together! (test data)",
      'muteChat': false,
      'pinChat': false,
      'realTimeLocation': false,
      'flights': [
        {
          'airline': 'AirAsia',
          'flightNumber': 'AK892',
          'routeCode': 'KUL-DPS',
          'routeCities': 'Kuala Lumpur to Denpasar',
          'dateTime': '${start.day}/${start.month}/${start.year} 08:30',
          'terminal': 'T2',
          'bookingRef': 'DEVSEED123',
          'status': 'Confirmed',
        },
      ],
      'hotelStays': [
        {
          'name': 'Bali Beach Resort',
          'location': 'Kuta, Bali',
          'checkIn': '${start.day}/${start.month}',
          'checkOut': '${start.add(const Duration(days: 4)).day}/${start.month}',
        },
      ],
      'days': days,
      'createdAt': FieldValue.serverTimestamp(),
      'isFakeSeed': true,
    });
    final tripId = tripRef.id;
    final tripRefDoc = _db.collection('trips').doc(tripId);

    await tripRefDoc.collection('votes').add({
      'title': 'Where should we eat tonight?',
      'createdBy': uid,
      'allowAddOptions': true,
      'allowMultipleChoice': false,
      'options': {
        'opt1': {'label': 'Seafood BBQ', 'votedBy': [uid]},
        'opt2': {'label': 'Local Warung', 'votedBy': ['dev_fake_sarah']},
        'opt3': {'label': 'Beach Club', 'votedBy': <String>[]},
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await tripRefDoc.collection('expenses').add({
      'tripId': tripId,
      'tripName': 'Bali Getaway',
      'title': 'Villa Deposit',
      'amount': 450.0,
      'category': 'Accommodation',
      'note': 'Test data',
      'location': 'Kuta, Bali',
      'paidBy': uid,
      'paidByName': myName,
      'date': FieldValue.serverTimestamp(),
      'participants': {
        uid: {'name': myName, 'share': 150.0, 'paid': true},
        'dev_fake_sarah': {'name': 'Sarah Lim', 'share': 150.0, 'paid': false},
        'dev_fake_weijie': {'name': 'Wei Jie Tan', 'share': 150.0, 'paid': false},
      },
      'participantIds': [uid, 'dev_fake_sarah', 'dev_fake_weijie'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await tripRefDoc.collection('expenses').add({
      'tripId': tripId,
      'tripName': 'Bali Getaway',
      'title': 'Snorkeling Tickets',
      'amount': 120.0,
      'category': 'Activities',
      'note': 'Test data',
      'location': 'Nusa Penida',
      'paidBy': 'dev_fake_sarah',
      'paidByName': 'Sarah Lim',
      'date': FieldValue.serverTimestamp(),
      'participants': {
        uid: {'name': myName, 'share': 40.0, 'paid': false},
        'dev_fake_sarah': {'name': 'Sarah Lim', 'share': 40.0, 'paid': true},
        'dev_fake_weijie': {'name': 'Wei Jie Tan', 'share': 40.0, 'paid': false},
      },
      'participantIds': [uid, 'dev_fake_sarah', 'dev_fake_weijie'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    final messages = tripRefDoc.collection('messages');
    await messages.add({
      'senderId': uid, 'senderName': myName,
      'text': "Can't wait for this trip!", 'createdAt': FieldValue.serverTimestamp(),
    });
    await messages.add({
      'senderId': 'dev_fake_sarah', 'senderName': 'Sarah Lim',
      'text': 'Me too! I booked the villa deposit already 🏖️', 'createdAt': FieldValue.serverTimestamp(),
    });
    await messages.add({
      'senderId': 'dev_fake_weijie', 'senderName': 'Wei Jie Tan',
      'text': "Don't forget sunscreen 😄", 'createdAt': FieldValue.serverTimestamp(),
    });

    return tripId;
  }

  // ---------------- Community posts ----------------
  Future<List<String>> _seedPosts(String uid, String myName) async {
    final ids = <String>[];
    final posts = [
      {
        'title': 'Hidden waterfalls in Bali',
        'description': 'Found this amazing spot off the tourist trail — test data post.',
        'location': 'Bali, Indonesia',
        'flagEmoji': '🇮🇩',
      },
      {
        'title': 'Best street food in Penang',
        'description': 'A 3-day food crawl through Georgetown — test data post.',
        'location': 'Penang, Malaysia',
        'flagEmoji': '🇲🇾',
      },
    ];
    for (final p in posts) {
      final ref = await _db.collection('posts').add({
        'authorId': uid,
        'author': myName,
        'handle': '@${myName.toLowerCase().replaceAll(' ', '')}',
        'avatarColorValue': 0xFF104259,
        'title': p['title'],
        'description': p['description'],
        'location': p['location'],
        'flagEmoji': p['flagEmoji'],
        'images': <String>[],
        'itinerary': <Map<String, dynamic>>[],
        'likedBy': <String>[],
        'savedBy': <String>[],
        'ratings': <String, dynamic>{},
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isFakeSeed': true,
      });
      ids.add(ref.id);
    }
    return ids;
  }

  // ---------------- Friends ----------------
  Future<List<String>> _seedFriends(String uid) async {
    final ids = <String>[];
    for (final e in _fakeMembers.entries) {
      await _db.collection('users').doc(uid).collection('friends').doc(e.key).set({
        'name': e.value,
        'addedAt': FieldValue.serverTimestamp(),
        'isFakeSeed': true,
      });
      ids.add(e.key);
    }
    return ids;
  }

  // ---------------- Insurance bookings ----------------
  Future<List<String>> _seedBookings(String uid) async {
    final ids = <String>[];
    final bookings = [
      {'title': 'Travel Basic Plan', 'subtitle': 'Policy #INS-DEVSEED1', 'trailing': 'RM 45.00'},
      {'title': 'Travel Premium Plan', 'subtitle': 'Policy #INS-DEVSEED2', 'trailing': 'RM 89.00'},
    ];
    for (final b in bookings) {
      final ref = await _db.collection('users').doc(uid).collection('bookings').add({
        'type': 'insurance',
        'title': b['title'],
        'subtitle': b['subtitle'],
        'trailing': b['trailing'],
        'createdAt': FieldValue.serverTimestamp(),
        'isFakeSeed': true,
      });
      ids.add(ref.id);
    }
    return ids;
  }

  // ---------------- Explore / Near By favorites ----------------
  Future<Map<String, List<String>>> _seedFavorites(String uid) async {
    final hotelsSnap = await _db.collection('catalog_hotels').limit(2).get();
    final attractionsSnap = await _db.collection('catalog_attractions').limit(2).get();
    final hotelIds = <String>[];
    final attractionIds = <String>[];
    for (final d in hotelsSnap.docs) {
      await d.reference.update({'favoritedBy': FieldValue.arrayUnion([uid])});
      hotelIds.add(d.id);
    }
    for (final d in attractionsSnap.docs) {
      await d.reference.update({'favoritedBy': FieldValue.arrayUnion([uid])});
      attractionIds.add(d.id);
    }
    return {'hotels': hotelIds, 'attractions': attractionIds};
  }
}
