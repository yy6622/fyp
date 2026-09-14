import 'package:flutter/material.dart';

import '../../models/insurance_models.dart';
import '../../theme.dart';
import 'insurance_widgets.dart';
import 'traveller_details_page.dart';

// ---------------------------------------------------------------------
// Insurance plan detail — coverage breakdown + "Enter Traveller"
// ---------------------------------------------------------------------
class InsurancePlanDetailPage extends StatelessWidget {
  final InsurancePlan plan;
  const InsurancePlanDetailPage({super.key, required this.plan});

  static const _icons = [
    (Icons.verified_outlined, 'Licenses'),
    (Icons.volunteer_activism_outlined, '24/7 Support'),
    (Icons.local_hospital_outlined, 'Cashless\nHospitalisation'),
    (Icons.luggage_outlined, 'Luggage\nProtect'),
    (Icons.support_agent_outlined, '24/7 Support'),
  ];

  static const _coverage = [
    ('Medical Expenses (Overseas)', 'RM 1,000,000', Icons.healing, Color(0xFF3AA089), Color(0xFFE1F3EE)),
    ('Trip Cancellation', 'RM 5,000', Icons.content_cut, Color(0xFFE0604E), Color(0xFFFAE7E4)),
    ('Baggage Loss or Delay', 'RM 3,000', Icons.luggage_outlined, Color(0xFFB08968), Color(0xFFF3EBE3)),
    ('Travel Delay', 'RM 1,000', Icons.people_alt_outlined, Color(0xFF4A78D0), Color(0xFFE7ECFA)),
    ('Personal Accident', 'RM 300,000', Icons.people_alt_outlined, Color(0xFFC98A4B), Color(0xFFF6EBE0)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Insurance', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
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
                                Text(plan.price, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const SizedBox(width: 4),
                                const Text('per trips', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 74,
                  child: Row(
                    children: _icons
                        .map((e) => Expanded(
                              child: Column(
                                children: [
                                  Icon(e.$1, size: 26, color: AppColors.navy),
                                  const SizedBox(height: 6),
                                  Text(
                                    e.$2,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 8, color: AppColors.textGrey),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
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
                      for (int i = 0; i < _coverage.length; i++) ...[
                        if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: _coverage[i].$5, shape: BoxShape.circle),
                                child: Icon(_coverage[i].$3, size: 17, color: _coverage[i].$4),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_coverage[i].$1, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              ),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                                  children: [
                                    const TextSpan(text: 'Up to '),
                                    TextSpan(
                                      text: _coverage[i].$2,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                      Text(plan.price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const Text('per trips', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
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
                    MaterialPageRoute(builder: (_) => TravellerDetailsPage(plan: plan)),
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
