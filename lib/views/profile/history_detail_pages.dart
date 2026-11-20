import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/insurance_models.dart';
import '../../repositories/insurance_repository.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import '../insurance/claim_refund_page.dart';
import '../insurance/insurance_chat_page.dart';
import '../shared/person_info_sheet.dart';

const List<String> _historyMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatPurchasedAt(DateTime? d) {
  if (d == null) return '';
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '${d.day} ${_historyMonthNames[d.month - 1]} ${d.year}, $hour12:$minute $ampm';
}

String _formatDateOnly(DateTime d) => '${d.day} ${_historyMonthNames[d.month - 1]} ${d.year}';

List<String> _split(String s) => s.trim().isEmpty ? const [] : s.split(', ').where((v) => v.trim().isNotEmpty).toList();

/// Shows the actual submission, not just its status; supports both claims and refunds.
void _showInsuranceRequestDetail(BuildContext context, ClaimOrRefundRecord r) {
  final label = r.isRefund ? 'Refund' : 'Claim';
  final style = _claimStatusStyle(r.status);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    // Keep visible space above the sheet even for long requests.
    builder: (sheetContext) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label ${r.ref}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.navy)),
              const SizedBox(height: 10),
              _field('Status', style.label),
              _field('Reason / Category', r.category.isEmpty ? '—' : r.category),
              _field('Details', r.description.isEmpty ? '—' : r.description),
              _field('Amount', r.amount == null ? 'Pending partner assessment' :
                  '${CurrencyService.instance.displayLabel(r.currencyCode)} ${r.amount!.toStringAsFixed(2)}'),
              if (r.createdAt != null) _field('Submitted', _formatPurchasedAt(r.createdAt)),
              const SizedBox(height: 16),
              const Text('Supporting Documents', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
              if (r.documents.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No documents attached.')),
              for (var i = 0; i < r.documents.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file, color: AppColors.primary),
                  title: Text('Document ${i + 1}', style: const TextStyle(color: AppColors.primary)),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () async {
                    final uri = Uri.tryParse(r.documents[i]);
                    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showInsuranceReadError(BuildContext context, Object? error) {
  final details = error?.toString() ?? 'Unknown error';
  final denied = details.toLowerCase().contains('permission-denied') ||
      details.toLowerCase().contains('missing or insufficient permissions');
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Unable to load request status'),
      content: Text(denied
          ? 'Firebase is not allowing this account to read its Claims / Refunds. The Firestore security rules must allow the policy buyer to read their own requests.\n\n$details'
          : 'Could not read the submitted request. Check your connection and Firestore configuration.\n\n$details'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
    ),
  );
}

/// Status rows use a full-width bottom border, including the chevron area.
/// The old layout put the chevron *outside* the bordered _field, leaving a gap.
Widget _tappableRequestStatusRow({
  required String label,
  required String value,
  required VoidCallback onTap,
  bool showError = false,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4))),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          Icon(showError ? Icons.error_outline : Icons.chevron_right,
              color: showError ? Colors.orange : AppColors.primary, size: 18),
        ],
      ),
    ),
  );
}

Widget _requestStatusField(String transactionId, {required bool isRefund}) {
  final stream = isRefund
      ? InsuranceRepository.instance.watchRefundsForTransaction(transactionId)
      : InsuranceRepository.instance.watchClaimsForTransaction(transactionId);
  final label = isRefund ? 'Refund Status' : 'Claim Status';
  return StreamBuilder<List<ClaimOrRefundRecord>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _tappableRequestStatusRow(
          label: label,
          value: 'Unable to load · Tap for reason',
          onTap: () => _showInsuranceReadError(context, snapshot.error),
          showError: true,
        );
      }
      final records = snapshot.data ?? const <ClaimOrRefundRecord>[];
      if (records.isEmpty) return _field(label, snapshot.hasData ? 'Not requested' : 'Loading…');
      final r = records.first;
      return _tappableRequestStatusRow(
        label: label,
        value: _claimStatusStyle(r.status).label,
        onTap: () => _showInsuranceRequestDetail(context, r),
      );
    },
  );
}

({Color color, String label}) _claimStatusStyle(String status) {
  switch (status) {
    case 'approved':
      return (color: Colors.green, label: 'Approved');
    case 'rejected':
      return (color: Colors.redAccent, label: 'Rejected');
    case 'under_review':
      return (color: Colors.orange, label: 'Under Review');
    default:
      return (color: AppColors.textGrey, label: 'Pending Review');
  }
}


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
  return Builder(
    builder: (context) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showPersonInfoSheet(context, name: name, roleLabel: roleLabel, email: email, phone: phone, idNumber: idNumber),
          child: Container(
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
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _passengersList({
  required List<String> names,
  List<String> idNumbers = const [],
  String email = '',
  String phone = '',
  String roleLabel = 'Passenger',
  String emptyMessage = 'No passenger details for this entry.',
}) {
  if (names.isEmpty && email.isEmpty && phone.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
        ),
      ),
    );
  }
  return ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (email.isNotEmpty || phone.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (email.isNotEmpty) Text('Contact Email: $email', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              if (email.isNotEmpty && phone.isNotEmpty) const SizedBox(height: 4),
              if (phone.isNotEmpty) Text('Contact Phone: $phone', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      for (int i = 0; i < names.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        Builder(
          builder: (context) {
            final personName = names[i].isEmpty ? '$roleLabel ${i + 1}' : names[i];
            final personId = i < idNumbers.length ? idNumbers[i] : '';
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showPersonInfoSheet(context, name: personName, roleLabel: roleLabel, email: email, phone: phone, idNumber: personId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9), child: Icon(Icons.person_outline, size: 16, color: AppColors.textGrey)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(personName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                          Text(roleLabel, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                          if (personId.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Passport/ID: $personId', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ],
  );
}

class HistoryFlightDetailPage extends StatefulWidget {
  final String routeCode;
  final String dateTime;
  final String price;
  final String bookingRef;
  final String status;
  final String bookingId;
  final Map<String, String> documents;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final DateTime? purchasedAt;

  const HistoryFlightDetailPage({
    super.key,
    required this.routeCode,
    required this.dateTime,
    required this.price,
    this.bookingRef = '',
    this.status = 'Confirmed',
    this.bookingId = '',
    this.documents = const {},
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.purchasedAt,
  });

  @override
  State<HistoryFlightDetailPage> createState() => _HistoryFlightDetailPageState();
}

class _HistoryFlightDetailPageState extends State<HistoryFlightDetailPage> {
  @override
  Widget build(BuildContext context) {
    return _HistoryDetailShell(
      title: 'Flight',
      tabs: const [
        PillTab('Detail', Icons.info_outline),
        PillTab('Passenger', Icons.people_outline),
      ],
      builders: [
        (_) => _infoCard('FLIGHT INFORMATION', [
              _field('Route', widget.routeCode),
              _field('Date & Time', widget.dateTime),
              _field('Price', widget.price),
              _field('Booking Reference', widget.bookingRef.isEmpty ? 'Not available' : widget.bookingRef),
              _field('Purchased On', widget.purchasedAt == null ? 'Not available' : _formatPurchasedAt(widget.purchasedAt)),
              _field('Status', widget.status, last: true),
            ]),
        (_) => _passengersList(
              names: _split(widget.guestName),
              idNumbers: _split(widget.guestIdNumber),
              email: widget.guestEmail,
              phone: widget.guestPhone,
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
  final DateTime? purchasedAt;

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
    this.purchasedAt,
  });

  @override
  State<HistoryHotelDetailPage> createState() => _HistoryHotelDetailPageState();
}

class _HistoryHotelDetailPageState extends State<HistoryHotelDetailPage> {
  @override
  Widget build(BuildContext context) {
    return _HistoryDetailShell(
      title: 'Hotel',
      tabs: const [
        PillTab('Detail', Icons.info_outline),
        PillTab('Guests', Icons.people_outline),
      ],
      builders: [
        (_) => _infoCard('HOTEL INFORMATION', [
              _field('Hotel Name', widget.name),
              _field('Location', widget.location),
              _field('Check-in', widget.checkIn.isEmpty ? 'Not available' : widget.checkIn),
              _field('Check-out', widget.checkOut.isEmpty ? 'Not available' : widget.checkOut),
              _field('Price / Night', widget.pricePerNight),
              _field('Booking Reference', widget.bookingRef.isEmpty ? 'Not available' : widget.bookingRef),
              _field('Purchased On', widget.purchasedAt == null ? 'Not available' : _formatPurchasedAt(widget.purchasedAt)),
              _field('Status', widget.status, last: true),
            ]),
        (_) => _peopleList(
              'Guest',
              name: widget.guestName,
              email: widget.guestEmail,
              phone: widget.guestPhone,
              idNumber: widget.guestIdNumber,
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
  final DateTime? purchasedAt;
  final String partnerId;
  final String providerName;
  final DateTime? travelStart;
  final DateTime? travelEnd;
  final String travellerIdNumber;
  final String travellerEmail;
  final String travellerPhone;

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
    this.purchasedAt,
    this.partnerId = '',
    this.providerName = '',
    this.travelStart,
    this.travelEnd,
    this.travellerIdNumber = '',
    this.travellerEmail = '',
    this.travellerPhone = '',
  });

  @override
  State<HistoryInsuranceDetailPage> createState() => _HistoryInsuranceDetailPageState();
}

class _HistoryInsuranceDetailPageState extends State<HistoryInsuranceDetailPage> {
  @override
  Widget build(BuildContext context) {
    return _HistoryDetailShell(
      title: 'Insurance',
      tabs: const [
        PillTab('Detail', Icons.info_outline),
        PillTab('Traveller', Icons.people_outline),
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
                      _field('Coverage Period', widget.travelStart == null || widget.travelEnd == null
                          ? 'Not available'
                          : '${_formatDateOnly(widget.travelStart!)} - ${_formatDateOnly(widget.travelEnd!)}'),
                      _field('Purchased On', widget.purchasedAt == null ? 'Not available' : _formatPurchasedAt(widget.purchasedAt)),
                      _field('Status', widget.status),
                      if (widget.transactionId.isNotEmpty) ...[
                        _requestStatusField(widget.transactionId, isRefund: true),
                        _requestStatusField(widget.transactionId, isRefund: false),
                      ],
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
                        child: StreamBuilder<List<ClaimOrRefundRecord>>(
                          stream: InsuranceRepository.instance.watchClaimsForTransaction(widget.transactionId),
                          builder: (context, snapshot) {
                            final submitted = (snapshot.data ?? const <ClaimOrRefundRecord>[]).isNotEmpty;
                            return OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              // Fail closed if the request state cannot be verified.
                              onPressed: (!snapshot.hasData || snapshot.hasError || submitted) ? null : () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => FileClaimPage(transactionId: widget.transactionId))),
                              icon: const Icon(Icons.assignment_outlined, size: 16, color: AppColors.primary),
                              label: Text(submitted ? 'Claim Submitted' : snapshot.hasError ? 'Claim Unavailable' : 'File a Claim',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StreamBuilder<List<ClaimOrRefundRecord>>(
                          stream: InsuranceRepository.instance.watchRefundsForTransaction(widget.transactionId),
                          builder: (context, snapshot) {
                            final existing = (snapshot.data ?? const <ClaimOrRefundRecord>[]).isNotEmpty;
                            return OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: (!snapshot.hasData || existing) ? null : () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => RequestRefundPage(transactionId: widget.transactionId))),
                              icon: const Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
                              label: Text(existing ? 'Refund Requested' : snapshot.hasError ? 'Refund Unavailable' : 'Request Refund',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                if (widget.partnerId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => InsuranceChatPage(
                                partnerId: widget.partnerId,
                                providerName: widget.providerName.isNotEmpty ? widget.providerName : 'Insurance Partner',
                                planName: widget.planName,
                              ))),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.primary),
                      label: const Text('Chat with Partner',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ),
                  ),
                ],
              ],
            ),
        (_) => _passengersList(
              names: _split(widget.travellerName),
              idNumbers: _split(widget.travellerIdNumber),
              email: widget.travellerEmail,
              phone: widget.travellerPhone,
              roleLabel: 'Traveller',
              emptyMessage: 'No traveller details for this entry.',
            ),
      ],
    );
  }
}
