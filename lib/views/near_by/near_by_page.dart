import 'package:flutter/material.dart';

import '../../controllers/near_by_controller.dart';
import '../../models/nearby_models.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../detail/detail_page_place.dart';
import '../shared/maps_launcher.dart';
import '../shared/translated_text.dart';
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
                  if (controller.locationStatus != LocationLookupStatus.success) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_off_outlined, size: 36, color: AppColors.textGrey),
                            const SizedBox(height: 12),
                            const Text(
                              "Couldn't get your location — turn on location services and allow access to see what's nearby.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(onPressed: controller.retryLocation, child: const Text('Try Again')),
                          ],
                        ),
                      ),
                    );
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

  /// Matches a place's category chip to its icon (see [_categories]) —
  /// used as the fallback image box so a place with no real photo still
  /// shows something relevant to what it actually is, not a plain blank
  /// grey square.
  IconData _iconFor(String category) {
    for (final (label, icon) in _categories) {
      if (label == category) return icon;
    }
    return Icons.place_outlined;
  }

  Widget _placeImage(NearbyPlace place) {
    if (place.image.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Icon(_iconFor(place.category), color: AppColors.textGrey, size: 22),
      );
    }
    return Image.network(
      place.image,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Icon(_iconFor(place.category), color: AppColors.textGrey, size: 22),
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
              child: _placeImage(place),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(place.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
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
                const SizedBox(height: 2),
                // A real IconButton (not a plain Icon) so its tap is
                // handled here and never bubbles up to the card's own
                // onTap (which opens the detail page instead) — lets
                // "get directions" work straight from the list, not just
                // from inside the detail page.
                IconButton(
                  onPressed: () => openDirections(context, place.lat, place.lon),
                  icon: const Icon(Icons.directions_outlined, size: 18, color: AppColors.primary),
                  tooltip: 'Get Directions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
