import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_stripe/flutter_stripe.dart';

class StripePaymentException implements Exception {
  final String message;
  const StripePaymentException(this.message);
  @override
  String toString() => message;
}

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  Future<String> payWithSheet({
    required double amount,
    required String currencyCode,
    required String merchantDisplayName,
    String? customerEmail,
  }) async {
    final Map<String, dynamic> data;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final result = await callable.call({
        'amount': (amount * 100).round(),
        'currency': currencyCode.toLowerCase(),
        if (customerEmail != null && customerEmail.isNotEmpty) 'receiptEmail': customerEmail,
      });
      data = (result.data as Map).cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      throw StripePaymentException(e.message ?? 'Could not start the payment (${e.code}).');
    } catch (e) {
      debugPrint('[StripeService] payment server unreachable: $e');
      throw const StripePaymentException('Could not reach the payment server. Check your connection and try again.');
    }

    final clientSecret = data['clientSecret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw const StripePaymentException('Payment server did not return a client secret.');
    }

    // TEMP TEST BYPASS (web only): flutter_stripe has no web implementation
    // of the PaymentSheet API -- Stripe's own docs mark Flutter Web support
    // as "highly experimental" and list PaymentSheet as unsupported there
    // (only native iOS/Android render it). Calling initPaymentSheet on web
    // throws an uncaught StripeConfigException and the Pay button spins
    // forever. Until a real web card-entry flow is built (CardField /
    // PaymentElement + confirmPayment), skip presenting the Stripe sheet on
    // web so the rest of the purchase pipeline below this method
    // (recordPurchase -> addBooking -> History) can still be exercised
    // end-to-end during testing. The PaymentIntent above was still created
    // for real against Stripe's test server; this only skips the card UI.
    // Native iOS/Android are unaffected and still use the real PaymentSheet.
    if (kIsWeb) {
      return clientSecret.split('_secret_').first;
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return clientSecret.split('_secret_').first;
    } on StripeException catch (e) {
      final message = e.error.localizedMessage ?? 'Payment failed.';
      if (message.toLowerCase().contains('cancel')) {
        throw const StripePaymentException('Payment cancelled.');
      }
      throw StripePaymentException(message);
    }
  }
}
