import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/group_trip_controller.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../services/hotel_document_service.dart';
import '../../theme.dart';
import '../detail/detail_widgets.dart';
import '../shared/member_select_section.dart';

// ---------------------------------------------------------------------
// Plan_Hotel_Detail — a hotel stay already on a trip's itinerary
// (trip.hotelStays). Previously tapping one of these reused
// DetailPageHotel, which is the *buy a hotel* page (its own "Select
// Hotel" purchase bar) — confusing for something already booked, and
// wrong since it has nothing to do with this stay's real check-in/
// check-out/guest data. This is the read-only counterpart to
// PlanFlightDetailPage — same Detail/Guests/Documents(/Review) tab
// structure, same real document upload, now that TripHotelStay carries
// bookingRef/status/refId/documents the same way TripFlight does.
// ---------------------------------------------------------------------
class PlanHotelDetailPage extends StatefulWidget {
  final String tripId;
  final String id;
  final String name;
  final String location;
  final String checkIn;
  final String checkOut;
  final String bookingRef;
  final String status;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  // The `catalog_hotels` doc id this stay was booked from — blank for a
  // manually-typed stay, in which case the Review tab is hidden (same
  // idea as HistoryHotelDetailPage.hotelId).
  final String refId;
  final Map<String, String> documents;
  // Who this stay is for, and the trip's full member roster to resolve
  // those uids into display names — see TripHotelStay.forMemberUids.
  final List<String> forMemberUids;
  final Map<String, String> memberNames;

  const PlanHotelDetailPage({
    super.key,
    this.tripId = '',
    this.id = '',
    required this.name,
    required this.location,
    this.checkIn = '',
    this.checkOut = '',
    this.bookingRef = '',
    this.status = 'Confirmed',
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.specialRequests = '',
    this.refId = '',
    this.documents = const {},
    this.forMemberUids = const [],
    this.memberNames = const {},
  });

  @override
  State<PlanHotelDetailPage> createState() => _PlanHotelDetailPageState();
}

class _PlanHotelDetailPageState extends State<PlanHotelDetailPage> {
  final PlanHotelDetailController controller = PlanHotelDetailController();
  // Local copy so an upload shows immediately without re-fetching the
  // whole trip — TripRepository.setHotelDocument is still the source of
  // truth in Firestore.
  late Map<String, String> _documents = Map.of(widget.documents);
  final Set<String> _uploading = {};

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  static const _docTypes = [
    ('Booking Confirmation', Icons.confirmation_number_outlined),
    ('Room Voucher', Icons.hotel_outlined),
    ('Passport Scan', Icons.badge_outlined),
    ('Travel Insurance', Icons.shield_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final hasReviews = widget.refId.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: const Text('Hotel Stay', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _tab('Detail', PlanHotelTab.detail)),
                  Expanded(child: _tab('Guests', PlanHotelTab.guests)),
                  Expanded(child: _tab('Documents', PlanHotelTab.documents)),
                  if (hasReviews) Expanded(child: _tab('Review', PlanHotelTab.review)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECECEC)),
            Expanded(
              child: switch (controller.tab) {
                PlanHotelTab.detail => _detailContent(),
                PlanHotelTab.guests => _guestsContent(),
                PlanHotelTab.documents => _documentsContent(),
                PlanHotelTab.review => hasReviews ? _reviewContent() : _detailContent(),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Same bottom-underline treatment as PlanFlightDetailPage's tabs.
  Widget _tab(String label, PlanHotelTab tab) {
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

  String _orNotSpecified(String v) => v.isEmpty ? 'Not specified' : v;

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
                child: const Text('HOTEL INFORMATION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
              ),
              _field('Hotel Name', _orNotSpecified(widget.name)),
              _field('Location', _orNotSpecified(widget.location)),
              _field('Check-in', _orNotSpecified(widget.checkIn)),
              _field('Check-out', _orNotSpecified(widget.checkOut)),
              _field('Booking Reference', widget.bookingRef.isEmpty ? 'Not available' : widget.bookingRef),
              _field(
                'For',
                forMembersLabel(widget.forMemberUids, widget.memberNames).isEmpty
                    ? 'Everyone'
                    : forMembersLabel(widget.forMemberUids, widget.memberNames).replaceFirst('For: ', ''),
              ),
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
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _guestsContent() {
    if (widget.guestName.isEmpty && widget.guestEmail.isEmpty && widget.guestPhone.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.tripId.isEmpty
                ? 'No guest details for this entry.'
                : 'No guest details yet — these are collected when a hotel is paid for through the app.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
        ),
      );
    }
    final initial = widget.guestName.trim().isNotEmpty ? widget.guestName.trim()[0].toUpperCase() : '?';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
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
                    Text(widget.guestName.isEmpty ? 'Guest' : widget.guestName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 4),
                    Text(
                      [widget.guestEmail, widget.guestPhone].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                    ),
                    if (widget.guestIdNumber.isNotEmpty)
                      Text('ID/Passport: ${widget.guestIdNumber}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    if (widget.specialRequests.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Request: ${widget.specialRequests}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _reviewContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ReviewsSection(
          title: widget.name,
          ratingSummary: 'Guest Reviews',
          reviewsStream: CatalogRepository.instance.watchHotelReviews(widget.refId).map((list) => list.map(reviewDataFromPlace).toList()),
          onSubmitReview: ({required authorId, required authorName, required rating, required comment}) =>
              CatalogRepository.instance.addHotelReview(
            widget.refId,
            authorId: authorId,
            authorName: authorName,
            rating: rating,
            comment: comment,
          ),
        ),
      ],
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
    final file = await HotelDocumentService.instance.pick(source);
    if (file == null || !mounted) return;
    setState(() => _uploading.add(docType));
    try {
      final url = await HotelDocumentService.instance.upload(
        tripId: widget.tripId,
        stayId: widget.id,
        docType: docType,
        file: file,
      );
      await TripRepository.instance.setHotelDocument(widget.tripId, widget.id, docType, url);
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
