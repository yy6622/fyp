import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../controllers/near_by_controller.dart';
import '../../models/nearby_models.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../detail/detail_page_place.dart';
import '../shared/maps_launcher.dart';

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
                child: SizedBox(
                  height: 170,
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => _map(),
                  ),
                ),
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
                    if (controller.error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_outlined, size: 32, color: AppColors.textGrey),
                              const SizedBox(height: 12),
                              Text(controller.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                              const SizedBox(height: 14),
                              OutlinedButton(onPressed: controller.retry, child: const Text('Try Again')),
                            ],
                          ),
                        ),
                      );
                    }
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

  IconData _iconFor(String category) {
    for (final (label, icon) in _categories) {
      if (label == category) return icon;
    }
    return Icons.place_outlined;
  }

  Color _colorFor(String category) {
    switch (category) {
      case 'Restaurants':
        return Colors.redAccent;
      case 'Cafes':
        return const Color(0xFFA9703B);
      case 'Attractions':
        return Colors.purple;
      case 'Shopping':
        return Colors.blue;
      case 'ATM':
        return Colors.green;
      case 'Pharmacy':
        return Colors.pink;
      default:
        return AppColors.primary;
    }
  }

  Widget _map() {
    final myLat = controller.myLat;
    final myLon = controller.myLon;
    if (myLat == null || myLon == null) {
      return Container(
        color: AppColors.chipGrey,
        alignment: Alignment.center,
        child: const Icon(Icons.map_outlined, size: 28, color: AppColors.textGrey),
      );
    }
    final me = ll.LatLng(myLat, myLon);
    return FlutterMap(
      options: MapOptions(initialCenter: me, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.voya.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: me,
              width: 30,
              height: 30,
              child: Container(
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
            for (final place in controller.places)
              Marker(
                point: ll.LatLng(place.lat, place.lon),
                width: 34,
                height: 34,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailPagePlace(place: place))),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _colorFor(place.category),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(_iconFor(place.category), size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
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
            if (place.category != 'Restaurants') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _placeImage(place),
              ),
              const SizedBox(width: 14),
            ],
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
                const SizedBox(height: 2),
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
