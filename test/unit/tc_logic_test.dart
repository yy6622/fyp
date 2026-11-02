// Executable test cases for pure app logic that needs no Firebase:
// schedule conflicts, attraction recommendation, invite codes, hashtags and
// sign-up form validation. Each test calls the real code in lib/.
// Run: flutter test test/unit
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voya/controllers/auth_controller.dart';
import 'package:voya/controllers/booking_details_controller.dart';
import 'package:voya/models/day_plan_models.dart';
import 'package:voya/repositories/catalog_repository.dart';
import 'package:voya/repositories/community_repository.dart';
import 'package:voya/repositories/trip_repository.dart';
import 'package:voya/services/content_moderation_service.dart';
import 'package:voya/services/maps_service.dart';
import 'package:voya/services/opening_hours.dart';
import 'package:voya/services/recommendation_service.dart';

ActivityItem _activity(String id, String time, String label, {List<String> forMembers = const []}) => ActivityItem(
      id: id,
      time: time,
      icon: Icons.place_outlined,
      label: label,
      voted: 0,
      total: 0,
      forMemberUids: forMembers,
    );

CatalogAttraction _attraction(
  String name, {
  String category = 'Landmark',
  String rating = '4.0',
  String openingHours = 'Mo-Su 09:00-18:00',
  List<String> facilities = const [],
  double? distanceKm,
  String price = 'Free',
}) =>
    CatalogAttraction(
      id: name.toLowerCase().replaceAll(' ', '_'),
      favoritedBy: const [],
      name: name,
      category: category,
      rating: rating,
      reviews: '0',
      price: price,
      image: '',
      openingHours: openingHours,
      facilities: facilities,
      distanceKm: distanceKm,
    );

// Wednesday 28 Oct 2026.
final _wed10am = DateTime(2026, 10, 28, 10, 0);
final _wed8pm = DateTime(2026, 10, 28, 20, 0);

RecommendationContext _ctx({
  bool openNow = false,
  bool accessible = false,
  DateTime? now,
  Map<String, int> affinity = const {},
}) =>
    RecommendationContext(
      withinBudget: (_) => true,
      affinity: affinity,
      requireOpenNow: openNow,
      requireAccessible: accessible,
      now: now ?? _wed10am,
    );

void main() {
  group('TC10 Activity schedule conflict', () {
    final members = ['ali', 'bella', 'chong'];

    test('TC10 two activities at the same time for the same member are a conflict', () {
      final days = [
        DayPlan(day: 1, weekday: 'Thu', date: '10 Dec', items: [
          _activity('a1', '10:00', 'Batu Caves', forMembers: ['bella']),
          _activity('a2', '10:00', 'Spa', forMembers: ['bella', 'chong']),
        ]),
      ];
      final conflicts = findScheduleConflicts(days, members);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.day, 1);
      expect(conflicts.first.time, '10:00');
      expect(conflicts.first.sharedMemberUids, ['bella']);
    });

    test('TC10 same time but different members is not a conflict', () {
      final days = [
        DayPlan(day: 1, weekday: 'Thu', date: '10 Dec', items: [
          _activity('a1', '10:00', 'Batu Caves', forMembers: ['ali']),
          _activity('a2', '10:00', 'Spa', forMembers: ['bella']),
        ]),
      ];
      expect(findScheduleConflicts(days, members), isEmpty);
    });

    test('TC10 an activity for everyone clashes with any other activity at that time', () {
      final days = [
        DayPlan(day: 2, weekday: 'Fri', date: '11 Dec', items: [
          _activity('a1', '13:00', 'Lunch'),
          _activity('a2', '13:00', 'Museum', forMembers: ['chong']),
        ]),
      ];
      expect(findScheduleConflicts(days, members).single.sharedMemberUids, ['chong']);
    });
  });

  group('TC21 Recommendation ranking', () {
    test('TC21 better-rated and closer attractions rank higher', () {
      final ranked = AttractionRecommendation.rank([
        _attraction('Far Average', rating: '3.5', distanceKm: 25),
        _attraction('Near Great', rating: '4.8', distanceKm: 1),
        _attraction('Mid Good', rating: '4.2', distanceKm: 8),
      ], _ctx());
      expect(ranked.map((a) => a.name), ['Near Great', 'Mid Good', 'Far Average']);
    });

    test('TC21 "Open now" removes places that are closed right now', () {
      final candidates = [
        _attraction('Day Museum', openingHours: 'Mo-Su 09:00-18:00'),
        _attraction('Night Market', openingHours: 'Mo-Su 18:00-23:00'),
      ];
      expect(AttractionRecommendation.rank(candidates, _ctx(openNow: true, now: _wed10am)).map((a) => a.name),
          ['Day Museum']);
      expect(AttractionRecommendation.rank(candidates, _ctx(openNow: true, now: _wed8pm)).map((a) => a.name),
          ['Night Market']);
    });

    test('TC21 places matching the traveller\'s interests rank first', () {
      final ranked = AttractionRecommendation.rank([
        _attraction('Shopping Mall', category: 'Shopping'),
        _attraction('Nature Park', category: 'Nature'),
      ], _ctx(affinity: {'Nature': 5}));
      expect(ranked.first.name, 'Nature Park');
    });

    test('TC21 the default weights sum to 1 (4.8.1)', () {
      expect(const RecommendationWeights().sum, closeTo(1.0, 1e-9));
    });

    test('TC21 opening-hours parser handles OSM syntax', () {
      expect(isOpenNow('Mo-Su 09:00-18:00', now: _wed10am), isTrue);
      expect(isOpenNow('Mo-Su 09:00-18:00', now: _wed8pm), isFalse);
      expect(isOpenNow('24/7', now: _wed8pm), isTrue);
    });
  });

  group('TC22 Wheelchair accessible filter', () {
    test('TC22 only accessible attractions remain when the filter is on', () {
      final ranked = AttractionRecommendation.rank([
        _attraction('Stairs Temple'),
        _attraction('Accessible Gallery', facilities: ['Wheelchair accessible']),
      ], _ctx(accessible: true));
      expect(ranked.map((a) => a.name), ['Accessible Gallery']);
    });
  });

  group('TC37 Hashtags', () {
    test('TC37 hashtags are trimmed, lower-cased, de-duplicated and lose the #', () {
      expect(CommunityRepository.normalizeTags(['#Bangkok', 'bangkok', ' #Food ', '', '#']), ['bangkok', 'food']);
    });
  });

  group('TC51 Invite codes', () {
    test('TC51 invite code survives links, spaces and dashes', () {
      final repo = TripRepository.instance;
      expect(repo.parseInviteCode('AbC123xyz'), 'AbC123xyz');
      expect(repo.parseInviteCode('https://voya.app/join/AbC123xyz'), 'AbC123xyz');
      expect(repo.parseInviteCode('AbC1 23x-yz'), 'AbC123xyz');
      expect(repo.parseInviteCode('   '), '');
    });
  });

  group('TC53 Transport suggestion between activities', () {
    test('TC53 short hops are walked, longer ones driven, with an ETA', () {
      final walk = MapsService.suggest(0.5);
      expect(walk.mode, SuggestedTravelMode.walk);
      expect(walk.etaMinutes, 7);
      final drive = MapsService.suggest(3);
      expect(drive.mode, SuggestedTravelMode.drive);
      expect(drive.etaMinutes, 7);
      expect(MapsService.suggest(null).mode, SuggestedTravelMode.unknown);
    });
  });

  group('TC31 Hotel booking guest details', () {
    test('TC31 the number of rooms cannot go below 1', () {
      final c = HotelGuestDetailsController();
      c.setRooms(0);
      expect(c.rooms, 1);
      c.setRooms(-3);
      expect(c.rooms, 1);
      c.setRooms(20);
      expect(c.rooms, 9);
    });

    test('TC31 missing or invalid guest details are refused', () {
      final c = HotelGuestDetailsController();
      expect(c.validate(), "The guest's full name is required.");
      c.setFullName('Tom Tan');
      c.setEmail('tom@');
      expect(c.validate(), 'Please enter a valid email address.');
      c.setEmail('tom@example.com');
      c.setPhone('12ab');
      expect(c.validate(), 'Please enter a valid phone number.');
      c.setPhone('+60 12-345 6789');
      c.setIdNumber('A12345678');
      expect(c.validate(), 'Please select check-in and check-out dates.');
      c.setDates(DateTime(2026, 12, 10), DateTime(2026, 12, 12));
      expect(c.validate(), isNull);
    });
  });

  group('TC01 / TC02 Sign-up form validation', () {
    late SignupController c;
    setUp(() => c = SignupController());
    tearDown(() => c.dispose());

    void fill(String user, String email, String pw, String confirm) {
      c.usernameController.text = user;
      c.emailController.text = email;
      c.passwordController.text = pw;
      c.confirmController.text = confirm;
    }

    test('TC01 the password rules accept Test@1234', () {
      fill('Test User', 'testuser01@gmail.com', 'Test@1234', 'Test@1234');
      expect(c.isPasswordValid, isTrue);
    });

    test('TC02 empty username or email is refused before contacting the server', () async {
      fill('', 'testuser01@gmail.com', 'Test@1234', 'Test@1234');
      expect(await c.signUp(), 'Enter a username.');
      fill('Test User', '', 'Test@1234', 'Test@1234');
      expect(await c.signUp(), 'Enter your email.');
    });

    test('TC02 weak password and mismatched confirmation are refused', () async {
      fill('Test User', 'testuser01@gmail.com', 'Test1234', 'Test1234');
      expect(c.isPasswordValid, isFalse, reason: 'no special character');
      expect(await c.signUp(), 'Password does not meet the requirements above.');
      fill('Test User', 'testuser01@gmail.com', 'Test@1234', 'Test@9999');
      expect(await c.signUp(), 'Passwords do not match.');
    });
  });

  group('TC38 Content moderation word list (works offline)', () {
    test('TC38 Profanity in English, Malay and Chinese is flagged', () {
      expect(ContentModerationService.localMatch('This hotel is shit and the staff are fucking idiots.'), isNotNull);
      expect(ContentModerationService.localMatch('Pemandu ni bodoh betul'), isNotNull);
      expect(ContentModerationService.localMatch('这个导游是傻逼'), isNotNull);
    });
    test('TC38 Normal travel text is not flagged', () {
      expect(ContentModerationService.localMatch('Three days of street food around Yaowarat and Chatuchak.'), isNull);
      expect(ContentModerationService.localMatch('Great tips, thanks! Scunthorpe and Essex were lovely.'), isNull);
      expect(ContentModerationService.localMatch('Try the char siew and the classic laksa'), isNull);
    });
  });
}
