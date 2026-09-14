import 'package:flutter/material.dart';

import '../../controllers/expenses_controller.dart';
import '../../theme.dart';
import 'expense_details_form_page.dart';
import 'friend_picker_dialog.dart';

/// Lets the payer type in each line of a receipt (label + price) and pick
/// who it's split between — a real itemized split, backed by
/// [AddExpenseController.items], instead of two fixed "Food 1"/"Drink 1"
/// rows nobody could edit.
class ItemizedSplitPage extends StatefulWidget {
  final AddExpenseController controller;
  const ItemizedSplitPage({super.key, required this.controller});

  @override
  State<ItemizedSplitPage> createState() => _ItemizedSplitPageState();
}

class _ItemizedSplitPageState extends State<ItemizedSplitPage> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        appBar: const VoyaAppBar(
          title: Text('Itemized Receipt', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 14),
                  if (widget.controller.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No items yet', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                    ),
                  ...widget.controller.items.asMap().entries.map((e) => _itemRow(e.key, e.value)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _addItemDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: const Text('Add Item', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  if (widget.controller.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Total: RM ${widget.controller.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: widget.controller.items.isEmpty
                      ? null
                      : () {
                          widget.controller.setSplitEqually(false);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailsFormPage(controller: widget.controller)));
                        },
                  child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(int index, ReceiptItem item) {
    final names = item.assigneeUids.map((uid) => widget.controller.trip.memberNames[uid] ?? '?').toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${item.label} — RM ${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.black)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  names.isEmpty ? 'Nobody assigned yet' : 'Split with: ${names.join(', ')}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
                ),
              ),
              GestureDetector(
                onTap: () => _openFriendPicker(index, item),
                child: const CircleAvatar(radius: 13, backgroundColor: AppColors.chipGrey, child: Icon(Icons.person_add_alt, size: 14, color: AppColors.navy)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addItemDialog() async {
    final label = TextEditingController();
    final price = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Item', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Item')),
            TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (RM)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    final priceValue = double.tryParse(price.text.trim());
    if (result == true && label.text.trim().isNotEmpty && priceValue != null && priceValue > 0) {
      widget.controller.addItem(label.text.trim(), priceValue);
    }
  }

  void _openFriendPicker(int index, ReceiptItem item) {
    showDialog(
      context: context,
      builder: (_) => FriendPickerDialog(
        trip: widget.controller.trip,
        initialSelectedUids: item.assigneeUids,
        onConfirm: (uids) => widget.controller.setItemAssignees(index, uids),
      ),
    );
  }
}
