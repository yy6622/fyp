import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../controllers/saved_items_controller.dart';
import '../../repositories/catalog_repository.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import '../detail/detail_page_attraction.dart';
import '../detail/detail_page_restaurant.dart';

enum _SavedTab { attractions, restaurants }

class SavedItemsPage extends StatefulWidget {
  final String tripId;
  final String tripName;
  const SavedItemsPage({super.key, required this.tripId, required this.tripName});

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

class _SavedItemsPageState extends State<SavedItemsPage> {
  late final SavedItemsController controller = SavedItemsController(tripId: widget.tripId);
  _SavedTab _tab = _SavedTab.attractions;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text('Saved for ${widget.tripName}',
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Row(
              children: [
                _tabButton('Attractions', _SavedTab.attractions),
                _tabButton('Restaurant', _SavedTab.restaurants),
              ],
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, _SavedTab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => setState(() => _tab = tab),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.white, width: 2)),
            ),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case _SavedTab.attractions:
        if (controller.loadingAttractions) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (controller.attractions.isEmpty) return _empty('No attractions saved for this trip yet.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          itemCount: controller.attractions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _attractionCard(controller.attractions[i]),
        );
      case _SavedTab.restaurants:
        if (controller.loadingRestaurants) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (controller.restaurants.isEmpty) return _empty('No restaurants saved for this trip yet.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          itemCount: controller.restaurants.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _restaurantCard(controller.restaurants[i]),
        );
    }
  }

  Widget _empty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
      ),
    );
  }

  Widget _cardImage(String url, IconData icon) {
    if (url.isEmpty) {
      return Container(width: 56, height: 56, color: AppColors.chipGrey, child: Icon(icon, color: AppColors.textGrey, size: 22));
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(width: 56, height: 56, color: AppColors.chipGrey),
      errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.chipGrey, child: Icon(icon, color: AppColors.textGrey, size: 22)),
    );
  }

  Widget _card({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: child,
      ),
    );
  }

  Widget _attractionCard(CatalogAttraction attraction) {
    return _card(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DetailPageAttraction(
          attraction: attraction,
          saved: true,
          onToggleSave: () => controller.unsaveAttraction(attraction),
        ),
      )),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _cardImage(attraction.image, Icons.attractions_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attraction.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(attraction.category, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text(attraction.price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.unsaveAttraction(attraction),
            child: const Icon(Icons.favorite, size: 20, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _restaurantCard(CatalogRestaurant restaurant) {
    return _card(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DetailPageRestaurant(
          restaurant: restaurant,
          saved: true,
          onToggleSave: () => controller.unsaveRestaurant(restaurant),
        ),
      )),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(restaurant.cuisineLabel, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text(restaurant.priceRange, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.unsaveRestaurant(restaurant),
            child: const Icon(Icons.favorite, size: 20, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
