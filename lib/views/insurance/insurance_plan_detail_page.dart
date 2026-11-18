import 'package:flutter/material.dart';

import '../../models/insurance_models.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import 'insurance_widgets.dart';
import 'traveller_details_page.dart';

class InsurancePlanDetailPage extends StatelessWidget {
  final InsurancePlan plan;
  final String? tripId;
  // See _ComparePlanCard.destination in insurance_plan_compare_page.dart --
  // only set when arriving from a quote/compare flow; threaded through to
  // TravellerDetailsPage so a standalone (no-trip) purchase still records
  // its destination.
  final String? destination;
  final int? initialTravellerCount;
  final DateTime? initialTravelStart;
  final DateTime? initialTravelEnd;
  const InsurancePlanDetailPage({
    super.key,
    required this.plan,
    this.tripId,
    this.destination,
    this.initialTravellerCount,
    this.initialTravelStart,
    this.initialTravelEnd,
  });

  static const _palette = [
    (Icons.healing, Color(0xFF3AA089), Color(0xFFE1F3EE)),
    (Icons.flight_takeoff_outlined, Color(0xFFE0604E), Color(0xFFFAE7E4)),
    (Icons.luggage_outlined, Color(0xFFB08968), Color(0xFFF3EBE3)),
    (Icons.schedule_outlined, Color(0xFF4A78D0), Color(0xFFE7ECFA)),
    (Icons.people_alt_outlined, Color(0xFFC98A4B), Color(0xFFF6EBE0)),
  ];

  (IconData, Color, Color) _coverageVisual(String label, int index) {
    final l = label.toLowerCase();
    if (l.contains('medical') || l.contains('health') || l.contains('hospital')) {
      return (Icons.healing, const Color(0xFF3AA089), const Color(0xFFE1F3EE));
    }
    if (l.contains('cancel')) return (Icons.event_busy_outlined, const Color(0xFFE0604E), const Color(0xFFFAE7E4));
    if (l.contains('baggage') || l.contains('luggage')) {
      return (Icons.luggage_outlined, const Color(0xFFB08968), const Color(0xFFF3EBE3));
    }
    if (l.contains('delay') || l.contains('flight')) {
      return (Icons.schedule_outlined, const Color(0xFF4A78D0), const Color(0xFFE7ECFA));
    }
    if (l.contains('accident') || l.contains('personal') || l.contains('death') || l.contains('disab')) {
      return (Icons.people_alt_outlined, const Color(0xFFC98A4B), const Color(0xFFF6EBE0));
    }
    return _palette[index % _palette.length];
  }

  IconData _highlightIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('licen')) return Icons.verified_outlined;
    if (l.contains('support') || l.contains('24')) return Icons.support_agent_outlined;
    if (l.contains('hospital') || l.contains('medical') || l.contains('cashless')) return Icons.local_hospital_outlined;
    if (l.contains('luggage') || l.contains('baggage')) return Icons.luggage_outlined;
    if (l.contains('cancel')) return Icons.event_busy_outlined;
    if (l.contains('covid') || l.contains('virus')) return Icons.coronavirus_outlined;
    return Icons.verified_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: const Text('Insurance', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
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
                            Text(plan.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            const SizedBox(height: 2),
                            const Text('Basic Travel Cover', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(plan.displayPrice, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const SizedBox(width: 4),
                                Text(insurancePriceUnitLabel(plan.category), style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (plan.highlights.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 74,
                    child: Row(
                      children: plan.highlights
                          .map((label) => Expanded(
                                child: Column(
                                  children: [
                                    Icon(_highlightIcon(label), size: 26, color: AppColors.navy),
                                    const SizedBox(height: 6),
                                    Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 8, color: AppColors.textGrey),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
                if (plan.hasNationalityRestriction) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8EE), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFCE4BE))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Color(0xFFB8740A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Only available to: ${plan.eligibleCountries.join(', ')}.',
                            style: const TextStyle(fontSize: 12, color: AppColors.navy, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (plan.coverageItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Key Coverage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const SizedBox(height: 8),
                        for (int i = 0; i < plan.coverageItems.length; i++) ...[
                          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
                          Builder(builder: (context) {
                            final item = plan.coverageItems[i];
                            final visual = _coverageVisual(item.label, i);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: visual.$3, shape: BoxShape.circle),
                                    child: Icon(visual.$1, size: 17, color: visual.$2),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(item.label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                                      children: [
                                        const TextSpan(text: 'Up to '),
                                        TextSpan(
                                          text: CurrencyService.instance.format(item.amount, 'MYR', 'MYR'),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.displayPrice, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text(insurancePriceUnitLabel(plan.category), style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TravellerDetailsPage(
                    plan: plan,
                    tripId: tripId,
                    destination: destination,
                    initialTravellerCount: initialTravellerCount,
                    initialTravelStart: initialTravelStart,
                    initialTravelEnd: initialTravelEnd,
                  )),
                  ),
                  child: const Text('Enter Traveller', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
