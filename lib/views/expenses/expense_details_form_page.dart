import 'package:flutter/material.dart';

import '../../controllers/expenses_controller.dart';
import '../../theme.dart';
import '../group/group_trip_page.dart';
import 'split_friends_page.dart';

class ExpenseDetailsFormPage extends StatefulWidget {
  final AddExpenseController controller;
  const ExpenseDetailsFormPage({super.key, required this.controller});

  @override
  State<ExpenseDetailsFormPage> createState() => _ExpenseDetailsFormPageState();
}

class _ExpenseDetailsFormPageState extends State<ExpenseDetailsFormPage> {
  void _editField(String label, String current, ValueChanged<String> onSaved, {TextInputType? keyboardType}) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $label', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: keyboardType),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onSaved(ctrl.text.trim().isEmpty ? current : ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final ok = await widget.controller.submit();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((r) => r.settings.name == GroupTripPage.routeName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title, an amount, and who to split with')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        appBar: const VoyaAppBar(
          title: Text('Add Expenses', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  _editableRow('Title', widget.controller.titleController.text.isEmpty ? 'Tap to add a title' : widget.controller.titleController.text,
                      onTap: () => _editField('Title', widget.controller.titleController.text, widget.controller.setTitle)),
                  if (widget.controller.splitEqually)
                    _editableRow('Amount', widget.controller.amountController.text.isEmpty ? 'Tap to add an amount' : 'RM ${widget.controller.amountController.text}',
                        onTap: () => _editField('Amount (RM)', widget.controller.amountController.text, widget.controller.setAmountText,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true)))
                  else
                    _row('Amount', 'RM ${widget.controller.amount.toStringAsFixed(2)} (from ${widget.controller.items.length} item${widget.controller.items.length == 1 ? '' : 's'})'),
                  _editableRow('Location', widget.controller.location, onTap: () => _editField('Location', widget.controller.location, widget.controller.setLocation)),
                  _editableRow('Category', widget.controller.category, onTap: () => _editField('Category', widget.controller.category, widget.controller.setCategory)),
                  _editableRow('Note', widget.controller.noteController.text.isEmpty ? 'Tap to add a note' : widget.controller.noteController.text,
                      onTap: () => _editField('Note', widget.controller.noteController.text, widget.controller.setNote)),
                  if (widget.controller.splitEqually)
                    _editableRow('Split Method', 'Equally · ${widget.controller.selectedUids.length} people',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SplitFriendsPage(controller: widget.controller))))
                  else
                    _row('Split Method', 'Itemized · ${widget.controller.items.length} items'),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reminder', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                        Switch(value: widget.controller.reminder, activeColor: AppColors.primary, onChanged: widget.controller.setReminder),
                      ],
                    ),
                  ),
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
                  onPressed: widget.controller.submitting ? null : _submit,
                  child: Text(widget.controller.submitting ? 'Saving...' : 'Save Expense',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _editableRow(String label, String value, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            Row(
              children: [
                Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black))),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
