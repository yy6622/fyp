import 'package:flutter/material.dart';

class BookingPaymentController extends ChangeNotifier {
  final double unitPrice;
  final int minQuantity;
  final int maxQuantity;

  /// True when [unitPrice] is already the FULL price for every unit of
  /// [quantity] combined (a Duffel flight offer's total_amount is already
  /// the price for every passenger and every leg of the trip -- it is not
  /// a true per-passenger price). In that case [quantity] is for display
  /// only ("2 Passengers") and must NOT multiply into the charge, or the
  /// traveller is charged double (and triple, quadruple...) what the
  /// flight actually costs. Hotels (and anything else with a genuine
  /// per-unit price, e.g. per room per night) leave this false, which
  /// keeps the original unitPrice * quantity behaviour.
  final bool priceIsTotal;

  BookingPaymentController({
    required this.unitPrice,
    int initialQuantity = 1,
    this.minQuantity = 1,
    this.maxQuantity = 9,
    this.priceIsTotal = false,
  }) : _quantity = initialQuantity.clamp(minQuantity, maxQuantity);

  int _quantity;
  int get quantity => _quantity;
  void setQuantity(int value) {
    final clamped = value.clamp(minQuantity, maxQuantity);
    if (clamped == _quantity) return;
    _quantity = clamped;
    notifyListeners();
  }

  double get subtotal => priceIsTotal ? unitPrice : unitPrice * _quantity;

  /// Flat default service fee added on top of the subtotal.
  static const double serviceFee = 2.0;
  double get total => subtotal + serviceFee;
}
