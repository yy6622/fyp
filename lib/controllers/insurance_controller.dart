import 'package:flutter/material.dart';

import '../models/insurance_models.dart';

/// Controller for [InsuranceListPage].
class InsuranceListController extends ChangeNotifier {
  InsuranceCategory? _filter;
  InsuranceCategory? get filter => _filter;

  List<InsurancePlan> get filtered =>
      _filter == null ? insurancePlans : insurancePlans.where((p) => p.category == _filter).toList();

  void setFilter(InsuranceCategory? value) {
    _filter = value;
    notifyListeners();
  }
}

/// Common nationality choices offered in the Traveller Details picker.
const List<String> nationalityOptions = [
  'Malaysian',
  'Singaporean',
  'Indonesian',
  'Thai',
  'Filipino',
  'Vietnamese',
  'Bruneian',
  'Chinese',
  'Japanese',
  'South Korean',
  'Indian',
  'British',
  'American',
  'Australian',
  'Other',
];

/// Per-traveller form data held by [TravellerDetailsController].
class TravellerData {
  String name = '';
  DateTime? dob;
  String? nationality;
  String passport = '';
  String email = '';
  String phone = '';
}

/// Controller for [TravellerDetailsPage].
class TravellerDetailsController extends ChangeNotifier {
  final List<TravellerData> travellers = [TravellerData()];
  int get travellerCount => travellers.length;

  static const maxTravellers = 6;

  /// Returns false (and leaves the list unchanged) once the traveller
  /// limit is reached, so the view can show feedback.
  bool addTraveller() {
    if (travellers.length >= maxTravellers) return false;
    travellers.add(TravellerData());
    notifyListeners();
    return true;
  }

  void removeTraveller(int index) {
    if (travellers.length <= 1) return;
    travellers.removeAt(index);
    notifyListeners();
  }

  void setNationality(int index, String value) {
    travellers[index].nationality = value;
    notifyListeners();
  }

  void setDob(int index, DateTime value) {
    travellers[index].dob = value;
    notifyListeners();
  }
}

/// Controller for [PaymentMethodPage].
class PaymentMethodController extends ChangeNotifier {
  final InsurancePlan plan;
  final int travellerCount;
  PaymentMethodController({required this.plan, required this.travellerCount});

  static const methods = [
    'Credit / Debit Card',
    'FPX Online Banking',
    'Touch in Go eWallet',
    'GrabPay',
    'ShopeePay',
  ];

  String _method = 'Credit / Debit Card';
  String get method => _method;

  double get unitPrice => double.tryParse(plan.price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
  double get subtotal => unitPrice * travellerCount;

  void setMethod(String value) {
    _method = value;
    notifyListeners();
  }
}
