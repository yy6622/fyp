import 'package:flutter/material.dart';

import '../../controllers/insurance_controller.dart';
import '../../data/countries.dart';
import '../../data/country_areas.dart';
import '../../models/insurance_models.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/nice_pickers.dart';
import 'insurance_plan_compare_page.dart';

const List<String> _quoteMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class InsuranceQuotePage extends StatefulWidget {
  final InsurancePartner partner;
  final String? tripId;
  const InsuranceQuotePage({super.key, required this.partner, this.tripId});

  @override
  State<InsuranceQuotePage> createState() => _InsuranceQuotePageState();
}

class _InsuranceQuotePageState extends State<InsuranceQuotePage> {
  late final InsuranceQuoteController controller;
  final TextEditingController _destinationCtrl = TextEditingController();
  bool _loadingTrip = false;
  bool _destinationFromTrip = false;

  @override
  void initState() {
    super.initState();
    controller = InsuranceQuoteController();
    if (widget.tripId != null && widget.tripId!.isNotEmpty) {
      _loadTrip();
    }
  }

  Future<void> _loadTrip() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingTrip = true);
    Trip? trip;
    try {
      trip = await TripRepository.instance.getTrip(widget.tripId!, uid);
    } catch (_) {
      trip = null;
    }
    if (!mounted) return;
    setState(() {
      _loadingTrip = false;
      if (trip != null) {
        if (trip.destination.trim().isNotEmpty) {
          _destinationCtrl.text = trip.destination;
          controller.setDestination(trip.destination);
          _destinationFromTrip = true;
        }
        if (trip.startDate != null && trip.endDate != null) {
          controller.setTravelDates(trip.startDate!, trip.endDate!);
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => '${d.day} ${_quoteMonthNames[d.month - 1]} ${d.year}';

  Future<void> _pickDestination() async {
    final searchController = TextEditingController();
    String? areaStepCountry;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void choose(String value) {
            controller.setDestination(value);
            Navigator.of(sheetContext).pop();
          }

          if (areaStepCountry != null) {
            final country = areaStepCountry!;
            final areas = kCountryAreas[country.toLowerCase()] ?? const [];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.navy),
                          onPressed: () => setSheetState(() => areaStepCountry = null),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Area in $country', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 28, top: 2),
                      child: Text('Optional — pick a city, or just use the whole country', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 360,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          ListTile(
                            title: Text('Just use $country', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                            trailing: controller.destination == country ? const Icon(Icons.check, color: AppColors.primary) : null,
                            onTap: () => choose(country),
                          ),
                          if (areas.isNotEmpty) const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          ...areas.map((area) {
                            final value = '$area, $country';
                            final selected = controller.destination == value;
                            return ListTile(
                              title: Text(area, style: const TextStyle(fontSize: 13.5)),
                              trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                              onTap: () => choose(value),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final query = searchController.text.trim();
          final queryLower = query.toLowerCase();
          final results = query.isEmpty ? kCountries : kCountries.where((c) => c.name.toLowerCase().contains(queryLower)).toList();
          final exactMatch = results.any((c) => c.name.toLowerCase() == queryLower);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select destination', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    autofocus: false,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search, or type a destination not listed',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textGrey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 360,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        if (query.isNotEmpty && !exactMatch)
                          ListTile(
                            leading: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            title: Text('Use "$query"', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            onTap: () => choose(query),
                          ),
                        if (query.isNotEmpty && !exactMatch && results.isNotEmpty) const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        if (results.isEmpty && query.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('No matching destination.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5))),
                          ),
                        ...results.map((c) {
                          final selected = controller.destination == c.name;
                          return ListTile(
                            title: Text(c.name, style: const TextStyle(fontSize: 13.5)),
                            trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                            onTap: () {
                              final areas = kCountryAreas[c.name.toLowerCase()];
                              if (areas == null || areas.isEmpty) {
                                choose(c.name);
                              } else {
                                setSheetState(() => areaStepCountry = c.name);
                              }
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
  }

  Future<void> _pickTravelDates() async {
    final now = DateTime.now();
    final picked = await showVoyaDateRangePicker(
      context: context,
      initialStart: controller.travelStart,
      initialEnd: controller.travelEnd,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      title: 'Travel Dates',
    );
    if (picked != null) controller.setTravelDates(picked.start, picked.end);
  }

  void _getQuote() {
    final error = controller.validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InsurancePlanComparePage(
          partner: widget.partner,
          destination: controller.destination,
          travelStart: controller.travelStart!,
          travelEnd: controller.travelEnd!,
          travellerCount: controller.travellerCount,
          tripId: widget.tripId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: VoyaAppBar(
        title: Text('Get a Quote — ${widget.partner.companyName}',
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
      body: _loadingTrip
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Tell us about your trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  const Text(
                    "We'll use this to work out your real premium before you compare plans.",
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 18),
                  const Text('Destination', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  _destinationFromTrip
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.flight_takeoff_outlined, size: 16, color: AppColors.textGrey),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_destinationCtrl.text, style: const TextStyle(fontSize: 13.5, color: Colors.black))),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: _pickDestination,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textGrey),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    controller.destination.isEmpty ? 'Select destination' : controller.destination,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: controller.destination.isEmpty ? AppColors.textGrey : Colors.black,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  const Text('Travel Dates', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickTravelDates,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textGrey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.travelStart != null && controller.travelEnd != null
                                  ? '${_formatDate(controller.travelStart!)} - ${_formatDate(controller.travelEnd!)}'
                                  : 'Select travel dates',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: controller.travelStart != null ? Colors.black : AppColors.textGrey,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Number of Travellers', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Travellers', style: TextStyle(fontSize: 13.5, color: Colors.black))),
                        _stepperButton(
                          Icons.remove,
                          enabled: controller.travellerCount > TravellerDetailsController.minTravellers,
                          onTap: () => controller.setTravellerCount(controller.travellerCount - 1),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text('${controller.travellerCount}',
                              textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        ),
                        _stepperButton(
                          Icons.add,
                          enabled: controller.travellerCount < TravellerDetailsController.maxTravellers,
                          onTap: () => controller.setTravellerCount(controller.travellerCount + 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _getQuote,
                    child: const Text('Get Quote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _stepperButton(IconData icon, {required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? AppColors.primary.withValues(alpha: 0.1) : AppColors.chipGrey),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: enabled ? AppColors.primary : AppColors.textGrey),
      ),
    );
  }
}
