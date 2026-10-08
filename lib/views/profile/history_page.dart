import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../repositories/booking_repository.dart';
import '../../theme.dart';
import 'history_detail_pages.dart';

// ---------------------------------------------------------------------
// History (Flight / Hotel / Insurance tabs)
// ---------------------------------------------------------------------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryController controller = HistoryController();

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
        title: const Text('History', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline, color: AppColors.navy),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new booking updates')),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            PillTabBar(
              tabs: const [
                PillTab('Flight', Icons.flight_takeoff),
                PillTab('Hotel', Icons.hotel_outlined),
                PillTab('Insurance', Icons.shield_outlined),
              ],
              selectedIndex: controller.tab.index,
              onSelected: (i) => controller.setTab(HistoryTab.values[i]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('March', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                  Row(
                    children: const [
                      Text('Filter', style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                      SizedBox(width: 4),
                      Icon(Icons.filter_list, size: 16, color: AppColors.navy),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  // All three tabs read real purchases from Firestore (`users/{uid}/bookings`
  // — see [BookingRepository] and [HistoryController]); nothing here is a
  // placeholder row anymore.
  Widget _buildList(BuildContext context) {
    final IconData icon;
    final bool loading;
    final List<BookingEntry> bookings;
    final String emptyMessage;
    switch (controller.tab) {
      case HistoryTab.flight:
        icon = Icons.flight_takeoff;
        loading = controller.loadingFlight;
        bookings = controller.flightBookings;
        emptyMessage = 'No flight bookings yet';
        break;
      case HistoryTab.hotel:
        icon = Icons.hotel_outlined;
        loading = controller.loadingHotel;
        bookings = controller.hotelBookings;
        emptyMessage = 'No hotel bookings yet';
        break;
      case HistoryTab.insurance:
        icon = Icons.shield_outlined;
        loading = controller.loadingInsurance;
        bookings = controller.insuranceBookings;
        emptyMessage = 'No insurance purchases yet';
        break;
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bookings.isEmpty) {
      return Center(child: Text(emptyMessage, style: const TextStyle(color: AppColors.textGrey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: bookings.length,
      itemBuilder: (context, i) => _historyRow(context, icon: icon, booking: bookings[i]),
    );
  }

  Widget _historyRow(
    BuildContext context, {
    required IconData icon,
    required BookingEntry booking,
  }) {
    final title = booking.title;
    final subtitle = booking.subtitle;
    final trailing = booking.trailing;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openHistoryDetail(context, booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFFE4372A), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
            Text(trailing, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  // Tapping a past booking opens a read-only "past record" page — same
  // tabs + plain info-card look for all three tabs (see
  // history_detail_pages.dart, styled to match PlanFlightDetailPage).
  // Hotel/Insurance used to reuse the *live shopping* pages
  // (DetailPageHotel / InsurancePlanDetailPage), which have their own
  // "Select Hotel" / "Enter Traveller" purchase button at the bottom — that
  // let a past booking be accidentally re-purchased from History, and
  // looked completely different from the Flight tab. The row's own
  // title/subtitle/trailing are threaded through so each page reflects the
  // booking that was actually tapped.
  void _openHistoryDetail(BuildContext context, BookingEntry b) {
    switch (controller.tab) {
      case HistoryTab.flight:
        // id is the real `users/{uid}/bookings` doc id — passed through as
        // bookingId so the Documents tab can actually attach an upload
        // (see HistoryFlightDetailPage / BookingDocumentService). Before,
        // this reused PlanFlightDetailPage with no tripId/id at all, which
        // left the upload button permanently disabled for every History
        // flight entry.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HistoryFlightDetailPage(
            routeCode: b.title,
            dateTime: b.subtitle,
            price: b.trailing,
            bookingRef: b.bookingRef,
            status: b.status.isEmpty ? 'Confirmed' : b.status,
            bookingId: b.id,
            documents: b.documents,
          ),
        ));
        break;
      case HistoryTab.hotel:
        // trailing reads like "RM 320 (per night)" (see BookingBar) — strip
        // the suffix back off, HistoryHotelDetailPage labels it itself.
        // refId (when set) is the original catalog_hotels doc id, which
        // unlocks a real Review tab on the detail page below. checkIn/
        // checkOut/bookingRef/guestName now come from the real booking
        // (written by BookingPaymentPage._confirmPayment) instead of the
        // hardcoded fallback dates this page used to default to.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HistoryHotelDetailPage(
            name: b.title,
            location: b.subtitle,
            pricePerNight: b.trailing.split(' (').first,
            checkIn: b.checkIn,
            checkOut: b.checkOut,
            bookingRef: b.bookingRef,
            status: b.status.isEmpty ? 'Confirmed' : b.status,
            guestName: b.guestName,
            guestEmail: b.guestEmail,
            guestPhone: b.guestPhone,
            guestIdNumber: b.guestIdNumber,
            specialRequests: b.specialRequests,
            hotelId: b.refId,
            bookingId: b.id,
            documents: b.documents,
          ),
        ));
        break;
      case HistoryTab.insurance:
        // subtitle reads like "Policy #INS-172..." (see PaymentMethodPage)
        // — strip the label back off, HistoryInsuranceDetailPage labels it
        // itself.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HistoryInsuranceDetailPage(
            planName: b.title,
            policyNumber: b.subtitle.replaceFirst('Policy #', ''),
            amountPaid: b.trailing,
            status: b.status.isEmpty ? 'Confirmed' : b.status,
            travellerName: b.guestName,
            bookingId: b.id,
            documents: b.documents,
          ),
        ));
        break;
    }
  }
}
