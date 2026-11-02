import 'package:flutter/material.dart';

enum InsuranceCategory { singleTrip, annual, family }

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
  final String? logoUrl;
  final String name;
  final String coverage;
  final String price;
  final InsuranceCategory category;
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
  final String status;
  final String destination;
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

const List<String> insuranceClaimCategories = ['Medical', 'Trip Cancellation', 'Baggage Loss', 'Flight Delay'];
const List<String> insuranceRefundCategories = [
  'Policy Cancellation',
  'Duplicate Payment',
  'Overpayment',
  'Premium Refund',
  'Service Not Rendered',
];
