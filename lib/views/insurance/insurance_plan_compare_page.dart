import 'package:flutter/material.dart';

import '../../controllers/insurance_controller.dart';
import '../../models/insurance_models.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import 'insurance_plan_detail_page.dart';
import 'insurance_widgets.dart';

/// Step 2 of buying from [partner] — that insurer's plans priced for the
/// exact trip collected on [InsuranceQuotePage], shown side by side like a
/// real insurer's plan-comparison chart. Tapping a plan goes to the normal
/// [InsurancePlanDetailPage], pre-filled with the quote's traveller count
/// and dates so nothing has to be re-entered or re-confirmed.
class InsurancePlanComparePage extends StatefulWidget {
  final InsurancePartner partner;
  final String destination;
  final DateTime travelStart;
  final DateTime travelEnd;
  final int travellerCount;
  final String? tripId;

  const InsurancePlanComparePage({
    super.key,
    required this.partner,
    required this.destination,
    required this.travelStart,
    required this.travelEnd,
    required this.travellerCount,
    this.tripId,
  });

  @override
  State<InsurancePlanComparePage> createState() => _InsurancePlanComparePageState();
}

class _InsurancePlanComparePageState extends State<InsurancePlanComparePage> {
  late final InsuranceListController controller;

  @override
  void initState() {
    super.initState();
    controller = InsuranceListController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: VoyaAppBar(
        title: Text('Compare Plans — ${widget.partner.companyName}',
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.flight_takeoff_outlined, size: 16, color: AppColors.textGrey),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.destination, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(widget.travelStart)} - ${_formatDate(widget.travelEnd)} · ${widget.travellerCount} traveller${widget.travellerCount > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                if (controller.loading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                // Lowest-to-highest by this quote's actual total (unit price x
                // travellers x coverage days -- insurancePlanTotal, same formula
                // the price breakdown below and the detail page both use), not
                // raw plan.price, so an Annual plan's flat yearly price still
                // compares fairly against a per-day plan's multiplied total.
                final userCurrency = CurrencyService.instance.lastKnownUserCurrency;
                final tripDays = widget.travelEnd.difference(widget.travelStart).inDays + 1;
                final plans = controller.filtered
                    .where((p) =>
                        p.partnerId == widget.partner.id &&
                        p.isEligibleForDestination(widget.destination) &&
                        p.isEligibleForTripDuration(tripDays < 1 ? 1 : tripDays))
                    .toList()
                  ..sort((a, b) => insurancePlanTotal(
                        a,
                        travellerCount: widget.travellerCount,
                        travelStart: widget.travelStart,
                        travelEnd: widget.travelEnd,
                        userCurrency: userCurrency,
                      ).compareTo(insurancePlanTotal(
                        b,
                        travellerCount: widget.travellerCount,
                        travelStart: widget.travelStart,
                        travelEnd: widget.travelEnd,
                        userCurrency: userCurrency,
                      )));
                if (plans.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'This partner has no plan available for your trip to ${widget.destination} right now -- it may not cover this destination, your residence country, or a trip this long.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ComparePlanCard(
                    plan: plans[i],
                    travelStart: widget.travelStart,
                    travelEnd: widget.travelEnd,
                    travellerCount: widget.travellerCount,
                    tripId: widget.tripId,
                    userCurrency: userCurrency,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparePlanCard extends StatelessWidget {
  final InsurancePlan plan;
  final DateTime travelStart;
  final DateTime travelEnd;
  final int travellerCount;
  final String? tripId;
  final String? userCurrency;

  const _ComparePlanCard({
    required this.plan,
    required this.travelStart,
    required this.travelEnd,
    required this.travellerCount,
    this.tripId,
    this.userCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final total = insurancePlanTotal(
      plan,
      travellerCount: travellerCount,
      travelStart: travelStart,
      travelEnd: travelEnd,
      userCurrency: userCurrency,
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InsurancePlanDetailPage(
            plan: plan,
            tripId: tripId,
            initialTravellerCount: travellerCount,
            initialTravelStart: travelStart,
            initialTravelEnd: travelEnd,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                insuranceLogo(plan, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 2),
                      Text('• ${plan.coverage}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${CurrencyService.instance.displayLabel(userCurrency ?? 'MYR')}${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    Text('total · ${plan.displayPrice(userCurrency)} ${insurancePriceUnitLabel(plan.category)}', style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
            if (plan.highlights.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: plan.highlights.take(3).map((h) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(8)),
                  child: Text(h, style: const TextStyle(fontSize: 9.5, color: AppColors.navy)),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
