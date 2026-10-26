import 'package:flutter/material.dart';

import '../../controllers/expenses_controller.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
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
          title: Text('Split With', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
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
                  onPressed: widget.controller.items.isEmpty || widget.controller.items.any((i) => i.assigneeUids.isEmpty)
                      ? null
                      : () => Navigator.of(context).maybePop(),
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
                child: GestureDetector(
                  onTap: () => _editItemDialog(index, item),
                  child: Text('${item.label} — RM ${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.black)),
                ),
              ),
              // Mainly for fixing/discarding a misread OCR line (FR56) —
              // tap the text above to correct it, or this to drop it
              // entirely, same as any item added by hand.
              GestureDetector(
                onTap: () => widget.controller.removeItem(index),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close, size: 16, color: AppColors.textGrey),
                ),
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

  /// The shared label/price validation behind both [_addItemDialog] and
  /// [_editItemDialog] — returns the first problem found, in plain words,
  /// or null once both fields are ready to save.
  String? _itemProblem(String labelText, String priceText) {
    final priceValue = double.tryParse(priceText);
    if (labelText.trim().isEmpty) return 'Give the item a name';
    if (priceValue == null || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(priceText)) {
      return 'Price: numbers only, up to 2 decimal places';
    }
    if (priceValue <= 0) return 'Price must be more than RM 0';
    if (priceValue > 1000000) return 'Price can\'t be more than RM 1,000,000';
    return null;
  }

  Future<void> _addItemDialog() async {
    final label = TextEditingController();
    final price = TextEditingController();
    final result = await showNiceFormDialog(
      context: context,
      title: 'Add Item',
      headerIcon: Icons.receipt_long_outlined,
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(label, 'Item', icon: Icons.label_outline, autofocus: true),
        niceDialogField(price, 'Price (RM)', icon: Icons.payments_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      ],
    );
    if (result != true) return;
    final problem = _itemProblem(label.text, price.text.trim());
    if (problem != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    widget.controller.addItem(label.text.trim(), double.parse(price.text.trim()));
  }

  /// Corrects an existing line in place — mainly for fixing an OCR
  /// misread (FR56: a wrong price, or a label that picked up stray
  /// characters) without having to delete it and re-add it from scratch,
  /// which would also lose any assignees already picked for it.
  Future<void> _editItemDialog(int index, ReceiptItem item) async {
    final label = TextEditingController(text: item.label);
    final price = TextEditingController(text: item.price.toStringAsFixed(2));
    final result = await showNiceFormDialog(
      context: context,
      title: 'Edit Item',
      headerIcon: Icons.edit_outlined,
      confirmLabel: 'Save',
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(label, 'Item', icon: Icons.label_outline, autofocus: true),
        niceDialogField(price, 'Price (RM)', icon: Icons.payments_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      ],
    );
    if (result != true) return;
    final problem = _itemProblem(label.text, price.text.trim());
    if (problem != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    widget.controller.editItem(index, label.text.trim(), double.parse(price.text.trim()));
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
