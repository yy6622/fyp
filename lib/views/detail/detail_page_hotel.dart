import 'package:flutter/material.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/nice_pickers.dart';
import 'detail_widgets.dart';

class DetailPageHotel extends StatefulWidget {
  final String hotelId;
  final String name;
  final String location;
  final String ratingLabel;
  final String pricePerNight;
  final String image;
  final String tripId;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final List<String> amenities;
  final String? checkInPolicyTime;
  final String? checkOutPolicyTime;

  const DetailPageHotel({
    super.key,
    this.hotelId = '',
    this.name = 'L Hotel',
    this.location = 'Shinjoku, Tokyo   1.2km to city center',
    this.ratingLabel = '4.8(1.2k)',
    this.pricePerNight = 'RM 320',
    this.image = '',
    this.tripId = '',
    this.checkIn,
    this.checkOut,
    this.amenities = const [],
    this.checkInPolicyTime,
    this.checkOutPolicyTime,
  });

  @override
  State<DetailPageHotel> createState() => _DetailPageHotelState();
}

class _DetailPageHotelState extends State<DetailPageHotel> {
  late DateTime? _checkIn = widget.checkIn;
  late DateTime? _checkOut = widget.checkOut;

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showVoyaDateRangePicker(
      context: context,
      initialStart: _checkIn,
      initialEnd: _checkOut,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      title: 'Check-in & Check-out',
    );
    if (range == null) return;
    setState(() {
      _checkIn = range.start;
      _checkOut = range.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DetailHeader(title: widget.name, imageUrl: widget.image),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    Text(widget.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: AppColors.orange),
                        const SizedBox(width: 4),
                        Text(widget.ratingLabel, style: const TextStyle(fontSize: 13, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(widget.location, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    const SizedBox(height: 16),
                    if (widget.amenities.isNotEmpty) ...[
                      SizedBox(
                        height: 74,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: widget.amenities
                              .map((a) => AmenityIcon(icon: _amenityIcon(a), label: a))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.name} is a well-reviewed stay in ${widget.location.split(',').first.trim()}, '
                      'popular for its location and amenities. Save it to your plan and check exact availability '
                      'closer to your travel dates.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    ..._detailsContent(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              BookingBar(
                price: widget.pricePerNight,
                priceSuffix: 'per night',
                buttonLabel: 'Select Hotel',
                bookingType: 'hotel',
                bookingTitle: widget.name,
                bookingSubtitle: widget.location,
                refId: widget.hotelId,
                tripId: widget.tripId,
                checkIn: _checkIn,
                checkOut: _checkOut,
                onPaid: widget.tripId.isEmpty
                    ? null
                    : (confirmation) => TripRepository.instance.addHotelStay(
                          widget.tripId,
                          TripHotelStay(
                            id: '${DateTime.now().microsecondsSinceEpoch}',
                            name: widget.name,
                            location: widget.location,
                            checkIn: confirmation.checkIn != null
                                ? formatLongDate(confirmation.checkIn!)
                                : (_checkIn != null ? formatLongDate(_checkIn!) : ''),
                            checkOut: confirmation.checkOut != null
                                ? formatLongDate(confirmation.checkOut!)
                                : (_checkOut != null ? formatLongDate(_checkOut!) : ''),
                            guestName: confirmation.guestName,
                            guestEmail: confirmation.guestEmail,
                            guestPhone: confirmation.guestPhone,
                            guestIdNumber: confirmation.guestIdNumber,
                            specialRequests: confirmation.specialRequests,
                            bookingRef: confirmation.paymentRef,
                            status: 'Confirmed',
                            refId: widget.hotelId,
                            forMemberUids: confirmation.forMemberUids,
                          ),
                          actorUid: AuthService.instance.currentUser?.uid,
                        ),
              ),
            ],
          ),
        ),
      );
  }

  List<Widget> _detailsContent() {
    return [
      _bookingRow(
        'Check-in',
        _checkIn != null ? formatLongDate(_checkIn!) : 'Select date',
        'Check-out',
        _checkOut != null ? formatLongDate(_checkOut!) : 'Select date',
        onTap: _pickDates,
      ),
      const SizedBox(height: 20),
      if (widget.checkInPolicyTime != null || widget.checkOutPolicyTime != null) ...[
        const Text('Hotel Policies', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECECEC)),
          ),
          child: Column(
            children: [
              if (widget.checkInPolicyTime != null) FareRuleRow(icon: Icons.login, text: 'Check-in from ${widget.checkInPolicyTime}'),
              if (widget.checkInPolicyTime != null && widget.checkOutPolicyTime != null) const SizedBox(height: 12),
              if (widget.checkOutPolicyTime != null) FareRuleRow(icon: Icons.logout, text: 'Check-out until ${widget.checkOutPolicyTime}'),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    ];
  }

  Widget _bookingRow(String label1, String value1, String label2, String value2, {VoidCallback? onTap}) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: InfoField(label: label1, value: value1)),
          Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 16),
          Expanded(child: InfoField(label: label2, value: value2)),
          if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: row);
  }

  IconData _amenityIcon(String amenity) {
    final a = amenity.toLowerCase();
    if (a.contains('wifi') || a.contains('wi-fi') || a.contains('internet')) return Icons.wifi;
    if (a.contains('breakfast')) return Icons.free_breakfast_outlined;
    if (a.contains('pool')) return Icons.pool_outlined;
    if (a.contains('gym') || a.contains('fitness')) return Icons.fitness_center_outlined;
    if (a.contains('spa')) return Icons.spa_outlined;
    if (a.contains('park')) return Icons.local_parking_outlined;
    if (a.contains('bar')) return Icons.local_bar_outlined;
    if (a.contains('restaurant') || a.contains('dining')) return Icons.restaurant_outlined;
    if (a.contains('air') && a.contains('condition')) return Icons.ac_unit_outlined;
    if (a.contains('laundry')) return Icons.local_laundry_service_outlined;
    if (a.contains('luggage') || a.contains('storage')) return Icons.luggage_outlined;
    if (a.contains('housekeeping') || a.contains('cleaning')) return Icons.cleaning_services_outlined;
    if (a.contains('desk') || a.contains('reception') || a.contains('24')) return Icons.support_agent_outlined;
    if (a.contains('pet')) return Icons.pets_outlined;
    if (a.contains('elevator') || a.contains('lift')) return Icons.elevator_outlined;
    if (a.contains('smok')) return Icons.smoking_rooms_outlined;
    return Icons.check_circle_outline;
  }

}
