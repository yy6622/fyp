import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../controllers/expenses_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../services/pdf_report_service.dart';
import '../../theme.dart';
import 'expense_painters.dart';
import 'transaction_detail_page.dart';

// ---------------------------------------------------------------------
// Expenses tab (Groups / Personal) — lives inside GroupTripPage
// ---------------------------------------------------------------------
class ExpensesTab extends StatefulWidget {
  final String tripId;
  const ExpensesTab({super.key, required this.tripId});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  late final ExpensesTabController controller = ExpensesTabController(tripId: widget.tripId);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final expenses = controller.visibleExpenses;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
          children: [
            _segmentToggle(),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: _generateReportButton(context)),
            const SizedBox(height: 10),
            controller.personal ? _summaryCard(personal: true) : _summaryCard(personal: false),
            const SizedBox(height: 20),
            if (controller.byCategory.isNotEmpty) ...[
              const Text('Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 10),
              ...controller.byCategory.entries.map((e) => _categoryRow(e.key, e.value, controller.totalExpenses)),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ],
            ),
            const SizedBox(height: 10),
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No expenses yet — tap + to add one.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
              )
            else
              ...expenses.map((e) => _transactionRow(context, e)),
          ],
        );
      },
    );
  }

  Widget _segmentToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          _segmentButton('Groups', !controller.personal),
          _segmentButton('Personal', controller.personal),
        ],
      ),
    );
  }

  Widget _segmentButton(String label, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setPersonal(label == 'Personal'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey)),
        ),
      ),
    );
  }

  /// Opens the Group/Personal choice sheet — deliberately independent of
  /// whichever one [controller.personal] currently has the screen set to
  /// (see [ExpensesTabController.snapshotFor]), since the person generating
  /// a report may want the other view without switching the toggle first.
  Widget _generateReportButton(BuildContext context) {
    return TextButton.icon(
      onPressed: controller.loading ? null : () => _showGenerateReportSheet(context),
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
      label: const Text('Generate Report', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _showGenerateReportSheet(BuildContext context) async {
    final personal = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Generate Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined, color: AppColors.primary),
              title: const Text('Group Report', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
              subtitle: const Text('Every bill for this trip, full amounts', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text('Personal Report', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
              subtitle: const Text("Just your own share of each bill", style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (personal == null || !context.mounted) return;
    await _generateReport(context, personal: personal);
  }

  Future<void> _generateReport(BuildContext context, {required bool personal}) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    try {
      final snapshot = controller.snapshotFor(personal);
      final bytes = await PdfReportService.buildExpenseReport(snapshot);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      final tripName = (snapshot.trip != null && snapshot.trip!.name.isNotEmpty) ? snapshot.trip!.name : 'Trip';
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '${personal ? "Personal" : "Group"}-Expense-Report-$tripName.pdf',
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate report: $e')));
      }
    }
  }

  Widget _summaryCard({required bool personal}) {
    final settledFraction = controller.settledFraction;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Expenses', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    const SizedBox(height: 4),
                    Text('RM ${controller.totalExpenses.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ],
                ),
              ),
              personal ? _walletIcon() : _pie(settledFraction.toDouble()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            // "You Owe" / "You're Owed" are a personal-money question, so they
            // only make sense once you're looking at your own bills — under
            // Groups the card instead shows group-wide budget stats, which
            // don't mean anything scoped to just one person.
            children: personal
                ? [
                    _statTile('You Owe', 'RM ${controller.youOwe.toStringAsFixed(2)}'),
                    _statTile("You're Owed", 'RM ${controller.youAreOwed.toStringAsFixed(2)}'),
                    _statTile('Pending Bills', '${controller.unsettledCount}'),
                  ]
                : [
                    _statTile('Total Bills', '${controller.totalBillsCount}'),
                    _statTile('Settled Bills', '${controller.settledCount}'),
                    _statTile('Unsettled bill', '${controller.unsettledCount}'),
                  ],
          ),
        ],
      ),
    );
  }

  /// Donut: green = share of the money already paid back, pink = still owed; % paid in the middle.
  Widget _pie(double fraction) {
    final empty = controller.visibleExpenses.isEmpty;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(76, 76), painter: PiePainter(fraction: fraction, empty: empty)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(empty ? '–' : '${(fraction * 100).round()}%',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
              if (!empty) const Text('paid', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  /// Personal's summary icon — a plain wallet glyph instead of the Groups
  /// donut, since "% of the group's bills settled" isn't a personal stat.
  Widget _walletIcon() {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
      child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 34),
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('drink')) return Icons.restaurant_outlined;
    if (c.contains('transport')) return Icons.directions_bus_outlined;
    if (c.contains('accommodation') || c.contains('hotel')) return Icons.hotel_outlined;
    if (c.contains('activit')) return Icons.local_activity_outlined;
    if (c.contains('shop')) return Icons.shopping_bag_outlined;
    return Icons.receipt_long_outlined;
  }

  Widget _categoryRow(String label, double amount, double total) {
    final pct = total == 0 ? 0.0 : (amount / total).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: AppColors.chipGrey, child: Icon(_categoryIcon(label), size: 16, color: AppColors.navy)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black)),
                    Text('RM ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: AppColors.chipGrey, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _transactionRow(BuildContext context, TripExpense expense) {
    // Settled only when EVERY participant has paid their share (the transaction is complete),
    // not just the signed-in user.
    final paidCount = expense.participants.where((p) => p.paid).length;
    final total = expense.participants.length;
    final settled = total > 0 && paidCount == total;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionDetailPage(expense: expense))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            UserAvatar(uid: expense.paidBy, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expenseLabel(expense), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  settled ? 'Settled' : 'Unsettled',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: settled ? Colors.green : Colors.red),
                ),
                Text('RM ${controller.displayAmount(expense).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
