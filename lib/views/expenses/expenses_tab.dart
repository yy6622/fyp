import 'package:flutter/material.dart';

import '../../controllers/expenses_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
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

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

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
            const SizedBox(height: 16),
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

  Widget _summaryCard({required bool personal}) {
    final settledFraction = controller.totalExpenses == 0
        ? 0.5
        : 1 - ((controller.youOwe + controller.youAreOwed) / (controller.totalExpenses == 0 ? 1 : controller.totalExpenses)).clamp(0, 1);
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
              SizedBox(width: 70, height: 70, child: CustomPaint(painter: PiePainter(fraction: settledFraction.toDouble()))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: personal
                ? [
                    _statTile('You Owe', 'RM ${controller.youOwe.toStringAsFixed(2)}'),
                    _statTile("You're Owed", 'RM ${controller.youAreOwed.toStringAsFixed(2)}'),
                    _statTile('Unsettled', '${controller.unsettledCount}'),
                  ]
                : [
                    _statTile('You Owe', 'RM ${controller.youOwe.toStringAsFixed(2)}'),
                    _statTile("You're Owed", 'RM ${controller.youAreOwed.toStringAsFixed(2)}'),
                    _statTile('Unsettled bill', '${controller.unsettledCount}'),
                  ],
          ),
        ],
      ),
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

  Widget _categoryRow(String label, double amount, double total) {
    final pct = total == 0 ? 0.0 : (amount / total).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
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
    final mine = expense.participants.where((p) => p.uid == _uid).toList();
    final settled = mine.isEmpty || mine.every((p) => p.paid);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionDetailPage(expense: expense))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFFDFDE0)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title, style: const TextStyle(fontSize: 13, color: Colors.black)),
                  if (controller.personal)
                    Text(expense.tripName, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
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
                Text('RM ${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
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
