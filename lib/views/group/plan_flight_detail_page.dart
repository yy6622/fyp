import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Plan_Flight_Detail — flight card inside a group's itinerary
// ---------------------------------------------------------------------
class PlanFlightDetailPage extends StatefulWidget {
  // Defaults match the original Japan-trip mock so the Group Trip caller
  // (group_trip_page.dart, which still just does const PlanFlightDetailPage())
  // renders exactly as before. History passes the actual tapped booking's
  // route/date through so this same page reflects what was tapped there too.
  final String airline;
  final String flightNumber;
  final String routeCode;
  final String routeCities;
  final String dateTime;
  final String terminal;
  final String bookingRef;
  final String status;

  const PlanFlightDetailPage({
    super.key,
    this.airline = 'Malaysia Airlines',
    this.flightNumber = 'MH0521',
    this.routeCode = 'KUL → KIX',
    this.routeCities = '(Kuala Lumpur → Osaka)',
    this.dateTime = '12 June 2026, 13:30',
    this.terminal = 'Terminal 1',
    this.bookingRef = 'ABC123',
    this.status = 'Confirmed',
  });

  @override
  State<PlanFlightDetailPage> createState() => _PlanFlightDetailPageState();
}

class _PlanFlightDetailPageState extends State<PlanFlightDetailPage> {
  final PlanFlightDetailController controller = PlanFlightDetailController();

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
        title: const Text('Flight', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.navy),
            onSelected: (_) {},
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'private', child: Text('Set to private')),
              PopupMenuItem(value: 'shift', child: Text('Shift to Plans')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Row(
              children: [
                Expanded(child: _tab('Detail', PlanFlightTab.detail)),
                Expanded(child: _tab('Passenger', PlanFlightTab.passenger)),
                Expanded(child: _tab('Documents', PlanFlightTab.documents)),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFECECEC)),
            Expanded(
              child: switch (controller.tab) {
                PlanFlightTab.detail => _detailContent(),
                PlanFlightTab.passenger => _passengerContent(),
                PlanFlightTab.documents => _documentsContent(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, PlanFlightTab tab) {
    final selected = controller.tab == tab;
    return GestureDetector(
      onTap: () => controller.setTab(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
      ),
    );
  }

  Widget _detailContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECECEC)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFE4E4E4),
                child: const Text('FLIGHT INFORMATION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
              ),
              _field('Airline', widget.airline),
              _field('Flight Number', widget.flightNumber),
              _fieldRoute(widget.routeCode, widget.routeCities),
              _field('Date & Time', widget.dateTime),
              _field('Terminal', widget.terminal),
              _field('Booking Reference', widget.bookingRef),
              _field('Status', widget.status, last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE4E4E4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  /// Same row shape as [_field] but the value is split into a bold route
  /// code and a smaller grey city name shown right after it.
  Widget _fieldRoute(String route, String cities) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Route', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          Row(
            children: [
              Text(route, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
              const SizedBox(width: 4),
              Text(cities, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _passengerContent() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Passenger name', style: TextStyle(fontSize: 13, color: Colors.black))),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _documentsContent() {
    const docs = [
      ('E-Ticket', Icons.confirmation_number_outlined),
      ('Boarding Pass', Icons.airplane_ticket_outlined),
      ('Passport Scan', Icons.badge_outlined),
      ('Travel Insurance', Icons.shield_outlined),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(docs[i].$2, size: 16, color: AppColors.navy),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(docs[i].$1, style: const TextStyle(fontSize: 13, color: Colors.black))),
            TextButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening file picker...')),
              ),
              icon: const Icon(Icons.upload_outlined, size: 16, color: AppColors.primary),
              label: const Text('Upload', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
