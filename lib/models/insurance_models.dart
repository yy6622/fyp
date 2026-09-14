import 'package:flutter/material.dart';

// ---------------------------------------------------------------------
// Shared insurance plan data — used by both the Home page preview row
// and the full Insurance list page, so there's a single source of truth.
// ---------------------------------------------------------------------
enum InsuranceCategory { singleTrip, family }

class InsurancePlan {
  final String provider;
  final String logoText;
  final Color logoColor;
  final String name;
  final String coverage;
  final String price;
  final InsuranceCategory category;
  const InsurancePlan({
    required this.provider,
    required this.logoText,
    required this.logoColor,
    required this.name,
    required this.coverage,
    required this.price,
    required this.category,
  });
}

const List<InsurancePlan> insurancePlans = [
  InsurancePlan(
    provider: 'Allianz Travel',
    logoText: 'A',
    logoColor: Color(0xFF0B3B8C),
    name: 'Allianz Travel',
    coverage: 'Medical Coverage up to RM 100,000',
    price: 'RM 53',
    category: InsuranceCategory.singleTrip,
  ),
  InsurancePlan(
    provider: 'AIG Travel Guard',
    logoText: 'AIG',
    logoColor: Color(0xFF1E88C7),
    name: 'AIG Travel Guard',
    coverage: 'Medical Coverage up to RM 100,000',
    price: 'RM 49',
    category: InsuranceCategory.singleTrip,
  ),
  InsurancePlan(
    provider: 'Allianz Travel',
    logoText: 'A',
    logoColor: Color(0xFF0B3B8C),
    name: 'Allianz Travel',
    coverage: 'Medical Coverage up to RM 100,000',
    price: 'RM 50',
    category: InsuranceCategory.singleTrip,
  ),
  InsurancePlan(
    provider: 'Allianz Travel',
    logoText: 'A',
    logoColor: Color(0xFF0B3B8C),
    name: 'Family Travel Cover',
    coverage: 'Medical Coverage up to RM 300,000 (family)',
    price: 'RM 150',
    category: InsuranceCategory.family,
  ),
];
