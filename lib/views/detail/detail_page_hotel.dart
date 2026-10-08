import 'package:flutter/material.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/translated_text.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Hotel detail
// ---------------------------------------------------------------------
class DetailPageHotel extends StatefulWidget {
  // Defaults match the original Japan-trip mock so existing callers that
  // still just do `const DetailPageHotel()` render exactly as before; real
  // callers (Explore, a trip's hotel stays) pass the actual hotel through.
  // [hotelId] is the `catalog_hotels` doc id — only set when this page was
  // opened from a real catalog hotel (Explore, Saved, History). No longer
  // used by this page itself (the Review tab that read it is gone), kept
  // only because BookingBar still records it as the booked stay's refId.
  final String hotelId;
  final String name;
  final String location;
  final String ratingLabel;
  final String pricePerNight;
  // The hotel's real photo (Duffel/RollingGo's own accommodation photo, or
  // the saved catalog hotel's `image`) — empty for a trip's manually-typed
  // hotel stay, which has no photo data at all, same as [hotelId].
  final String image;
  // The trip this stay should be added to once payment succeeds (see
  // BookingBar's onPaid) — blank when there's no trip context. checkIn/
  // checkOut are the dates actually searched for (when known) so the
  // trip's own hotel-stay record reflects real dates instead of blanks.
  final String tripId;
  final String checkIn;
  final String checkOut;
  // Real per-hotel amenity names from Duffel/RollingGo (see
  // DuffelStayResult.amenities / CatalogHotel.amenities) — empty for a
  // manually-typed trip stay or any source result that just didn't have
  // this data. The amenities row only renders when this is non-empty,
  // rather than ever showing a fixed list that isn't actually about this
  // hotel.
  final List<String> amenities;

  const DetailPageHotel({
    super.key,
    this.hotelId = '',
    this.name = 'L Hotel',
    this.location = 'Shinjoku, Tokyo   1.2km to city center',
    this.ratingLabel = '4.8(1.2k)',
    this.pricePerNight = 'RM 320',
    this.image = '',
    this.tripId = '',
    this.checkIn = '',
    this.checkOut = '',
    this.amenities = const [],
  });

  @override
  State<DetailPageHotel> createState() => _DetailPageHotelState();
}

class _DetailPageHotelState extends State<DetailPageHotel> {
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
                      DetailHeader(title: widget.name, imageUrl: widget.image, translate: true),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          // Same fix as DetailPageAttraction/DetailPageRestaurant:
                          // without this, Column centers every child that
                          // doesn't already fill the width (name, rating,
                          // "About"), which is why this page looked
                          // inconsistent with the others' left-aligned layout.
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    TranslatedText(widget.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
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
                    // Only render this row when the source result actually
                    // had amenities data — no fixed fallback list, same
                    // "don't fabricate" rule this app uses for
                    // reviewScore/description elsewhere.
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
                onPaid: widget.tripId.isEmpty
                    ? null
                    : (confirmation) => TripRepository.instance.addHotelStay(
                          widget.tripId,
                          TripHotelStay(
                            id: '${DateTime.now().microsecondsSinceEpoch}',
                            name: widget.name,
                            location: widget.location,
                            // The dates actually confirmed at checkout —
                            // real, not whatever (possibly blank) dates
                            // this page happened to be opened with.
                            checkIn: confirmation.checkIn != null ? formatLongDate(confirmation.checkIn!) : widget.checkIn,
                            checkOut: confirmation.checkOut != null ? formatLongDate(confirmation.checkOut!) : widget.checkOut,
                            guestName: confirmation.guestName,
                            guestEmail: confirmation.guestEmail,
                            guestPhone: confirmation.guestPhone,
                            guestIdNumber: confirmation.guestIdNumber,
                            specialRequests: confirmation.specialRequests,
                            // The real Stripe PaymentIntent id from this
                            // charge, and the catalog hotel this stay was
                            // booked from (when there is one) — previously
                            // dropped on the floor because TripHotelStay had
                            // nowhere to put them, which is why Plan's hotel
                            // viewer couldn't show a Booking Reference or a
                            // Review tab the way Flight's can.
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
      _bookingRow('Check-in', '12 Jun 2026', 'Check-out', '15 Jun 2026'),
      const SizedBox(height: 10),
      _bookingRowSingle('2 Guests / 1 Room'),
      const SizedBox(height: 20),
      const Text('Hotel Policies', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: const Column(
          children: [
            FareRuleRow(icon: Icons.login, text: 'Check-in from 3:00 PM'),
            SizedBox(height: 12),
            FareRuleRow(icon: Icons.logout, text: 'Check-out until 12:00 PM'),
            SizedBox(height: 12),
            FareRuleRow(icon: Icons.event_available_outlined, text: 'Free cancellation up to 24 hours before check-in'),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _bookingRow(String label1, String value1, String label2, String value2) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: InfoField(label: label1, value: value1)),
          Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 16),
          Expanded(child: InfoField(label: label2, value: value2)),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
  }

  /// Maps a real amenity name (Duffel's `description`/`type`, or
  /// RollingGo's plain `hotelAmenities` string — e.g. "WiFi"/"WIFI",
  /// "Pool", "Gym", "Parking", "Bar", "SPA") to a representative icon.
  /// Matching is case-insensitive substring matching rather than an exact
  /// lookup table, since the two APIs don't share one fixed vocabulary;
  /// anything unrecognized still renders with its real label text, just
  /// under a generic fallback icon instead of guessing wrong.
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

  Widget _bookingRowSingle(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black)),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
  }

}
