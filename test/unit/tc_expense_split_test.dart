// Executable test cases for the Shared-Expense Distribution Algorithm (4.8.4).
// Runs the real functions from lib/repositories/trip_repository.dart.
// Run: flutter test test/unit
import 'package:flutter_test/flutter_test.dart';
import 'package:voya/repositories/trip_repository.dart';

double _sum(Map<String, double> shares) =>
    shares.values.fold<int>(0, (n, v) => n + (v * 100).round()) / 100.0;

void main() {
  group('TC16 Equal split with remainder', () {
    test('TC16 RM10.00 among 3 members gives 3.34 / 3.33 / 3.33', () {
      final shares = splitExpenseEqual(10.00, ['ali', 'bella', 'chong']);
      expect(shares['ali'], 3.34);
      expect(shares['bella'], 3.33);
      expect(shares['chong'], 3.33);
      expect(_sum(shares), 10.00);
    });

    test('TC16 shares always add up to the exact total', () {
      for (final total in [0.01, 1.00, 99.99, 100.00, 1234.57]) {
        for (var n = 1; n <= 7; n++) {
          final uids = List.generate(n, (i) => 'u$i');
          expect(_sum(splitExpenseEqual(total, uids)), total, reason: 'total $total among $n');
        }
      }
    });
  });

  group('TC17 Custom split not matching total', () {
    test('TC17 RM100 with shares 40 + 40 is rejected', () {
      expect(() => splitExpenseCustom(100.00, {'ali': 40.00, 'bella': 40.00}), throwsArgumentError);
    });

    test('TC17 a negative custom share is rejected', () {
      expect(() => splitExpenseCustom(10.00, {'ali': 15.00, 'bella': -5.00}), throwsArgumentError);
    });

    test('TC17 shares that do add up are accepted unchanged', () {
      expect(splitExpenseCustom(10.00, {'ali': 3.33, 'bella': 3.33, 'chong': 3.34}),
          {'ali': 3.33, 'bella': 3.33, 'chong': 3.34});
    });
  });

  group('TC18 Negative or zero amount', () {
    test('TC18 RM0.00 is rejected', () {
      expect(() => splitExpenseEqual(0, ['ali', 'bella']), throwsArgumentError);
    });

    test('TC18 RM-5.00 is rejected', () {
      expect(() => splitExpenseEqual(-5, ['ali', 'bella']), throwsArgumentError);
    });

    test('TC18 an expense with no members is rejected', () {
      expect(() => splitExpenseEqual(10, []), throwsArgumentError);
    });
  });

  group('TC58 Per-item split', () {
    test('TC58 each member pays the sum of their own items', () {
      final shares = splitExpenseItemized([
        (price: 12.00, assigneeUids: {'ali'}),
        (price: 9.00, assigneeUids: {'bella', 'chong'}),
        (price: 10.00, assigneeUids: {'ali', 'bella', 'chong'}),
      ]);
      expect(shares['ali'], closeTo(12.00 + 3.34, 0.001));
      expect(shares['bella'], closeTo(4.50 + 3.33, 0.001));
      expect(shares['chong'], closeTo(4.50 + 3.33, 0.001));
      expect(_sum(shares), 31.00);
    });

    test('TC58 an item nobody is assigned to is rejected', () {
      expect(
        () => splitExpenseItemized([(price: 5.00, assigneeUids: <String>{})]),
        throwsArgumentError,
      );
    });
  });
}
