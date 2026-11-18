import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/currency_service.dart';

enum InsuranceCategory { basic, annual }

String insuranceCategoryToTripType(InsuranceCategory c) {
  switch (c) {
    case InsuranceCategory.basic:
      return 'Basic';
    case InsuranceCategory.annual:
      return 'Annual';
  }
}

InsuranceCategory insuranceCategoryFromTripType(String tripType) {
  switch (tripType) {
    case 'Annual':
      return InsuranceCategory.annual;
    default:
      return InsuranceCategory.basic;
  }
}

bool insuranceCategoryPricesByDay(InsuranceCategory c) => c != InsuranceCategory.annual;

String insurancePriceUnitLabel(InsuranceCategory c) =>
    insuranceCategoryPricesByDay(c) ? 'per day' : 'per year';

enum InsurancePlanStatus { draft, pendingReview, published, rejected, suspended, expired }

InsurancePlanStatus insurancePlanStatusFromString(String s) {
  switch (s) {
    case 'draft':
      return InsurancePlanStatus.draft;
    case 'pending_review':
      return InsurancePlanStatus.pendingReview;
    case 'rejected':
      return InsurancePlanStatus.rejected;
    case 'suspended':
      return InsurancePlanStatus.suspended;
    case 'expired':
      return InsurancePlanStatus.expired;
    // 'active'/'inactive' are the pre-review-workflow values a very old
    // plan doc might still carry; treat 'active' as published (it was
    // visible before) and anything else unrecognised as draft (hidden).
    case 'active':
    case 'published':
      return InsurancePlanStatus.published;
    default:
      return InsurancePlanStatus.draft;
  }
}

class InsurancePlan {
  final String id;
  final String partnerId;
  final String provider;
  final String logoText;
  final Color logoColor;
  final String? logoUrl;
  final String name;
  final String coverage;
  final String price;
  final InsuranceCategory category;
  final List<InsuranceCoverageItem> coverageItems;
  final List<String> highlights;
  // Which traveller nationalities (matching the app's own `nationalityOptions`
  // list) may buy this plan at all. Empty means no restriction -- every
  // nationality can buy it, same as before this existed.
  final List<String> eligibleCountries;
  final List<String> eligibleDestinations;
  final int? minAge;
  final int? maxAge;
  final int? minTripDurationDays;
  final int? maxTripDurationDays;
  const InsurancePlan({
    required this.id,
    required this.partnerId,
    required this.provider,
    required this.logoText,
    required this.logoColor,
    this.logoUrl,
    required this.name,
    required this.coverage,
    required this.price,
    required this.category,
    this.coverageItems = const [],
    this.highlights = const [],
    this.eligibleCountries = const [],
    this.eligibleDestinations = const [],
    this.minAge,
    this.maxAge,
    this.minTripDurationDays,
    this.maxTripDurationDays,
  });

  bool get hasNationalityRestriction => eligibleCountries.isNotEmpty;

  bool isEligibleForNationality(String nationality) =>
      eligibleCountries.isEmpty || eligibleCountries.contains(nationality);

  bool isEligibleForAge(int age) {
    if (minAge != null && age < minAge!) return false;
    if (maxAge != null && age > maxAge!) return false;
    return true;
  }

  bool isEligibleForTripDuration(int days) {
    if (minTripDurationDays != null && days < minTripDurationDays!) return false;
    if (maxTripDurationDays != null && days > maxTripDurationDays!) return false;
    return true;
  }

  bool isEligibleForDestination(String travellerDestination) {
    if (eligibleDestinations.isEmpty) return true;
    final country = travellerDestination.split(',').last.trim().toLowerCase();
    return eligibleDestinations.any((d) => d.toLowerCase() == country);
  }

  double get priceAmountMyr => double.tryParse(price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

  // Always plain MYR -- no profile-currency conversion for insurance
  // premiums (removed per product decision; was previously converted via
  // CurrencyService using the traveller's profile currency setting).
  String get displayPrice => CurrencyService.instance.format(priceAmountMyr, 'MYR', 'MYR');
}

int ageInYearsOn(DateTime dob, DateTime asOf) {
  int age = asOf.year - dob.year;
  if (asOf.month < dob.month || (asOf.month == dob.month && asOf.day < dob.day)) {
    age -= 1;
  }
  return age < 0 ? 0 : age;
}

class InsuranceCoverageItem {
  final String label;
  final double amount;
  const InsuranceCoverageItem({required this.label, required this.amount});
}

class InsuranceTransaction {
  final String id;
  final String buyerId;
  final String partnerId;
  final String providerName;
  final String planName;
  final String customerName;
  final String customerEmail;
  final double premium;
  final String currencyCode;
  final String status;
  final String destination;
  final DateTime? travelStart;
  final DateTime? travelEnd;
  // Human-readable reference shown to admin/partner (e.g. "TXN-2026-12345")
  // -- see data.js/insurance_repository.dart's newTxnRef()/_newRef('TXN').
  final String txnRef;
  // "INS-<paymentRef>", shown to the traveller as their policy number.
  final String policyNumber;
  // A snapshot of the plan's coverage text at purchase time (plans can be
  // edited later; the policy the traveller actually bought shouldn't change
  // retroactively).
  final String coverage;
  final String travellerName;
  final String travellerIdNumber;
  final String travellerEmail;
  final String travellerPhone;
  final DateTime? createdAt;
  const InsuranceTransaction({
    required this.id,
    required this.buyerId,
    required this.partnerId,
    required this.providerName,
    required this.planName,
    required this.customerName,
    required this.customerEmail,
    required this.premium,
    this.currencyCode = '',
    required this.status,
    this.destination = '',
    this.travelStart,
    this.travelEnd,
    this.txnRef = '',
    this.policyNumber = '',
    this.coverage = '',
    this.travellerName = '',
    this.travellerIdNumber = '',
    this.travellerEmail = '',
    this.travellerPhone = '',
    this.createdAt,
  });
}

class InsurancePartner {
  final String id;
  final String companyName;
  final String logoText;
  final Color logoColor;
  final String? logoUrl;
  final String registrationNumber;
  final String phone;
  final String supportEmail;
  final int activePlanCount;
  const InsurancePartner({
    required this.id,
    required this.companyName,
    required this.logoText,
    required this.logoColor,
    this.logoUrl,
    this.registrationNumber = '',
    this.phone = '',
    this.supportEmail = '',
    this.activePlanCount = 0,
  });
}

double insuranceCoverageDays(InsuranceCategory category, DateTime? travelStart, DateTime? travelEnd) {
  if (!insuranceCategoryPricesByDay(category)) return 1;
  if (travelStart == null || travelEnd == null) return 1;
  final days = travelEnd.difference(travelStart).inDays + 1;
  return days < 1 ? 1 : days.toDouble();
}

double insurancePlanTotal(
  InsurancePlan plan, {
  required int travellerCount,
  DateTime? travelStart,
  DateTime? travelEnd,
}) {
  final days = insuranceCoverageDays(plan.category, travelStart, travelEnd);
  return plan.priceAmountMyr * travellerCount * days;
}

const List<String> insuranceClaimCategories = ['Medical', 'Trip Cancellation', 'Baggage Loss', 'Flight Delay'];
const List<String> insuranceRefundCategories = [
  'Policy Cancellation',
  'Duplicate Payment',
  'Overpayment',
  'Premium Refund',
  'Service Not Rendered',
];


class ClaimTimelineEntry {
  final String status;
  final DateTime? at;
  final String note;

  const ClaimTimelineEntry({required this.status, required this.at, required this.note});

  factory ClaimTimelineEntry.fromMap(Map<String, dynamic> m) => ClaimTimelineEntry(
        status: (m['status'] as String?) ?? '',
        at: DateTime.tryParse((m['at'] as String?) ?? ''),
        note: (m['note'] as String?) ?? '',
      );
}

class ClaimOrRefundRecord {
  final String id;
  final bool isRefund;
  final String ref;
  final String status;
  final double amount;
  final String currencyCode;
  final String category;
  final DateTime? createdAt;
  final List<ClaimTimelineEntry> timeline;

  const ClaimOrRefundRecord({
    required this.id,
    required this.isRefund,
    required this.ref,
    required this.status,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.createdAt,
    required this.timeline,
  });

  factory ClaimOrRefundRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc, {required bool isRefund}) {
    final m = doc.data();
    return ClaimOrRefundRecord(
      id: doc.id,
      isRefund: isRefund,
      ref: (m[isRefund ? 'refundRef' : 'claimRef'] as String?) ?? '',
      status: (m['status'] as String?) ?? 'new',
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: (m['currencyCode'] as String?) ?? 'MYR',
      category: (m[isRefund ? 'reason' : 'category'] as String?) ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      timeline: ((m['timeline'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClaimTimelineEntry.fromMap)
          .toList(),
    );
  }

  /// The most recent timeline note worth showing under the status chip --
  /// e.g. the "Requested more information from the policyholder" text the
  /// partner console writes when it asks for more info.
  String? get latestNote {
    if (timeline.isEmpty) return null;
    final note = timeline.last.note.trim();
    return note.isEmpty ? null : note;
  }
}
