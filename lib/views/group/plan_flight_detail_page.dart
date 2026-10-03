import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/group_trip_controller.dart';
import '../../models/booking_details.dart';
import '../../repositories/trip_repository.dart';
import '../../services/flight_document_service.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Plan_Flight_Detail — flight card inside a group's itinerary. Shown for a
// flight that's actually on the trip (trip.flights), so every field here
// is the real stored TripFlight data — never a placeholder. [tripId]/[id]
// are blank only when this page is opened for a bare History entry with
// no real trip.flights record behind it (see group_trip_page.dart's
// _pickHistoryFlight), in which case Passenger/Documents editing is
// disabled rather than silently doing nothing.
// ---------------------------------------------------------------------
class PlanFlightDetailPage extends StatefulWidget {
  final String tripId;
  final String id;
  final String airline;
  final String flightNumber;
  final String routeCode;
  final String routeCities;
  final String dateTime;
  final String terminal;
  final String bookingRef;
  final String status;
  final List<String> passengers;
  final List<PassengerDetail> passengerDetails;
  final String contactEmail;
  final String contactPhone;
  final Map<String, String> documents;

  const PlanFlightDetailPage({
    super.key,
    this.tripId = '',
    this.id = '',
    this.airline = '',
    this.flightNumber = '',
    this.routeCode = '',
    this.routeCities = '',
    this.dateTime = '',
    this.terminal = '',
    this.bookingRef = '',
    this.status = 'Confirmed',
    this.passengers = const [],
    this.passengerDetails = const [],
    this.contactEmail = '',
    this.contactPhone = '',
    this.documents = const {},
  });

  @override
  State<PlanFlightDetailPage> createState() => _PlanFlightDetailPageState();
}

class _PlanFlightDetailPageState extends State<PlanFlightDetailPage> {
  final PlanFlightDetailController controller = PlanFlightDetailController();
  // Local copy so an upload shows immediately without re-fetching the
  // whole trip — TripRepository.setFlightDocument is still the source of
  // truth in Firestore.
  late Map<String, String> _documents = Map.of(widget.documents);
  final Set<String> _uploading = {};

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  static const _docTypes = [
    ('E-Ticket', Icons.confirmation_number_outlined),
    ('Boarding Pass', Icons.airplane_ticket_outlined),
    ('Passport Scan', Icons.badge_outlined),
    ('Travel Insurance', Icons.shield_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: const Text('Flight', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _tab('Detail', PlanFlightTab.detail)),
                  Expanded(child: _tab('Passenger', PlanFlightTab.passenger)),
                  Expanded(child: _tab('Documents', PlanFlightTab.documents)),
                ],
              ),
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

  /// Same bottom-underline treatment as DetailPageHotel's Details/Review
  /// toggle (_tabButton there) — same text size/weight/colors — so this
  /// page's tabs read as the same tab system, not a different one.
  Widget _tab(String label, PlanFlightTab tab) {
    final selected = controller.tab == tab;
    return GestureDetector(
      onTap: () => controller.setTab(tab),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10, top: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
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
              _field('Airline', _orNotSpecified(widget.airline)),
              _field('Flight Number', _orNotSpecified(widget.flightNumber)),
              _fieldRoute(widget.routeCode, widget.routeCities),
              _field('Date & Time', _orNotSpecified(widget.dateTime)),
              _field('Terminal', _orNotSpecified(widget.terminal)),
              _field('Booking Reference', widget.bookingRef.isEmpty ? 'Not available' : widget.bookingRef),
              _field('Status', widget.status, last: true),
            ],
          ),
        ),
      ],
    );
  }

  String _orNotSpecified(String v) => v.isEmpty ? 'Not specified' : v;

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
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  /// Route code and city names stacked on their own lines instead of
  /// crammed into one Row next to the "Route" label — a long real city
  /// pair (e.g. "Kuala Lumpur → Tokyo (Narita)") has room to sit on its
  /// own line under the bold route code rather than fighting the label
  /// for width.
  Widget _fieldRoute(String route, String cities) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Route', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_orNotSpecified(route),
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
                if (cities.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(cities, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _formatDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  Widget _passengerContent() {
    if (widget.passengers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.tripId.isEmpty
                ? 'No passenger details for this entry.'
                : 'No passenger details yet — these are collected when a flight is paid for through the app.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
        ),
      );
    }
    // Richer per-passenger records exist for anything booked since the
    // real passenger-details flow was added; older/manually-typed entries
    // only ever have the bare name list, so fall back to that.
    final hasFullDetails = widget.passengerDetails.length == widget.passengers.length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.contactEmail.isNotEmpty || widget.contactPhone.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.contact_mail_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${widget.contactEmail}${widget.contactEmail.isNotEmpty && widget.contactPhone.isNotEmpty ? ' · ' : ''}${widget.contactPhone}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.black)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (int i = 0; i < widget.passengers.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _passengerCard(i, hasFullDetails ? widget.passengerDetails[i] : null),
        ],
      ],
    );
  }

  Widget _passengerCard(int index, PassengerDetail? detail) {
    final name = widget.passengers[index];
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(initial, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Passenger ${index + 1}' : name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'DOB: ${detail.dob != null ? _formatDate(detail.dob!) : '—'} · ${detail.nationality ?? '—'}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                  ),
                  Text(
                    'Passport ${detail.passportNumber.isEmpty ? '—' : detail.passportNumber}'
                    '${detail.passportExpiry != null ? ' (exp. ${_formatDate(detail.passportExpiry!)})' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentsContent() {
    final canUpload = widget.tripId.isNotEmpty && widget.id.isNotEmpty;
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _docTypes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final (label, icon) = _docTypes[i];
        final url = _documents[label];
        final uploading = _uploading.contains(label);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: AppColors.navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, color: Colors.black)),
                    if (url != null) ...[
                      const SizedBox(height: 2),
                      const Text('Uploaded', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                    ] else if (!canUpload) ...[
                      const SizedBox(height: 2),
                      const Text('Not available for this entry', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ],
                ),
              ),
              if (uploading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              else if (url != null)
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  child: const Text('View', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                )
              else
                TextButton.icon(
                  onPressed: canUpload ? () => _uploadDocument(label) : null,
                  icon: Icon(Icons.upload_outlined, size: 16, color: canUpload ? AppColors.primary : AppColors.textGrey),
                  label: Text('Upload', style: TextStyle(color: canUpload ? AppColors.primary : AppColors.textGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadDocument(String docType) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await FlightDocumentService.instance.pick(source);
    if (file == null || !mounted) return;
    setState(() => _uploading.add(docType));
    try {
      final url = await FlightDocumentService.instance.upload(
        tripId: widget.tripId,
        flightId: widget.id,
        docType: docType,
        file: file,
      );
      await TripRepository.instance.setFlightDocument(widget.tripId, widget.id, docType, url);
      if (!mounted) return;
      setState(() {
        _documents = {..._documents, docType: url};
        _uploading.remove(docType);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading.remove(docType));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }
}
