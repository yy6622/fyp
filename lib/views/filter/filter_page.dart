import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/filter_controller.dart';
import '../../models/duffel_models.dart';
import '../../models/filter_models.dart';
import '../../services/duffel_api_service.dart';
import '../../theme.dart';

class FilterPage extends StatefulWidget {
  final FilterType type;
  final FilterController controller;
  final List<String> availableAirlines;
  // Flight-only route search (From/To, backed by Duffel's live place
  // suggestions -- see DuffelPlace's doc comment). These four default to
  // whatever search actually produced the results currently on screen
  // (ExploreController.homeAirportCode/lastFlightDestination*), so the
  // fields read as "change this" instead of starting blank; [onRouteSearch]
  // is only called, and only once, if the user actually picks a different
  // airport on either side and taps Apply -- every other control in this
  // sheet re-filters the existing results client-side, but a new route
  // needs a brand new Duffel search, which only the owning page
  // (explore_page.dart) can run.
  final String currentOriginCode;
  final String currentOriginLabel;
  final String currentDestinationQuery;
  final String currentDestinationLabel;
  // Traveller counts/cabin for the current flight results -- see
  // ExploreController.flightAdults/flightChildAges/flightCabinClass.
  final int currentAdults;
  final List<int> currentChildAges;
  final String currentCabinClass;
  final void Function(String origin, String destination, String label, int adults, List<int> childAges, String cabinClass)?
      onRouteSearch;
  const FilterPage({
    super.key,
    required this.type,
    required this.controller,
    this.availableAirlines = const [],
    this.currentOriginCode = '',
    this.currentOriginLabel = '',
    this.currentDestinationQuery = '',
    this.currentDestinationLabel = '',
    this.currentAdults = 1,
    this.currentChildAges = const [],
    this.currentCabinClass = 'economy',
    this.onRouteSearch,
  });

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  FilterController get controller => widget.controller;

  DuffelPlace? _pickedOrigin;
  DuffelPlace? _pickedDestination;
  int? _pickedAdults;
  List<int>? _pickedChildAges;
  String? _pickedCabinClass;

  static const Map<String, String> _cabinClassLabels = {
    'economy': 'Economy',
    'premium_economy': 'Premium Economy',
    'business': 'Business',
    'first': 'First',
  };

  int get _adults => _pickedAdults ?? widget.currentAdults;
  List<int> get _childAges => _pickedChildAges ?? widget.currentChildAges;
  String get _cabinClass => _pickedCabinClass ?? widget.currentCabinClass;

  String get _travelersLabel {
    final adultsPart = '$_adults ${_adults == 1 ? 'Adult' : 'Adults'}';
    final childPart = _childAges.isEmpty ? '' : ', ${_childAges.length} ${_childAges.length == 1 ? 'Child' : 'Children'}';
    final cabin = _cabinClassLabels[_cabinClass] ?? 'Economy';
    return '$adultsPart$childPart · $cabin';
  }

  Future<void> _openTravelersSheet() async {
    final result = await showModalBottomSheet<(int, List<int>, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TravelersCabinSheet(adults: _adults, childAges: _childAges, cabinClass: _cabinClass),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickedAdults = result.$1;
      _pickedChildAges = result.$2;
      _pickedCabinClass = result.$3;
    });
  }

  String get _originLabel =>
      _pickedOrigin?.displayLabel ?? (widget.currentOriginLabel.isNotEmpty ? widget.currentOriginLabel : 'Choose departure airport');
  String get _destinationLabel => _pickedDestination?.displayLabel ??
      (widget.currentDestinationLabel.isNotEmpty ? widget.currentDestinationLabel : 'Choose destination');

  Future<void> _openPlaceSearch({required bool isOrigin}) async {
    final picked = await showModalBottomSheet<DuffelPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PlaceSearchSheet(title: isOrigin ? 'Departure airport' : 'Destination'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isOrigin) {
        _pickedOrigin = picked;
      } else {
        _pickedDestination = picked;
      }
    });
  }

  Widget _routeField({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.chipGrey,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, color: AppColors.navy, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  List<Widget> _routeFilters() {
    if (widget.onRouteSearch == null) return const [];
    return [
      _sectionTitle('Route'),
      _routeField(icon: Icons.flight_takeoff, label: 'From', value: _originLabel, onTap: () => _openPlaceSearch(isOrigin: true)),
      const SizedBox(height: 8),
      _routeField(icon: Icons.flight_land, label: 'To', value: _destinationLabel, onTap: () => _openPlaceSearch(isOrigin: false)),
      const SizedBox(height: 8),
      _routeField(icon: Icons.person_outline, label: 'Travelers & Cabin', value: _travelersLabel, onTap: _openTravelersSheet),
      const SizedBox(height: 20),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                _buildHandle(),
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: _buildFilterContent(),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.type.label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: controller.resetFilters,
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.navy),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- type-specific content builders ----
  List<Widget> _buildFilterContent() {
    switch (widget.type) {
      case FilterType.flight:
        return _flightFilters();
      case FilterType.hotel:
        return _hotelFilters();
      case FilterType.attraction:
        return _attractionFilters();
      case FilterType.restaurant:
        return _restaurantFilters();
    }
  }

  // ---------------- FLIGHT ----------------
  List<Widget> _flightFilters() {
    return [
      ..._routeFilters(),
      _sectionTitle('Price Range'),
      _priceRangeSlider(controller.flightPriceRange, 0, 5000, controller.setFlightPriceRange),
      const SizedBox(height: 20),
      _sectionTitle('Departure Time'),
      _chipsGroup(
        ['Early Morning', 'Morning', 'Afternoon', 'Evening', 'Night'],
        controller.departureTimes,
        icons: const [
          Icons.wb_twilight,
          Icons.wb_sunny_outlined,
          Icons.wb_cloudy_outlined,
          Icons.nightlight_round,
          Icons.dark_mode_outlined,
        ],
      ),
      const SizedBox(height: 20),
      _sectionTitle('Stops'),
      _chipsGroup(['Direct', '1 Stop', '2+ Stops'], controller.stops, singleSelect: true),
      const SizedBox(height: 20),
      _sectionTitle('Airlines'),
      if (widget.availableAirlines.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Search flights to see airlines for this route.',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
        )
      else
        _checklistGroup(widget.availableAirlines, controller.airlines),
      const SizedBox(height: 20),
      _sectionTitle('Flight Duration (hrs)'),
      _priceRangeSlider(controller.durationRange, 0, 24, controller.setDurationRange, prefix: '', suffix: 'h'),
    ];
  }

  List<Widget> _hotelFilters() {
    return [
      _sectionTitle('Price Range (per night)'),
      _priceRangeSlider(controller.hotelPriceRange, 0, 3000, controller.setHotelPriceRange),
      const SizedBox(height: 20),
      _sectionTitle('Star Rating'),
      _chipsGroup(['3★', '4★', '5★'], controller.starRatings),
    ];
  }

  List<Widget> _attractionFilters() {
    return [
      _sectionTitle('Category'),
      _chipsGroup(
        // These 6 labels are the user-facing buckets; the real match against
        // each attraction's raw category (Museum/Art & Culture/Adventure/
        // Nature/Historic Site/Shopping/Landmark/Attraction — the exact
        // values admin_web/js/places-import.js's Geoapify import assigns,
        // the source of ~15k of this catalogue's attractions) happens via
        // attractionCategoryBucket() in explore_page.dart, not a literal
        // string match — "Cultural" alone never appears as a stored
        // category, so matching the label verbatim silently matched
        // nothing. ("Nightlife" was dropped for the same reason: no import
        // path ever assigns it, so it could never match a single result;
        // "Landmark" replaces it as a real, commonly-assigned category.)
        ['Museum', 'Nature', 'Adventure', 'Cultural', 'Shopping', 'Landmark'],
        controller.attractionCategories,
        icons: const [
          Icons.museum_outlined,
          Icons.park_outlined,
          Icons.terrain_outlined,
          Icons.temple_buddhist_outlined,
          Icons.shopping_bag_outlined,
          Icons.location_city_outlined,
        ],
      ),
      const SizedBox(height: 20),
      _sectionTitle('Price'),
      _singleChoiceRow(
        ['Any', 'Free', 'RM0 - 50', 'RM50 - 150', 'RM150+'],
        controller.attractionPrice,
        controller.setAttractionPrice,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Availability'),
      _switchTile('Open now', controller.openNow, controller.setOpenNow),
      const SizedBox(height: 8),
      _switchTile('Wheelchair accessible', controller.accessibleOnly, controller.setAccessibleOnly),
    ];
  }

  List<Widget> _restaurantFilters() {
    return [
      _sectionTitle('Cuisine'),
      _chipsGroup(
        // These are the exact cuisine tags admin_web/js/places-import.js's
        // Geoapify import assigns (CUISINE_BY_PREFIX) — the source of this
        // catalogue's ~3,760 real restaurants — so every chip here is
        // guaranteed to match real data. The old list ('Western', 'Local',
        // 'Fine Dining') never matched anything: those aren't cuisine tags
        // Geoapify (or the admin's own restaurant-form.html picker) ever
        // produces, so those 3 chips always returned zero results, and
        // common real cuisines (Chinese, Thai, Indian, Korean, Vietnamese,
        // Seafood, Vegetarian, Middle Eastern) had no chip at all.
        [
          'Japanese', 'Chinese', 'Thai', 'Korean', 'Vietnamese', 'Italian',
          'Indian', 'Seafood', 'Vegetarian', 'Middle Eastern', 'Fast Food', 'Cafe & Dessert',
        ],
        controller.restaurantCuisines,
        icons: const [
          Icons.ramen_dining_outlined,
          Icons.rice_bowl_outlined,
          Icons.local_fire_department_outlined,
          Icons.outdoor_grill_outlined,
          Icons.soup_kitchen_outlined,
          Icons.local_pizza_outlined,
          Icons.dinner_dining_outlined,
          Icons.set_meal_outlined,
          Icons.eco_outlined,
          Icons.kebab_dining_outlined,
          Icons.fastfood_outlined,
          Icons.icecream_outlined,
        ],
      ),
      const SizedBox(height: 20),
      _sectionTitle('Price'),
      _singleChoiceRow(
        ['Any', 'RM0 - 20', 'RM20 - 50', 'RM50 - 100', 'RM100+'],
        controller.restaurantPrice,
        controller.setRestaurantPrice,
      ),
    ];
  }


  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.navy,
        ),
      ),
    );
  }

  Widget _priceRangeSlider(
      RangeValues values,
      double min,
      double max,
      ValueChanged<RangeValues> onChanged, {
        String prefix = 'RM ',
        String suffix = '',
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: 40,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.chipGrey,
          labels: RangeLabels(
            '$prefix${values.start.round()}$suffix',
            '$prefix${values.end.round()}$suffix',
          ),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _valuePill('$prefix${values.start.round()}$suffix'),
            _valuePill('$prefix${values.end.round()}$suffix'),
          ],
        ),
      ],
    );
  }

  Widget _valuePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.chipGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
    );
  }

  Widget _chipsGroup(
      List<String> options,
      Set<String> selected, {
        List<IconData>? icons,
        bool singleSelect = false,
      }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(options.length, (i) {
        final label = options[i];
        final isSelected = selected.contains(label);
        return GestureDetector(
          onTap: () => controller.toggleInSet(selected, label, singleSelect: singleSelect),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.chipGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icons != null) ...[
                  Icon(
                    icons[i],
                    size: 15,
                    color: isSelected ? Colors.white : AppColors.textGrey,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _checklistGroup(List<String> options, Set<String> selected) {
    return Column(
      children: options.map((label) {
        final isSelected = selected.contains(label);
        return InkWell(
          onTap: () => controller.toggleInSet(selected, label),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? AppColors.primary : AppColors.textGrey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppColors.navy),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _singleChoiceRow(
      List<String> options,
      String selectedValue,
      ValueChanged<String> onSelect,
      ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((label) {
        final isSelected = label == selectedValue;
        return GestureDetector(
          onTap: () => onSelect(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.chipGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textGrey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.chipGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: controller.resetFilters,
              child: const Text(
                'Reset',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                final changedRoute = _pickedOrigin != null || _pickedDestination != null;
                final changedTravelers = _pickedAdults != null || _pickedChildAges != null || _pickedCabinClass != null;
                if (widget.type == FilterType.flight && widget.onRouteSearch != null && (changedRoute || changedTravelers)) {
                  final origin = _pickedOrigin?.iataCode ?? widget.currentOriginCode;
                  final destination = _pickedDestination?.iataCode ?? widget.currentDestinationQuery;
                  if (origin.isNotEmpty && destination.isNotEmpty) {
                    widget.onRouteSearch!(
                      origin,
                      destination,
                      _pickedDestination?.displayLabel ?? widget.currentDestinationLabel,
                      _adults,
                      _childAges,
                      _cabinClass,
                    );
                  }
                }
                Navigator.of(context).maybePop();
              },
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Live "type to search" picker for one side of the flight Filter
/// sheet's route search (From or To) -- backed by Duffel's own
/// /places/suggestions (DuffelApiService.searchPlaces), the same
/// endpoint Skyscanner-style flight search UIs use for their From/To
/// autocomplete. Debounces so it doesn't fire a network call on every
/// keystroke.
class _PlaceSearchSheet extends StatefulWidget {
  final String title;
  const _PlaceSearchSheet({required this.title});

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<DuffelPlace> _results = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final results = await DuffelApiService.instance.searchPlaces(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = [];
        _loading = false;
        _error = "Couldn't search airports right now.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.navy),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: 'City or airport name',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.chipGrey,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textGrey)))
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  _controller.text.trim().length < 2 ? 'Start typing a city or airport.' : 'No matches.',
                                  style: const TextStyle(color: AppColors.textGrey),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _results.length,
                                itemBuilder: (context, i) {
                                  final p = _results[i];
                                  return ListTile(
                                    leading: Icon(p.type == 'city' ? Icons.location_city : Icons.flight_outlined, color: AppColors.primary),
                                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy)),
                                    subtitle: p.subtitle != null ? Text(p.subtitle!) : null,
                                    trailing: Text(p.iataCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                                    onTap: () => Navigator.of(context).pop(p),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Adults/children count + cabin class picker for the flight Filter
/// sheet's Travelers & Cabin row -- mirrors Skyscanner's own "Travelers
/// and cabin class" popover. Each child gets its own "Age of child N"
/// dropdown (0-17) right under the Children stepper, same as Skyscanner,
/// because Duffel needs a real age per child to price the fare
/// correctly (see DuffelApiService.searchFlights' doc comment).
class _TravelersCabinSheet extends StatefulWidget {
  final int adults;
  final List<int> childAges;
  final String cabinClass;
  const _TravelersCabinSheet({required this.adults, required this.childAges, required this.cabinClass});

  @override
  State<_TravelersCabinSheet> createState() => _TravelersCabinSheetState();
}

class _TravelersCabinSheetState extends State<_TravelersCabinSheet> {
  late int _adults = widget.adults;
  late List<int> _childAges = List<int>.from(widget.childAges);
  late String _cabinClass = widget.cabinClass;

  static const _cabinOptions = [
    ('economy', 'Economy'),
    ('premium_economy', 'Premium Economy'),
    ('business', 'Business'),
    ('first', 'First'),
  ];

  Widget _stepperRow(String label, int value, {required VoidCallback? onMinus, required VoidCallback? onPlus}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy))),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
            color: onMinus == null ? AppColors.textGrey.withValues(alpha: 0.4) : AppColors.primary,
          ),
          SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
            color: onPlus == null ? AppColors.textGrey.withValues(alpha: 0.4) : AppColors.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(4))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Travelers & Cabin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    IconButton(icon: const Icon(Icons.close, color: AppColors.navy), onPressed: () => Navigator.of(context).maybePop()),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _stepperRow('Adults', _adults,
                        onMinus: _adults > 1 ? () => setState(() => _adults--) : null,
                        onPlus: _adults < 9 ? () => setState(() => _adults++) : null),
                    const Divider(height: 1),
                    _stepperRow('Children', _childAges.length,
                        onMinus: _childAges.isNotEmpty ? () => setState(() => _childAges.removeLast()) : null,
                        onPlus: _childAges.length < 8 ? () => setState(() => _childAges.add(8)) : null),
                    for (var i = 0; i < _childAges.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text('Age of child ${i + 1}', style: const TextStyle(fontSize: 13, color: AppColors.textGrey))),
                            DropdownButton<int>(
                              value: _childAges[i],
                              items: [for (var age = 0; age <= 17; age++) DropdownMenuItem(value: age, child: Text('$age'))],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _childAges[i] = v);
                              },
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    const Text('Cabin Class', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in _cabinOptions)
                          GestureDetector(
                            onTap: () => setState(() => _cabinClass = option.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: _cabinClass == option.$1 ? AppColors.primary : AppColors.chipGrey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(option.$2,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _cabinClass == option.$1 ? Colors.white : AppColors.textGrey)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop((_adults, _childAges, _cabinClass)),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
