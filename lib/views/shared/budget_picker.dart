import 'package:flutter/material.dart';

import '../../theme.dart';
import 'nice_dialog.dart';

class BudgetSliderField extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const BudgetSliderField({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 500,
    this.max = 10000,
  });

  Future<void> _enterAmount(BuildContext context) async {
    final textController = TextEditingController(text: value.round().toString());
    final result = await showNiceFormDialog(
      context: context,
      title: 'Enter Amount',
      headerIcon: Icons.edit_outlined,
      confirmLabel: 'Set',
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(
          textController,
          'Budget per Person (RM)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          required: true,
        ),
      ],
    );
    if (result != true) return;
    final parsed = double.tryParse(textController.text.trim());
    if (parsed == null || parsed < 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid budget amount.')));
      return;
    }
    onChanged(parsed.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Column(
      children: [
        GestureDetector(
          onTap: () => _enterAmount(context),
          child: Column(
            children: [
              Text('RM ${value.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 2),
              const Text('Tap to enter an exact amount', style: TextStyle(fontSize: 11, color: AppColors.textGrey, decoration: TextDecoration.underline)),
            ],
          ),
        ),
        Slider(
          value: clamped,
          min: min,
          max: max,
          divisions: ((max - min) / 100).round(),
          activeColor: AppColors.primary,
          inactiveColor: AppColors.chipGrey,
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RM ${min.round()}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            Text('RM ${max.round()}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
      ],
    );
  }
}

Future<double?> showBudgetPickerSheet(
  BuildContext context, {
  required double initialValue,
  double min = 500,
  double max = 10000,
}) {
  double current = initialValue > 0 ? initialValue.clamp(min, max) : min;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Budget per Person', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: const Icon(Icons.close, size: 20, color: AppColors.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BudgetSliderField(
                value: current,
                min: min,
                max: max,
                onChanged: (v) => setSheetState(() => current = v),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(current),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
