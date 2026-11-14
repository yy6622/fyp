import 'package:flutter/material.dart';

import '../services/currency_service.dart';

/// Only two kinds of plan now (simplified from a three-way Single
/// Trip/Annual/Family split): [basic] covers one trip's dates, priced per
/// traveller per day of that trip; [annual] covers unlimited trips within
/// a year, priced as a flat yearly amount. Firestore's `tripType` field
/// still stores a human label (see insuranceCategoryToTripType below) --
/// older plans saved before this change may still say "Single Trip" or
/// "Family" there, which insuranceCategoryFromTripType treats as [basic]
/// so nothing already published silently disappears.
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
      // Covers 'Basic' and any pre-simplification value ('Single Trip',
      // 'Family') -- all of those priced per day the same way Basic does
      // now, so folding them in here changes nothing about how an
      // existing plan is actually charged.
      return InsuranceCategory.basic;
  }
}

/// Basic plans are priced per traveller per day of the trip (so a longer
/// trip costs more, like real travel insurance). Annual plans are a flat
/// yearly price, since they cover unlimited trips within the year rather
/// than one trip's dates.
bool insuranceCategoryPricesByDay(InsuranceCategory c) => c != InsuranceCategory.annual;

String insurancePriceUnitLabel(InsuranceCategory c) =>
    insuranceCategoryPricesByDay(c) ? 'per day' : 'per year';

/// A plan's review state in the partner -> admin publishing workflow.
/// Mirrors InsurancePartner's own pending/approved/suspended/rejected
/// pattern, one level down (per plan rather than per organization):
///  - [draft]: partner is still editing, nothing public yet.
///  - [pendingReview]: partner submitted it; waiting on an admin.
///  - [published]: admin approved it -- the only state a traveller ever
///    sees (InsuranceRepository.watchPlans() only reads `published`).
///  - [rejected]: admin declined it, with a reason; partner edits and
///    resubmits to try again.
///  - [suspended]: was published, now pulled (either the partner paused
///    it, or an admin did for compliance) -- resubmit to republish.
///  - [expired]: past its own validity window; same visibility as
///    suspended, kept distinct so reporting can tell "we turned this off"
///    from "this plan's own listed validity ran out".
/// Firestore stores these as the same snake_case strings in `status`
/// (admin_web/partner/plan-form.html writes them, firestore.rules
/// restricts which ones a partner may set) -- this enum only exists on
/// the app side for the one place that might still want to reason about
/// it structurally; the app itself never receives anything but
/// `published` from watchPlans(), so most app code never needs this type.
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
  // Which trip destinations (real countries, set by the partner on
  // plan-form.html -- required there, picked from the same accurate
  // country list the traveller picks their own destination from, never
  // free-typed) this plan actually covers. A plan only ever shows up on
  // InsurancePlanComparePage when the traveller's chosen destination is
  // in here -- see isEligibleForDestination.
  final List<String> eligibleDestinations;
  // Age eligibility, in whole years as of the trip's start date. Null
  // means no restriction on that end. Checked against each traveller's
  // own date of birth (TravellerData.dob, already collected per-traveller
  // on TravellerDetailsPage) -- see TravellerDetailsController.validate.
  final int? minAge;
  final int? maxAge;
  // Trip-length eligibility, in whole days (inclusive of both ends, same
  // counting as insuranceCoverageDays). Null means no restriction on that
  // end. Mostly meaningful for Basic plans -- an Annual plan covers many
  // trips of whatever length, so a partner would normally leave these
  // unset for one, but nothing stops them restricting it if they want to.
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

  // The traveller's destination picker (InsuranceQuotePage) can produce
  // either a bare country ("Thailand") or "Area, Country" ("Phuket,
  // Thailand") -- always match on the country part. Plans created before
  // this field existed have an empty list; treat that as "no destination
  // on file" rather than "covers nowhere" so they don't vanish from
  // comparison (the plan-form now requires at least one, so this only
  // ever applies to older data).
  bool isEligibleForDestination(String travellerDestination) {
    if (eligibleDestinations.isEmpty) return true;
    final country = travellerDestination.split(',').last.trim().toLowerCase();
    return eligibleDestinations.any((d) => d.toLowerCase() == country);
  }

  /// [price] is always set by the partner in MYR -- plan-form.html has no
  /// currency picker, every partner types a plain RM amount -- so this is
  /// the one place that turns it into whatever the traveller actually
  /// prefers, the same way CatalogHotel/CatalogFlight.displayPrice do for
  /// bookings. Pass null (or leave it off) to get the plan's real RM price.
  double get priceAmountMyr => double.tryParse(price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

  String displayPrice([String? userCurrency]) =>
      CurrencyService.instance.format(priceAmountMyr, 'MYR', userCurrency);
}

/// Whole years of age [dob] has reached as of [asOf] (defaults to today) --
/// shared by [TravellerDetailsController.validate] against
/// [InsurancePlan.isEligibleForAge] and anywhere else an age needs
/// computing from a date of birth, so the "has their birthday happened
/// yet this year" edge case is only handled once.
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
  // The currency [premium] was actually charged in -- the traveller's
  // preference at checkout, converted from the plan's MYR price same as
  // everything on PaymentMethodController. Empty for transactions made
  // before this existed, which were always MYR (nothing else was
  // possible yet), so callers should treat '' the same as 'MYR'.
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
  // The actual insured traveller(s), collected on TravellerDetailsPage --
  // distinct from [customerName]/[customerEmail] above, which are the
  // buyer's own account (who can file a claim/refund). This is this
  // transaction's single source of truth for who's insured: it used to
  // also be written to a separate users/{uid}/bookings doc for the
  // History page, which meant the same purchase was stored twice.
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

/// One insurance company registered in the partner console
/// (`insurance_partners/{uid}`). Shown on [InsurancePartnerListPage] so a
/// traveller picks who to buy from (and can message) before ever seeing a
/// plan -- mirrors how a real insurer-select step would work, distinct from
/// [InsurancePlan] which is one product that partner sells.
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

/// Number of days a [plan] is priced for, given a travel period -- Basic
/// plans charge per day of the actual trip (inclusive of both ends,
/// minimum 1 day); Annual plans are a flat yearly price, so this is
/// always 1 regardless of dates. Shared by the quote/compare screens and
/// [PaymentMethodController] so the two never compute a different number.
double insuranceCoverageDays(InsuranceCategory category, DateTime? travelStart, DateTime? travelEnd) {
  if (!insuranceCategoryPricesByDay(category)) return 1;
  if (travelStart == null || travelEnd == null) return 1;
  final days = travelEnd.difference(travelStart).inDays + 1;
  return days < 1 ? 1 : days.toDouble();
}

/// The real total price of [plan] for [travellerCount] traveller(s) over
/// [travelStart]..[travelEnd] -- unit price x travellers x coverage days,
/// the same formula [PaymentMethodController.subtotal] charges at
/// checkout. Used by the quote/compare screens so the price shown while
/// picking a plan is never just the bare per-day/per-year unit rate.
double insurancePlanTotal(
  InsurancePlan plan, {
  required int travellerCount,
  DateTime? travelStart,
  DateTime? travelEnd,
  String? userCurrency,
}) {
  final unit = CurrencyService.instance.convertOrSame(plan.priceAmountMyr, from: 'MYR', to: userCurrency);
  final days = insuranceCoverageDays(plan.category, travelStart, travelEnd);
  return unit * travellerCount * days;
}

const List<String> insuranceClaimCategories = ['Medical', 'Trip Cancellation', 'Baggage Loss', 'Flight Delay'];
const List<String> insuranceRefundCategories = [
  'Policy Cancellation',
  'Duplicate Payment',
  'Overpayment',
  'Premium Refund',
  'Service Not Rendered',
];
