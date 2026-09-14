import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';

/// Controller for [ExpensesTab] (Groups / Personal toggle). "Groups" streams
/// this trip's own expenses; "Personal" streams every expense the
/// signed-in user participates in, across every trip.
class ExpensesTabController extends ChangeNotifier {
  final String tripId;
  ExpensesTabController({required this.tripId}) {
    _groupSub = TripRepository.instance.watchExpenses(tripId).listen((list) {
      _groupExpenses = list;
      _loading = false;
      notifyListeners();
    });
    final uid = _uid;
    if (uid.isNotEmpty) {
      _personalSub = TripRepository.instance.watchMyExpenses(uid).listen((list) {
        _personalExpenses = list;
        notifyListeners();
      });
    }
  }

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  bool _personal = false;
  bool get personal => _personal;
  void setPersonal(bool value) {
    _personal = value;
    notifyListeners();
  }

  bool _loading = true;
  bool get loading => _loading;

  List<TripExpense> _groupExpenses = [];
  List<TripExpense> _personalExpenses = [];

  StreamSubscription<List<TripExpense>>? _groupSub;
  StreamSubscription<List<TripExpense>>? _personalSub;

  List<TripExpense> get visibleExpenses => _personal ? _personalExpenses : _groupExpenses;

  double get totalExpenses => visibleExpenses.fold(0.0, (s, e) => s + e.amount);

  /// What the signed-in user still owes (their unpaid share of bills
  /// someone else paid).
  double get youOwe => visibleExpenses.fold(0.0, (s, e) {
        if (e.paidBy == _uid) return s;
        return s + e.participants.where((p) => p.uid == _uid && !p.paid).fold(0.0, (s2, p) => s2 + p.share);
      });

  /// What others still owe the signed-in user (for bills they paid).
  double get youAreOwed => visibleExpenses.fold(0.0, (s, e) {
        if (e.paidBy != _uid) return s;
        return s + e.participants.where((p) => p.uid != _uid && !p.paid).fold(0.0, (s2, p) => s2 + p.share);
      });

  int get unsettledCount => visibleExpenses.where((e) => e.participants.any((p) => !p.paid)).length;

  /// Category -> total amount, for the simple breakdown bar list.
  Map<String, double> get byCategory {
    final map = <String, double>{};
    for (final e in visibleExpenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> setParticipantPaid(TripExpense expense, bool paid) {
    return TripRepository.instance.setParticipantPaid(expense.tripId, expense.id, _uid, paid);
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _personalSub?.cancel();
    super.dispose();
  }
}

/// One line item on a scanned/entered receipt, with who it's split between.
class ReceiptItem {
  String label;
  double price;
  Set<String> assigneeUids;
  ReceiptItem({required this.label, required this.price, Set<String>? assigneeUids})
      : assigneeUids = assigneeUids ?? {};
}

/// Shared state for the whole "Add Expense" flow (Add Expense Choice ->
/// Itemized Split / Expense Details Form -> Split Friends), so the amount,
/// category and participants entered on one page are still there on the
/// next. Created once by [AddExpenseChoicePage] and passed down; only that
/// page disposes it.
class AddExpenseController extends ChangeNotifier {
  final String tripId;
  final Trip trip;
  AddExpenseController({required this.tripId, required this.trip}) {
    selectedUids = trip.memberIds.toSet();
  }

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String location = 'Unknown';
  String category = 'Food & Drinks';
  bool reminder = true;

  /// True = split the entered [amountController] amount equally between
  /// [selectedUids]; false = itemized split driven by [items].
  bool splitEqually = true;
  late Set<String> selectedUids;
  final List<ReceiptItem> items = [];

  bool _submitting = false;
  bool get submitting => _submitting;

  void setTitle(String v) {
    titleController.text = v;
    notifyListeners();
  }

  void setAmountText(String v) {
    amountController.text = v;
    notifyListeners();
  }

  void setNote(String v) {
    noteController.text = v;
    notifyListeners();
  }

  void setLocation(String v) {
    location = v;
    notifyListeners();
  }

  void setCategory(String v) {
    category = v;
    notifyListeners();
  }

  void setReminder(bool v) {
    reminder = v;
    notifyListeners();
  }

  void setSplitEqually(bool v) {
    splitEqually = v;
    notifyListeners();
  }

  void setSelectedUids(Set<String> uids) {
    selectedUids = uids;
    notifyListeners();
  }

  void addItem(String label, double price) {
    items.add(ReceiptItem(label: label, price: price));
    notifyListeners();
  }

  void setItemAssignees(int index, Set<String> uids) {
    items[index].assigneeUids = uids;
    notifyListeners();
  }

  double get amount {
    if (splitEqually) return double.tryParse(amountController.text.trim()) ?? 0;
    return items.fold(0.0, (s, i) => s + i.price);
  }

  Map<String, double> _computeShares() {
    if (!splitEqually) {
      final map = <String, double>{};
      for (final item in items) {
        if (item.assigneeUids.isEmpty) continue;
        final per = item.price / item.assigneeUids.length;
        for (final uid in item.assigneeUids) {
          map[uid] = (map[uid] ?? 0) + per;
        }
      }
      return map;
    }
    final uids = selectedUids.isEmpty ? trip.memberIds.toSet() : selectedUids;
    if (uids.isEmpty) return {};
    final per = amount / uids.length;
    return {for (final u in uids) u: per};
  }

  Future<bool> submit() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
    final title = titleController.text.trim();
    final amt = amount;
    final shares = _computeShares();
    if (title.isEmpty || amt <= 0 || shares.isEmpty) return false;
    _submitting = true;
    notifyListeners();
    try {
      final myName = trip.memberNames[uid] ?? 'You';
      final participants = shares.entries
          .map((e) => ExpenseParticipant(
                uid: e.key,
                name: trip.memberNames[e.key] ?? 'Member',
                share: e.value,
                paid: e.key == uid,
              ))
          .toList();
      await TripRepository.instance.addExpense(
        tripId,
        tripName: trip.name,
        title: title,
        amount: amt,
        category: category,
        note: noteController.text.trim(),
        location: location,
        paidBy: uid,
        paidByName: myName,
        participants: participants,
      );
      return true;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }
}
