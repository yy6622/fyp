import 'package:flutter/material.dart';

import '../../controllers/booking_payment_controller.dart';
import '../../models/booking_details.dart';
import '../../repositories/booking_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../services/stripe_service.dart';
import '../../theme.dart';
import '../../services/verification_service.dart';
import '../auth/otp_verification_page.dart';

class BookingConfirmation {
  final String paymentRef;

  final List<PassengerDetail> passengerDetails;
  final String contactEmail;
  final String contactPhone;

  // Hotel only.
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  final DateTime? checkIn;
  final DateTime? checkOut;

  final List<String> forMemberUids;

  const BookingConfirmation({
    required this.paymentRef,
    this.passengerDetails = const [],
    this.contactEmail = '',
    this.contactPhone = '',
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.specialRequests = '',
    this.checkIn,
    this.checkOut,
    this.forMemberUids = const [],
  });

  List<String> get passengerNames => passengerDetails.map((p) => p.name).toList();
}

class BookingPaymentPage extends StatefulWidget {
  final String itemTitle;
  final String itemSubtitle;
  final double unitPrice;
  final String currencyLabel;
  final String unitSuffix;
  final String bookingType;
  final String bookingTitle;
  final String bookingSubtitle;
  final String refId;
  final int quantity;

  final List<PassengerDetail> passengerDetails;
  final String contactEmail;
  final String contactPhone;

  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  final DateTime? checkIn;
  final DateTime? checkOut;

  final List<String> forMemberUids;

  final String tripId;
  final Future<void> Function(BookingConfirmation confirmation)? onPaid;

  const BookingPaymentPage({
    super.key,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.unitPrice,
    required this.currencyLabel,
    required this.unitSuffix,
    required this.bookingType,
    required this.bookingTitle,
    required this.bookingSubtitle,
    this.refId = '',
    this.quantity = 1,
    this.passengerDetails = const [],
    this.contactEmail = '',
    this.contactPhone = '',
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.specialRequests = '',
    this.checkIn,
    this.checkOut,
    this.forMemberUids = const [],
    this.tripId = '',
    this.onPaid,
  });

  @override
  State<BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends State<BookingPaymentPage> {
  late final BookingPaymentController controller = BookingPaymentController(
    unitPrice: widget.unitPrice,
    initialQuantity: widget.quantity,
    minQuantity: widget.quantity,
    maxQuantity: widget.quantity,
  );
  bool _paying = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get _isoCurrency => widget.currencyLabel.toUpperCase() == 'RM' ? 'myr' : widget.currencyLabel.toLowerCase();

  String get _quantityLabel {
    switch (widget.bookingType) {
      case 'flight':
        return 'Passengers';
      case 'hotel':
        return 'Rooms';
      default:
        return 'Quantity';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Payment', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.itemTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                  const SizedBox(height: 2),
                                  Text(widget.itemSubtitle,
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${widget.currencyLabel} ${widget.unitPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                Text(widget.unitSuffix, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFECECEC)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_quantityLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                            Text('${controller.quantity}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.bookingType == 'flight') ...[
                    const SizedBox(height: 24),
                    _passengerSummarySection(),
                  ],
                  if (widget.bookingType == 'hotel') ...[
                    const SizedBox(height: 24),
                    _guestSummarySection(),
                  ],
                  const SizedBox(height: 24),
                  const Text('Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 4),
                  _summaryRow('${widget.currencyLabel} ${widget.unitPrice.toStringAsFixed(0)} × ${controller.quantity}',
                      '${widget.currencyLabel} ${controller.subtotal.toStringAsFixed(2)}'),
                  _summaryRow('Service Fee', '${widget.currencyLabel} 0.00'),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFECECEC)),
                  _summaryRow('Total Amount', '${widget.currencyLabel} ${controller.subtotal.toStringAsFixed(2)}', bold: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _paying ? null : _confirmPayment,
                  child: _paying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text('Pay ${widget.currencyLabel} ${controller.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passengerSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Passenger Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
          for (int i = 0; i < widget.passengerDetails.length; i++) ...[
            const SizedBox(height: 10),
            Text('Passenger ${i + 1}: ${widget.passengerDetails[i].name}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
            Text(
              'Passport ${widget.passengerDetails[i].passportNumber} · ${widget.passengerDetails[i].nationality ?? '—'}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
            ),
          ],
          const SizedBox(height: 10),
          Text('Contact: ${widget.contactEmail} · ${widget.contactPhone}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _guestSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Guest Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 10),
          Text(widget.guestName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
          Text('${widget.guestEmail} · ${widget.guestPhone}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
          Text('ID/Passport: ${widget.guestIdNumber}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
          if (widget.specialRequests.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Request: ${widget.specialRequests}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
          ],
          const SizedBox(height: 10),
          if (widget.checkIn != null && widget.checkOut != null)
            Text('${formatLongDate(widget.checkIn!)} → ${formatLongDate(widget.checkOut!)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? AppColors.navy : AppColors.textGrey,
              )),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 17 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: bold ? AppColors.primary : Colors.black87,
              )),
        ],
      ),
    );
  }

  Future<void> _confirmPayment() async {
    final user = AuthService.instance.currentUser;
    // FR04 step-up: a payment needs the 6-digit code emailed to the traveller.
    if (!await confirmWithEmailCode(context, CodePurpose.payment)) return;
    if (!mounted) return;
    setState(() => _paying = true);
    final String paymentRef;
    try {
      paymentRef = await StripeService.instance.payWithSheet(
        amount: controller.subtotal,
        currencyCode: _isoCurrency,
        merchantDisplayName: 'Voya',
        customerEmail: user?.email,
      );
    } on StripePaymentException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      if (e.message != 'Payment cancelled.') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }

    if (user != null) {
      final qtyNote = controller.quantity > 1 ? ' · ${controller.quantity} $_quantityLabel' : '';
      final isFlight = widget.bookingType == 'flight';
      final guestName = isFlight ? widget.passengerDetails.map((p) => p.name).where((n) => n.isNotEmpty).join(', ') : widget.guestName;
      final guestEmail = isFlight ? widget.contactEmail : widget.guestEmail;
      final guestPhone = isFlight ? widget.contactPhone : widget.guestPhone;
      final guestIdNumber = isFlight
          ? widget.passengerDetails.map((p) => p.passportNumber).where((n) => n.isNotEmpty).join(', ')
          : widget.guestIdNumber;
      try {
        await BookingRepository.instance.addBooking(
          uid: user.uid,
          type: widget.bookingType,
          title: widget.bookingTitle,
          subtitle: '${widget.bookingSubtitle}$qtyNote',
          trailing: '${widget.currencyLabel} ${controller.subtotal.toStringAsFixed(2)}',
          refId: widget.refId,
          bookingRef: paymentRef,
          status: 'Confirmed',
          guestName: guestName,
          guestEmail: guestEmail,
          guestPhone: guestPhone,
          guestIdNumber: guestIdNumber,
          specialRequests: widget.specialRequests,
          checkIn: widget.checkIn != null ? formatLongDate(widget.checkIn!) : '',
          checkOut: widget.checkOut != null ? formatLongDate(widget.checkOut!) : '',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _paying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment succeeded, but saving the booking failed: $e')),
        );
        return;
      }
    }

    try {
      await widget.onPaid?.call(BookingConfirmation(
        paymentRef: paymentRef,
        passengerDetails: widget.passengerDetails,
        contactEmail: widget.contactEmail,
        contactPhone: widget.contactPhone,
        guestName: widget.guestName,
        guestEmail: widget.guestEmail,
        guestPhone: widget.guestPhone,
        guestIdNumber: widget.guestIdNumber,
        specialRequests: widget.specialRequests,
        checkIn: widget.checkIn,
        checkOut: widget.checkOut,
        forMemberUids: widget.forMemberUids,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment succeeded, but adding it to your plan failed: $e')),
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
