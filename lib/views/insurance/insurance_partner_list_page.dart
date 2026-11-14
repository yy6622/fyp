import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../controllers/insurance_controller.dart';
import '../../models/insurance_models.dart';
import '../../theme.dart';
import 'insurance_partner_detail_page.dart';

/// Entry point of the insurance flow: pick an insurer first, then (from
/// [InsurancePartnerDetailPage]) chat with them or get a quote — only after
/// that does a traveller ever see a specific plan. There is deliberately no
/// "browse all plans" shortcut here: a plan is only ever shown once a
/// partner has been chosen and has handed one over via the quote step, not
/// before.
class InsurancePartnerListPage extends StatefulWidget {
  final String? tripId;
  const InsurancePartnerListPage({super.key, this.tripId});

  @override
  State<InsurancePartnerListPage> createState() => _InsurancePartnerListPageState();
}

class _InsurancePartnerListPageState extends State<InsurancePartnerListPage> {
  final InsurancePartnerListController controller = InsurancePartnerListController();

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
                  const Text('Choose an insurer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  const Text(
                    "Pick who you'd like to buy cover from — you can message them with questions before you buy.",
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  ...controller.partners.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PartnerCard(partner: p, tripId: widget.tripId),
                      )),
                  if (controller.partners.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No insurance partners yet', style: TextStyle(color: AppColors.textGrey)),
                      ),
                    ),
                ],
              ),
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

Widget partnerLogo(InsurancePartner partner, {double size = 46}) {
  final letterBadge = Text(
    partner.logoText,
    style: TextStyle(
      color: partner.logoColor,
      fontWeight: FontWeight.bold,
      fontSize: partner.logoText.length > 1 ? size * 0.24 : size * 0.34,
    ),
  );
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFECECEC)),
    ),
    alignment: Alignment.center,
    child: (partner.logoUrl != null && partner.logoUrl!.isNotEmpty)
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: partner.logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (context, url) => letterBadge,
              errorWidget: (context, url, error) => letterBadge,
            ),
          )
        : letterBadge,
  );
}

class _PartnerCard extends StatelessWidget {
  final InsurancePartner partner;
  final String? tripId;
  const _PartnerCard({required this.partner, this.tripId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InsurancePartnerDetailPage(partner: partner, tripId: tripId)),
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
            partnerLogo(partner),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    partner.activePlanCount == 1 ? '1 plan available' : '${partner.activePlanCount} plans available',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
