import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/country_gateways.dart';
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
      // A solo trip has no one to split a bill with, so "Group" vs
      // "Personal" is a distinction without a difference — force personal
      // view so the UI doesn't offer a switch that changes nothing.
      if (t != null && t.memberIds.length <= 1) _personal = true;
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

  /// A native-currency amount must not be added to an amount in another
  /// currency. Older transactions without a label are treated as unknown.
  bool get hasMixedCurrencies => _hasMixedCurrenciesFor(visibleExpenses);

  bool _hasMixedCurrenciesFor(List<TripExpense> expenses) {
    final codes = expenses.map((expense) {
      final match = RegExp(r'Currency:\s*([A-Z]{3})\b', caseSensitive: false).firstMatch(expense.note);
      if (match != null) return match.group(1)!.toUpperCase();
      // Old scans that explicitly said they were converted to RM were
      // already stored in MYR; don't infer their original currency.
      if (expense.note.contains('converted to RM')) return 'MYR';
      return 'UNKNOWN';
    }).toSet();
    return codes.length > 1;
  }

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
      hasMixedCurrencies: _hasMixedCurrenciesFor(visible),
      budgetComparable: visible.isEmpty || visible.every((e) {
        final match = RegExp(r'Currency:\s*([A-Z]{3})\b', caseSensitive: false).firstMatch(e.note);
        return match?.group(1)?.toUpperCase() == 'MYR' || e.note.contains('converted to RM');
      }),
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
  final bool hasMixedCurrencies;
  final bool budgetComparable;
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
    required this.hasMixedCurrencies,
    required this.budgetComparable,
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
    if (trip.memberIds.length <= 1) reminder = false;
    noteController.text = 'Currency: ${currencyForDestination(trip.destination) ?? 'Unknown (please edit)'}';
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

  // No default on purpose -- a multi-member trip must explicitly pick
  // Equally vs Itemized rather than silently inheriting "Equally"; a
  // solo trip never shows this choice at all (see the `memberIds.length
  // > 1` guard in expense_details_form_page.dart) so it just stays null
  // and is treated the same as "Equally" everywhere below.
  bool? splitEqually;
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
      // Destination is only a fallback when the receipt does not print a currency.
      final localCurrency = currencyForDestination(trip.destination);
      final result = await ReceiptOcrService.instance.scan(photo, localCurrency: localCurrency);

      // Prefill the title from the store name -- only when the traveller
      // hasn't already typed one, so a re-scan never clobbers their own
      // edit. This is a best-effort OCR guess (ReceiptOcrService.storeName
      // docs its limits), so it's left fully editable either way.
      if (result.storeName != null && titleController.text.trim().isEmpty) {
        titleController.text = result.storeName!;
      }
      // Make the original, unconverted currency explicit in Note.
      final code = result.currencyCode ?? localCurrency;
      final currencyNote = 'Currency: ${code ?? 'Unknown (please edit)'}';
      final currentNote = noteController.text.trim();
      final currencyLine = RegExp(r'Currency:\s*[^\n\r]*', caseSensitive: false);
      if (currencyLine.hasMatch(currentNote)) {
        noteController.text = currentNote.replaceFirst(currencyLine, currencyNote);
      } else {
        noteController.text = currentNote.isEmpty ? currencyNote : '$currentNote\n$currencyNote';
      }
      // Only while category is still at its untouched default -- never
      // overrides a category the traveller already picked themselves.
      if (category == 'Food & Drinks' && result.guessedCategory != null) {
        category = result.guessedCategory!;
      }
      final consistencyNote = result.looksConsistent
          ? ''
          : ' (the amounts on this scan don\'t quite add up — please double-check them)';
      // A voucher/loyalty/coupon discount isn't something any one item or
      // person "owns" either, same as tax -- it's split equally across
      // every trip member rather than pro-rated per item, so it's called
      // out here once rather than silently folded into a smaller total.
      final discountNote = (result.discount ?? 0) > 0.01
          ? ' (${result.discount!.toStringAsFixed(2)} voucher/loyalty discount applied, split equally)'
          : '';

      if (result.items.isNotEmpty) {
        if (trip.memberIds.length <= 1) {
          // Solo trip: there's no one to itemize a split between, and the
          // whole "Split Equally / Itemized" row (plus the only way to
          // reach the per-item assignee picker) is hidden for a 1-member
          // trip -- see expense_details_form_page.dart's `memberIds.length
          // > 1` guard. Switching into itemized mode here would leave every
          // item's assigneeUids permanently empty with no UI left to fix
          // it, which is exactly the "every item needs someone to pay for
          // it" dead end this used to hit. Just total the scanned items
          // instead and stay in (the only available) Split Equally mode.
          final sum = (result.items.fold<double>(0, (s, i) => s + i.price) + (result.additionalTax) - (result.discount ?? 0))
              .clamp(0.0, double.infinity);
          amountController.text = sum.toStringAsFixed(2);
          return 'Found ${result.items.length} item${result.items.length == 1 ? '' : 's'} on your receipt, '
              'totalling ${sum.toStringAsFixed(2)}$consistencyNote$discountNote — review it before saving.';
        }
        items
          ..clear()
          ..addAll(result.items.map((i) => ReceiptItem(label: i.label, price: i.price)));
        // Tax/GST/SST/service-charge lines are deliberately excluded from
        // the item list above (they're not something any one item/person
        // "owns"), but they're real money that was paid. ReceiptOcrService
        // now tags that figure directly as `tax` when it recognised a
        // dedicated tax/charge line; fall back to "total minus item sum"
        // only when it didn't (e.g. a receipt that prints just one grand
        // total with no separate tax line) so the difference isn't
        // silently lost either way. The discount (if any) is added back
        // on here first, since `result.total` is already net of it --
        // without that, a discounted receipt with no separate tax line
        // would make this fallback read as a smaller (or even negative)
        // "tax" than was really charged.
        final itemSum = result.items.fold<double>(0, (s, i) => s + i.price);
        final extra = result.tax != null
            ? result.additionalTax
            : ((result.total != null ? result.total! - itemSum : 0.0) + (result.discount ?? 0));
        if (extra > 0.01) {
          items.add(ReceiptItem(label: 'Tax & Service Charge', price: extra, assigneeUids: trip.memberIds.toSet()));
        }
        // Voucher/loyalty discount, split equally across every member --
        // see discountNote above. Stored as a negative-price item so the
        // itemized total (items.fold) nets out to what was actually paid,
        // same mechanism tax above uses, just subtracting instead of
        // adding.
        if ((result.discount ?? 0) > 0.01) {
          items.add(ReceiptItem(label: 'Voucher/Loyalty Discount', price: -result.discount!, assigneeUids: trip.memberIds.toSet()));
        }
        // Deliberately NOT setting splitEqually here. Every split choice on
        // this form is meant to be an explicit tap, never a silent default
        // (see the field's own doc comment above, and
        // expense_details_form_page.dart's `splitEqually == null` ->
        // "Choose a split method" submit guard) -- a scan shouldn't be the
        // one path that quietly skips that. The items list is already
        // populated, so picking "Itemized" afterwards shows them exactly
        // as scanned; nothing is lost by waiting for that tap.
        return 'Found ${items.length} item${items.length == 1 ? '' : 's'} on your receipt$consistencyNote$discountNote — '
            'choose a split method to review them.';
      }
      if (result.total != null) {
        amountController.text = result.total!.toStringAsFixed(2);
        return 'Found a total of ${result.total!.toStringAsFixed(2)}$consistencyNote — review it and choose who to split with.';
      }
      if (result.error == 'not a receipt') {
        // Distinct from the generic failure below -- this fires when the
        // photo plainly has no price/total/tax text anywhere on it at
        // all, i.e. it's very likely not a receipt in the first place
        // (a selfie, a landscape, a random document), so the traveller
        // should be told that plainly instead of being left thinking the
        // scanner just glitched on a real receipt.
        return "That doesn't look like a receipt image. Please upload a photo of the actual receipt, or enter the details manually.";
      }
      if (result.error != null) {
        // The photo does look money-shaped (it has price text, a total,
        // etc.) but couldn't be read cleanly -- most often blur, glare, or
        // a bad angle. Unlike the "not a receipt" message above, the fix
        // here is a better photo, not manual entry, so say that first.
        return "This photo is too blurry to read clearly. Please retake or upload a clearer photo of the receipt, or enter the details manually.";
      }
      return "This photo is too blurry to read clearly. Please retake or upload a clearer photo of the receipt, or enter the details manually.";
    } finally {
      _scanningReceipt = false;
      notifyListeners();
    }
  }

  double get amount {
    if (splitEqually == false) return items.fold(0.0, (s, i) => s + i.price);
    return double.tryParse(amountController.text.trim()) ?? 0;
  }

  Map<String, double> _computeShares() {
    if (splitEqually == false) {
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
    final enteredNote = noteController.text.trim();
    final manualDescription = enteredNote
        .replaceAll(RegExp(r'Currency:\s*[^\n\r]*', caseSensitive: false), '')
        .trim();
    final title = titleController.text.trim().isNotEmpty
        ? titleController.text.trim()
        : (manualDescription.isNotEmpty ? manualDescription : category);
    final note = RegExp(r'Currency:\s*[^\n\r]*', caseSensitive: false).hasMatch(enteredNote)
        ? enteredNote
        : <String>[
            if (enteredNote.isNotEmpty) enteredNote,
            'Currency: ${currencyForDestination(trip.destination) ?? 'Unknown'}',
          ].join('\n');
    final amt = amount;
    final shares = _computeShares();
    if (amt <= 0 || amt > 1000000 || shares.isEmpty) return false;
    // A solo trip never shows the split-method choice at all, so it has
    // nothing to pick -- only a multi-member trip must explicitly choose
    // before this can submit.
    if (splitEqually == null && trip.memberIds.length > 1) return false;
    if (splitEqually == false && items.any((i) => i.assigneeUids.isEmpty)) return false;
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
        note: note,
        location: location,
        paidBy: uid,
        paidByName: myName,
        participants: participants,
        receiptImageUrl: receiptImageUrl,
        items: splitEqually == false
            ? items.map((i) => ExpenseLineItem(label: i.label, price: i.price, assigneeUids: i.assigneeUids.toList())).toList()
            : const [],
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
