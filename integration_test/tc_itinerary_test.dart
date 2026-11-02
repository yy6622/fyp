// Itinerary Management Module - TC06, TC07, TC09, TC10, TC11, TC43, TC51, TC52,
// TC54, TC57, TC69 (FR12 delete group) and TC70 (FR15/FR17 edit/delete messages).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/controllers/create_plan_wizard_controller.dart';
import 'package:voya/models/day_plan_models.dart';
import 'package:voya/repositories/friends_repository.dart';
import 'package:voya/repositories/notifications_repository.dart';
import 'package:voya/repositories/trip_repository.dart';
import 'package:voya/repositories/user_repository.dart';
import 'package:voya/services/weather_service.dart';

import 'helpers/test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestUser ali, bella, chong, dina, outsider;
  late String tripId;
  final repo = TripRepository.instance;

  setUpAll(() async {
    await initTestEnv();
    await resetEmulators();
    outsider = await createTraveller('Outsider Olly');
    dina = await createTraveller('Dina');
    chong = await createTraveller('Chong');
    bella = await createTraveller('Bella');
    ali = await createTraveller('Ali'); // signed in last = trip owner
  });

  testWidgets('TC07 End date cannot end up before the start date', (tester) async {
    final w = CreatePlanWizardController();
    w.setEndDate(DateTime(2026, 12, 12));
    w.setStartDate(DateTime(2026, 12, 15));
    expect(w.endDate, DateTime(2026, 12, 15), reason: 'end date resets to the start date');
    w.dispose();
  });

  testWidgets('TC06 Create a group trip that all members can see', (tester) async {
    await signInAs(ali);
    final w = CreatePlanWizardController();
    w.tripNameController.text = 'Bangkok Getaway';
    w.setDestination('Bangkok, Thailand');
    w.setStartDate(DateTime(2026, 12, 10));
    w.setEndDate(DateTime(2026, 12, 12));
    for (final m in [bella, chong, dina]) {
      w.addTraveller(FriendEntry(uid: m.uid, name: m.name));
    }

    tripId = await w.createTrip();
    w.dispose();

    final trip = await repo.getTrip(tripId, ali.uid);
    expect(trip, isNotNull);
    expect(trip!.memberIds.toSet(), {ali.uid, bella.uid, chong.uid, dina.uid});
    expect(trip.days, hasLength(3), reason: '10-12 Dec = 3 days 2 nights');
    expect(trip.ownerId, ali.uid);

    for (final m in [bella, chong, dina]) {
      await signInAs(m);
      final mine = await repo.watchMyTrips(m.uid).first;
      expect(mine.map((t) => t.id), contains(tripId), reason: '${m.name} sees the trip on Home');
    }
  });

  testWidgets('TC09 Other members are notified when the plan changes', (tester) async {
    await signInAs(ali);
    await repo.addActivity(tripId, 1,
        time: '10:00', label: 'Chatuchak Market', iconKey: 'shopping', actorUid: ali.uid);
    await settle();

    await signInAs(bella);
    final inbox = await NotificationsRepository.instance.watch(bella.uid).first;
    expect(
      inbox.any((n) => n.type == 'trip_activity_added' && n.body.contains('Chatuchak Market')),
      isTrue,
      reason: 'Bella gets "Ali added Chatuchak Market to Day 2"',
    );
  });

  testWidgets('TC10 Two activities for the same member at the same time are detected', (tester) async {
    await signInAs(ali);
    await repo.addActivity(tripId, 0, time: '10:00', label: 'Grand Palace', iconKey: 'place', forMemberUids: [bella.uid]);
    await repo.addActivity(tripId, 0, time: '10:00', label: 'Thai Massage', iconKey: 'activity',
        forMemberUids: [bella.uid, chong.uid]);

    final trip = (await repo.getTrip(tripId, ali.uid))!;
    final conflicts = findScheduleConflicts(trip.days, trip.memberIds);
    expect(conflicts, hasLength(1));
    expect(conflicts.single.sharedMemberUids, [bella.uid]);
  });

  testWidgets('TC11 Messages reach other members in real time, with an unread badge', (tester) async {
    await signInAs(ali);
    final trip = (await repo.getTrip(tripId, ali.uid))!;
    await repo.sendMessage(tripId,
        senderId: ali.uid, senderName: ali.name, memberIds: trip.memberIds, text: "Let's go Petronas Towers on day 2");
    await settle();

    await signInAs(bella);
    final messages = await repo.watchMessages(tripId).first;
    expect(messages.map((m) => m.text), contains("Let's go Petronas Towers on day 2"));
    final forBella = (await repo.getTrip(tripId, bella.uid))!;
    expect(forBella.unreadCounts[bella.uid], 1);
    expect(forBella.unreadCounts[ali.uid] ?? 0, 0, reason: 'the sender gets no badge');
  });

  testWidgets('TC70 Only the sender can edit or delete a message (FR15, FR17)', (tester) async {
    await signInAs(ali);
    final ref = await FirebaseFirestore.instance.collection('trips').doc(tripId).collection('messages').add({
      'senderId': ali.uid, 'senderName': ali.name, 'text': 'meet at 9', 'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await repo.editMessage(tripId, ref.id, 'meet at 10');
    final edited = await ref.get();
    expect(edited.data()?['text'], 'meet at 10');
    expect(edited.data()?['edited'], isTrue);

    await signInAs(bella);
    await expectDenied(() => repo.editMessage(tripId, ref.id, 'hacked'), reason: "Bella edits Ali's message");
    await expectDenied(() => repo.deleteMessage(tripId, ref.id), reason: "Bella deletes Ali's message");

    await signInAs(ali);
    await repo.deleteMessage(tripId, ref.id);
    expect((await ref.get()).exists, isFalse);
  });

  testWidgets('TC43 A non-member cannot read or change the trip', (tester) async {
    await signInAs(outsider);
    await expectDenied(() => repo.getTrip(tripId, outsider.uid), reason: 'read trip');
    await expectDenied(() => repo.watchMessages(tripId).first, reason: 'read chat');
    await expectDenied(
      () => FirebaseFirestore.instance.collection('trips').doc(tripId).update({'name': 'hijacked'}),
      reason: 'rename trip',
    );
  });

  testWidgets('TC51 The owner removes a member, who then loses access', (tester) async {
    await signInAs(ali);
    await repo.removeMember(tripId, dina.uid, actorUid: ali.uid);
    final trip = (await repo.getTrip(tripId, ali.uid))!;
    expect(trip.memberIds, isNot(contains(dina.uid)));

    await signInAs(dina);
    expect((await repo.watchMyTrips(dina.uid).first).map((t) => t.id), isNot(contains(tripId)));
    await expectDenied(() => repo.getTrip(tripId, dina.uid));
  });

  testWidgets('TC52 Live location is visible only while sharing is on', (tester) async {
    await signInAs(bella);
    await UserRepository.instance.setShareLocation(bella.uid, true);
    await UserRepository.instance.updateLocation(bella.uid, 13.7563, 100.5018);

    await signInAs(ali);
    var b = (await UserRepository.instance.fetchProfile(bella.uid))!;
    expect(b.shareLocation, isTrue);
    expect(b.lastLat, closeTo(13.7563, 1e-6));

    await signInAs(bella);
    await UserRepository.instance.setShareLocation(bella.uid, false);
    await signInAs(ali);
    b = (await UserRepository.instance.fetchProfile(bella.uid))!;
    expect(b.shareLocation, isFalse);
  });

  testWidgets('TC57 A hotel can be saved into the itinerary before booking', (tester) async {
    await signInAs(ali);
    await repo.addHotelStay(
      tripId,
      const TripHotelStay(name: 'Siam Kempinski', location: 'Pathum Wan', checkIn: '10 Dec 2026', checkOut: '12 Dec 2026'),
      actorUid: ali.uid,
    );
    final trip = (await repo.getTrip(tripId, ali.uid))!;
    expect(trip.hotelStays.map((h) => h.name), contains('Siam Kempinski'));
  });

  testWidgets('TC54 Live conditions: real weather for the destination', (tester) async {
    // Live check against Open-Meteo (needs internet on the device).
    final weather = await WeatherService.instance.forDestination('Kuala Lumpur');
    expect(weather, isNotNull, reason: 'Open-Meteo returned no weather');
    expect(weather!.tempC, inInclusiveRange(-30, 50));
  });

  testWidgets('TC65 A change made offline syncs once the connection is back (NFR B-ii)', (tester) async {
    await signInAs(ali);
    await FirebaseFirestore.instance.disableNetwork();
    final pending = repo.addActivity(tripId, 2, time: '20:00', label: 'Night market (added offline)', iconKey: 'food');
    await Future<void>.delayed(const Duration(seconds: 2));
    await FirebaseFirestore.instance.enableNetwork();
    await pending.timeout(const Duration(seconds: 30));

    final onServer = await ownerGet('trips/$tripId');
    final day3 = Map<String, dynamic>.from((onServer!['days'] as Map)['2'] as Map);
    final labels = Map<String, dynamic>.from(day3['items'] as Map).values.map((i) => (i as Map)['label']);
    expect(labels, contains('Night market (added offline)'));
  });

  testWidgets('TC66 Two members editing the same day at once keep both changes (NFR C-ii)', (tester) async {
    await signInAs(ali);
    await Future.wait([
      repo.addActivity(tripId, 2, time: '09:00', label: 'Breakfast at Ali\'s pick', iconKey: 'food'),
      repo.addActivity(tripId, 2, time: '09:30', label: 'Temple at Bella\'s pick', iconKey: 'place'),
    ]);
    final trip = (await repo.getTrip(tripId, ali.uid))!;
    final day3 = trip.days[2].items.map((i) => i.label).toList();
    expect(day3, containsAll(['Breakfast at Ali\'s pick', 'Temple at Bella\'s pick']));
    expect(day3.where((l) => l == 'Breakfast at Ali\'s pick'), hasLength(1), reason: 'no duplicates');
  });

  testWidgets('TC69 Only the owner can delete the whole group (FR12)', (tester) async {
    await signInAs(bella);
    await expectLater(repo.deleteTrip(tripId, bella.uid), throwsA(isA<Exception>()));

    await signInAs(ali);
    await repo.deleteTrip(tripId, ali.uid);
    expect(await ownerGet('trips/$tripId'), isNull);
    expect(await ownerList('trips/$tripId/messages'), isEmpty);
  });
}
