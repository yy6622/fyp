import 'package:flutter/material.dart';

import '../../controllers/booking_payment_controller.dart';
import '../../models/booking_details.dart';
import '../../repositories/booking_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../services/stripe_service.dart';
import '../../theme.dart';

/// Everything collected at checkout that a paid-for flight/hotel needs once
/// it's added to a trip's plan — handed to [BookingBar.onPaid] so the detail
/// page that knows the rest of the flight/hotel data (airline, route, hotel
/// name/location, ...) can build a real `TripFlight`/`TripHotelStay` from
/// it, instead of this generic checkout page having to know about those
/// models itself.
///
/// All the passenger/guest fields below are collected one step earlier, on
/// [FlightPassengerDetailsPage]/[HotelGuestDetailsPage] — this page only
/// ever forwards what it was handed, plus the real [paymentRef] from the
/// Stripe charge that only it can produce.
class BookingConfirmation {
  // The real Stripe PaymentIntent id (see [StripeService.payWithSheet]) —
  // used as a genuine, transaction-linked booking reference.
  final String paymentRef;

  // Flight only — one full record per passenger (name, DOB, nationality,
  // passport number + expiry), length == quantity.
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
  });

  /// Back-compat convenience for any display code that just wants the
  /// plain list of passenger names (e.g. PlanFlightDetailPage's summary
  /// row) without caring about the rest of each passenger's record.
  List<String> get passengerNames => passengerDetails.map((p) => p.name).toList();
}

// ---------------------------------------------------------------------
// Flight/Hotel checkout — a real Stripe payment (sandbox: no actual money
// moves, but every charge genuinely goes through Stripe's own servers and
// its real Payment Sheet UI). Passenger/guest details and the seat/room
// quantity are collected one step earlier (FlightPassengerDetailsPage /
// HotelGuestDetailsPage, reached from [BookingBar]) — this page just shows
// the item + those details as a final review, then charges the card.
// ---------------------------------------------------------------------
class BookingPaymentPage extends StatefulWidget {
  final String itemTitle;
  final String itemSubtitle;
  // The real per-unit price, already parsed out of whatever formatted
  // string (e.g. "RM 592") the detail page was showing — see
  // [BookingBar]'s call site for how that's derived.
  final double unitPrice;
  final String currencyLabel;
  // 'per night' / 'Economy' / etc — shown under the unit price, same text
  // BookingBar itself used to show.
  final String unitSuffix;
  // 'flight' | 'hotel' — decides what [BookingRepository] files this
  // booking under and which details summary (Passenger vs Guest) is shown
  // below.
  final String bookingType;
  final String bookingTitle;
  final String bookingSubtitle;
  final String refId;
  // Seats (flight) / rooms (hotel) — fixed here, decided on the details
  // page one step earlier.
  final int quantity;

  // Flight details, collected on FlightPassengerDetailsPage.
  final List<PassengerDetail> passengerDetails;
  final String contactEmail;
  final String contactPhone;

  // Hotel details, collected on HotelGuestDetailsPage.
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;
  final DateTime? checkIn;
  final DateTime? checkOut;

  // The trip to auto-add this booking to once payment succeeds, and the
  // callback that does it (built by the detail page that knows the full
  // flight/hotel data) — see [BookingBar]. Blank/null when there's no
  // trip context, in which case paying just records History as before.
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

  /// Stripe needs the real ISO currency code (e.g. "myr"), but
  /// [BookingBar] hands this page the *display* label instead — which is
  /// the ISO code itself for every currency except MYR, where
  /// CurrencyService deliberately shows "RM" (what Malaysians actually
  /// call it) rather than the ISO code. That's the one special case to
  /// undo here; everything else is already the ISO code.
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
    setState(() => _paying = true);
    final String paymentRef;
    try {
      // The actual charge — Stripe's own Payment Sheet collects the card
      // and confirms the PaymentIntent the createPaymentIntent Cloud
      // Function created (see StripeService). Nothing is booked unless
      // this genuinely succeeds.
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
      try {
        await BookingRepository.instance.addBooking(
          uid: user.uid,
          type: widget.bookingType,
          title: widget.bookingTitle,
          subtitle: '${widget.bookingSubtitle}$qtyNote',
          trailing: '${widget.currencyLabel} ${controller.subtotal.toStringAsFixed(2)}',
          refId: widget.refId,
        );
      } catch (e) {
        // The Stripe charge itself already succeeded at this point — only
        // the follow-up Firestore write failed, so this says so rather
        // than implying the payment didn't go through.
        if (!mounted) return;
        setState(() => _paying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment succeeded, but saving the booking failed: $e')),
        );
        return;
      }
    }

    // Auto-add the paid flight/hotel to the trip it was booked for (see
    // BookingBar.onPaid) — best-effort: the charge and the booking-history
    // entry above already succeeded, so a failure here only means the trip
    // itself doesn't get this entry, not that the payment is in doubt.
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
