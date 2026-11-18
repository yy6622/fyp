import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../views/payment/paypal_checkout_page.dart';

class PayPalPaymentException implements Exception {
  final String message;
  const PayPalPaymentException(this.message);
  @override
  String toString() => message;
}

class PayPalService {
  PayPalService._();
  static final PayPalService instance = PayPalService._();

  Future<String> payWithPayPal(
    BuildContext context, {
    required double amount,
    required String currencyCode,
  }) async {
    final Map<String, dynamic> data;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createPaypalOrder');
      final result = await callable.call({
        'amount': amount,
        'currency': currencyCode.toUpperCase(),
      });
      data = (result.data as Map).cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      throw PayPalPaymentException(e.message ?? 'Could not start the payment (${e.code}).');
    } catch (e) {
      debugPrint('[PayPalService] payment server unreachable: $e');
      throw const PayPalPaymentException('Could not reach the payment server. Check your connection and try again.');
    }

    final orderId = data['orderId'] as String?;
    final approveUrl = data['approveUrl'] as String?;
    if (orderId == null || orderId.isEmpty || approveUrl == null || approveUrl.isEmpty) {
      throw const PayPalPaymentException('Payment server did not return a PayPal approval link.');
    }

    if (!context.mounted) {
      throw const PayPalPaymentException('Payment cancelled.');
    }
    final approved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PayPalCheckoutPage(approveUrl: approveUrl)),
    );
    if (approved != true) {
      throw const PayPalPaymentException('Payment cancelled.');
    }

    try {
      final captureCallable = FirebaseFunctions.instance.httpsCallable('capturePaypalOrder');
      final captureResult = await captureCallable.call({'orderId': orderId});
      final captureData = (captureResult.data as Map).cast<String, dynamic>();
      final captureId = captureData['captureId'] as String?;
      if (captureId == null || captureId.isEmpty) {
        throw const PayPalPaymentException('PayPal did not return a capture reference.');
      }
      return captureId;
    } on FirebaseFunctionsException catch (e) {
      throw PayPalPaymentException(e.message ?? 'Could not confirm the PayPal payment (${e.code}).');
    }
  }
}
