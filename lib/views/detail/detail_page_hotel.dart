import 'package:flutter/material.dart';

import '../../controllers/detail_page_controller.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/translated_text.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Hotel detail (Details / Review tabs)
// ---------------------------------------------------------------------
class DetailPageHotel extends StatefulWidget {
  // Defaults match the original Japan-trip mock so existing callers that
  // still just do `const DetailPageHotel()` render exactly as before; real
  // callers (Explore, a trip's hotel stays) pass the actual hotel through.
  // [hotelId] is the `catalog_hotels` doc id — only set when this page was
  // opened from a real catalog hotel (Explore, Saved, History), not for a
  // trip's own manually-typed hotel stay, which has no catalog doc to
  // attach real reviews to. When it's empty the Reviews section is hidden
  // entirely rather than showing something fake.
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
  });

  @override
  State<DetailPageHotel> createState() => _DetailPageHotelState();
}

class _DetailPageHotelState extends State<DetailPageHotel> {
  final DetailPageHotelController controller = DetailPageHotelController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
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
                    SizedBox(
                      height: 74,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const [
                          AmenityIcon(icon: Icons.wifi, label: 'Free Wifi'),
                          AmenityIcon(icon: Icons.free_breakfast_outlined, label: 'Breakfast'),
                          AmenityIcon(icon: Icons.cleaning_services_outlined, label: 'Housekeeping'),
                          AmenityIcon(icon: Icons.luggage_outlined, label: 'Luggage storage'),
                          AmenityIcon(icon: Icons.support_agent_outlined, label: '24h Desk'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.name} is a well-reviewed stay in ${widget.location.split(',').first.trim()}, '
                      'popular for its location and amenities. Save it to your plan and check exact availability '
                      'closer to your travel dates.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _tabButton('Details', !controller.showReview)),
                        Expanded(child: _tabButton('Review', controller.showReview)),
                      ],
                    ),
                    const Divider(height: 1, color: Color(0xFFECECEC)),
                    const SizedBox(height: 16),
                    if (!controller.showReview) ..._detailsContent() else ..._reviewContent(),
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
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool selected) {
    return GestureDetector(
      onTap: () => controller.setShowReview(label == 'Review'),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textGrey,
          ),
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

  List<Widget> _reviewContent() {
    // No catalog doc to attach real reviews to (a manually-typed trip
    // hotel stay, or the default preview) — skip the section rather than
    // showing canned content that isn't about a real place.
    if (widget.hotelId.isEmpty) {
      return const [
        Text('No review for this hotel yet.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ];
    }
    return [
      ReviewsSection(
        title: widget.name,
        ratingSummary: widget.ratingLabel,
        reviewsStream: CatalogRepository.instance.watchHotelReviews(widget.hotelId).map((list) => list.map(reviewDataFromPlace).toList()),
        onSubmitReview: ({required authorId, required authorName, required rating, required comment}) => CatalogRepository.instance.addHotelReview(
          widget.hotelId,
          authorId: authorId,
          authorName: authorName,
          rating: rating,
          comment: comment,
        ),
        allowWriting: false,
      ),
    ];
  }
}
