import 'package:flutter/material.dart';

import '../../controllers/insurance_controller.dart';
import '../../models/insurance_models.dart';
import '../../theme.dart';
import 'insurance_widgets.dart';

class InsuranceListPage extends StatefulWidget {
  final String? tripId;
  const InsuranceListPage({super.key, this.tripId});

  @override
  State<InsuranceListPage> createState() => _InsuranceListPageState();
}

class _InsuranceListPageState extends State<InsuranceListPage> {
  final InsuranceListController controller = InsuranceListController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Insurance', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => controller.loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _buildBanner(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _filterTab('All', null),
                      const SizedBox(width: 16),
                      _filterTab('Single Trips', InsuranceCategory.singleTrip),
                      const SizedBox(width: 16),
                      _filterTab('Annual', InsuranceCategory.annual),
                      const SizedBox(width: 16),
                      _filterTab('Family', InsuranceCategory.family),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...controller.filtered.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InsurancePlanCard(plan: p, tripId: widget.tripId),
                      )),
                  if (controller.filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          controller.filter == null ? 'No insurance plans yet' : 'No plans in this category yet',
                          style: const TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _filterTab(String label, InsuranceCategory? value) {
    final selected = controller.filter == value;
    return GestureDetector(
      onTap: () => controller.setFilter(value),
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
      child: const SizedBox(
        height: 130,
        width: double.infinity,
        child: AppImage('assets/images/insurance.png', fit: BoxFit.cover),
      ),
    );
  }
}
