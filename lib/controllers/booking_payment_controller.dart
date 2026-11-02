import 'package:flutter/material.dart';

class BookingPaymentController extends ChangeNotifier {
  final double unitPrice;
  final int minQuantity;
  final int maxQuantity;

  BookingPaymentController({
    required this.unitPrice,
    int initialQuantity = 1,
    this.minQuantity = 1,
    this.maxQuantity = 9,
  }) : _quantity = initialQuantity.clamp(minQuantity, maxQuantity);

  int _quantity;
  int get quantity => _quantity;
  void setQuantity(int value) {
    final clamped = value.clamp(minQuantity, maxQuantity);
    if (clamped == _quantity) return;
    _quantity = clamped;
    notifyListeners();
  }

  double get subtotal => unitPrice * _quantity;
}
