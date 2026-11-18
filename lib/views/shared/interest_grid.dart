import 'package:flutter/material.dart';

import '../../controllers/create_plan_wizard_controller.dart' show CreatePlanWizardController;
import '../../theme.dart';

class InterestGrid extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final List<String> options;

  const InterestGrid({
    super.key,
    required this.selected,
    required this.onToggle,
    this.options = CreatePlanWizardController.interestOptions,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: options.map((label) {
        final isSelected = selected.contains(label);
        return GestureDetector(
          onTap: () => onToggle(label),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.chipGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textGrey),
            ),
          ),
        );
      }).toList(),
    );
  }
}
