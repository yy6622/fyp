import 'dart:async';

import 'package:flutter/material.dart';

import '../models/insurance_models.dart';
import '../repositories/insurance_repository.dart';
import 'booking_details_controller.dart' show isValidEmailFormat, isValidPhoneFormat, isValidPassportFormat, isValidICFormat;

/// Controller for [InsurancePartnerListPage] — the entry point of the
/// partner-first flow (pick an insurer before ever seeing a plan).
class InsurancePartnerListController extends ChangeNotifier {
  bool _loading = true;
  bool get loading => _loading;

  List<InsurancePartner> _partners = [];
  List<InsurancePartner> get partners => _partners;

  StreamSubscription<List<InsurancePartner>>? _sub;

  InsurancePartnerListController() {
    _sub = InsuranceRepository.instance.watchApprovedPartners().listen((partners) {
      _partners = partners;
      _loading = false;
      notifyListeners();
    }, onError: (_) {
      _partners = [];
      _loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class InsuranceQuoteController extends ChangeNotifier {
  String destination;
  DateTime? travelStart;
  DateTime? travelEnd;
  int _travellerCount;
  int get travellerCount => _travellerCount;

  InsuranceQuoteController({String? initialDestination, DateTime? initialStart, DateTime? initialEnd, int initialTravellerCount = 1})
      : destination = initialDestination ?? '',
        travelStart = initialStart,
        travelEnd = initialEnd,
        _travellerCount = initialTravellerCount.clamp(
          TravellerDetailsController.minTravellers,
          TravellerDetailsController.maxTravellers,
        );

  void setDestination(String value) {
    destination = value;
    notifyListeners();
  }

  void setTravelDates(DateTime start, DateTime end) {
    travelStart = start;
    travelEnd = end;
    notifyListeners();
  }

  void setTravellerCount(int value) {
    _travellerCount = value.clamp(TravellerDetailsController.minTravellers, TravellerDetailsController.maxTravellers);
    notifyListeners();
  }

  /// Null while the quote is incomplete — mirrors [TravellerDetailsController.validate]'s
  /// date checks so the "Get Quote" button can't be pressed with a broken date range.
  String? validate() {
    if (destination.trim().isEmpty) return 'Please enter where you\'re travelling to.';
    if (travelStart == null || travelEnd == null) return 'Please select your travel dates.';
    if (travelEnd!.isBefore(travelStart!)) return 'Travel end date must be on or after the start date.';
    return null;
  }
}

class InsuranceListController extends ChangeNotifier {
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
      _plans = [];
      _loading = false;
      notifyListeners();
    });
  }

  List<InsurancePlan> get filtered => _plans;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

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

class TravellerData {
  String name = '';
  DateTime? dob;
  String? nationality;
  String identityNumber = '';
  String email = '';
  String phone = '';
}

/// Controller for [TravellerDetailsPage].
class TravellerDetailsController extends ChangeNotifier {
  final List<TravellerData> travellers = [TravellerData()];
  int get travellerCount => travellers.length;

  DateTime? travelStart;
  DateTime? travelEnd;

  void setTravelDates(DateTime start, DateTime end) {
    travelStart = start;
    travelEnd = end;
    notifyListeners();
  }

  static const minTravellers = 1;
  static const maxTravellers = 6;

  /// Grows/shrinks [travellers] to match a quantity picked up front (a
  /// stepper), same pattern as the flight/hotel booking controllers —
  /// new entries are blank, extra ones are dropped from the end.
  void setTravellerCount(int value) {
    final target = value.clamp(minTravellers, maxTravellers);
    if (target == travellers.length) return;
    while (travellers.length < target) {
      travellers.add(TravellerData());
    }
    while (travellers.length > target) {
      travellers.removeLast();
    }
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

  void setName(int index, String value) {
    travellers[index].name = value;
  }

  void setIdentityNumber(int index, String value) {
    travellers[index].identityNumber = value;
  }

  void setEmail(int index, String value) {
    travellers[index].email = value;
  }

  void setPhone(int index, String value) {
    travellers[index].phone = value;
  }

  String? validate(InsurancePlan plan) {
    if (travelStart == null || travelEnd == null) return 'Please select your travel dates.';
    if (travelEnd!.isBefore(travelStart!)) return 'Travel end date must be on or after the start date.';
    for (var i = 0; i < travellers.length; i++) {
      final t = travellers[i];
      final who = travellers.length > 1 ? 'Traveller ${i + 1}' : 'The traveller';
      if (t.name.trim().isEmpty) return "$who's full name is required.";
      if (t.dob == null) return "$who's date of birth is required.";
      if (t.nationality == null || t.nationality!.isEmpty) return "$who's nationality is required.";
      if (!plan.isEligibleForNationality(t.nationality!)) {
        return "$who (${t.nationality}) isn't eligible for this plan — it's only available to: ${plan.eligibleCountries.join(', ')}.";
      }
      if (t.dob != null) {
        final age = ageInYearsOn(t.dob!, travelStart!);
        if (!plan.isEligibleForAge(age)) {
          final lo = plan.minAge;
          final hi = plan.maxAge;
          final range = lo != null && hi != null
              ? 'aged $lo-$hi'
              : lo != null
                  ? 'aged $lo or older'
                  : 'aged $hi or younger';
          return "$who is $age, but this plan only covers travellers $range.";
        }
      }
      // Malaysians travelling on their IC (MyKad) don't carry a passport
      // for domestic/regional trips, so only require one for foreigners —
      // matching how Malaysian travel insurers actually underwrite this.
      final isMalaysian = t.nationality == 'Malaysian';
      if (t.identityNumber.trim().isEmpty) {
        return isMalaysian ? "$who's IC number is required." : "$who's passport number is required.";
      }
      if (isMalaysian) {
        if (!isValidICFormat(t.identityNumber)) return "$who's IC number doesn't look right — 12 digits (e.g. 901231-14-5566).";
      } else {
        if (!isValidPassportFormat(t.identityNumber)) return "$who's passport number doesn't look right — letters/digits only, 5-12 characters.";
      }
    }
    final lead = travellers.first;
    if (lead.email.trim().isEmpty) return 'A contact email is required.';
    if (!isValidEmailFormat(lead.email)) return 'Please enter a valid contact email address.';
    if (lead.phone.trim().isEmpty) return 'A contact phone number is required.';
    if (!isValidPhoneFormat(lead.phone)) return 'Please enter a valid contact phone number.';
    return null;
  }
}

/// Controller for [PaymentMethodPage].
class PaymentMethodController extends ChangeNotifier {
  final InsurancePlan plan;
  final int travellerCount;
  final DateTime travelStart;
  final DateTime travelEnd;
  PaymentMethodController({
    required this.plan,
    required this.travellerCount,
    required this.travelStart,
    required this.travelEnd,
  });

  static const methods = [
    'Credit / Debit Card',
    'FPX Online Banking',
    'Touch in Go eWallet',
    'GrabPay',
    'ShopeePay',
  ];

  String _method = 'Credit / Debit Card';
  String get method => _method;

  // Always plain MYR -- no profile-currency conversion for insurance
  // premiums (removed per product decision).
  double get unitPrice => plan.priceAmountMyr;

  int get coverageDays => insuranceCoverageDays(plan.category, travelStart, travelEnd).toInt();

  double get subtotal => unitPrice * travellerCount * coverageDays;

  static const double serviceFee = 2.0;
  double get total => subtotal + serviceFee;

  /// Every plan is quoted and charged in MYR.
  String get chargeCurrencyCode => 'MYR';

  void setMethod(String value) {
    _method = value;
    notifyListeners();
  }
}
