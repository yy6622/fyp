import 'package:flutter/material.dart';

import '../../theme.dart';

// ---------------------------------------------------------------------
// Past-booking detail pages opened from History's Hotel / Insurance tabs.
//
// These mirror PlanFlightDetailPage's look exactly (VoyaAppBar + "Set to
// private / Shift to Plans" menu + tab row + plain bordered info card) so
// all three History tabs feel like one consistent "view a past booking"
// experience. They are deliberately NOT the live shopping/purchase pages
// (DetailPageHotel / InsurancePlanDetailPage) that History used to reuse —
// those have a "Select Hotel" / "Enter Traveller" purchase action at the
// bottom, which would let a past booking be re-purchased by accident.
//
// Only what BookingEntry actually stores (title/subtitle/trailing) is real;
// the remaining fields use the same kind of static defaults
// PlanFlightDetailPage already uses for airline/terminal/booking
// reference/status, since per-booking data that fine-grained isn't kept.
// ---------------------------------------------------------------------

enum _InfoTab { detail, people, documents }

/// Shared shell: VoyaAppBar with the popup menu, the 3-tab row, and the
/// tab body switch. Both pages below just supply their own tab bodies.
class _HistoryDetailShell extends StatefulWidget {
  final String title;
  final String peopleTabLabel;
  final Widget Function(BuildContext context) detailBuilder;
  final Widget Function(BuildContext context) peopleBuilder;
  final Widget Function(BuildContext context) documentsBuilder;

  const _HistoryDetailShell({
    required this.title,
    required this.peopleTabLabel,
    required this.detailBuilder,
    required this.peopleBuilder,
    required this.documentsBuilder,
  });

  @override
  State<_HistoryDetailShell> createState() => _HistoryDetailShellState();
}

class _HistoryDetailShellState extends State<_HistoryDetailShell> {
  _InfoTab _tab = _InfoTab.detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(widget.title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
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
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: _tabButton('Detail', _InfoTab.detail)),
              Expanded(child: _tabButton(widget.peopleTabLabel, _InfoTab.people)),
              Expanded(child: _tabButton('Documents', _InfoTab.documents)),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFECECEC)),
          Expanded(
            child: switch (_tab) {
              _InfoTab.detail => widget.detailBuilder(context),
              _InfoTab.people => widget.peopleBuilder(context),
              _InfoTab.documents => widget.documentsBuilder(context),
            },
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _InfoTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
      ),
    );
  }
}

/// One label/value row inside an info card — same shape History's flight
/// detail page (PlanFlightDetailPage._field) uses.
Widget _field(String label, String value, {bool last = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
        ),
      ],
    ),
  );
}

Widget _infoCard(String header, List<Widget> fields) {
  return ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECECEC))),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE4E4E4),
              child: Text(header, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
            ),
            ...fields,
          ],
        ),
      ),
    ],
  );
}

/// Placeholder people list — same visual as PlanFlightDetailPage's
/// Passenger tab (a plain named list; no per-booking data is stored for
/// this yet, same as flight's).
Widget _peopleList(String label) {
  return ListView.separated(
    padding: const EdgeInsets.all(20),
    itemCount: 1,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (context, i) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black))),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    ),
  );
}

Widget _documentsList(List<(String, IconData)> docs) {
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

// ---------------------------------------------------------------------
// Hotel
// ---------------------------------------------------------------------
class HistoryHotelDetailPage extends StatelessWidget {
  final String name;
  final String location;
  final String pricePerNight;
  final String checkIn;
  final String checkOut;
  final String bookingRef;
  final String status;

  const HistoryHotelDetailPage({
    super.key,
    required this.name,
    required this.location,
    required this.pricePerNight,
    this.checkIn = '12 Jun 2026',
    this.checkOut = '15 Jun 2026',
    this.bookingRef = 'HTL0456',
    this.status = 'Confirmed',
  });

  static const _docs = [
    ('Booking Confirmation', Icons.confirmation_number_outlined),
    ('Room Voucher', Icons.hotel_outlined),
    ('Passport Scan', Icons.badge_outlined),
    ('Travel Insurance', Icons.shield_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return _HistoryDetailShell(
      title: 'Hotel',
      peopleTabLabel: 'Guests',
      detailBuilder: (_) => _infoCard('HOTEL INFORMATION', [
        _field('Hotel Name', name),
        _field('Location', location),
        _field('Check-in', checkIn),
        _field('Check-out', checkOut),
        _field('Price / Night', pricePerNight),
        _field('Booking Reference', bookingRef),
        _field('Status', status, last: true),
      ]),
      peopleBuilder: (_) => _peopleList('Guest name'),
      documentsBuilder: (_) => _documentsList(_docs),
    );
  }
}

// ---------------------------------------------------------------------
// Insurance
// ---------------------------------------------------------------------
class HistoryInsuranceDetailPage extends StatelessWidget {
  final String planName;
  final String policyNumber;
  final String amountPaid;
  final String coverage;
  final String status;

  const HistoryInsuranceDetailPage({
    super.key,
    required this.planName,
    required this.policyNumber,
    required this.amountPaid,
    this.coverage = 'Basic Travel Cover',
    this.status = 'Confirmed',
  });

  static const _docs = [
    ('Policy Document', Icons.description_outlined),
    ('Certificate of Insurance', Icons.verified_outlined),
    ('Passport Scan', Icons.badge_outlined),
    ('Claim Form', Icons.assignment_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return _HistoryDetailShell(
      title: 'Insurance',
      peopleTabLabel: 'Traveller',
      detailBuilder: (_) => _infoCard('INSURANCE INFORMATION', [
        _field('Plan Name', planName),
        _field('Coverage', coverage),
        _field('Policy Number', policyNumber),
        _field('Amount Paid', amountPaid),
        _field('Status', status, last: true),
      ]),
      peopleBuilder: (_) => _peopleList('Traveller name'),
      documentsBuilder: (_) => _documentsList(_docs),
    );
  }
}
