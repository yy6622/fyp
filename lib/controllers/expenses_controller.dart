import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';
import '../services/receipt_ocr_service.dart';
import '../services/receipt_service.dart';

/// Controller for [ExpensesTab] (Groups / Personal toggle). Both views are
/// scoped to this one trip only, and both list every expense the
/// signed-in user is a participant in — the difference is the AMOUNT
/// shown for each one. "Groups" shows each bill's full amount (what the
/// whole group spent). "Personal" shows only the signed-in user's own
/// share of each bill (what it actually costs THEM), regardless of who
/// paid it — RM25 split two ways is RM25 under Groups and RM12.50 under
/// Personal, never RM25 under both. See [displayAmount]. Neither view
/// ever pulls in another trip's expenses: a "fee for this trip" must not
/// interconnect with any other trip's data.
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

  /// This trip's expenses where the signed-in user is a participant —
  /// derived client-side from [_groupExpenses] (already scoped to
  /// [tripId]) rather than a separate cross-trip query, so it can never
  /// show another trip's transactions. Same set of bills as "I have a
  /// share in this" — who paid is irrelevant to whether a bill belongs
  /// here, only to how much of it is "mine" (see [displayAmount]).
  List<TripExpense> get _personalExpenses =>
      _groupExpenses.where((e) => e.participants.any((p) => p.uid == _uid)).toList();

  List<TripExpense> get visibleExpenses => _personal ? _personalExpenses : _groupExpenses;

  /// The signed-in user's own share of [e] — 0 if they're somehow not a
  /// participant (shouldn't happen for anything in [visibleExpenses]).
  double myShareOf(TripExpense e) => e.participants.where((p) => p.uid == _uid).fold(0.0, (s, p) => s + p.share);

  /// What to show as "the amount" for [e] in the current view: the whole
  /// bill under Groups, just the signed-in user's own share under
  /// Personal. Used for the summary total, the category breakdown and
  /// each transaction row, so a RM25 bill split two ways reads as RM25
  /// in Groups and RM12.50 in Personal everywhere it's shown — never RM25
  /// in both, which is exactly what looked broken before this existed.
  double displayAmount(TripExpense e) => _personal ? myShareOf(e) : e.amount;

  double get totalExpenses => visibleExpenses.fold(0.0, (s, e) => s + displayAmount(e));

  /// Total number of bills recorded for this trip — every real expense,
  /// never filtered down to just the signed-in user's own bills, so it
  /// stays the same number regardless of which tab is open. Replaces an
  /// earlier "remaining budget" tile here: that one kept reusing
  /// [budgetPerPerson] (a single person's own allowance, set at creation)
  /// under a "Group" stat, which read as a personal number no matter how
  /// it was computed — a plain count sidesteps that entirely.
  int get totalBillsCount => _groupExpenses.length;

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

  /// A bill is settled only when every participant has paid their share.
  bool isSettled(TripExpense e) => e.participants.isNotEmpty && e.participants.every((p) => p.paid);

  int get unsettledCount => visibleExpenses.where((e) => !isSettled(e)).length;

  int get settledCount => visibleExpenses.where(isSettled).length;

  /// Share of all the money in these bills that has been paid (the pie chart). 0.5 with no bills.
  double get settledFraction {
    final total = visibleExpenses.fold(0.0, (s, e) => s + e.participants.fold(0.0, (s2, p) => s2 + p.share));
    if (total <= 0) return visibleExpenses.isEmpty ? 0.5 : 1.0;
    final paid = visibleExpenses.fold(0.0, (s, e) => s + e.participants.where((p) => p.paid).fold(0.0, (s2, p) => s2 + p.share));
    return (paid / total).clamp(0.0, 1.0);
  }

  /// Category -> total amount, for the simple breakdown bar list. Same
  /// Groups-vs-Personal amount rule as [displayAmount].
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

  /// A snapshot of every report-relevant stat for [personal] (true) or
  /// Group (false), independent of whatever the Groups/Personal toggle is
  /// currently showing on screen — used by "Generate Report" so a PDF can
  /// be produced for either view without flipping (and having to restore)
  /// the live toggle. Deliberately reimplements the same formulas as the
  /// getters above (rather than calling them, which only ever read
  /// [_personal]) so generating a report can never have the side effect
  /// of changing what's on screen.
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

    // "Trip Budget" stat: [Trip.budgetPerPerson] is already documented
    // elsewhere in this file as a single person's own allowance, so the
    // Personal report uses it as-is; the Group report multiplies it by
    // the member count as its best real approximation of a whole-group
    // budget (there is no separate group-level budget field to read
    // instead). Both are real, derived numbers — never a placeholder.
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

  /// One entry per calendar day of the trip (from [Trip.startDate] to
  /// [Trip.endDate] inclusive, zero-filled for days with no spending) for
  /// the report's "Daily Expense Trend" chart — falls back to just the
  /// dates that actually have an expense, sorted, when the trip has no
  /// date range set.
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

/// One row of an [ExpensesReportSnapshot] — the expense plus the two
/// values that depend on whether the snapshot is Personal or Group
/// ([ExpensesTabController.displayAmount]/[ExpensesTabController.isSettled]
/// computed once up front, instead of every reader re-deriving them).
class ExpenseReportRow {
  final TripExpense expense;
  final double amount;
  final bool settled;
  const ExpenseReportRow({required this.expense, required this.amount, required this.settled});
}

/// Everything [PdfReportService]'s expense report needs, computed once by
/// [ExpensesTabController.snapshotFor] so the PDF generator never touches
/// Firestore or the live controller state directly.
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
  /// One entry per day of the trip, zero-filled — see [ExpensesTabController._dailyTotalsFor].
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

  /// Trip Budget minus Total Expenses — can go negative (over budget),
  /// shown as-is rather than clamped, so going over is actually visible.
  double get remainingBudget => tripBudget - totalExpenses;
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
    // start from the trip's destination instead of "Unknown"; still editable
    if (trip.destination.trim().isNotEmpty) location = trip.destination.trim();
  }

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String location = 'Unknown';
  String category = 'Food & Drinks';
  bool reminder = true;

  /// Set when this expense was started from "Upload Receipt" and a photo
  /// was actually picked/taken — shown as a preview on the Details form and
  /// uploaded to Firebase Storage on [submit]. Null for "Manual Entry".
  File? receiptImage;
  void setReceiptImage(File? file) {
    receiptImage = file;
    notifyListeners();
  }

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

  /// Drops a wrongly-read or unwanted line — most useful right after
  /// [scanReceipt] prefills [items] from a photo, since OCR occasionally
  /// misreads a line (FR56) and there was previously no way to undo a
  /// single item short of starting the whole expense over.
  void removeItem(int index) {
    items.removeAt(index);
    notifyListeners();
  }

  /// Fixes a line's label/price in place — again mainly for correcting
  /// an OCR misread (FR56) without losing whatever assignees were
  /// already picked for it.
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

  /// FR56 — runs on-device OCR (see [ReceiptOcrService]) over whatever
  /// photo [receiptImage] currently holds and prefills the form from
  /// whatever it manages to read:
  ///  - items found -> replaces [items] and switches to itemized split
  ///    (each item still needs an assignee on the Itemized Split page —
  ///    this never guesses who to split a line with).
  ///  - no items but a total was found -> fills [amountController] and
  ///    leaves the equal-split amount field for the person to confirm.
  ///  - neither -> nothing changes; the person just fills the form by
  ///    hand, exactly like before this feature existed.
  /// Returns a short message describing what happened, for the caller to
  /// show as a SnackBar; never throws.
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
      // A thrown exception (model/Play-Services unavailable, corrupt
      // image, ...) looked identical to "ran fine, found nothing" before
      // ReceiptOcrResult.error existed — surfacing it here instead of
      // the generic message is what actually lets a real failure get
      // diagnosed instead of just looking like a blank receipt.
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

  /// Runs the Shared-Expense Distribution Algorithm (see
  /// trip_repository.dart's splitExpenseEqual/splitExpenseItemized for the
  /// cents-safe floor + remainder rule this uses): EQUAL when
  /// [splitEqually], otherwise this app's itemized form of CUSTOM (each
  /// receipt line item split among whoever it's assigned to, then summed
  /// per member). Returns {} if the inputs aren't ready yet (nothing
  /// selected, or an itemized item with no assignee) rather than throwing
  /// — [submit] treats an empty map as "not ready", same as before.
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
    // No separate title any more: the note describes the expense (it is kept as the title too, so
    // older screens and notifications that read `title` still have something to show).
    final title = noteController.text.trim();
    final amt = amount;
    final shares = _computeShares();
    if (amt <= 0 || amt > 1000000 || shares.isEmpty) return false;
    // Itemized split: every line item must have at least one assignee, or
    // the shares (derived only from assigned items) would silently add up
    // to less than the saved total — money "lost" from the split.
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
        // FR60 — the Details form's "Reminder" switch (default on):
        // immediately nudges everyone else in [participants] to pay
        // their share, instead of just sitting there as a label.
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
