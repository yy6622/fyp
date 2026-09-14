import 'package:flutter/material.dart';

import '../../controllers/saved_items_controller.dart';
import '../../repositories/catalog_repository.dart';
import '../../theme.dart';
import '../detail/detail_page_attraction.dart';
import '../detail/detail_page_flight.dart';
import '../detail/detail_page_hotel.dart';
import '../detail/detail_page_restaurant.dart';

enum _SavedTab { flights, hotels, attractions, restaurants }

/// Shown when the heart icon on Explore is tapped — everything the user
/// saved for [tripName] specifically (see [SavedItemsController]).
class SavedItemsPage extends StatefulWidget {
  final String tripId;
  final String tripName;
  const SavedItemsPage({super.key, required this.tripId, required this.tripName});

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

class _SavedItemsPageState extends State<SavedItemsPage> {
  late final SavedItemsController controller = SavedItemsController(tripId: widget.tripId);
  _SavedTab _tab = _SavedTab.flights;

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
                Expanded(child: _tabButton('Flights', _SavedTab.flights)),
                Expanded(child: _tabButton('Hotels', _SavedTab.hotels)),
                Expanded(child: _tabButton('Places', _SavedTab.attractions)),
                Expanded(child: _tabButton('Food', _SavedTab.restaurants)),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFECECEC)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, _SavedTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case _SavedTab.flights:
        if (controller.loadingFlights) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (controller.flights.isEmpty) return _empty('No flights saved for this trip yet.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          itemCount: controller.flights.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _flightCard(controller.flights[i]),
        );
      case _SavedTab.hotels:
        if (controller.loadingHotels) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (controller.hotels.isEmpty) return _empty('No hotels saved for this trip yet.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          itemCount: controller.hotels.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _hotelCard(controller.hotels[i]),
        );
      case _SavedTab.attractions:
        if (controller.loadingAttractions) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (controller.attractions.isEmpty) return _empty('No places saved for this trip yet.');
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

  Widget _flightCard(CatalogFlight flight) {
    return _card(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DetailPageFlight(
          fromCode: flight.from,
          toCode: flight.to,
          depTime: flight.depTime,
          arrTime: flight.arrTime,
          duration: flight.duration,
          stops: flight.stops,
          price: flight.price,
          priceSuffix: flight.fareType,
        ),
      )),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${flight.from} → ${flight.to}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text('${flight.depTime} - ${flight.arrTime} · ${flight.stops}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text(flight.price, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.unsaveFlight(flight),
            child: const Icon(Icons.favorite, size: 20, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _hotelCard(CatalogHotel hotel) {
    return _card(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DetailPageHotel(
          name: hotel.name,
          location: hotel.location,
          ratingLabel: '${hotel.rating}(${hotel.reviews})',
          pricePerNight: hotel.price,
        ),
      )),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(hotel.image, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hotel.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(hotel.location, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text('${hotel.price} per night', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.unsaveHotel(hotel),
            child: const Icon(Icons.favorite, size: 20, color: Colors.redAccent),
          ),
        ],
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
            child: Image.network(attraction.image, width: 56, height: 56, fit: BoxFit.cover),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(restaurant.image, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
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
