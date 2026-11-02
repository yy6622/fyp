import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';
import '../services/receipt_ocr_service.dart';
import '../services/receipt_service.dart';

class ExpensesTabController extends ChangeNotifier {
  final String tripId;
  ExpensesTabController({required this.tripId}) {
    _groupSub = TripRepository.instance.watchExpenses(tripId).listen((list) {
      _groupExpenses = list;
      _loading = false;
      notifyListeners();
    });
    _tripSub = TripRepository.instance.watchTrip(tripId, _uid).listen((t) {
      _trip = t;
      notifyListeners();
    });
  }

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  Trip? _trip;
  Trip? get trip => _trip;

  bool _personal = false;
  bool get personal => _personal;
  void setPersonal(bool value) {
    _personal = value;
    notifyListeners();
  }

  bool _loading = true;
  bool get loading => _loading;

  List<TripExpense> _groupExpenses = [];

  StreamSubscription<List<TripExpense>>? _groupSub;
  StreamSubscription<Trip?>? _tripSub;

  List<TripExpense> get _personalExpenses =>
      _groupExpenses.where((e) => e.participants.any((p) => p.uid == _uid)).toList();

  List<TripExpense> get visibleExpenses => _personal ? _personalExpenses : _groupExpenses;

  double myShareOf(TripExpense e) => e.participants.where((p) => p.uid == _uid).fold(0.0, (s, p) => s + p.share);

  double displayAmount(TripExpense e) => _personal ? myShareOf(e) : e.amount;

  double get totalExpenses => visibleExpenses.fold(0.0, (s, e) => s + displayAmount(e));

  int get totalBillsCount => _groupExpenses.length;

  double get youOwe => visibleExpenses.fold(0.0, (s, e) {
        if (e.paidBy == _uid) return s;
        return s + e.participants.where((p) => p.uid == _uid && !p.paid).fold(0.0, (s2, p) => s2 + p.share);
      });

  double get youAreOwed => visibleExpenses.fold(0.0, (s, e) {
        if (e.paidBy != _uid) return s;
        return s + e.participants.where((p) => p.uid != _uid && !p.paid).fold(0.0, (s2, p) => s2 + p.share);
      });

  bool isSettled(TripExpense e) => e.participants.isNotEmpty && e.participants.every((p) => p.paid);

  int get unsettledCount => visibleExpenses.where((e) => !isSettled(e)).length;

  int get settledCount => visibleExpenses.where(isSettled).length;

  double get settledFraction {
    final total = visibleExpenses.fold(0.0, (s, e) => s + e.participants.fold(0.0, (s2, p) => s2 + p.share));
    if (total <= 0) return visibleExpenses.isEmpty ? 0.5 : 1.0;
    final paid = visibleExpenses.fold(0.0, (s, e) => s + e.participants.where((p) => p.paid).fold(0.0, (s2, p) => s2 + p.share));
    return (paid / total).clamp(0.0, 1.0);
  }

  Map<String, double> get byCategory {
    final map = <String, double>{};
    for (final e in visibleExpenses) {
      map[e.category] = (map[e.category] ?? 0) + displayAmount(e);
    }
    return map;
  }

  Future<void> setParticipantPaid(TripExpense expense, bool paid) {
    return TripRepository.instance.setParticipantPaid(expense.tripId, expense.id, _uid, paid);
  }

  ExpensesReportSnapshot snapshotFor(bool personal) {
    final visible = personal ? _personalExpenses : _groupExpenses;
    double amountOf(TripExpense e) => personal ? myShareOf(e) : e.amount;
    bool settledOf(TripExpense e) => e.participants.isNotEmpty && e.participants.every((p) => p.paid);

    final rows = visible.map((e) => ExpenseReportRow(expense: e, amount: amountOf(e), settled: settledOf(e))).toList();
    final totalExpenses = rows.fold(0.0, (s, r) => s + r.amount);
    final unsettledCount = rows.where((r) => !r.settled).length;
    final settledCount = rows.where((r) => r.settled).length;

    double youOwe = 0, youAreOwed = 0;
    for (final e in visible) {
      if (e.paidBy == _uid) {
        youAreOwed += e.participants.where((p) => p.uid != _uid && !p.paid).fold(0.0, (s, p) => s + p.share);
      } else {
        youOwe += e.participants.where((p) => p.uid == _uid && !p.paid).fold(0.0, (s, p) => s + p.share);
      }
    }

    final byCategory = <String, double>{};
    for (final r in rows) {
      byCategory[r.expense.category] = (byCategory[r.expense.category] ?? 0) + r.amount;
    }

    final memberCount = _trip?.memberIds.length ?? 0;
    final perPersonBudget = _trip?.budgetPerPerson ?? 0;
    final tripBudget = personal ? perPersonBudget : perPersonBudget * memberCount;

    return ExpensesReportSnapshot(
      trip: _trip,
      personal: personal,
      generatedForUid: _uid,
      generatedForName: _trip?.memberNames[_uid] ?? 'You',
      memberCount: memberCount,
      rows: rows,
      totalExpenses: totalExpenses,
      totalBillsCount: _groupExpenses.length,
      settledCount: settledCount,
      unsettledCount: unsettledCount,
      youOwe: youOwe,
      youAreOwed: youAreOwed,
      byCategory: byCategory,
      tripBudget: tripBudget,
      dailyTotals: _dailyTotalsFor(rows),
    );
  }

  List<MapEntry<DateTime, double>> _dailyTotalsFor(List<ExpenseReportRow> rows) {
    DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final byDay = <DateTime, double>{};
    for (final r in rows) {
      final d = r.expense.date;
      if (d == null) continue;
      final key = dayOnly(d);
      byDay[key] = (byDay[key] ?? 0) + r.amount;
    }
    final start = _trip?.startDate;
    final end = _trip?.endDate;
    if (start != null && end != null && !end.isBefore(start)) {
      final days = <MapEntry<DateTime, double>>[];
      var cur = dayOnly(start);
      final last = dayOnly(end);
      while (!cur.isAfter(last)) {
        days.add(MapEntry(cur, byDay[cur] ?? 0));
        cur = cur.add(const Duration(days: 1));
      }
      return days;
    }
    final entries = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _tripSub?.cancel();
    super.dispose();
  }
}

class ExpenseReportRow {
  final TripExpense expense;
  final double amount;
  final bool settled;
  const ExpenseReportRow({required this.expense, required this.amount, required this.settled});
}

class ExpensesReportSnapshot {
  final Trip? trip;
  final bool personal;
  final String generatedForUid;
  final String generatedForName;
  final int memberCount;
  final List<ExpenseReportRow> rows;
  final double totalExpenses;
  final int totalBillsCount;
  final int settledCount;
  final int unsettledCount;
  final double youOwe;
  final double youAreOwed;
  final Map<String, double> byCategory;
  final double tripBudget;
  final List<MapEntry<DateTime, double>> dailyTotals;
  const ExpensesReportSnapshot({
    required this.trip,
    required this.personal,
    required this.generatedForUid,
    required this.generatedForName,
    required this.memberCount,
    required this.rows,
    required this.totalExpenses,
    required this.totalBillsCount,
    required this.settledCount,
    required this.unsettledCount,
    required this.youOwe,
    required this.youAreOwed,
    required this.byCategory,
    required this.tripBudget,
    required this.dailyTotals,
  });

  double get remainingBudget => tripBudget - totalExpenses;
}

class ReceiptItem {
  String label;
  double price;
  Set<String> assigneeUids;
  ReceiptItem({required this.label, required this.price, Set<String>? assigneeUids})
      : assigneeUids = assigneeUids ?? {};
}

class AddExpenseController extends ChangeNotifier {
  final String tripId;
  final Trip trip;
  AddExpenseController({required this.tripId, required this.trip}) {
    selectedUids = trip.memberIds.toSet();
    if (trip.destination.trim().isNotEmpty) location = trip.destination.trim();
  }

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String location = 'Unknown';
  String category = 'Food & Drinks';
  bool reminder = true;

  File? receiptImage;
  void setReceiptImage(File? file) {
    receiptImage = file;
    notifyListeners();
  }

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

  void removeItem(int index) {
    items.removeAt(index);
    notifyListeners();
  }

  void editItem(int index, String label, double price) {
    items[index].label = label;
    items[index].price = price;
    notifyListeners();
  }

  void setItemAssignees(int index, Set<String> uids) {
    items[index].assigneeUids = uids;
    notifyListeners();
  }

  bool _scanningReceipt = false;
  bool get scanningReceipt => _scanningReceipt;

  Future<String> scanReceipt() async {
    final photo = receiptImage;
    if (photo == null) return '';
    _scanningReceipt = true;
    notifyListeners();
    try {
      final result = await ReceiptOcrService.instance.scan(photo);
      if (result.items.isNotEmpty) {
        items
          ..clear()
          ..addAll(result.items.map((i) => ReceiptItem(label: i.label, price: i.price)));
        splitEqually = false;
        return 'Found ${items.length} item${items.length == 1 ? '' : 's'} on your receipt — '
            'review them and pick who\'s splitting each one.';
      }
      if (result.total != null) {
        amountController.text = result.total!.toStringAsFixed(2);
        return 'Found a total of RM ${result.total!.toStringAsFixed(2)} — review it and choose who to split with.';
      }
      if (result.error != null) {
        return "Couldn't scan this receipt (${result.error}) — please enter the details manually.";
      }
      return "Couldn't read this receipt automatically — please enter the details manually.";
    } finally {
      _scanningReceipt = false;
      notifyListeners();
    }
  }

  double get amount {
    if (splitEqually) return double.tryParse(amountController.text.trim()) ?? 0;
    return items.fold(0.0, (s, i) => s + i.price);
  }

  Map<String, double> _computeShares() {
    if (!splitEqually) {
      if (items.isEmpty || items.any((i) => i.assigneeUids.isEmpty)) return {};
      return splitExpenseItemized([for (final i in items) (price: i.price, assigneeUids: i.assigneeUids)]);
    }
    final uids = selectedUids.isEmpty ? trip.memberIds.toSet() : selectedUids;
    if (uids.isEmpty || amount <= 0) return {};
    return splitExpenseEqual(amount, uids.toList());
  }

  Future<bool> submit() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
    final title = noteController.text.trim();
    final amt = amount;
    final shares = _computeShares();
    if (amt <= 0 || amt > 1000000 || shares.isEmpty) return false;
    if (!splitEqually && items.any((i) => i.assigneeUids.isEmpty)) return false;
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
      var receiptImageUrl = '';
      final photo = receiptImage;
      if (photo != null) {
        receiptImageUrl = await ReceiptService.instance.upload(tripId, uid, photo);
      }
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
        receiptImageUrl: receiptImageUrl,
        sendReminder: reminder,
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
