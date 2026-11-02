import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../controllers/explore_controller.dart';
import '../../controllers/filter_controller.dart';
import '../../models/duffel_models.dart';
import '../../models/explore_models.dart';
import '../../repositories/catalog_repository.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/format_utils.dart';
import '../../services/recommendation_service.dart';
import '../../theme.dart';
import '../detail/detail_page_attraction.dart';
import '../detail/detail_page_flight.dart';
import '../detail/detail_page_hotel.dart';
import '../detail/detail_page_restaurant.dart';
import '../detail/detail_widgets.dart' show tagChip;
import '../filter/filter_page.dart';
import '../near_by/near_by_page.dart';
import 'attraction_chat_page.dart';
import 'saved_items_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final ExploreController controller = ExploreController();
  final TextEditingController _searchController = TextEditingController();
  final FilterController filterController = FilterController();

  final GlobalKey _bestFlightsKey = GlobalKey();

  final GlobalKey _belowBannerKey = GlobalKey();

  final ScrollController _pageScroll = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _pageScroll.dispose();
    controller.dispose();
    filterController.dispose();
    super.dispose();
  }

  void _scrollToBestFlights() {
    final ctx = _bestFlightsKey.currentContext ?? _belowBannerKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut, alignment: 0.0);
      return;
    }
    if (!_pageScroll.hasClients) return;
    final p = _pageScroll.position;
    _pageScroll.animateTo((p.pixels + p.viewportDimension * 0.6).clamp(0.0, p.maxScrollExtent),
        duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
  }

  void _runTopBarSearch() => controller.searchFromTopBar(_searchController.text);

  void _clearManualSearch() {
    _searchController.clear();
    controller.clearManualSearch();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, filterController]),
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        floatingActionButton: _buildAiFab(),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _pageScroll,
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildTripCard(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    if (controller.isManualSearch) ...[
                      const SizedBox(height: 10),
                      _buildManualSearchBar(),
                    ],
                    const SizedBox(height: 14),
                    _buildCategoryChips(),
                    const SizedBox(height: 10),
                    _buildBody(),
                  ],
                ),
              ),
              if (controller.showTripSwitcher) _buildTripSwitcherOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Header ----------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Find your next adventure',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
          Row(
            children: [
              HeaderIconButton(
                icon: Icons.favorite_border,
                onTap: _openSavedItems,
              ),
              if (controller.selectedCategory != ExploreCategory.all) ...[
                const SizedBox(width: 10),
                HeaderIconButton(
                  icon: Icons.tune,
                  onTap: _openFilterSheet,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openSavedItems() {
    final trip = controller.selectedTrip;
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a plan first to save flights, hotels and attractions to it.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SavedItemsPage(tripId: trip.id, tripName: trip.name)),
    );
  }

  void _openFilterSheet() {
    final availableAirlines = controller.flightResults.map((f) => f.airlineName).where((n) => n.isNotEmpty).toSet().toList()
      ..sort();
    filterController.airlines.removeWhere((a) => !availableAirlines.contains(a));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterPage(
        type: controller.selectedCategory.filterType,
        controller: filterController,
        availableAirlines: availableAirlines,
      ),
    );
  }


  List<int> _numbersIn(String text) => RegExp(r'\d+').allMatches(text).map((m) => int.parse(m.group(0)!)).toList();

  bool _priceTextMatchesBucket(String priceText, String bucket) {
    final lower = priceText.toLowerCase();
    if (bucket == 'Free') return lower.contains('free');
    if (lower.contains('free')) return false;
    final numbers = _numbersIn(priceText);
    if (numbers.isEmpty) return false;
    final lo = numbers.first;
    final hi = numbers.length > 1 ? numbers.last : numbers.first;
    switch (bucket) {
      case 'RM0 - 20':
      case 'RM0 - 50':
        return lo <= (bucket == 'RM0 - 20' ? 20 : 50);
      case 'RM20 - 50':
        return hi >= 20 && lo <= 50;
      case 'RM50 - 100':
        return hi >= 50 && lo <= 100;
      case 'RM50 - 150':
        return hi >= 50 && lo <= 150;
      case 'RM100+':
        return hi >= 100;
      case 'RM150+':
        return hi >= 150;
      default:
        return true;
    }
  }

  List<DuffelFlightOffer> get _visibleFlights {
    final f = filterController;
    return controller.flightResults.where((flight) {
      final amount = CurrencyService.instance.convert(flight.totalAmount, from: flight.totalCurrency, to: 'MYR') ?? flight.totalAmount;
      if (amount < f.priceRange.start || amount > f.priceRange.end) return false;
      if (f.stops.isNotEmpty) {
        final bucket = flight.stops == 0 ? 'Direct' : (flight.stops == 1 ? '1 Stop' : '2+ Stops');
        if (!f.stops.contains(bucket)) return false;
      }
      if (f.departureTimes.isNotEmpty) {
        final hour = flight.departureAt.hour;
        final bucket = hour < 6
            ? 'Early Morning'
            : hour < 12
                ? 'Morning'
                : hour < 17
                    ? 'Afternoon'
                    : hour < 21
                        ? 'Evening'
                        : 'Night';
        if (!f.departureTimes.contains(bucket)) return false;
      }
      if (f.airlines.isNotEmpty && !f.airlines.contains(flight.airlineName)) return false;
      final hours = flight.flightDuration.inMinutes / 60.0;
      if (hours < f.durationRange.start || hours > f.durationRange.end) return false;
      return true;
    }).toList();
  }

  List<DuffelStayResult> get _visibleHotels {
    final f = filterController;
    return controller.hotelResults.where((hotel) {
      final amount = CurrencyService.instance.convert(hotel.cheapestTotalAmount, from: hotel.cheapestCurrency, to: 'MYR') ?? hotel.cheapestTotalAmount;
      if (amount < f.priceRange.start || amount > f.priceRange.end) return false;
      if (f.starRatings.isNotEmpty) {
        final star = hotel.rating?.round();
        if (star == null || !f.starRatings.contains('$star★')) return false;
      }
      if (f.guestRating != 'Any') {
        final score = hotel.reviewScore != null ? hotel.reviewScore! / 2 : hotel.rating;
        final threshold = double.tryParse(f.guestRating.replaceAll('+', '')) ?? 0;
        if (score == null || score < threshold) return false;
      }
      return true;
    }).toList();
  }

  List<CatalogAttraction> get _visibleAttractions {
    final f = filterController;
    final categoryFiltered = controller.attractions.where((item) {
      if (f.attractionCategories.isEmpty) return true;
      final tags = item.categories.isNotEmpty ? item.categories : [item.category];
      return f.attractionCategories.any(tags.contains);
    }).toList();
    final ctx = RecommendationContext(
      withinBudget: (a) => f.attractionPrice == 'Any' || _priceTextMatchesBucket(a.price, f.attractionPrice),
      affinity: controller.attractionAffinity,
      requireOpenNow: f.openNow,
      requireAccessible: f.accessibleOnly,
    );
    return AttractionRecommendation.rank(categoryFiltered, ctx);
  }

  List<CatalogRestaurant> get _visibleRestaurants {
    final f = filterController;
    return controller.restaurants.where((item) {
      if (f.restaurantCuisines.isNotEmpty && !f.restaurantCuisines.any(item.cuisineTags.contains)) return false;
      if (f.restaurantPrice != 'Any' && !_priceTextMatchesBucket(item.priceRange, f.restaurantPrice)) return false;
      return true;
    }).toList();
  }

  // ---------------- Current trip card ----------------
  Widget _buildTripCard() {
    final trip = controller.selectedTrip;
    if (trip == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppColors.chipGrey),
          child: const Text('No trips yet — create one from the Plan tab to see it here.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 1.2),
            ),
            child: Row(
              children: [
                _tripInfoItem('Destination', trip.destination.isEmpty ? '-' : trip.destination),
                _verticalDivider(),
                _tripInfoItem('Date', trip.startDate == null ? '-' : trip.dateRangeLabel.split(' · ').first),
                _verticalDivider(),
                _tripInfoItem('Travellers', '${trip.memberIds.length} Travellers'),
                _verticalDivider(),
                _tripInfoItem('Budget', 'RM ${trip.budgetPerPerson.toStringAsFixed(0)}'),
                const SizedBox(width: 8),
                if (controller.trips.length > 1)
                  GestureDetector(
                    onTap: () => controller.toggleTripSwitcher(),
                    child: const Icon(Icons.swap_horiz, color: AppColors.primary, size: 20),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: AppColors.scaffoldBackground,
              child: Text(
                trip.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSwitcherOverlay() {
    final media = MediaQuery.of(context);
    const topOffset = 96.0;
    const bottomBreathingRoom = 40.0;
    final maxHeight = media.size.height - media.viewInsets.bottom - topOffset - bottomBreathingRoom;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => controller.closeTripSwitcher(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: topOffset),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight < 120 ? 120 : maxHeight),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(controller.trips.length, (i) {
                      final trip = controller.trips[i];
                      final selected = i == controller.selectedTripIndex;
                      return Padding(
                        padding: EdgeInsets.only(bottom: i < controller.trips.length - 1 ? 10 : 0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => controller.selectTrip(i),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? AppColors.primary : const Color(0xFFE2E6E9),
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trip.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _tripInfoItem('Destination', trip.destination.isEmpty ? '-' : trip.destination),
                                    _verticalDivider(),
                                    _tripInfoItem('Date', trip.startDate == null ? '-' : trip.dateRangeLabel.split(' · ').first),
                                    _verticalDivider(),
                                    _tripInfoItem('Travellers', '${trip.memberIds.length} Travellers'),
                                    _verticalDivider(),
                                    _tripInfoItem('Budget', 'RM ${trip.budgetPerPerson.toStringAsFixed(0)}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiFab() {
    return FloatingActionButton(
      heroTag: 'explore_ai_fab',
      mini: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.primary,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AttractionChatPage(
          destination: controller.bannerDestination,
          candidates: controller.attractions,
          uid: AuthService.instance.currentUser?.uid ?? '',
          tripId: controller.selectedTrip?.id,
        ),
      )),
      child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE2E6E9),
    );
  }

  Widget _tripInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------- Search bar ----------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.chipGrey,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _runTopBarSearch,
              child: const Icon(Icons.search, color: AppColors.textGrey, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runTopBarSearch(),
                decoration: const InputDecoration(
                  hintText: 'Search destination, flight, hotel, attraction, ...',
                  hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            controller.isManualSearch
                ? GestureDetector(
                    onTap: _clearManualSearch,
                    child: const Icon(Icons.close, color: AppColors.textGrey, size: 20),
                  )
                : const Icon(Icons.mic_none, color: AppColors.textGrey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.search, size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing results for "${controller.lastSearchQuery}"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
              ),
            ),
            GestureDetector(
              onTap: _clearManualSearch,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 14, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Category chips ----------------
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: ExploreCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = ExploreCategory.values[index];
          final selected = category == controller.selectedCategory;
          return GestureDetector(
            onTap: () => controller.setSelectedCategory(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.chipGrey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 16,
                    color: selected ? Colors.white : AppColors.textGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (controller.selectedCategory) {
      case ExploreCategory.all:
        return _buildAllView();
      case ExploreCategory.flights:
        return _buildFlightListView();
      case ExploreCategory.accommodation:
        return _buildHotelListView();
      case ExploreCategory.attractions:
        return _buildAttractionListView();
      case ExploreCategory.restaurants:
        return _buildRestaurantListView();
    }
  }

  Widget _buildAllView() {
    final showFlights = controller.loadingFlights || (controller.flightError == null && _visibleFlights.isNotEmpty);
    final showHotels = controller.loadingHotels || (controller.hotelError == null && _visibleHotels.isNotEmpty);
    final showAttractions = controller.loadingPlaces || _visibleAttractions.isNotEmpty;
    final showRestaurants = controller.loadingPlaces || _visibleRestaurants.isNotEmpty;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildExploreBanner(),
        SizedBox(key: _belowBannerKey, height: 22),
        if (showFlights) ...[
          KeyedSubtree(
            key: _bestFlightsKey,
            child: _buildSectionHeader(Icons.flight_takeoff, 'Best Flight Deals', ExploreCategory.flights,
                subtitle: controller.flightResultsLabel == 'Popular destinations' ? null : controller.flightResultsLabel),
          ),
          const SizedBox(height: 12),
          _buildFlightHorizontalList(),
          const SizedBox(height: 22),
        ],
        if (showHotels) ...[
          _buildSectionHeader(Icons.hotel_outlined, 'Recommended Hotels', ExploreCategory.accommodation,
              subtitle: controller.hotelResultsLabel == 'Popular destinations' ? null : controller.hotelResultsLabel),
          const SizedBox(height: 12),
          _buildHotelHorizontalList(),
          const SizedBox(height: 22),
        ],
        if (showAttractions) ...[
          _buildSectionHeader(Icons.attractions_outlined, 'Top Attractions', ExploreCategory.attractions),
          const SizedBox(height: 12),
          _buildAttractionHorizontalList(),
          const SizedBox(height: 22),
        ],
        if (showRestaurants) ...[
          _buildSectionHeader(Icons.restaurant_outlined, 'Top Restaurants', ExploreCategory.restaurants),
          const SizedBox(height: 12),
          _buildRestaurantHorizontalList(),
          const SizedBox(height: 22),
        ],
        _buildNearbyPreview(),
      ],
    );
  }

  Widget _buildNearbyPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.near_me_outlined, size: 18, color: AppColors.navy),
              SizedBox(width: 8),
              Text('Explore Nearby', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NearByPage())),
            child: const Text('View On Map', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  static const _bannerFallbackImage = 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800';

  Widget _buildExploreBanner() {
    final destination = controller.bannerDestination;
    final hasTrip = controller.selectedTrip != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                controller.bannerImageUrl ?? _bannerFallbackImage,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Image.network(_bannerFallbackImage, fit: BoxFit.cover),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Explore $destination',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasTrip ? 'Your trip is coming up' : 'One of our popular picks',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Text(
                      'Find the best flights and hotel deals below',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _scrollToBestFlights,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Explore Now',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ExploreCategory jumpTo, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => controller.setSelectedCategory(jumpTo),
            child: const Text(
              'View All',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightHorizontalList() {
    if (controller.loadingFlights) return const SizedBox(height: 148, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (controller.flightError != null || _visibleFlights.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 148,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _visibleFlights.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildFlightCompactCard(_visibleFlights[index]),
      ),
    );
  }

  Widget _buildFlightCompactCard(DuffelFlightOffer flight) {
    final saved = controller.savedFlightIds.contains(flight.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _flightDetailFor(flight))),
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(12),
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
                _airlineLogo(flight.airlineLogoUrl, size: 22, iconSize: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(flight.airlineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                ),
                GestureDetector(
                  onTap: () => controller.saveFlightResult(flight),
                  child: Icon(saved ? Icons.favorite : Icons.favorite_border, size: 16, color: saved ? Colors.redAccent : AppColors.textGrey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${flight.originCode} → ${flight.destinationCode}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text('${flight.durationLabel} · ${flight.stopsLabel}', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
            const SizedBox(height: 10),
            Text(
              controller.formatPrice(flight.totalAmount, flight.totalCurrency),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  DetailPageFlight _flightDetailFor(DuffelFlightOffer flight) => DetailPageFlight(
        airline: flight.airlineName,
        fromCode: flight.originCode,
        fromCity: flight.originCityName,
        toCode: flight.destinationCode,
        toCity: flight.destinationCityName,
        flightNo: flight.flightNumber,
        date: formatLongDate(flight.departureAt),
        depTime: _hhmm(flight.departureAt),
        arrTime: _hhmm(flight.arrivalAt),
        duration: flight.durationLabel,
        stops: flight.stopsLabel,
        price: controller.formatPrice(flight.totalAmount, flight.totalCurrency),
        priceSuffix: 'Economy',
        airlineLogoUrl: flight.airlineLogoUrl,
        tripId: controller.selectedTrip?.id ?? '',
        departureAt: flight.departureAt,
        arrivalAt: flight.arrivalAt,
        aircraftName: flight.aircraftName,
        cabinClass: flight.cabinClass,
        originTerminal: flight.originTerminal,
        destinationTerminal: flight.destinationTerminal,
        checkedBagQuantity: flight.checkedBagQuantity,
        carryOnBagQuantity: flight.carryOnBagQuantity,
        changeAllowed: flight.changeAllowed,
        changePenaltyAmount: flight.changePenaltyAmount,
        changePenaltyCurrency: flight.changePenaltyCurrency,
        refundAllowed: flight.refundAllowed,
        refundPenaltyAmount: flight.refundPenaltyAmount,
        refundPenaltyCurrency: flight.refundPenaltyCurrency,
      );

  String _hhmm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _airlineLogo(String? logoUrl, {required double size, required double iconSize}) {
    Widget fallback() => Icon(Icons.flight, size: iconSize, color: AppColors.textGrey);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(size * 0.3)),
      alignment: Alignment.center,
      child: logoUrl == null
          ? fallback()
          : FittedBox(
              fit: BoxFit.contain,
              child: SvgPicture.network(
                logoUrl,
                placeholderBuilder: (_) => fallback(),
                errorBuilder: (_, __, ___) => fallback(),
              ),
            ),
    );
  }

  Widget _buildFlightListView() => _buildFlightListBody();

  Widget _buildFlightListBody() {
    if (controller.loadingFlights) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (controller.flightError != null || _visibleFlights.isEmpty) {
      return _searchEmptyBox('No flights found — try a different search.', padded: true);
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _visibleFlights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildFlightRowCard(_visibleFlights[index]),
    );
  }

  Widget _buildFlightRowCard(DuffelFlightOffer flight) {
    final saved = controller.savedFlightIds.contains(flight.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _flightDetailFor(flight))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Row(
          children: [
            _airlineLogo(flight.airlineLogoUrl, size: 46, iconSize: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flight.airlineName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(_hhmm(flight.departureAt), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      Expanded(
                        child: Column(
                          children: [
                            Text(flight.durationLabel, style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
                            Container(margin: const EdgeInsets.symmetric(horizontal: 6), height: 1, color: const Color(0xFFD9D9D9)),
                          ],
                        ),
                      ),
                      Text(_hhmm(flight.arrivalAt), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(flight.originCode, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                      Text(flight.stopsLabel, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                      Text(flight.destinationCode, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(controller.formatPrice(flight.totalAmount, flight.totalCurrency),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => controller.saveFlightResult(flight),
              child: Icon(saved ? Icons.favorite : Icons.favorite_border, size: 18, color: saved ? Colors.redAccent : AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelHorizontalList() {
    if (controller.loadingHotels) return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (controller.hotelError != null || _visibleHotels.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _visibleHotels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildHotelCompactCard(_visibleHotels[index]),
      ),
    );
  }

  DetailPageHotel _hotelDetailFor(DuffelStayResult hotel) => DetailPageHotel(
        name: hotel.name,
        location: hotel.address,
        ratingLabel: hotel.reviewScore != null
            ? '${(hotel.reviewScore! / 2).toStringAsFixed(1)}(${hotel.reviewCount ?? 0})'
            : (hotel.rating != null ? hotel.rating!.toStringAsFixed(1) : ''),
        pricePerNight: controller.formatPrice(hotel.cheapestTotalAmount, hotel.cheapestCurrency),
        image: hotel.photoUrl ?? '',
        tripId: controller.selectedTrip?.id ?? '',
        checkIn: controller.lastHotelCheckIn,
        checkOut: controller.lastHotelCheckOut,
        amenities: hotel.amenities,
        checkInPolicyTime: hotel.checkInPolicyTime,
        checkOutPolicyTime: hotel.checkOutPolicyTime,
      );

  Widget _buildHotelCompactCard(DuffelStayResult hotel) {
    final saved = controller.savedStayIds.contains(hotel.searchResultId);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _hotelDetailFor(hotel))),
      child: Container(
        width: 155,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _placeCardImage(hotel.photoUrl ?? '', height: 95, width: double.infinity, icon: Icons.hotel_outlined),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => controller.saveHotelResult(hotel),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(saved ? Icons.favorite : Icons.favorite_border, size: 12, color: saved ? Colors.redAccent : AppColors.textGrey),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  if (hotel.reviewScore != null || hotel.rating != null)
                    Row(children: [
                      const Icon(Icons.star, size: 12, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text(
                        hotel.reviewScore != null
                            ? '${(hotel.reviewScore! / 2).toStringAsFixed(1)} (${hotel.reviewCount ?? 0})'
                            : hotel.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                      ),
                    ]),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: '${controller.formatPrice(hotel.cheapestTotalAmount, hotel.cheapestCurrency)} ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const TextSpan(text: 'per night', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelListView() => _buildHotelListBody();

  Widget _buildHotelListBody() {
    if (controller.loadingHotels) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (controller.hotelError != null || _visibleHotels.isEmpty) {
      return _searchEmptyBox('No hotels found — try a different search.', padded: true);
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _visibleHotels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildHotelRowCard(_visibleHotels[index]),
    );
  }

  Widget _buildHotelRowCard(DuffelStayResult hotel) {
    final saved = controller.savedStayIds.contains(hotel.searchResultId);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _hotelDetailFor(hotel))),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _placeCardImage(hotel.photoUrl ?? '', width: 80, height: 80, icon: Icons.hotel_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotel.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  if (hotel.reviewScore != null || hotel.rating != null)
                    Row(children: [
                      const Icon(Icons.star, size: 14, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text(
                        hotel.reviewScore != null
                            ? '${(hotel.reviewScore! / 2).toStringAsFixed(1)}(${hotel.reviewCount ?? 0})'
                            : hotel.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ]),
                  const SizedBox(height: 4),
                  Text(hotel.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: '${controller.formatPrice(hotel.cheapestTotalAmount, hotel.cheapestCurrency)} ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const TextSpan(text: 'per night', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    ]),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => controller.saveHotelResult(hotel),
              child: Icon(saved ? Icons.favorite : Icons.favorite_border, size: 18, color: saved ? Colors.redAccent : AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchEmptyBox(String message, {bool padded = false}) {
    final child = Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textGrey));
    return Padding(
      padding: padded ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24) : const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );
  }

  Widget _placeCardImage(String url, {required double height, required double width, required IconData icon}) {
    if (url.isEmpty) {
      return Container(height: height, width: width, color: AppColors.chipGrey, child: Icon(icon, color: AppColors.textGrey, size: height * 0.35));
    }
    return Image.network(
      url,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(height: height, width: width, color: AppColors.chipGrey, child: Icon(icon, color: AppColors.textGrey, size: height * 0.35)),
    );
  }

  // ================= ATTRACTIONS =================
  Widget _buildAttractionHorizontalList() {
    if (controller.loadingPlaces && _visibleAttractions.isEmpty) {
      return const SizedBox(height: 198, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_visibleAttractions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 198,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _visibleAttractions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildAttractionCompactCard(_visibleAttractions[index]),
      ),
    );
  }

  Widget _buildAttractionCompactCard(CatalogAttraction item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openAttractionDetail(item, favorited),
      child: Container(
      width: 145,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: _placeCardImage(item.image, height: 95, width: double.infinity, icon: Icons.attractions_outlined),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => controller.toggleAttractionFavorite(item),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 12, color: favorited ? Colors.redAccent : AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${item.rating} (${item.reviews})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _openAttractionDetail(CatalogAttraction item, bool favorited) {
    final tripId = controller.selectedTrip?.id;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailPageAttraction(
        attraction: item,
        saved: favorited,
        onToggleSave: tripId == null ? null : () => controller.toggleAttractionFavorite(item),
      ),
    ));
  }

  Widget _buildAttractionListView() {
    if (controller.loadingPlaces && _visibleAttractions.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_visibleAttractions.isEmpty) return _searchEmptyBox('No attractions found — try a different search.', padded: true);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _visibleAttractions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildAttractionRowCard(_visibleAttractions[index]),
    );
  }

  Widget _buildAttractionRowCard(CatalogAttraction item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openAttractionDetail(item, favorited),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _placeCardImage(item.image, width: 80, height: 80, icon: Icons.attractions_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.chipGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.category, style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.toggleAttractionFavorite(item),
            child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 18, color: favorited ? Colors.redAccent : AppColors.textGrey),
          ),
        ],
      ),
      ),
    );
  }

  // ================= RESTAURANTS =================
  Widget _buildRestaurantHorizontalList() {
    if (controller.loadingPlaces && _visibleRestaurants.isEmpty) {
      return const SizedBox(height: 108, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_visibleRestaurants.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _visibleRestaurants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildRestaurantCompactCard(_visibleRestaurants[index]),
      ),
    );
  }

  void _openRestaurantDetail(CatalogRestaurant item, bool favorited) {
    final tripId = controller.selectedTrip?.id;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailPageRestaurant(
        restaurant: item,
        saved: favorited,
        onToggleSave: tripId == null ? null : () => controller.toggleRestaurantFavorite(item),
      ),
    ));
  }

  Widget _buildRestaurantCompactCard(CatalogRestaurant item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openRestaurantDetail(item, favorited),
      child: Container(
      width: 145,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => controller.toggleRestaurantFavorite(item),
                  child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 14, color: favorited ? Colors.redAccent : AppColors.textGrey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, size: 12, color: AppColors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${item.rating} (${item.reviews})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.priceRange,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRestaurantListView() {
    if (controller.loadingPlaces && _visibleRestaurants.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_visibleRestaurants.isEmpty) return _searchEmptyBox('No restaurants found — try a different search.', padded: true);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _visibleRestaurants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildRestaurantRowCard(_visibleRestaurants[index]),
    );
  }

  Widget _buildRestaurantRowCard(CatalogRestaurant item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openRestaurantDetail(item, favorited),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 4, runSpacing: 4, children: item.cuisineTags.map(tagChip).toList()),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.location, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text(item.priceRange, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.toggleRestaurantFavorite(item),
            child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 18, color: favorited ? Colors.redAccent : AppColors.textGrey),
          ),
        ],
      ),
      ),
    );
  }
}
