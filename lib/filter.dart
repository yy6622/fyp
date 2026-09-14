import 'package:flutter/material.dart';

import 'theme.dart';

/// Each tab in Explore has its own kind of filter.
enum FilterType { flight, hotel, attraction, nearby, plan }

extension FilterTypeLabel on FilterType {
  String get label {
    switch (this) {
      case FilterType.flight:
        return 'Flight Filters';
      case FilterType.hotel:
        return 'Hotel Filters';
      case FilterType.attraction:
        return 'Attraction Filters';
      case FilterType.nearby:
        return 'Nearby Filters';
      case FilterType.plan:
        return 'Plan Filters';
    }
  }
}

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
  // ---- shared state (only the relevant fields get used per type) ----
  RangeValues _priceRange = const RangeValues(100, 1500);
  RangeValues _durationRange = const RangeValues(1, 12);
  double _distanceKm = 5;
  double _tripDays = 5;
  bool _openNow = false;

  final Set<String> _departureTimes = {};
  final Set<String> _stops = {'Direct'};
  final Set<String> _airlines = {};

  final Set<String> _starRatings = {};
  final Set<String> _propertyTypes = {};
  final Set<String> _amenities = {};
  String _guestRating = 'Any';

  final Set<String> _attractionCategories = {};
  String _attractionPrice = 'Any';
  String _attractionDuration = 'Any';

  final Set<String> _nearbyCategories = {};
  String _nearbyRating = 'Any';

  final Set<String> _tripTypes = {};
  final Set<String> _seasons = {};
  String _pace = 'Balanced';

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
          child: Column(
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
                onPressed: _resetFilters,
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

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(100, 1500);
      _durationRange = const RangeValues(1, 12);
      _distanceKm = 5;
      _tripDays = 5;
      _openNow = false;
      _departureTimes.clear();
      _stops
        ..clear()
        ..add('Direct');
      _airlines.clear();
      _starRatings.clear();
      _propertyTypes.clear();
      _amenities.clear();
      _guestRating = 'Any';
      _attractionCategories.clear();
      _attractionPrice = 'Any';
      _attractionDuration = 'Any';
      _nearbyCategories.clear();
      _nearbyRating = 'Any';
      _tripTypes.clear();
      _seasons.clear();
      _pace = 'Balanced';
    });
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
      _priceRangeSlider(_priceRange, 0, 5000, (v) => setState(() => _priceRange = v)),
      const SizedBox(height: 20),
      _sectionTitle('Departure Time'),
      _chipsGroup(
        ['Early Morning', 'Morning', 'Afternoon', 'Evening', 'Night'],
        _departureTimes,
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
      _chipsGroup(['Direct', '1 Stop', '2+ Stops'], _stops, singleSelect: true),
      const SizedBox(height: 20),
      _sectionTitle('Airlines'),
      _checklistGroup(
        ['AirAsia', 'Malaysia Airlines', 'Singapore Airlines', 'Emirates', 'Batik Air'],
        _airlines,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Flight Duration (hrs)'),
      _priceRangeSlider(_durationRange, 0, 24, (v) => setState(() => _durationRange = v),
          prefix: '', suffix: 'h'),
    ];
  }

  // ---------------- HOTEL ----------------
  List<Widget> _hotelFilters() {
    return [
      _sectionTitle('Price Range (per night)'),
      _priceRangeSlider(_priceRange, 0, 3000, (v) => setState(() => _priceRange = v)),
      const SizedBox(height: 20),
      _sectionTitle('Star Rating'),
      _chipsGroup(['3★', '4★', '5★'], _starRatings),
      const SizedBox(height: 20),
      _sectionTitle('Property Type'),
      _chipsGroup(
        ['Hotel', 'Resort', 'Villa', 'Apartment', 'Hostel'],
        _propertyTypes,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Amenities'),
      _checklistGroup(
        ['Free WiFi', 'Swimming Pool', 'Breakfast Included', 'Parking', 'Gym', 'Pet Friendly'],
        _amenities,
      ),
      const SizedBox(height: 20),
      _sectionTitle('Guest Rating'),
      _singleChoiceRow(['Any', '3.5+', '4.0+', '4.5+'], _guestRating, (v) {
        setState(() => _guestRating = v);
      }),
    ];
  }

  // ---------------- ATTRACTION / PLACES ----------------
  List<Widget> _attractionFilters() {
    return [
      _sectionTitle('Category'),
      _chipsGroup(
        ['Museum', 'Nature', 'Adventure', 'Cultural', 'Shopping', 'Nightlife'],
        _attractionCategories,
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
        _attractionPrice,
            (v) => setState(() => _attractionPrice = v),
      ),
      const SizedBox(height: 20),
      _sectionTitle('Duration'),
      _singleChoiceRow(
        ['Any', '< 1 hr', '1 - 3 hrs', 'Half day', 'Full day'],
        _attractionDuration,
            (v) => setState(() => _attractionDuration = v),
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
              value: _distanceKm,
              min: 1,
              max: 50,
              divisions: 49,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.chipGrey,
              label: '${_distanceKm.round()} km',
              onChanged: (v) => setState(() => _distanceKm = v),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${_distanceKm.round()} km',
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
        _nearbyCategories,
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
      _singleChoiceRow(['Any', '3.5+', '4.0+', '4.5+'], _nearbyRating, (v) {
        setState(() => _nearbyRating = v);
      }),
      const SizedBox(height: 12),
      _switchTile('Open Now', _openNow, (v) => setState(() => _openNow = v)),
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
              value: _tripDays,
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.chipGrey,
              label: '${_tripDays.round()} days',
              onChanged: (v) => setState(() => _tripDays = v),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${_tripDays.round()} days',
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
      _priceRangeSlider(_priceRange, 0, 10000, (v) => setState(() => _priceRange = v)),
      const SizedBox(height: 20),
      _sectionTitle('Trip Type'),
      _chipsGroup(
        ['Solo', 'Couple', 'Family', 'Friends', 'Business'],
        _tripTypes,
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
      _chipsGroup(['Spring', 'Summer', 'Autumn', 'Winter'], _seasons),
      const SizedBox(height: 20),
      _sectionTitle('Pace'),
      _singleChoiceRow(['Relaxed', 'Balanced', 'Packed'], _pace, (v) {
        setState(() => _pace = v);
      }),
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
          onTap: () {
            setState(() {
              if (singleSelect) {
                selected
                  ..clear()
                  ..add(label);
              } else {
                if (isSelected) {
                  selected.remove(label);
                } else {
                  selected.add(label);
                }
              }
            });
          },
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
          onTap: () {
            setState(() {
              isSelected ? selected.remove(label) : selected.add(label);
            });
          },
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

  int _ratingStars = 0;
  Widget _ratingSelector() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Row(
          children: List.generate(5, (i) {
            final filled = i < _ratingStars;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                filled ? Icons.star : Icons.star_border,
                color: AppColors.orange,
                size: 26,
              ),
              onPressed: () {
                setState(() => _ratingStars = i + 1);
                setLocalState(() {});
              },
            );
          }),
        );
      },
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
              onPressed: _resetFilters,
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