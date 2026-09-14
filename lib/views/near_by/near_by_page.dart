import 'package:flutter/material.dart';

import '../../controllers/near_by_controller.dart';
import '../../models/nearby_models.dart';
import '../../theme.dart';
import '../detail/detail_page_place.dart';
import 'map_painter.dart';

class NearByPage extends StatefulWidget {
  const NearByPage({super.key});

  @override
  State<NearByPage> createState() => _NearByPageState();
}

class _NearByPageState extends State<NearByPage> {
  final NearByController controller = NearByController();

  static const _categories = [
    ('Restaurants', Icons.restaurant_outlined),
    ('Cafes', Icons.local_cafe_outlined),
    ('Attractions', Icons.attractions_outlined),
    ('Shopping', Icons.shopping_bag_outlined),
    ('ATM', Icons.local_atm_outlined),
    ('Pharmacy', Icons.local_pharmacy_outlined),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Text('Near By', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final (label, icon) = _categories[i];
                    final selected = label == controller.selectedCategory;
                    return GestureDetector(
                      onTap: () => controller.selectCategory(label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.chipGrey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textGrey),
                            const SizedBox(width: 6),
                            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(height: 170, child: CustomPaint(painter: MapPainter(), size: Size.infinite)),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  if (controller.loading) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (controller.places.isEmpty) {
                    return const Center(child: Text('No places found nearby', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: controller.places.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _placeCard(controller.places[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeCard(NearbyPlace place) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailPagePlace(place: place))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                place.image,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 4),
                  Text(place.categoryLabel, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text(place.rating, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.near_me_outlined, size: 14, color: AppColors.primary),
                const SizedBox(height: 4),
                Text(place.distance, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
