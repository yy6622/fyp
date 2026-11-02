import 'package:cloud_functions/cloud_functions.dart';
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
