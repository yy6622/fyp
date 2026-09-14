import 'package:flutter/material.dart';

import '../../models/nearby_models.dart';
import '../../theme.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Near-by place detail (restaurant, cafe, attraction, shop, ATM, pharmacy)
// ---------------------------------------------------------------------
// Near By places are a lighter-weight catalogue than Explore's hotels /
// attractions (no id-based favoriting yet), so this is a plain info page —
// no booking or save action, just what NearByPage's row already knows
// plus a bit more context.
class DetailPagePlace extends StatelessWidget {
  final NearbyPlace place;
  const DetailPagePlace({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            DetailHeader(title: place.name),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  Text(place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  Text(place.categoryLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text(place.rating, style: const TextStyle(fontSize: 13, color: Colors.black)),
                      const SizedBox(width: 18),
                      const Icon(Icons.near_me_outlined, size: 15, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(place.distance, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 16),
                  const Text('Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: InfoField(label: 'Category', value: place.category)),
                            Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
                            const SizedBox(width: 16),
                            Expanded(child: InfoField(label: 'Distance', value: place.distance)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: InfoField(label: 'Rating', value: place.rating)),
                            Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
                            const SizedBox(width: 16),
                            Expanded(child: InfoField(label: 'Type', value: place.categoryLabel)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
