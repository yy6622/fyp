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
  final String name;
  final String coverage;
  final String price;
  final InsuranceCategory category;
  const InsurancePlan({
    required this.id,
    required this.partnerId,
    required this.provider,
    required this.logoText,
    required this.logoColor,
    required this.name,
    required this.coverage,
    required this.price,
    required this.category,
  });
}
