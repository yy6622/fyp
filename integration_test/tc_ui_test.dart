// UI-driven test cases that used to be manual:
//   TC08  Edit Plan: leaving with unsaved changes asks to save or discard.
//   TC63  NFR A-i: each main screen responds within 2 seconds.
//   TC68  NFR E-ii: Explore, Profile, Community and Expenses within 3 taps of Home.
// They pump the real screens (MainPage, GroupTripPage) against the emulators.
// Times are measured on the Android emulator, which is slower than a phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/controllers/create_plan_wizard_controller.dart';
import 'package:voya/repositories/trip_repository.dart';
import 'package:voya/theme.dart';
import 'package:voya/views/community/community_page.dart';
import 'package:voya/views/explore/explore_page.dart';
import 'package:voya/views/group/group_trip_page.dart';
import 'package:voya/views/home/home_page.dart';
import 'package:voya/views/plan/plan_page.dart';
import 'package:voya/views/profile/profile_page.dart';
import 'package:voya/views/shared/bottom_nav.dart';

import 'helpers/test_env.dart';

const destination = 'Tioman Island';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestUser user;
  late String tripId;

  setUpAll(() async {
    await initTestEnv();
    await resetEmulators();
    user = await createTraveller('Ui Tester');
    final w = CreatePlanWizardController();
    w.tripNameController.text = 'UI Test Trip';
    w.setDestination(destination);
    final start = DateTime.now().add(const Duration(days: 3));
    w.setStartDate(DateTime(start.year, start.month, start.day));
    w.setEndDate(DateTime(start.year, start.month, start.day).add(const Duration(days: 2)));
    tripId = await w.createTrip();
    w.dispose();
    await TripRepository.instance.addActivity(tripId, 0, time: '10:00', label: 'Snorkelling at Coral Bay', iconKey: 'activity');
    await TripRepository.instance.addActivity(tripId, 0, time: '14:00', label: 'Juara Beach', iconKey: 'place');
  });

  // The bottom bar shows a text label only on the selected tab, so tap the icon.
  const navIcons = {
    'Home': 'assets/images/nav_home.png',
    'Explore': 'assets/images/nav_compass.png',
    'Plan': 'assets/images/nav_plan.png',
    'Profile': 'assets/images/nav_account.png',
  };
  Finder navTab(String label) =>
      find.byWidgetPredicate((w) => w is AppImage && w.asset == navIcons[label], description: '$label tab');

  testWidgets('TC08 Leaving Edit Plan with unsaved changes asks to save or discard', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('previous screen'))));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => GroupTripPage(tripId: tripId)));
    // A trip opens on Overview; the day pager at the bottom opens Day 1.
    await pumpUntil(tester, find.text('Day 1'));
    await tester.tap(find.text('Day 1').last);
    await pumpUntil(tester, find.text('Snorkelling at Coral Bay'));

    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await pumpUntil(tester, find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Unsaved:'), findsOneWidget, reason: 'the change is only a draft');

    await nav.currentState!.maybePop(); // the back button
    await pumpUntil(tester, find.text('Save your changes?'));
    expect(find.text('Save your changes?'), findsOneWidget);
    expect(find.text('previous screen').hitTestable(), findsNothing, reason: 'the page did not close');
  });

  testWidgets('TC63 Home, Explore, Plan and Profile each respond within 2 seconds (NFR A-i)', (tester) async {
    final times = <String, Duration>{};
    final open = Stopwatch()..start();
    await tester.pumpWidget(const MaterialApp(home: MainPage()));
    await pumpUntil(tester, find.text(destination).hitTestable());
    times['Home (with the next trip loaded)'] = open.elapsed;

    final screens = {'Explore': ExplorePage, 'Plan': PlanPage, 'Profile': ProfilePage, 'Home': HomePage};
    for (final e in screens.entries) {
      final watch = Stopwatch()..start();
      await tester.tap(navTab(e.key));
      await pumpUntil(tester, find.byType(e.value).hitTestable(), step: const Duration(milliseconds: 16));
      times[e.key] = watch.elapsed;
    }
    for (final e in times.entries) {
      debugPrint('[TC63] ${e.key}: ${e.value.inMilliseconds} ms');
      expect(e.value.inMilliseconds, lessThan(2000), reason: '${e.key} took ${e.value.inMilliseconds} ms');
    }
  });

  testWidgets('TC68 Explore, Profile, Community and Expenses are within 3 taps of Home (NFR E-ii)', (tester) async {
    Future<int> reach(List<Finder Function()> taps, Finder target) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: MainPage()));
      await pumpUntil(tester, find.text(destination).hitTestable());
      var count = 0;
      for (final f in taps) {
        final finder = f();
        await pumpUntil(tester, finder);
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(finder);
        count++;
        await tester.pump(const Duration(milliseconds: 400));
      }
      await pumpUntil(tester, target);
      return count;
    }

    final taps = <String, int>{
      'Explore': await reach([() => navTab('Explore')], find.byType(ExplorePage).hitTestable()),
      'Profile': await reach([() => navTab('Profile')], find.byType(ProfilePage).hitTestable()),
      'Community': await reach([() => find.text('View All').first], find.byType(CommunityPage)),
      'Expenses': await reach(
        [() => find.text(destination).first, () => find.text('Expenses').first],
        find.byType(FloatingActionButton), // only shown on the Expenses tab
      ),
    };
    for (final e in taps.entries) {
      debugPrint('[TC68] ${e.key}: ${e.value} tap(s)');
      expect(e.value, lessThanOrEqualTo(3), reason: '${e.key} needs ${e.value} taps');
    }
  });
}
