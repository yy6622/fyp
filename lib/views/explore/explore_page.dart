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
import '../../theme.dart';
import '../detail/detail_page_attraction.dart';
import '../detail/detail_page_flight.dart';
import '../detail/detail_page_hotel.dart';
import '../detail/detail_page_restaurant.dart';
import '../detail/detail_widgets.dart' show tagChip;
import '../filter/filter_page.dart';
import '../near_by/near_by_page.dart';
import '../shared/translated_text.dart';
import 'saved_items_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final ExploreController controller = ExploreController();
  final TextEditingController _searchController = TextEditingController();
  // Shared with FilterPage (see _openFilterSheet) so a selection made
  // there actually changes what's shown here instead of just closing the
  // sheet — kept alive for the page's lifetime (not recreated per sheet
  // open) so filters chosen for one category stay applied when the sheet
  // is reopened.
  final FilterController filterController = FilterController();

  @override
  void dispose() {
    _searchController.dispose();
    controller.dispose();
    filterController.dispose();
    super.dispose();
  }

  void _runTopBarSearch() => controller.searchFromTopBar(_searchController.text);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Listens to both — a filter selection only calls filterController's
      // notifyListeners(), not controller's, so without this the list
      // behind the sheet would never actually re-filter.
      listenable: Listenable.merge([controller, filterController]),
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: Stack(
            children: [
              // Whole page scrolls as one — the header/trip card/search
              // bar/category chips used to sit in a plain Column above an
              // Expanded(ListView), so only that bottom list could scroll
              // and everything above it was pinned in place. Now it's all
              // one SingleChildScrollView, with each category's own list
              // (_buildBody()) laid out inline (shrinkWrap, no scrolling
              // of its own) instead of independently scrollable.
              SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildTripCard(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
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
              // "All" is a mixed discovery feed across every category, so
              // there's no single filter sheet that applies to it — the
              // filter button only makes sense once a specific category
              // (Flights/Hotels/Attractions/Restaurants) is selected.
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterPage(type: controller.selectedCategory.filterType, controller: filterController),
    );
  }

  // ---------------- Filtering ----------------
  // Applies filterController's current selections (set from the Filter
  // sheet opened above) to whichever list the active category is showing.
  // Values with no real backing field on the result (hotel amenities and
  // property type — Duffel/RollingGo's parsed stay result doesn't carry
  // either) are left out of the match rather than compared against
  // fabricated data; every other field here is a real one already on the
  // result/catalogue object.

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
        // RollingGo never returns a guest reviewScore, only the official
        // star rating — falling back to that (same as everywhere else
        // this value is shown) instead of silently excluding every
        // RollingGo hotel whenever this filter is used.
        final score = hotel.reviewScore != null ? hotel.reviewScore! / 2 : hotel.rating;
        final threshold = double.tryParse(f.guestRating.replaceAll('+', '')) ?? 0;
        if (score == null || score < threshold) return false;
      }
      // Property Type / Amenities: no matching field on DuffelStayResult
      // yet — not filtered on, see note above.
      return true;
    }).toList();
  }

  List<CatalogAttraction> get _visibleAttractions {
    final f = filterController;
    return controller.attractions.where((item) {
      if (f.attractionCategories.isNotEmpty) {
        final tags = item.categories.isNotEmpty ? item.categories : [item.category];
        if (!f.attractionCategories.any(tags.contains)) return false;
      }
      if (f.attractionPrice != 'Any' && !_priceTextMatchesBucket(item.price, f.attractionPrice)) return false;
      if (f.ratingStars > 0) {
        final rating = double.tryParse(item.rating) ?? 0;
        if (rating.round() < f.ratingStars) return false;
      }
      // Duration: recommendedDuration isn't consistently structured
      // across every attraction yet, so that chip stays display-only
      // rather than guessing at a match.
      return true;
    }).toList();
  }

  List<CatalogRestaurant> get _visibleRestaurants {
    final f = filterController;
    return controller.restaurants.where((item) {
      if (f.restaurantCuisines.isNotEmpty && !f.restaurantCuisines.any(item.cuisineTags.contains)) return false;
      if (f.restaurantPrice != 'Any' && !_priceTextMatchesBucket(item.priceRange, f.restaurantPrice)) return false;
      if (f.ratingStars > 0) {
        final rating = double.tryParse(item.rating) ?? 0;
        if (rating.round() < f.ratingStars) return false;
      }
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

  // ---------------- Trip switcher popup ----------------
  // Per the user's own reference mockup: each trip in the list is styled
  // as a smaller version of the current-trip bar above it (_tripInfoItem
  // reused as-is) — trip name as a header, then the same
  // Destination/Date/Travellers/Budget four-column row with the same thin
  // vertical dividers — instead of the icon+stacked-text row this popup
  // had before. The selected trip gets the bar's own teal border; the
  // rest get a light grey outline. Same real trip data throughout, only
  // the card styling changed.
  Widget _buildTripSwitcherOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => controller.closeTripSwitcher(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 96),
              child: GestureDetector(
                onTap: () {},
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
            const Icon(Icons.mic_none, color: AppColors.textGrey, size: 20),
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

  // ---------------- Body switch (the important part) ----------------
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

  // ================= ALL (mixed / discovery view) =================
  Widget _buildAllView() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildExploreBanner(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.flight_takeoff, 'Best Flight Deals', ExploreCategory.flights),
        const SizedBox(height: 12),
        _buildFlightHorizontalList(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.hotel_outlined, 'Recommended Hotels', ExploreCategory.accommodation),
        const SizedBox(height: 12),
        _buildHotelHorizontalList(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.attractions_outlined, 'Top Attractions', ExploreCategory.attractions),
        const SizedBox(height: 12),
        _buildAttractionHorizontalList(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.restaurant_outlined, 'Top Restaurants', ExploreCategory.restaurants),
        const SizedBox(height: 12),
        _buildRestaurantHorizontalList(),
        const SizedBox(height: 22),
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

  Widget _buildExploreBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
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
                const Text(
                  'Explore Japan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sakura session is here',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Text(
                  'Up to 30 % off on flight and hotel',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Container(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ExploreCategory jumpTo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
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

  // ================= FLIGHTS (real Duffel search results) =================
  // No more seeded/placeholder flight data — every card below comes from
  // controller.flightResults, which is either a trip-driven search, the
  // cached "popular destinations" default, or the person's own manual
  // search (see ExploreController). "Favorite" here means "save this
  // real result into the trip's saved items" — a one-way action per
  // result (see controller.savedFlightIds); unsaving happens from the
  // Saved Items page like any other saved catalogue item.
  Widget _buildFlightHorizontalList() {
    if (controller.loadingFlights) return const SizedBox(height: 148, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (controller.flightError != null) return _searchErrorBox(controller.flightError!);
    if (_visibleFlights.isEmpty) return _searchEmptyBox('No flights found.');
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
        toCode: flight.destinationCode,
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
      );

  String _hhmm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// Duffel's real airline logos (`carrier.logo_symbol_url`/
  /// `logo_lockup_url`, see [DuffelFlightOffer.airlineLogoUrl]) are
  /// published as SVG (confirmed against Duffel's own API schema docs) —
  /// a plain `Image.network` can't decode that, which is why wiring the
  /// real URL straight into an `Image.network` threw "Invalid image data"
  /// on every single card. Renders with [SvgPicture.network] instead, and
  /// falls back to a plain flight icon whenever there's no logo URL at
  /// all, it's still loading, or it fails to load.
  ///
  /// Real airlines' logos come in very different native shapes — a
  /// square/circular "symbol" mark for some, a wide wordmark for others
  /// (e.g. VietJet's). A fixed-size circle with `BoxFit.cover` cropped
  /// those wide ones unpredictably and let them visually overflow the
  /// card. [size] is instead a fixed outer box every logo is scaled to
  /// fit *inside* (`BoxFit.contain`, via `FittedBox`) — so every logo
  /// renders at the exact same, consistent footprint regardless of its
  /// own aspect ratio, never cropped and never overflowing it.
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
    if (controller.flightError != null) return _searchErrorBox(controller.flightError!, padded: true);
    if (_visibleFlights.isEmpty) return _searchEmptyBox('No flights found — try a different search.', padded: true);
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

  // ================= ACCOMMODATION (real Duffel Stays results) ================
  Widget _buildHotelHorizontalList() {
    if (controller.loadingHotels) return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (controller.hotelError != null) return _searchErrorBox(controller.hotelError!);
    if (_visibleHotels.isEmpty) return _searchEmptyBox('No hotels found.');
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
        // Not saved yet — no catalog id, so the detail page's Reviews
        // section shows its "not available yet" state until this
        // result is saved (see DetailPageHotel's own doc comment).
        name: hotel.name,
        location: hotel.address,
        // Same RollingGo-has-no-reviewScore fallback as CatalogRepository.
        // saveDuffelStay — shows the real star rating instead of nothing.
        ratingLabel: hotel.reviewScore != null
            ? '${(hotel.reviewScore! / 2).toStringAsFixed(1)}(${hotel.reviewCount ?? 0})'
            : (hotel.rating != null ? hotel.rating!.toStringAsFixed(1) : ''),
        pricePerNight: controller.formatPrice(hotel.cheapestTotalAmount, hotel.cheapestCurrency),
        image: hotel.photoUrl ?? '',
        tripId: controller.selectedTrip?.id ?? '',
        checkIn: controller.lastHotelCheckIn != null ? formatLongDate(controller.lastHotelCheckIn!) : '',
        checkOut: controller.lastHotelCheckOut != null ? formatLongDate(controller.lastHotelCheckOut!) : '',
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
                  child: hotel.photoUrl == null
                      ? Container(height: 95, width: double.infinity, color: AppColors.chipGrey, child: const Icon(Icons.hotel_outlined, color: AppColors.textGrey))
                      : Image.network(hotel.photoUrl!, height: 95, width: double.infinity, fit: BoxFit.cover),
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
    if (controller.hotelError != null) return _searchErrorBox(controller.hotelError!, padded: true);
    if (_visibleHotels.isEmpty) return _searchEmptyBox('No hotels found — try a different search.', padded: true);
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
              child: hotel.photoUrl == null
                  ? Container(width: 80, height: 80, color: AppColors.chipGrey, child: const Icon(Icons.hotel_outlined, color: AppColors.textGrey))
                  : Image.network(hotel.photoUrl!, width: 80, height: 80, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(hotel.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
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

  Widget _searchErrorBox(String message, {bool padded = false}) {
    final child = Container(
      padding: const EdgeInsets.all(16),
      margin: padded ? const EdgeInsets.symmetric(horizontal: 20) : EdgeInsets.zero,
      decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 11.5, color: AppColors.navy))),
      ]),
    );
    return padded ? Padding(padding: const EdgeInsets.only(top: 8), child: child) : Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);
  }

  Widget _searchEmptyBox(String message, {bool padded = false}) {
    final child = Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textGrey));
    return Padding(
      padding: padded ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24) : const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );
  }

  /// Attractions/restaurants now come from OpenStreetMap (see
  /// CatalogRepository.refreshAttractions/refreshRestaurants) instead of
  /// a hand-picked seeded catalogue, and OSM entries frequently have no
  /// photo at all — so unlike the old fixed Unsplash URLs, [url] here is
  /// often empty or can fail to load. A plain `Image.network` has no
  /// fallback for either case; this does, matching the icon-on-chipGrey
  /// placeholder Near By's place cards already use for the same reason.
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
    return SizedBox(
      height: 190,
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
                TranslatedText(
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
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                TranslatedText(
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
    return SizedBox(
      height: 190,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: _placeCardImage(item.image, height: 95, width: double.infinity, icon: Icons.restaurant_outlined),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => controller.toggleRestaurantFavorite(item),
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
                TranslatedText(
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
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.priceRange, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRestaurantListView() {
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _placeCardImage(item.image, width: 80, height: 80, icon: Icons.restaurant_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
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
