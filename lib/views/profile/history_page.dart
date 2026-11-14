import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../repositories/booking_repository.dart';
import '../../theme.dart';
import 'history_detail_pages.dart';

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
                  Text(
                    _currentBookings.isEmpty
                        ? ''
                        : '${_currentBookings.length} ${_currentBookings.length == 1 ? 'booking' : 'bookings'}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                  ),
                  InkWell(
                    onTap: () => _openSortSheet(context),
                    child: Row(
                      children: [
                        Text('Filter', style: TextStyle(fontSize: 12.5, color: controller.oldestFirst ? AppColors.primary : AppColors.navy)),
                        const SizedBox(width: 4),
                        Icon(Icons.filter_list, size: 16, color: controller.oldestFirst ? AppColors.primary : AppColors.navy),
                      ],
                    ),
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

  List<BookingEntry> get _currentBookings {
    switch (controller.tab) {
      case HistoryTab.flight:
        return controller.flightBookings;
      case HistoryTab.hotel:
        return controller.hotelBookings;
      case HistoryTab.insurance:
        return controller.insuranceBookings;
    }
  }

  Future<void> _openSortSheet(BuildContext context) async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort by', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: controller.oldestFirst,
              title: const Text('Newest first'),
              onChanged: (v) => Navigator.of(sheetContext).pop(v),
            ),
            RadioListTile<bool>(
              value: true,
              groupValue: controller.oldestFirst,
              title: const Text('Oldest first'),
              onChanged: (v) => Navigator.of(sheetContext).pop(v),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) controller.setOldestFirst(choice);
  }

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

  void _openHistoryDetail(BuildContext context, BookingEntry b) {
    switch (controller.tab) {
      case HistoryTab.flight:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HistoryFlightDetailPage(
            routeCode: b.title,
            dateTime: b.subtitle,
            price: b.trailing,
            bookingRef: b.bookingRef,
            status: b.status.isEmpty ? 'Confirmed' : b.status,
            bookingId: b.id,
            documents: b.documents,
            guestName: b.guestName,
            guestEmail: b.guestEmail,
            guestPhone: b.guestPhone,
            guestIdNumber: b.guestIdNumber,
            purchasedAt: b.purchasedAt,
          ),
        ));
        break;
      case HistoryTab.hotel:
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
            purchasedAt: b.purchasedAt,
          ),
        ));
        break;
      case HistoryTab.insurance:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HistoryInsuranceDetailPage(
            planName: b.title,
            policyNumber: b.subtitle.replaceFirst('Policy #', ''),
            amountPaid: b.trailing,
            status: b.status.isEmpty ? 'Confirmed' : b.status,
            travellerName: b.guestName,
            bookingId: b.id,
            documents: b.documents,
            coverage: b.coverage,
            transactionId: b.transactionId,
            purchasedAt: b.purchasedAt,
            partnerId: b.partnerId,
            providerName: b.providerName,
            travelStart: b.travelStart,
            travelEnd: b.travelEnd,
            travellerIdNumber: b.guestIdNumber,
            travellerEmail: b.guestEmail,
            travellerPhone: b.guestPhone,
          ),
        ));
        break;
    }
  }
}
