import 'package:flutter/material.dart';

import '../../controllers/booking_payment_controller.dart';
import '../../models/booking_details.dart';
import '../../models/duffel_models.dart';
import '../../repositories/booking_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../services/duffel_api_service.dart';
import '../../services/paypal_service.dart';
import '../../services/stripe_service.dart';
import '../../theme.dart';
import '../payment/payment_method_picker.dart';

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
  /// See [BookingPaymentController.priceIsTotal]: true for flights,
  /// because [unitPrice] there is already the Duffel offer's full
  /// total for every passenger and leg, not a per-passenger price.
  final bool priceIsTotal;
  final List<DuffelOfferPassenger> offerPassengers;
  final double offerTotalAmount;
  final String offerTotalCurrency;

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

  // Flight-only -- the full itinerary shown before payment (see
  // _flightSummarySection below), not just itemTitle/itemSubtitle's
  // thin "KUL -> TFU" / "22 Nov 18:45".
  final String? fromCode;
  final String? fromCity;
  final String? toCode;
  final String? toCity;
  final String? flightDate;
  final String? depTime;
  final String? arrTime;
  final String? duration;
  final String? stops;
  final String? airline;
  final String? airlineLogoUrl;
  final String? cabinClass;

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
    this.priceIsTotal = false,
    this.offerPassengers = const [],
    this.offerTotalAmount = 0,
    this.offerTotalCurrency = '',
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
    this.fromCode,
    this.fromCity,
    this.toCode,
    this.toCity,
    this.flightDate,
    this.depTime,
    this.arrTime,
    this.duration,
    this.stops,
    this.airline,
    this.airlineLogoUrl,
    this.cabinClass,
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
    priceIsTotal: widget.priceIsTotal,
  );
  bool _paying = false;
  PaymentMethodOption _method = PaymentMethodOption.card;

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
        centerTitle: true,
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
                    _flightSummarySection(),
                    const SizedBox(height: 24),
                    _passengerSummarySection(),
                  ],
                  if (widget.bookingType == 'hotel') ...[
                    const SizedBox(height: 24),
                    _staySummarySection(),
                    const SizedBox(height: 24),
                    _guestSummarySection(),
                  ],
                  const SizedBox(height: 24),
                  const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 10),
                  PaymentMethodPicker(
                    value: _method,
                    onChanged: (v) => setState(() => _method = v),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 4),
                  _summaryRow(
                      widget.priceIsTotal
                          ? '${widget.currencyLabel} ${widget.unitPrice.toStringAsFixed(0)} (${controller.quantity} ${_quantityLabel.toLowerCase()})'
                          : '${widget.currencyLabel} ${widget.unitPrice.toStringAsFixed(0)} × ${controller.quantity}',
                      '${widget.currencyLabel} ${controller.subtotal.toStringAsFixed(2)}'),
                  _summaryRow('Service Fee', '${widget.currencyLabel} ${BookingPaymentController.serviceFee.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFECECEC)),
                  _summaryRow('Total Amount', '${widget.currencyLabel} ${controller.total.toStringAsFixed(2)}', bold: true),
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
                      : Text('Pay ${widget.currencyLabel} ${controller.total.toStringAsFixed(2)}',
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
        ],
      ),
    );
  }

  Widget _staySummarySection() {
    final checkIn = widget.checkIn;
    final checkOut = widget.checkOut;
    final nights = (checkIn != null && checkOut != null) ? checkOut.difference(checkIn).inDays : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stay Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 12),
          if (checkIn != null && checkOut != null) ...[
            Row(
              children: [
                Expanded(
                  child: _stayDateColumn('Check-in', checkIn),
                ),
                const Icon(Icons.arrow_forward, size: 16, color: AppColors.textGrey),
                Expanded(
                  child: _stayDateColumn('Check-out', checkOut, alignEnd: true),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (nights != null)
                Text(nights == 1 ? '1 night' : '$nights nights', style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              Text(_quantityLabel == 'Rooms' ? '${controller.quantity} ${controller.quantity == 1 ? 'room' : 'rooms'}' : '',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stayDateColumn(String label, DateTime date, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        const SizedBox(height: 2),
        Text(formatLongDate(date), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
      ],
    );
  }

  Widget _flightSummarySection() {
    final hasRoute = (widget.fromCode ?? '').isNotEmpty && (widget.toCode ?? '').isNotEmpty;
    if (!hasRoute) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Flight Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              if ((widget.cabinClass ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.cabinClass!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                ),
            ],
          ),
          if ((widget.flightDate ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.flightDate!, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.depTime ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    Text('${widget.fromCode ?? ''}${(widget.fromCity ?? '').isNotEmpty ? ' · ${widget.fromCity}' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    if ((widget.duration ?? '').isNotEmpty)
                      Text(widget.duration!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Icon(Icons.arrow_forward, size: 15, color: AppColors.textGrey),
                    ),
                    Text((widget.stops ?? '').isNotEmpty ? widget.stops! : 'Direct flight',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(widget.arrTime ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    Text('${widget.toCode ?? ''}${(widget.toCity ?? '').isNotEmpty ? ' · ${widget.toCity}' : ''}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  ],
                ),
              ),
            ],
          ),
          if ((widget.airline ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFDDDDDD)),
            const SizedBox(height: 10),
            Row(
              children: [
                if ((widget.airlineLogoUrl ?? '').isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(widget.airlineLogoUrl!, width: 20, height: 20, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(widget.airline!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
              ],
            ),
          ],
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
    if (user == null) {
      // Stop here, BEFORE any money moves or a real Duffel order is
      // created -- continuing would charge the traveller and book a real
      // flight/hotel with nowhere to save the record, which is exactly
      // what "Duffel has it, Firebase doesn't, no message" looks like.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You've been signed out. Please sign in again and retry this booking.")),
      );
      return;
    }
    setState(() => _paying = true);
    final String paymentRef;
    try {
      paymentRef = _method == PaymentMethodOption.paypal
          ? await PayPalService.instance.payWithPayPal(
              context,
              amount: controller.total,
              currencyCode: _isoCurrency,
            )
          : await StripeService.instance.payWithSheet(
              amount: controller.total,
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
    } on PayPalPaymentException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      if (e.message != 'Payment cancelled.') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }

    // A real Duffel order only ever succeeds against Duffel's own test
    // airline ("Duffel Airways", IATA code ZZ) -- for any real-world
    // airline (Malaysia Airlines, etc.) a `duffel_test_...` key always
    // fails order creation with a generic "internal_error", since that
    // would require actually ticketing with that airline's live system.
    // So this only attempts createOrder for a Duffel Airways offer
    // (identifiable by its airline name, same as Duffel's own test-mode
    // docs identify it by owner.iata_code == 'ZZ' / owner.name ==
    // "Duffel Airways"); every other flight, and every hotel, keeps going
    // straight to the Firestore-only booking exactly as before. If this
    // DOES fail even for a Duffel Airways offer (e.g. no network), it
    // still falls back to the Firestore-only booking rather than losing
    // a payment that has already gone through.
    var providerName = '';
    var externalOrderId = '';
    final isDuffelTestAirline = widget.bookingType == 'flight' && widget.airline?.trim().toLowerCase() == 'duffel airways';
    if (isDuffelTestAirline) {
      try {
        final orderId = await DuffelApiService.instance.createOrder(
          offerId: widget.refId,
          offerPassengers: widget.offerPassengers,
          passengerDetails: widget.passengerDetails,
          totalAmount: widget.offerTotalAmount,
          totalCurrency: widget.offerTotalCurrency,
          contactEmail: widget.contactEmail,
          contactPhone: widget.contactPhone,
        );
        if (orderId.isNotEmpty) {
          providerName = 'Duffel';
          externalOrderId = orderId;
        }
      } catch (_) {
        // Fall back to Firestore-only below -- the payment already went
        // through, so this must never block the booking from being saved.
      }
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
          providerName: providerName,
          externalOrderId: externalOrderId,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.bookingType == 'flight'
            ? 'Payment successful! Your flight is booked.'
            : 'Payment successful! Your booking is confirmed.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
