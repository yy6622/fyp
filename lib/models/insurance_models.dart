import 'package:flutter/material.dart';

// ---------------------------------------------------------------------
// Shared insurance plan data — read live from Firestore's
// `insurance_plans` collection (authored in the admin/partner web
// console, admin_web/partner/plans.html), not hardcoded. See
// InsuranceRepository.watchPlans() for how a Firestore doc becomes one
// of these.
// ---------------------------------------------------------------------
enum InsuranceCategory { singleTrip, annual, family }

/// Maps to/from the `tripType` string the partner console's plan form
/// writes — see admin_web/partner/plans.html's
/// `<select id="fType"><option>Single Trip</option><option>Annual</option><option>Family</option></select>`.
String insuranceCategoryToTripType(InsuranceCategory c) {
  switch (c) {
    case InsuranceCategory.singleTrip:
      return 'Single Trip';
    case InsuranceCategory.annual:
      return 'Annual';
    case InsuranceCategory.family:
      return 'Family';
  }
}

InsuranceCategory insuranceCategoryFromTripType(String tripType) {
  switch (tripType) {
    case 'Annual':
      return InsuranceCategory.annual;
    case 'Family':
      return InsuranceCategory.family;
    default:
      return InsuranceCategory.singleTrip;
  }
}

class InsurancePlan {
  final String id;
  final String partnerId;
  final String provider;
  final String logoText;
  final Color logoColor;
  // The partner's real uploaded logo (admin_web/partner/organization.html),
  // denormalized onto the plan doc as `providerLogoUrl` when the partner
  // creates/edits a plan — see admin_web/partner/plans.html. Null/empty
  // when the partner never uploaded one, or for plans saved before this
  // existed; [insuranceLogo] falls back to the letter badge in that case.
  final String? logoUrl;
  final String name;
  final String coverage;
  final String price;
  final InsuranceCategory category;
  // Real per-plan detail the partner fills in on admin_web/partner/
  // plans.html — a structured breakdown (medical/baggage/trip-cancellation
  // amounts, etc.) and a short list of highlight badges, rather than the
  // same fixed 5 coverage lines and 5 icons every plan used to show.
  // Empty for a plan saved before this existed, or a partner who hasn't
  // filled it in yet — the detail page hides each section rather than
  // ever padding it out with made-up numbers.
  final List<InsuranceCoverageItem> coverageItems;
  final List<String> highlights;
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
  });
}

/// One line of [InsurancePlan.coverageItems] — "Medical Expenses
/// (Overseas)" paired with the real RM amount the partner entered for it.
class InsuranceCoverageItem {
  final String label;
  final double amount;
  const InsuranceCoverageItem({required this.label, required this.amount});
}

/// A real purchase record from `insurance_transactions/{id}` — same
/// collection the partner console's Transactions list reads (see
/// InsuranceRepository.recordPurchase). Used by the rider-facing Claim/
/// Refund flow so every value on those forms (provider, plan, amount,
/// travel dates) comes from the real stored purchase instead of being
/// re-typed or guessed.
class InsuranceTransaction {
  final String id;
  final String buyerId;
  final String partnerId;
  final String providerName;
  final String planName;
  final String customerName;
  final String customerEmail;
  final double premium;
  final String status;
  final String destination;
  // Null for a transaction recorded before travel-period capture existed
  // (see TravellerDetailsController) — InsuranceRepository.requestRefund
  // treats that legacy case as still eligible, since there is no stored
  // date to check against and the partner reviews every request by hand
  // regardless.
  final DateTime? travelStart;
  final DateTime? travelEnd;
  const InsuranceTransaction({
    required this.id,
    required this.buyerId,
    required this.partnerId,
    required this.providerName,
    required this.planName,
    required this.customerName,
    required this.customerEmail,
    required this.premium,
    required this.status,
    this.destination = '',
    this.travelStart,
    this.travelEnd,
  });
}

/// Categories the rider picks from when filing a claim or requesting a
/// refund — exactly the dropdown values the partner console itself uses
/// (admin_web/partner/claims.html's CLAIM_CATEGORIES/REFUND_CATEGORIES),
/// so a rider-submitted document's `category` is always one the partner
/// console already knows how to display/filter by.
const List<String> insuranceClaimCategories = ['Medical', 'Trip Cancellation', 'Baggage Loss', 'Flight Delay'];
const List<String> insuranceRefundCategories = [
  'Policy Cancellation',
  'Duplicate Payment',
  'Overpayment',
  'Premium Refund',
  'Service Not Rendered',
];
