import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/booking_repository.dart';
import '../../services/auth_service.dart';
import '../../services/booking_document_service.dart';
import '../../theme.dart';
import '../insurance/claim_refund_page.dart';


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

class HistoryHotelDetailPage extends StatefulWidget {
  final String name;
  final String location;
  final String pricePerNight;
  final String checkIn;
  final String checkOut;
  final String bookingRef;
  final String status;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  final String hotelId;
  final String bookingId;
  final Map<String, String> documents;

  const HistoryHotelDetailPage({
    super.key,
    required this.name,
    required this.location,
    required this.pricePerNight,
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
    return _HistoryDetailShell(
      title: 'Hotel',
      tabs: const [
        PillTab('Detail', Icons.info_outline),
        PillTab('Guests', Icons.people_outline),
        PillTab('Documents', Icons.description_outlined),
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
      ],
    );
  }
}

class HistoryInsuranceDetailPage extends StatefulWidget {
  final String planName;
  final String policyNumber;
  final String amountPaid;
  final String coverage;
  final String status;
  final String travellerName;
  final String bookingId;
  final Map<String, String> documents;
  final String transactionId;

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
    this.transactionId = '',
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
        (context) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECECEC))),
                  child: Column(
                    children: [
                      _field('Plan Name', widget.planName),
                      _field('Coverage', widget.coverage),
                      _field('Policy Number', widget.policyNumber),
                      _field('Amount Paid', widget.amountPaid),
                      _field('Status', widget.status, last: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.transactionId.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
                    child: const Text(
                      "Filing a claim or refund isn't available for this policy — it was purchased before this feature existed.",
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => FileClaimPage(transactionId: widget.transactionId))),
                          icon: const Icon(Icons.assignment_outlined, size: 16, color: AppColors.primary),
                          label: const Text('File a Claim',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => RequestRefundPage(transactionId: widget.transactionId))),
                          icon: const Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
                          label: const Text('Request Refund',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
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
