import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../controllers/insurance_controller.dart';
import '../../models/insurance_models.dart';
import '../../repositories/insurance_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/paypal_service.dart';
import '../../services/stripe_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import '../payment/payment_method_picker.dart';
import 'insurance_widgets.dart';

class PaymentMethodPage extends StatefulWidget {
  final InsurancePlan plan;
  final int travellerCount;
  final List<TravellerData> travellers;
  final String? tripId;
  final DateTime travelStart;
  final DateTime travelEnd;
  const PaymentMethodPage({
    super.key,
    required this.plan,
    required this.travellerCount,
    this.travellers = const [],
    this.tripId,
    required this.travelStart,
    required this.travelEnd,
  });

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  late final PaymentMethodController controller = PaymentMethodController(
    plan: widget.plan,
    travellerCount: widget.travellerCount,
    travelStart: widget.travelStart,
    travelEnd: widget.travelEnd,
    userCurrency: CurrencyService.instance.lastKnownUserCurrency,
  );
  bool _paying = false;
  PaymentMethodOption _method = PaymentMethodOption.card;

  String get _currencyLabel => CurrencyService.instance.displayLabel(controller.chargeCurrencyCode);

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(widget.plan.displayPrice(controller.userCurrency), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            Text(insurancePriceUnitLabel(widget.plan.category),
                                style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 12),
                  PaymentMethodPicker(
                    value: _method,
                    onChanged: (v) => setState(() => _method = v),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 4),
                  _summaryRow(
                    insuranceCategoryPricesByDay(widget.plan.category)
                        ? '$_currencyLabel ${controller.unitPrice.toStringAsFixed(2)}/day × ${controller.coverageDays} day(s) × ${widget.travellerCount} traveller(s)'
                        : '$_currencyLabel ${controller.unitPrice.toStringAsFixed(2)} × ${widget.travellerCount} traveller(s)',
                    '$_currencyLabel ${controller.subtotal.toStringAsFixed(2)}',
                  ),
                  _summaryRow('Service Fee', '$_currencyLabel ${controller.serviceFeeConverted.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFECECEC)),
                  _summaryRow('Total Amount', '$_currencyLabel ${controller.total.toStringAsFixed(2)}', bold: true),
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
                      : Text('Pay $_currencyLabel ${controller.total.toStringAsFixed(2)}',
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

    setState(() => _paying = true);

    final String paymentRef;
    try {
      paymentRef = _method == PaymentMethodOption.paypal
          ? await PayPalService.instance.payWithPayPal(
              context,
              amount: controller.total,
              currencyCode: controller.chargeCurrencyCode.toLowerCase(),
            )
          : await StripeService.instance.payWithSheet(
              amount: controller.total,
              currencyCode: controller.chargeCurrencyCode.toLowerCase(),
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

    final policyNumber = 'INS-$paymentRef';
    // user.displayName only ever gets set by Firebase Auth itself for a
    // Google sign-in -- an email/password signup never calls
    // updateDisplayName, so it's always empty for those accounts. Reading
    // it here meant the admin's "Customer" column showed a real name for
    // some rows and a bare email for others depending on how that one
    // traveller happened to sign up. The traveller's own profile name
    // (set at signup for every sign-in method -- see UserRepository) is
    // the one source that's actually always there.
    String? profileName;
    try {
      profileName = (await UserRepository.instance.fetchProfile(uid))?.name.trim();
    } catch (_) {
      profileName = null;
    }
    final customerName = (profileName?.isNotEmpty ?? false)
        ? profileName!
        : (user?.displayName?.trim().isNotEmpty == true ? user!.displayName!.trim() : (user?.email ?? 'Voya user'));
    // The buyer's own account name/email stays the transaction's
    // customerName (who can file a claim/refund). The actual insured
    // traveller(s) — collected on TravellerDetailsPage and otherwise
    // discarded after travellerCount is read off them — are what the
    // booking's History page should show, same as a flight booking shows
    // each passenger rather than just whoever paid.
    final travellerNames = widget.travellers.map((t) => t.name.trim()).where((n) => n.isNotEmpty).join(', ');
    final travellerIdNumbers = widget.travellers.map((t) => t.identityNumber.trim()).where((n) => n.isNotEmpty).join(', ');
    final leadTravellerEmail = widget.travellers.isNotEmpty ? widget.travellers.first.email.trim() : '';
    final leadTravellerPhone = widget.travellers.isNotEmpty ? widget.travellers.first.phone.trim() : '';
    String purchaseDestination = '';
    try {
      if (widget.tripId != null && widget.tripId!.isNotEmpty) {
        final trip = await TripRepository.instance.getTrip(widget.tripId!, uid);
        purchaseDestination = trip?.destination ?? '';
      }
      // Single write: insurance_transactions is now the only place a
      // purchase is stored (it used to also be mirrored into
      // users/{uid}/bookings purely so the History page had somewhere
      // to read guest details from -- HistoryController now reads
      // straight from InsuranceRepository.watchTransactionsForBuyer()
      // instead, so the traveller fields have to be recorded here).
      final transactionId = await InsuranceRepository.instance.recordPurchase(
        plan: widget.plan,
        buyerId: uid,
        customerName: customerName,
        customerEmail: user?.email ?? '',
        premium: controller.subtotal,
        currencyCode: controller.chargeCurrencyCode,
        travelStart: widget.travelStart,
        travelEnd: widget.travelEnd,
        destination: purchaseDestination,
        policyNumber: policyNumber,
        coverage: widget.plan.coverage,
        travellerName: travellerNames.isNotEmpty ? travellerNames : customerName,
        travellerIdNumber: travellerIdNumbers,
        travellerEmail: leadTravellerEmail,
        travellerPhone: leadTravellerPhone,
      );
      if (widget.tripId != null && widget.tripId!.isNotEmpty) {
        await TripRepository.instance.setInsurance(
          widget.tripId!,
          TripInsurance(
            planName: widget.plan.name,
            coverage: widget.plan.coverage,
            price: '$_currencyLabel ${controller.subtotal.toStringAsFixed(2)}',
            policyNumber: policyNumber,
            transactionId: transactionId,
            travellerName: travellerNames.isNotEmpty ? travellerNames : customerName,
            travellerIdNumber: travellerIdNumbers,
            travellerEmail: leadTravellerEmail,
            travellerPhone: leadTravellerPhone,
            purchasedAt: DateTime.now(),
            partnerId: widget.plan.partnerId,
            providerName: widget.plan.provider,
            travelStart: widget.travelStart,
            travelEnd: widget.travelEnd,
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
    bool emailSent = false;
    try {
      await FirebaseFunctions.instance.httpsCallable('sendPolicyEmail').call({
        'planName': widget.plan.name,
        'provider': widget.plan.provider,
        'policyNumber': policyNumber,
        'travellerCount': widget.travellerCount,
        'premium': controller.subtotal,
        'destination': purchaseDestination,
        'travelStart': widget.travelStart.toIso8601String(),
        'travelEnd': widget.travelEnd.toIso8601String(),
      });
      emailSent = true;
    } catch (e) {
      // Best-effort only: the purchase already succeeded above, so a failed
      // email send should never block the user or roll anything back.
      emailSent = false;
    }

    if (!mounted) return;
    showNiceInfoDialog(
      context: context,
      title: 'Payment Successful',
      message: 'Your ${widget.plan.name} plan for ${widget.travellerCount} traveller(s) is confirmed. '
          '${emailSent ? 'A copy of your policy has been sent to your email.' : 'We could not send a copy to your email right now, but your policy is saved under My Bookings.'}',
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
