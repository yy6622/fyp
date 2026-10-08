import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/booking_repository.dart';
import '../../repositories/catalog_repository.dart';
import '../../services/auth_service.dart';
import '../../services/booking_document_service.dart';
import '../../theme.dart';
import '../detail/detail_widgets.dart';

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
// Documents are real, though (see BookingDocumentService) — every booking
// has a real Firestore doc id to attach an upload to, unlike the fields
// above.
// ---------------------------------------------------------------------

/// Shared shell: VoyaAppBar with the popup menu, a [PillTabBar] (matching
/// Plan's Plan/Chat/Expenses/Vote look), and the tab body switch. [tabs]
/// and [builders] must be the same length and in the same order — each
/// page below supplies its own set (Hotel adds a 4th "Review" tab only
/// when it has a real catalog id to show reviews for).
class _HistoryDetailShell extends StatefulWidget {
  final String title;
  final List<PillTab> tabs;
  final List<Widget Function(BuildContext context)> builders;

  const _HistoryDetailShell({
    required this.title,
    required this.tabs,
    required this.builders,
  });

  @override
  State<_HistoryDetailShell> createState() => _HistoryDetailShellState();
}

class _HistoryDetailShellState extends State<_HistoryDetailShell> {
  int _tabIndex = 0;

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
          PillTabBar(
            tabs: widget.tabs,
            selectedIndex: _tabIndex,
            onSelected: (i) => setState(() => _tabIndex = i),
          ),
          Expanded(child: widget.builders[_tabIndex](context)),
        ],
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

/// Guest/traveller list for a past booking — [roleLabel] is the row's
/// caption ("Guest", "Traveller"), [name]/[email]/[phone]/[idNumber] are
/// the real values captured at checkout (see BookingPaymentPage.
/// _confirmPayment → BookingRepository.addBooking). Used to show the
/// literal role label itself as if it were a name — this now shows what
/// was actually booked, with an honest "Not available" when a legacy
/// booking (from before these fields existed) has none stored.
Widget _peopleList(String roleLabel, {required String name, String email = '', String phone = '', String idNumber = ''}) {
  final hasName = name.isNotEmpty;
  return ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 16, backgroundColor: const Color(0xFFD9D9D9), child: Icon(Icons.person_outline, size: 16, color: AppColors.textGrey)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasName ? name : 'Not available', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                  Text(roleLabel, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                  if (email.isNotEmpty || phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text([email, phone].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  ],
                  if (idNumber.isNotEmpty) Text('ID/Passport: $idNumber', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Real document upload for a History booking — same Upload/uploading-
/// spinner/Uploaded+View states PlanFlightDetailPage's Documents tab
/// uses, backed by [BookingDocumentService] + [BookingRepository.
/// setBookingDocument] instead of the trip-flight equivalents. [onUpload]
/// drives the parent's own state (so a fresh upload shows immediately
/// without waiting for the next watchBookings snapshot).
Widget _documentsList({
  required List<(String, IconData)> docs,
  required Map<String, String> documents,
  required Set<String> uploading,
  required void Function(String docType) onUpload,
}) {
  return ListView.separated(
    padding: const EdgeInsets.all(20),
    itemCount: docs.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (context, i) {
      final (label, icon) = docs[i];
      final url = documents[label];
      final isUploading = uploading.contains(label);
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
                  ],
                ],
              ),
            ),
            if (isUploading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            else if (url != null)
              TextButton(
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: const Text('View', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              )
            else
              TextButton.icon(
                onPressed: () => onUpload(label),
                icon: const Icon(Icons.upload_outlined, size: 16, color: AppColors.primary),
                label: const Text('Upload', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      );
    },
  );
}

/// Shared upload flow (pick source → pick file → upload → save the URL)
/// used by both booking detail pages below — identical to
/// PlanFlightDetailPage._uploadDocument except it saves through
/// [BookingRepository.setBookingDocument] instead of a trip flight's
/// document map.
mixin _BookingDocumentUploader<T extends StatefulWidget> on State<T> {
  Map<String, String> get documents;
  set documents(Map<String, String> value);
  Set<String> get uploading;
  String get bookingId;

  Future<void> uploadDocument(String docType) async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not available for this entry.')));
      return;
    }
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
    final file = await BookingDocumentService.instance.pick(source);
    if (file == null || !mounted) return;
    setState(() => uploading.add(docType));
    try {
      final url = await BookingDocumentService.instance.upload(uid: uid, bookingId: bookingId, docType: docType, file: file);
      await BookingRepository.instance.setBookingDocument(uid, bookingId, docType, url);
      if (!mounted) return;
      setState(() {
        documents = {...documents, docType: url};
        uploading.remove(docType);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading.remove(docType));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }
}

// ---------------------------------------------------------------------
// Flight
// ---------------------------------------------------------------------
// History's Flight tab used to reuse PlanFlightDetailPage with no
// tripId/id (see group_trip_page.dart's _pickHistoryFlight comment for the
// in-trip case) — that disabled its Documents tab entirely, which is what
// made the upload button look broken for a past flight booking. This page
// is the Flight sibling of HistoryHotelDetailPage/HistoryInsuranceDetailPage
// below: a real `users/{uid}/bookings` doc id to upload against, instead of
// a trip-scoped flight id that a bare History entry never has.
class HistoryFlightDetailPage extends StatefulWidget {
  final String routeCode;
  final String dateTime;
  final String price;
  final String bookingRef;
  final String status;
  final String bookingId;
  final Map<String, String> documents;

  const HistoryFlightDetailPage({
    super.key,
    required this.routeCode,
    required this.dateTime,
    required this.price,
    this.bookingRef = '',
    this.status = 'Confirmed',
    this.bookingId = '',
    this.documents = const {},
  });

  static const _docs = [
    ('E-Ticket', Icons.confirmation_number_outlined),
    ('Boarding Pass', Icons.airplane_ticket_outlined),
    ('Passport Scan', Icons.badge_outlined),
    ('Travel Insurance', Icons.shield_outlined),
  ];

  @override
  State<HistoryFlightDetailPage> createState() => _HistoryFlightDetailPageState();
}

class _HistoryFlightDetailPageState extends State<HistoryFlightDetailPage> with _BookingDocumentUploader<HistoryFlightDetailPage> {
  @override
  late Map<String, String> documents = Map.of(widget.documents);
  @override
  final Set<String> uploading = {};
  @override
  String get bookingId => widget.bookingId;

  @override
  Widget build(BuildContext context) {
    return _HistoryDetailShell(
      title: 'Flight',
      tabs: const [
        PillTab('Detail', Icons.info_outline),
        PillTab('Documents', Icons.description_outlined),
      ],
      builders: [
        (_) => _infoCard('FLIGHT INFORMATION', [
              _field('Route', widget.routeCode),
              _field('Date & Time', widget.dateTime),
              _field('Price', widget.price),
              _field('Booking Reference', widget.bookingRef.isEmpty ? 'Not available' : widget.bookingRef),
              _field('Status', widget.status, last: true),
            ]),
        (_) => _documentsList(
              docs: HistoryFlightDetailPage._docs,
              documents: documents,
              uploading: uploading,
              onUpload: uploadDocument,
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Hotel
// ---------------------------------------------------------------------
class HistoryHotelDetailPage extends StatefulWidget {
  final String name;
  final String location;
  final String pricePerNight;
  final String checkIn;
  final String checkOut;
  final String bookingRef;
  final String status;
  // Guest details captured at checkout (see BookingPaymentPage.
  // _confirmPayment) — blank for a legacy booking made before these were
  // stored.
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  // The `catalog_hotels` doc id this booking refers to — blank for a stay
  // with no catalog link (a manually-typed hotel). Only when this is set
  // do we know which real place to show reviews for, so the Review tab
  // only appears then, instead of showing reviews for the wrong hotel or
  // crashing on an empty id.
  final String hotelId;
  // The `users/{uid}/bookings` doc id this booking actually is — what
  // document uploads attach to (see BookingRepository.setBookingDocument).
  // Blank only for a legacy/placeholder call site, in which case uploads
  // are disabled (see _BookingDocumentUploader.uploadDocument).
  final String bookingId;
  final Map<String, String> documents;

  const HistoryHotelDetailPage({
    super.key,
    required this.name,
    required this.location,
    required this.pricePerNight,
    // These used to default to fake-looking fixed dates/reference
    // ("12 Jun 2026" / "HTL0456") whenever the call site didn't pass real
    // ones — which was always, since history_page.dart never had real
    // values to pass. Now that BookingPaymentPage actually stores
    // checkIn/checkOut/bookingRef, an honest "Not available" is correct
    // for the rare legacy booking that still has none.
    this.checkIn = '',
    this.checkOut = '',
    this.bookingRef = '',
    this.status = 'Confirmed',
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.specialRequests = '',
    this.hotelId = '',
    this.bookingId = '',
    this.documents = const {},
  });

  static const _docs = [
    ('Booking Confirmation', Icons.confirmation_number_outlined),
    ('Room Voucher', Icons.hotel_outlined),
    ('Passport Scan', Icons.badge_outlined),
    ('Travel Insurance', Icons.shield_outlined),
  ];

  @override
  State<HistoryHotelDetailPage> createState() => _HistoryHotelDetailPageState();
}

class _HistoryHotelDetailPageState extends State<HistoryHotelDetailPage> with _BookingDocumentUploader<HistoryHotelDetailPage> {
  @override
  late Map<String, String> documents = Map.of(widget.documents);
  @override
  final Set<String> uploading = {};
  @override
  String get bookingId => widget.bookingId;

  @override
  Widget build(BuildContext context) {
    final hasReviews = widget.hotelId.isNotEmpty;
    return _HistoryDetailShell(
      title: 'Hotel',
      tabs: [
        const PillTab('Detail', Icons.info_outline),
        const PillTab('Guests', Icons.people_outline),
        const PillTab('Documents', Icons.description_outlined),
        if (hasReviews) const PillTab('Review', Icons.rate_review_outlined),
      ],
      builders: [
        (_) => _infoCard('HOTEL INFORMATION', [
              _field('Hotel Name', widget.name),
              _field('Location', widget.location),
              _field('Check-in', widget.checkIn.isEmpty ? 'Not available' : widget.checkIn),
              _field('Check-out', widget.checkOut.isEmpty ? 'Not available' : widget.checkOut),
              _field('Price / Night', widget.pricePerNight),
              _field('Booking Reference', widget.bookingRef.isEmpty ? 'Not available' : widget.bookingRef),
              _field('Status', widget.status, last: true),
            ]),
        (_) => _peopleList(
              'Guest',
              name: widget.guestName,
              email: widget.guestEmail,
              phone: widget.guestPhone,
              idNumber: widget.guestIdNumber,
            ),
        (_) => _documentsList(
              docs: HistoryHotelDetailPage._docs,
              documents: documents,
              uploading: uploading,
              onUpload: uploadDocument,
            ),
        if (hasReviews)
          (_) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ReviewsSection(
                    title: widget.name,
                    ratingSummary: 'Guest Reviews',
                    reviewsStream: CatalogRepository.instance.watchHotelReviews(widget.hotelId).map((list) => list.map(reviewDataFromPlace).toList()),
                    onSubmitReview: ({required authorId, required authorName, required rating, required comment}) =>
                        CatalogRepository.instance.addHotelReview(
                      widget.hotelId,
                      authorId: authorId,
                      authorName: authorName,
                      rating: rating,
                      comment: comment,
                    ),
                  ),
                ],
              ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Insurance
// ---------------------------------------------------------------------
class HistoryInsuranceDetailPage extends StatefulWidget {
  final String planName;
  final String policyNumber;
  final String amountPaid;
  final String coverage;
  final String status;
  final String travellerName;
  final String bookingId;
  final Map<String, String> documents;

  const HistoryInsuranceDetailPage({
    super.key,
    required this.planName,
    required this.policyNumber,
    required this.amountPaid,
    this.coverage = 'Basic Travel Cover',
    this.status = 'Confirmed',
    this.travellerName = '',
    this.bookingId = '',
    this.documents = const {},
  });

  static const _docs = [
    ('Policy Document', Icons.description_outlined),
    ('Certificate of Insurance', Icons.verified_outlined),
    ('Passport Scan', Icons.badge_outlined),
    ('Claim Form', Icons.assignment_outlined),
  ];

  @override
  State<HistoryInsuranceDetailPage> createState() => _HistoryInsuranceDetailPageState();
}

class _HistoryInsuranceDetailPageState extends State<HistoryInsuranceDetailPage> with _BookingDocumentUploader<HistoryInsuranceDetailPage> {
  @override
  late Map<String, String> documents = Map.of(widget.documents);
  @override
  final Set<String> uploading = {};
  @override
  String get bookingId => widget.bookingId;

  @override
  Widget build(BuildContext context) {
    return _HistoryDetailShell(
      title: 'Insurance',
      tabs: const [
        PillTab('Detail', Icons.info_outline),
        PillTab('Traveller', Icons.people_outline),
        PillTab('Documents', Icons.description_outlined),
      ],
      builders: [
        (_) => _infoCard('INSURANCE INFORMATION', [
              _field('Plan Name', widget.planName),
              _field('Coverage', widget.coverage),
              _field('Policy Number', widget.policyNumber),
              _field('Amount Paid', widget.amountPaid),
              _field('Status', widget.status, last: true),
            ]),
        (_) => _peopleList('Traveller', name: widget.travellerName),
        (_) => _documentsList(
              docs: HistoryInsuranceDetailPage._docs,
              documents: documents,
              uploading: uploading,
              onUpload: uploadDocument,
            ),
      ],
    );
  }
}
