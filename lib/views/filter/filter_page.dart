import 'package:flutter/material.dart';

import '../../controllers/filter_controller.dart';
import '../../models/filter_models.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// FilterPage — content changes completely based on `type`
// ---------------------------------------------------------------------
class FilterPage extends StatefulWidget {
  final FilterType type;
  const FilterPage({super.key, required this.type});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  final FilterController controller = FilterController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
      case FilterType.nearby:
        return _nearbyFilters();
      case FilterType.plan:
        return _planFilters();
    }
  }

  // ---------------- FLIGHT ----------------
  List<Widget> _flightFilters() {
    return [
      _sectionTitle('Price Range'),
      _priceRangeSlider(controller.priceRange, 0, 5000, controller.setPriceRange),
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
      _checklistGroup(
        ['AirAsia', 'Malaysia Airlines', 'Singapore Airlines', 'Emirates', 'Batik Air'],
        controller.airlines,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Flight Duration (hrs)'),
      _priceRangeSlider(controller.durationRange, 0, 24, controller.setDurationRange, prefix: '', suffix: 'h'),
    ];
  }

  // ---------------- HOTEL ----------------
  List<Widget> _hotelFilters() {
    return [
      _sectionTitle('Price Range (per night)'),
      _priceRangeSlider(controller.priceRange, 0, 3000, controller.setPriceRange),
      const SizedBox(height: 20),
      _sectionTitle('Star Rating'),
      _chipsGroup(['3★', '4★', '5★'], controller.starRatings),
      const SizedBox(height: 20),
      _sectionTitle('Property Type'),
      _chipsGroup(
        ['Hotel', 'Resort', 'Villa', 'Apartment', 'Hostel'],
        controller.propertyTypes,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Amenities'),
      _checklistGroup(
        ['Free WiFi', 'Swimming Pool', 'Breakfast Included', 'Parking', 'Gym', 'Pet Friendly'],
        controller.amenities,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Guest Rating'),
      _singleChoiceRow(['Any', '3.5+', '4.0+', '4.5+'], controller.guestRating, controller.setGuestRating),
    ];
  }

  // ---------------- ATTRACTION / PLACES ----------------
  List<Widget> _attractionFilters() {
    return [
      _sectionTitle('Category'),
      _chipsGroup(
        ['Museum', 'Nature', 'Adventure', 'Cultural', 'Shopping', 'Nightlife'],
        controller.attractionCategories,
        icons: const [
          Icons.museum_outlined,
          Icons.park_outlined,
          Icons.terrain_outlined,
          Icons.temple_buddhist_outlined,
          Icons.shopping_bag_outlined,
          Icons.nightlife_outlined,
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
      _sectionTitle('Duration'),
      _singleChoiceRow(
        ['Any', '< 1 hr', '1 - 3 hrs', 'Half day', 'Full day'],
        controller.attractionDuration,
        controller.setAttractionDuration,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Rating'),
      _ratingSelector(),
    ];
  }

  // ---------------- RESTAURANT ----------------
  List<Widget> _restaurantFilters() {
    return [
      _sectionTitle('Cuisine'),
      _chipsGroup(
        ['Japanese', 'Western', 'Local', 'Cafe', 'Fast Food', 'Fine Dining'],
        controller.restaurantCuisines,
        icons: const [
          Icons.ramen_dining_outlined,
          Icons.lunch_dining_outlined,
          Icons.rice_bowl_outlined,
          Icons.coffee_outlined,
          Icons.fastfood_outlined,
          Icons.wine_bar_outlined,
        ],
      ),
      const SizedBox(height: 20),
      _sectionTitle('Price'),
      _singleChoiceRow(
        ['Any', 'RM0 - 20', 'RM20 - 50', 'RM50 - 100', 'RM100+'],
        controller.restaurantPrice,
        controller.setRestaurantPrice,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Rating'),
      _ratingSelector(),
    ];
  }

  // ---------------- NEARBY ----------------
  List<Widget> _nearbyFilters() {
    return [
      _sectionTitle('Distance (km)'),
      Row(
        children: [
          Expanded(
            child: Slider(
              value: controller.distanceKm,
              min: 1,
              max: 50,
              divisions: 49,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.chipGrey,
              label: '${controller.distanceKm.round()} km',
              onChanged: controller.setDistanceKm,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${controller.distanceKm.round()} km',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _sectionTitle('Category'),
      _chipsGroup(
        ['Restaurants', 'Cafes', 'Attractions', 'Shopping', 'ATM', 'Pharmacy'],
        controller.nearbyCategories,
        icons: const [
          Icons.restaurant_outlined,
          Icons.local_cafe_outlined,
          Icons.attractions_outlined,
          Icons.shopping_bag_outlined,
          Icons.local_atm_outlined,
          Icons.local_pharmacy_outlined,
        ],
      ),
      const SizedBox(height: 20),
      _sectionTitle('Rating'),
      _singleChoiceRow(['Any', '3.5+', '4.0+', '4.5+'], controller.nearbyRating, controller.setNearbyRating),
      const SizedBox(height: 12),
      _switchTile('Open Now', controller.openNow, controller.setOpenNow),
    ];
  }

  // ---------------- PLAN (itinerary) ----------------
  List<Widget> _planFilters() {
    return [
      _sectionTitle('Trip Duration (days)'),
      Row(
        children: [
          Expanded(
            child: Slider(
              value: controller.tripDays,
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.chipGrey,
              label: '${controller.tripDays.round()} days',
              onChanged: controller.setTripDays,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${controller.tripDays.round()} days',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _sectionTitle('Budget Range'),
      _priceRangeSlider(controller.priceRange, 0, 10000, controller.setPriceRange),
      const SizedBox(height: 20),
      _sectionTitle('Trip Type'),
      _chipsGroup(
        ['Solo', 'Couple', 'Family', 'Friends', 'Business'],
        controller.tripTypes,
        icons: const [
          Icons.person_outline,
          Icons.favorite_border,
          Icons.family_restroom_outlined,
          Icons.groups_outlined,
          Icons.work_outline,
        ],
      ),
      const SizedBox(height: 20),
      _sectionTitle('Travel Season'),
      _chipsGroup(['Spring', 'Summer', 'Autumn', 'Winter'], controller.seasons),
      const SizedBox(height: 20),
      _sectionTitle('Pace'),
      _singleChoiceRow(['Relaxed', 'Balanced', 'Packed'], controller.pace, controller.setPace),
    ];
  }

  // ---------------------------------------------------------------
  // Reusable filter building blocks
  // ---------------------------------------------------------------
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

  /// Wrap of selectable chips. If [singleSelect] is true, acts like a radio
  /// group (only one chip can be active at a time).
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

  /// Vertical checklist with checkboxes — used where many options may apply
  /// at once (airlines, amenities).
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

  /// Horizontal row of pill options where exactly one must be selected.
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

  Widget _ratingSelector() {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < controller.ratingStars;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: AppColors.orange,
            size: 26,
          ),
          onPressed: () => controller.setRatingStars(i + 1),
        );
      }),
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
              onPressed: () => Navigator.of(context).maybePop(),
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
