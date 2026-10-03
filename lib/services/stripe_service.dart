import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Thrown when a Stripe checkout is cancelled or fails — callers show
/// whatever message makes sense for where they are (see
/// [BookingPaymentPage]'s `_confirmPayment`).
class StripePaymentException implements Exception {
  final String message;
  const StripePaymentException(this.message);
  @override
  String toString() => message;
}

/// Drives a real Stripe payment (test/sandbox mode): asks the
/// `createPaymentIntent` Cloud Function (functions/index.js) for a
/// PaymentIntent — the one step that needs the secret key, which is why
/// it happens server-side, not here — then presents Stripe's own native
/// Payment Sheet to actually collect card details and confirm the charge.
/// Nothing here ever sees a card number; Stripe's SDK handles that
/// directly, which is the whole reason to use the Payment Sheet instead of
/// a hand-rolled card form.
class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  /// [amount] is in the currency's *major* unit (e.g. 592.00 for RM592),
  /// matching how the rest of this app already stores/displays prices —
  /// converted to the minor unit (sen/cents) Stripe's API actually expects
  /// before it's sent. Returns the real Stripe PaymentIntent id (the
  /// `pi_...` part of the client secret) once the charge actually goes
  /// through — callers use it as a genuine, transaction-linked booking
  /// reference (see BookingPaymentPage) instead of inventing one.
  Future<String> payWithSheet({
    required double amount,
    required String currencyCode,
    required String merchantDisplayName,
    String? customerEmail,
  }) async {
    final Map<String, dynamic> data;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      // Called without a generic type param and cast manually afterward —
      // the platform channel hands back a plain Map (not necessarily typed
      // exactly as Map<String, dynamic>), so forcing that type through
      // call<T>() itself risks a cast failure inside the plugin; casting
      // the already-received value is the safer order.
      final result = await callable.call({
        'amount': (amount * 100).round(),
        'currency': currencyCode.toLowerCase(),
        if (customerEmail != null && customerEmail.isNotEmpty) 'receiptEmail': customerEmail,
      });
      data = (result.data as Map).cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      throw StripePaymentException(e.message ?? 'Could not start the payment (${e.code}).');
    } catch (e) {
      throw StripePaymentException('Could not reach the payment server: $e');
    }

    final clientSecret = data['clientSecret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw const StripePaymentException('Payment server did not return a client secret.');
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          // Test mode only — Stripe.publishableKey (set at app startup,
          // see main.dart) is itself the pk_test_... key, so every charge
          // made through this sheet is already a sandbox charge with no
          // real money moving, independent of this flag.
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // clientSecret is always "pi_XXXX_secret_YYYY" — the part before
      // "_secret_" is the PaymentIntent's own real id (confirmed against
      // Stripe's own client-secret format docs).
      return clientSecret.split('_secret_').first;
    } on StripeException catch (e) {
      // Matched by message text rather than a specific FailureCode enum
      // member — flutter_stripe's exact enum values differ across major
      // versions, and guessing wrong here would be a compile-time error,
      // not just a wrong message, so this sticks to what the package's own
      // docs confirm exists: StripeException.error.localizedMessage.
      final message = e.error.localizedMessage ?? 'Payment failed.';
      if (message.toLowerCase().contains('cancel')) {
        throw const StripePaymentException('Payment cancelled.');
      }
      throw StripePaymentException(message);
    }
  }
}
