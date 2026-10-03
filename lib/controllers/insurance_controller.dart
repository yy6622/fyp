import 'dart:async';

import 'package:flutter/material.dart';

import '../models/insurance_models.dart';
import '../repositories/insurance_repository.dart';

/// Controller for [InsuranceListPage]. Streams real plans from
/// [InsuranceRepository] instead of a hardcoded list.
class InsuranceListController extends ChangeNotifier {
  InsuranceCategory? _filter;
  InsuranceCategory? get filter => _filter;

  bool _loading = true;
  bool get loading => _loading;

  List<InsurancePlan> _plans = [];
  StreamSubscription<List<InsurancePlan>>? _sub;

  InsuranceListController() {
    _sub = InsuranceRepository.instance.watchPlans().listen((plans) {
      _plans = plans;
      _loading = false;
      notifyListeners();
    }, onError: (_) {
      // Permission-denied (rules not deployed yet) or a transient
      // Firestore error shouldn't leave the page spinning forever —
      // fall back to an empty list, same as "no plans published yet".
      _plans = [];
      _loading = false;
      notifyListeners();
    });
  }

  List<InsurancePlan> get filtered =>
      _filter == null ? _plans : _plans.where((p) => p.category == _filter).toList();

  void setFilter(InsuranceCategory? value) {
    _filter = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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

  // These four were previously missing — the Full Name/Passport/Email/
  // Phone fields on TravellerDetailsPage were plain TextFields with no
  // controller or onChanged wired up, so anything typed into them was
  // silently discarded (only DOB and Nationality, which go through the
  // picker setters above, actually reached TravellerData). No
  // notifyListeners() here — these are plain text fields the widget
  // itself already shows what was typed for; rebuilding on every
  // keystroke would just fight the TextField's own cursor.
  void setName(int index, String value) {
    travellers[index].name = value;
  }

  void setPassport(int index, String value) {
    travellers[index].passport = value;
  }

  void setEmail(int index, String value) {
    travellers[index].email = value;
  }

  void setPhone(int index, String value) {
    travellers[index].phone = value;
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
