import 'package:flutter/material.dart';

import '../../models/insurance_models.dart';
import '../../theme.dart';
import 'insurance_plan_detail_page.dart';

Widget insuranceLogo(InsurancePlan plan, {double size = 46}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFECECEC)),
    ),
    alignment: Alignment.center,
    child: Text(
      plan.logoText,
      style: TextStyle(
        color: plan.logoColor,
        fontWeight: FontWeight.bold,
        fontSize: plan.logoText.length > 1 ? size * 0.24 : size * 0.34,
      ),
    ),
  );
}

/// A single plan row, shared by the Home page preview and the full list.
class InsurancePlanCard extends StatelessWidget {
  final InsurancePlan plan;
  const InsurancePlanCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InsurancePlanDetailPage(plan: plan)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Row(
          children: [
            insuranceLogo(plan),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 2),
                  const Text('Basic Travel Cover', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  const SizedBox(height: 4),
                  Text(
                    '• ${plan.coverage}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.price,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const Text('per trips', style: TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Narrower card used in the Home page's horizontal preview row.
class InsurancePlanTile extends StatelessWidget {
  final InsurancePlan plan;
  const InsurancePlanTile({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InsurancePlanDetailPage(plan: plan)),
      ),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                insuranceLogo(plan, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                      const Text('Basic Travel Cover', style: TextStyle(fontSize: 8.5, color: AppColors.textGrey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(plan.price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(width: 3),
                const Text('per trips', style: TextStyle(fontSize: 8.5, color: AppColors.textGrey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
