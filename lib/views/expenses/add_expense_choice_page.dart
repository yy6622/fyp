import 'package:flutter/material.dart';

import '../../controllers/expenses_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'expense_details_form_page.dart';
import 'itemized_split_page.dart';

// ---------------------------------------------------------------------
// Add Expense flow — loads the trip once, then shares one
// [AddExpenseController] across every page in the flow so the amount,
// category and participants chosen on one step are still there on the
// next.
// ---------------------------------------------------------------------
class AddExpenseChoicePage extends StatefulWidget {
  final String tripId;
  const AddExpenseChoicePage({super.key, required this.tripId});

  @override
  State<AddExpenseChoicePage> createState() => _AddExpenseChoicePageState();
}

class _AddExpenseChoicePageState extends State<AddExpenseChoicePage> {
  AddExpenseController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final trip = await TripRepository.instance.watchTrip(widget.tripId, uid).first;
    if (!mounted || trip == null) return;
    setState(() => _controller = AddExpenseController(tripId: widget.tripId, trip: trip));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Add Expenses', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _tile(context, 'Itemized Receipt', 'Add items and split by who ordered what',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemizedSplitPage(controller: controller)))),
                _tile(context, 'Manual Entry', 'Enter one amount and split equally',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailsFormPage(controller: controller)))),
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFDFDE0), borderRadius: BorderRadius.circular(22))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}
