import 'package:flutter/material.dart';

import '../../controllers/insurance_controller.dart';
import '../../models/insurance_models.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/insurance_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/stripe_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import 'insurance_widgets.dart';
import '../../services/verification_service.dart';
import '../auth/otp_verification_page.dart';

class PaymentMethodPage extends StatefulWidget {
  final InsurancePlan plan;
  final int travellerCount;
  final String? tripId;
  final DateTime travelStart;
  final DateTime travelEnd;
  const PaymentMethodPage({
    super.key,
    required this.plan,
    required this.travellerCount,
    this.tripId,
    required this.travelStart,
    required this.travelEnd,
  });

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  late final PaymentMethodController controller =
      PaymentMethodController(plan: widget.plan, travellerCount: widget.travellerCount);
  bool _paying = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Insurance', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    child: Row(
                      children: [
                        insuranceLogo(widget.plan),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.plan.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                              const SizedBox(height: 2),
                              const Text('Basic Travel Cover', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                        Text(widget.plan.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 4),
                  const Text('Paid securely by card via Stripe — tap "Pay" below to enter your card details.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card, color: AppColors.primary, size: 20),
                        SizedBox(width: 12),
                        Expanded(child: Text('Credit / Debit Card', style: TextStyle(fontSize: 13.5, color: Colors.black))),
                        Icon(Icons.lock_outline, size: 16, color: AppColors.textGrey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 4),
                  _summaryRow('Subtotal', 'RM ${controller.subtotal.toStringAsFixed(2)}'),
                  _summaryRow('Discount (0%)', 'RM 0.00', color: Colors.green),
                  _summaryRow('Service Fee', 'RM 0.00'),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFECECEC)),
                  _summaryRow('Total Amount', 'RM ${controller.subtotal.toStringAsFixed(2)}', bold: true),
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Pay RM ${controller.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPayment() async {
    final user = AuthService.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    // FR04 step-up: a payment needs the 6-digit code emailed to the traveller.
    if (!await confirmWithEmailCode(context, CodePurpose.payment)) return;
    if (!mounted) return;
    setState(() => _paying = true);

    final String paymentRef;
    try {
      paymentRef = await StripeService.instance.payWithSheet(
        amount: controller.subtotal,
        currencyCode: 'myr',
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

    try {
      final policyNumber = 'INS-$paymentRef';
      String purchaseDestination = '';
      if (widget.tripId != null && widget.tripId!.isNotEmpty) {
        final trip = await TripRepository.instance.getTrip(widget.tripId!, uid);
        purchaseDestination = trip?.destination ?? '';
      }
      final transactionId = await InsuranceRepository.instance.recordPurchase(
        plan: widget.plan,
        buyerId: uid,
        customerName: user?.displayName?.trim().isNotEmpty == true ? user!.displayName!.trim() : (user?.email ?? 'Voya user'),
        customerEmail: user?.email ?? '',
        premium: controller.subtotal,
        travelStart: widget.travelStart,
        travelEnd: widget.travelEnd,
        destination: purchaseDestination,
      );
      await BookingRepository.instance.addBooking(
        uid: uid,
        type: 'insurance',
        title: widget.plan.name,
        subtitle: 'Policy #$policyNumber',
        trailing: 'RM ${controller.subtotal.toStringAsFixed(2)}',
        bookingRef: paymentRef,
        status: 'Confirmed',
        coverage: widget.plan.coverage,
        transactionId: transactionId,
      );
      if (widget.tripId != null && widget.tripId!.isNotEmpty) {
        await TripRepository.instance.setInsurance(
          widget.tripId!,
          TripInsurance(
            planName: widget.plan.name,
            coverage: widget.plan.coverage,
            price: 'RM ${controller.subtotal.toStringAsFixed(2)}',
            policyNumber: policyNumber,
            transactionId: transactionId,
          ),
          actorUid: uid,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment succeeded, but saving the policy failed: $e')),
      );
      return;
    }
    if (!mounted) return;
    showNiceInfoDialog(
      context: context,
      title: 'Payment Successful',
      message: 'Your ${widget.plan.name} plan for ${widget.travellerCount} traveller(s) is confirmed. '
          'A copy of your policy has been sent to your email.',
      onDone: () => Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
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
                color: color ?? (bold ? AppColors.primary : Colors.black87),
              )),
        ],
      ),
    );
  }
}
