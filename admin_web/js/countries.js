// Single canonical country list shared by every admin_web page that needs
// one -- partner/plan-form.html's destination chip-picker,
// partner/register.html and partner/organization.html's "Country of
// registration" dropdown. Kept in the same names/order as the Flutter
// app's lib/data/countries.dart (kCountries) so a country picked here
// always matches exactly what the traveller-facing app itself can pick
// (plan-form.html's eligibility filtering depends on an exact string
// match, not a fuzzy one -- see InsurancePlan.isEligibleForDestination
// in lib/models/insurance_models.dart).
export const COUNTRY_OPTIONS = [
  "Malaysia", "Singapore", "Indonesia", "Thailand", "Vietnam", "Philippines",
  "Japan", "South Korea", "China", "Hong Kong", "Taiwan", "India",
  "Australia", "New Zealand", "United Kingdom", "Ireland", "France",
  "Germany", "Italy", "Spain", "Netherlands", "Switzerland",
  "United States", "Canada", "United Arab Emirates", "Saudi Arabia",
  "Turkey", "South Africa", "Brazil", "Mexico",
];
