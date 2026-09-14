import 'package:flutter/material.dart';

import 'theme.dart';

// ---------------------------------------------------------------------
// Shared insurance plan data — used by both the Home page preview row
// and the full Insurance list page, so there's a single source of truth.
// ---------------------------------------------------------------------
enum InsuranceCategory { singleTrip, family }

class InsurancePlan {
  final String provider;
  final String logoText;
  final Color logoColor;
  final String name;
  final String coverage;
  final String price;
  final InsuranceCategory category;
  const InsurancePlan({
    required this.provider,
    required this.logoText,
    required this.logoColor,
    required this.name,
    required this.coverage,
    required this.price,
    required this.category,
  });
}

const List<InsurancePlan> insurancePlans = [
  InsurancePlan(
    provider: 'Allianz Travel',
    logoText: 'A',
    logoColor: Color(0xFF0B3B8C),
    name: 'Allianz Travel',
    coverage: 'Medical Coverage up to RM 100,000',
    price: 'RM 53',
    category: InsuranceCategory.singleTrip,
  ),
  InsurancePlan(
    provider: 'AIG Travel Guard',
    logoText: 'AIG',
    logoColor: Color(0xFF1E88C7),
    name: 'AIG Travel Guard',
    coverage: 'Medical Coverage up to RM 100,000',
    price: 'RM 49',
    category: InsuranceCategory.singleTrip,
  ),
  InsurancePlan(
    provider: 'Allianz Travel',
    logoText: 'A',
    logoColor: Color(0xFF0B3B8C),
    name: 'Allianz Travel',
    coverage: 'Medical Coverage up to RM 100,000',
    price: 'RM 50',
    category: InsuranceCategory.singleTrip,
  ),
  InsurancePlan(
    provider: 'Allianz Travel',
    logoText: 'A',
    logoColor: Color(0xFF0B3B8C),
    name: 'Family Travel Cover',
    coverage: 'Medical Coverage up to RM 300,000 (family)',
    price: 'RM 150',
    category: InsuranceCategory.family,
  ),
];

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

// ---------------------------------------------------------------------
// Insurance list page — "View All" from Home lands here.
// ---------------------------------------------------------------------
class InsuranceListPage extends StatefulWidget {
  const InsuranceListPage({super.key});

  @override
  State<InsuranceListPage> createState() => _InsuranceListPageState();
}

class _InsuranceListPageState extends State<InsuranceListPage> {
  InsuranceCategory? _filter;

  List<InsurancePlan> get _filtered =>
      _filter == null ? insurancePlans : insurancePlans.where((p) => p.category == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Insurance', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _buildBanner(),
          const SizedBox(height: 18),
          Row(
            children: [
              _filterTab('All', null),
              const SizedBox(width: 20),
              _filterTab('Single Trips', InsuranceCategory.singleTrip),
              const SizedBox(width: 20),
              _filterTab('Family', InsuranceCategory.family),
            ],
          ),
          const SizedBox(height: 16),
          ..._filtered.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InsurancePlanCard(plan: p),
              )),
          if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No plans in this category yet', style: TextStyle(color: AppColors.textGrey)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterTab(String label, InsuranceCategory? value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? AppColors.navy : AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 2, width: 44, color: selected ? AppColors.primary : Colors.transparent),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDCEEF7), Color(0xFFBFE1F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Travel with peace\nof mind',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy, height: 1.25),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find the right protection\nfor your journey',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textGrey, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.shield, size: 56, color: Color(0xFF2E6E96)),
          ],
        ),
      ),
    );
  }
}

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
    ('Medical Expenses (Overseas)', 'Up to RM 1,000,000', Icons.local_hospital_outlined, Color(0xFF2E8B57)),
    ('Trip Cancellation', 'Up to RM 5,000', Icons.content_cut, Color(0xFFE4A11B)),
    ('Baggage Loss or Delay', 'Up to RM 3,000', Icons.luggage_outlined, Color(0xFFE4A11B)),
    ('Travel Delay', 'Up to RM 1,000', Icons.connect_without_contact, Color(0xFF3A7DD9)),
    ('Personal Accident', 'Up to RM 300,000', Icons.accessibility_new, Color(0xFF3A7DD9)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
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
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(plan.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const Text('per trips', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                        ],
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
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
                                    child: Icon(e.$1, size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 4),
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
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Key Coverage', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 14),
                      ..._coverage.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Icon(c.$3, size: 18, color: c.$4),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(c.$1, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
                                ),
                                Text(c.$2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                              ],
                            ),
                          )),
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

// ---------------------------------------------------------------------
// Traveller details form
// ---------------------------------------------------------------------
class TravellerDetailsPage extends StatefulWidget {
  final InsurancePlan plan;
  const TravellerDetailsPage({super.key, required this.plan});

  @override
  State<TravellerDetailsPage> createState() => _TravellerDetailsPageState();
}

class _TravellerDetailsPageState extends State<TravellerDetailsPage> {
  int _travellerCount = 1;

  void _addTraveller() {
    if (_travellerCount >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 6 travellers per booking')),
      );
      return;
    }
    setState(() => _travellerCount++);
  }

  void _removeTraveller(int index) {
    if (_travellerCount <= 1) return;
    setState(() => _travellerCount--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Insurance', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Traveller Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      for (int i = 0; i < _travellerCount; i++) ...[
                        const SizedBox(height: 18),
                        _travellerFields(i),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, style: BorderStyle.solid),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _addTraveller,
                          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                          label: const Text('Add Traveller', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PaymentMethodPage(plan: widget.plan, travellerCount: _travellerCount)),
                ),
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _travellerFields(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Traveller ${index + 1}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(width: 6),
            const Text('(Adult)', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const Spacer(),
            if (index > 0)
              GestureDetector(
                onTap: () => _removeTraveller(index),
                child: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _field('Full Name (as in passport)'),
        const SizedBox(height: 10),
        _field('Date of Birth'),
        const SizedBox(height: 10),
        _field('Nationality', trailing: Icons.keyboard_arrow_down),
        const SizedBox(height: 10),
        _field('Passport Number'),
        if (index == 0) ...[
          const SizedBox(height: 10),
          _field('Email'),
          const SizedBox(height: 10),
          _field('Phone Number'),
        ],
      ],
    );
  }

  Widget _field(String label, {IconData? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13.5, color: Colors.black),
            ),
          ),
          if (trailing != null) Icon(trailing, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Payment method selection
// ---------------------------------------------------------------------
class PaymentMethodPage extends StatefulWidget {
  final InsurancePlan plan;
  final int travellerCount;
  const PaymentMethodPage({super.key, required this.plan, required this.travellerCount});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  String _method = 'Credit / Debit Card';

  static const _methods = [
    'Credit / Debit Card',
    'FPX Online Banking',
    'Touch in Go eWallet',
    'GrabPay',
    'ShopeePay',
  ];

  double get _unitPrice => double.tryParse(widget.plan.price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
  double get _subtotal => _unitPrice * widget.travellerCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
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
                      insuranceLogo(widget.plan),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.plan.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            const SizedBox(height: 2),
                            const Text('Basic Travel Cover', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      Text(widget.plan.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 12),
                ..._methods.map((m) => _methodTile(m)),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFECECEC)),
                const SizedBox(height: 4),
                _summaryRow('Subtotal', 'RM ${_subtotal.toStringAsFixed(2)}'),
                _summaryRow('Discount (0%)', 'RM 0.00', color: Colors.green),
                _summaryRow('Service Fee', 'RM 0.00'),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFECECEC)),
                _summaryRow('Total Amount', 'RM ${_subtotal.toStringAsFixed(2)}', bold: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _confirmPayment,
                child: Text('Pay RM ${_subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmPayment() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: const Text('Payment Successful', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: Text(
          'Your ${widget.plan.name} plan for ${widget.travellerCount} traveller(s) is confirmed. '
          'A copy of your policy has been sent to your email.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(String method) {
    final selected = _method == method;
    return GestureDetector(
      onTap: () => setState(() => _method = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFECECEC), width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textGrey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(method, style: const TextStyle(fontSize: 13.5, color: Colors.black))),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? AppColors.navy : AppColors.textGrey,
              )),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 17 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color ?? (bold ? AppColors.primary : Colors.black87),
              )),
        ],
      ),
    );
  }
}
