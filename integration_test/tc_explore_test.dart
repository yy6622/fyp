// Travel Discovery Module - TC23 (search with no results), driven through the
// real Explore screen: type into the search bar, switch to Attractions, and
// check the empty-state message instead of an error.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/views/explore/explore_page.dart';

import 'helpers/test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestEnv();
    await resetEmulators();
    await createTraveller('Explorer Eve');
  });

  testWidgets('TC23 Searching an unknown place shows "No result" instead of an error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExplorePage()));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Attractions').first);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, 'xyzabc123qq');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    final emptyMessage = find.text('No attractions found — try a different search.');
    for (var i = 0; i < 80 && emptyMessage.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(emptyMessage, findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
