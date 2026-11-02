// Group Voting (4.8.5) and Shared Expenses (4.8.4) against the emulators -
// TC12, TC13, TC14, TC15, TC16, TC17, TC19, TC20, TC73 (FR60 payment reminder).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/repositories/notifications_repository.dart';
import 'package:voya/repositories/trip_repository.dart';

import 'helpers/test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestUser ali, bella, chong, outsider;
  late String tripId;
  final repo = TripRepository.instance;

  Future<TripVote> pollTitled(String title) async =>
      (await repo.watchVotes(tripId).first).firstWhere((v) => v.title == title);

  setUpAll(() async {
    await initTestEnv();
    await resetEmulators();
    outsider = await createTraveller('Outsider Olly');
    chong = await createTraveller('Chong');
    bella = await createTraveller('Bella');
    ali = await createTraveller('Ali');
    tripId = await repo.createTrip(
      ownerId: ali.uid,
      ownerName: ali.name,
      name: 'KL Getaway',
      destination: 'Kuala Lumpur, Malaysia',
      startDate: DateTime(2026, 12, 10),
      endDate: DateTime(2026, 12, 12),
      budgetPerPerson: 1500,
      interests: const ['Food'],
      extraMembers: {bella.uid: bella.name, chong.uid: chong.name},
    );
  });

  // ---------------------------------------------------------------- voting
  testWidgets('TC12 Create a poll with options from the saved list', (tester) async {
    await signInAs(ali);
    await repo.createVote(tripId,
        title: 'Day 2 lunch',
        options: const ['Madam Kwan\'s', 'Jalan Alor', 'Village Park'],
        allowAddOptions: true,
        allowMultipleChoice: false,
        createdBy: ali.uid);

    await signInAs(bella);
    final poll = await pollTitled('Day 2 lunch');
    expect(poll.options.map((o) => o.label).toSet(), {'Madam Kwan\'s', 'Jalan Alor', 'Village Park'});
    expect(poll.isClosed, isFalse);
  });

  testWidgets('TC13 Casting a vote adds one to that option', (tester) async {
    await signInAs(bella);
    final poll = await pollTitled('Day 2 lunch');
    final option = poll.options.firstWhere((o) => o.label == 'Jalan Alor');

    await repo.castVote(tripId, poll, option.id, bella.uid);

    final after = await pollTitled('Day 2 lunch');
    expect(after.options.firstWhere((o) => o.id == option.id).votedBy, [bella.uid]);
  });

  testWidgets('TC14 A second vote on a single-choice poll is rejected', (tester) async {
    await signInAs(bella);
    final poll = await pollTitled('Day 2 lunch');
    final other = poll.options.firstWhere((o) => o.label == 'Village Park');

    await expectLater(repo.castVote(tripId, poll, other.id, bella.uid), throwsA(isA<StateError>()));

    final after = await pollTitled('Day 2 lunch');
    expect(after.options.fold<int>(0, (n, o) => n + o.votedBy.length), 1, reason: 'counts unchanged');
  });

  testWidgets('TC14b Two members voting at the same time are both counted', (tester) async {
    await signInAs(ali);
    final poll = await pollTitled('Day 2 lunch');
    final option = poll.options.firstWhere((o) => o.label == 'Madam Kwan\'s');
    // Same account fires two casts at once: the transaction must let exactly one through.
    final results = await Future.wait([
      repo.castVote(tripId, poll, option.id, ali.uid).then((_) => 'ok').catchError((_) => 'rejected'),
      repo.castVote(tripId, poll, option.id, ali.uid).then((_) => 'ok').catchError((_) => 'rejected'),
    ]);
    expect(results.where((r) => r == 'ok'), hasLength(1));
    final after = await pollTitled('Day 2 lunch');
    expect(after.options.firstWhere((o) => o.id == option.id).votedBy, [ali.uid]);
  });

  testWidgets('TC15 Voting on a closed poll is rejected', (tester) async {
    await signInAs(ali);
    await repo.createVote(tripId,
        title: 'Closed poll',
        options: const ['A', 'B'],
        allowAddOptions: false,
        allowMultipleChoice: false,
        createdBy: ali.uid,
        deadline: DateTime.now().subtract(const Duration(hours: 1)));
    final poll = await pollTitled('Closed poll');
    expect(poll.isClosed, isTrue);

    await signInAs(chong);
    await expectLater(repo.castVote(tripId, poll, poll.options.first.id, chong.uid), throwsA(isA<StateError>()));
  });

  testWidgets('TC15b A non-member cannot vote', (tester) async {
    await signInAs(outsider);
    final poll = TripVote(
      id: (await ownerList('trips/$tripId/votes')).firstWhere((v) => v['title'] == 'Day 2 lunch')['id'] as String,
      title: 'Day 2 lunch',
      createdBy: ali.uid,
      allowAddOptions: true,
      allowMultipleChoice: false,
      options: const [],
      createdAt: null,
    );
    await expectLater(repo.castVote(tripId, poll, 'any', outsider.uid), throwsA(anything));
  });

  // -------------------------------------------------------------- expenses
  late String expenseId;

  testWidgets('TC16 Equal split RM10.00 among 3 is stored as 3.34 / 3.33 / 3.33', (tester) async {
    await signInAs(ali);
    final shares = splitExpenseEqual(10.00, [ali.uid, bella.uid, chong.uid]);
    final names = {ali.uid: ali.name, bella.uid: bella.name, chong.uid: chong.name};
    final stored = await repo.addExpense(
      tripId,
      tripName: 'KL Getaway',
      title: 'Teh tarik',
      amount: 10.00,
      category: 'Food',
      note: 'Teh tarik',
      location: 'Jalan Alor',
      paidBy: ali.uid,
      paidByName: ali.name,
      participants: [
        for (final e in shares.entries)
          ExpenseParticipant(uid: e.key, name: names[e.key]!, share: e.value, paid: e.key == ali.uid),
      ],
    );
    expect(stored[ali.uid], 3.34);
    expect(stored[bella.uid], 3.33);
    expect(stored[chong.uid], 3.33);

    await signInAs(bella);
    final expense = (await repo.watchExpenses(tripId).first).single;
    expenseId = expense.id;
    expect(expense.amount, 10.00);
    expect(expense.shareFor(bella.uid), 3.33);
    expect(expense.isSettled(bella.uid), isFalse);
  });

  testWidgets('TC17 Shares that do not add up to the amount are refused', (tester) async {
    await signInAs(ali);
    await expectLater(
      repo.addExpense(
        tripId,
        tripName: 'KL Getaway',
        title: 'Hotel',
        amount: 100,
        category: 'Accommodation',
        note: '',
        location: '',
        paidBy: ali.uid,
        paidByName: ali.name,
        participants: [
          ExpenseParticipant(uid: ali.uid, name: ali.name, share: 40, paid: true),
          ExpenseParticipant(uid: bella.uid, name: bella.name, share: 40, paid: false),
        ],
      ),
      throwsArgumentError,
    );
    expect((await repo.watchExpenses(tripId).first), hasLength(1), reason: 'nothing saved');
  });

  testWidgets('TC19 A member marks their share as settled', (tester) async {
    await signInAs(bella);
    await repo.setParticipantPaid(tripId, expenseId, bella.uid, true);
    final expense = (await repo.watchExpenses(tripId).first).firstWhere((e) => e.id == expenseId);
    expect(expense.isSettled(bella.uid), isTrue);
    expect(expense.isSettled(chong.uid), isFalse);
  });

  testWidgets('TC20 The payer replaces the receipt; other members cannot edit the expense', (tester) async {
    await signInAs(ali);
    var expense = (await repo.watchExpenses(tripId).first).firstWhere((e) => e.id == expenseId);
    await repo.updateExpense(expense,
        title: expense.title,
        amount: expense.amount,
        category: expense.category,
        note: expense.note,
        receiptImageUrl: 'https://example.com/receipt2.jpg');
    expense = (await repo.watchExpenses(tripId).first).firstWhere((e) => e.id == expenseId);
    expect(expense.receiptImageUrl, 'https://example.com/receipt2.jpg');

    await signInAs(chong);
    await expectDenied(
      () => repo.updateExpense(expense,
          title: 'changed by Chong', amount: expense.amount, category: 'Food', note: '', receiptImageUrl: ''),
      reason: 'only the payer edits an expense',
    );
  });

  testWidgets('TC73 Payment reminder notifies only members who have not paid (FR60)', (tester) async {
    await signInAs(ali);
    final sent = await repo.sendPaymentReminder(tripId, expenseId);
    expect(sent, 1, reason: 'Bella already paid, Ali is the payer - only Chong is reminded');

    await signInAs(chong);
    final inbox = await NotificationsRepository.instance.watch(chong.uid).first;
    expect(inbox.any((n) => n.type == 'trip_expense_payment_reminder'), isTrue);
    await signInAs(bella);
    final bellaInbox = await NotificationsRepository.instance.watch(bella.uid).first;
    expect(bellaInbox.any((n) => n.type == 'trip_expense_payment_reminder'), isFalse);
  });
}
