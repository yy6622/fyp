class CountryGateway {
  final String flightIataCode;

  final String hotelPlaceQuery;

  /// The country's local currency (ISO 4217). Used by the receipt-scan
  /// currency conversion (see ReceiptOcrService) to work out what a
  /// traveller's receipt was most likely paid in, based on the trip's own
  /// destination rather than trying to OCR a currency symbol off a photo.
  final String currencyCode;

  const CountryGateway({required this.flightIataCode, required this.hotelPlaceQuery, required this.currencyCode});
}

const Map<String, CountryGateway> kCountryGateways = {
  'malaysia': CountryGateway(flightIataCode: 'KUL', hotelPlaceQuery: 'Kuala Lumpur, Malaysia', currencyCode: 'MYR'),
  'singapore': CountryGateway(flightIataCode: 'SIN', hotelPlaceQuery: 'Singapore', currencyCode: 'SGD'),
  'indonesia': CountryGateway(flightIataCode: 'DPS', hotelPlaceQuery: 'Bali, Indonesia', currencyCode: 'IDR'),
  'thailand': CountryGateway(flightIataCode: 'BKK', hotelPlaceQuery: 'Bangkok, Thailand', currencyCode: 'THB'),
  'vietnam': CountryGateway(flightIataCode: 'SGN', hotelPlaceQuery: 'Ho Chi Minh City, Vietnam', currencyCode: 'VND'),
  'philippines': CountryGateway(flightIataCode: 'MNL', hotelPlaceQuery: 'Manila, Philippines', currencyCode: 'PHP'),
  'japan': CountryGateway(flightIataCode: 'TYO', hotelPlaceQuery: 'Tokyo, Japan', currencyCode: 'JPY'),
  'south korea': CountryGateway(flightIataCode: 'SEL', hotelPlaceQuery: 'Seoul, South Korea', currencyCode: 'KRW'),
  'china': CountryGateway(flightIataCode: 'BJS', hotelPlaceQuery: 'Beijing, China', currencyCode: 'CNY'),
  'hong kong': CountryGateway(flightIataCode: 'HKG', hotelPlaceQuery: 'Hong Kong', currencyCode: 'HKD'),
  'taiwan': CountryGateway(flightIataCode: 'TPE', hotelPlaceQuery: 'Taipei, Taiwan', currencyCode: 'TWD'),
  'india': CountryGateway(flightIataCode: 'DEL', hotelPlaceQuery: 'Delhi, India', currencyCode: 'INR'),
  'australia': CountryGateway(flightIataCode: 'SYD', hotelPlaceQuery: 'Sydney, Australia', currencyCode: 'AUD'),
  'new zealand': CountryGateway(flightIataCode: 'AKL', hotelPlaceQuery: 'Auckland, New Zealand', currencyCode: 'NZD'),
  'united kingdom': CountryGateway(flightIataCode: 'LON', hotelPlaceQuery: 'London, United Kingdom', currencyCode: 'GBP'),
  'ireland': CountryGateway(flightIataCode: 'DUB', hotelPlaceQuery: 'Dublin, Ireland', currencyCode: 'EUR'),
  'france': CountryGateway(flightIataCode: 'PAR', hotelPlaceQuery: 'Paris, France', currencyCode: 'EUR'),
  'germany': CountryGateway(flightIataCode: 'BER', hotelPlaceQuery: 'Berlin, Germany', currencyCode: 'EUR'),
  'italy': CountryGateway(flightIataCode: 'ROM', hotelPlaceQuery: 'Rome, Italy', currencyCode: 'EUR'),
  'spain': CountryGateway(flightIataCode: 'MAD', hotelPlaceQuery: 'Madrid, Spain', currencyCode: 'EUR'),
  'netherlands': CountryGateway(flightIataCode: 'AMS', hotelPlaceQuery: 'Amsterdam, Netherlands', currencyCode: 'EUR'),
  'switzerland': CountryGateway(flightIataCode: 'ZRH', hotelPlaceQuery: 'Zurich, Switzerland', currencyCode: 'CHF'),
  'united states': CountryGateway(flightIataCode: 'NYC', hotelPlaceQuery: 'New York, United States', currencyCode: 'USD'),
  'canada': CountryGateway(flightIataCode: 'YTO', hotelPlaceQuery: 'Toronto, Canada', currencyCode: 'CAD'),
  'united arab emirates': CountryGateway(flightIataCode: 'DXB', hotelPlaceQuery: 'Dubai, United Arab Emirates', currencyCode: 'AED'),
  'saudi arabia': CountryGateway(flightIataCode: 'RUH', hotelPlaceQuery: 'Riyadh, Saudi Arabia', currencyCode: 'SAR'),
  'turkey': CountryGateway(flightIataCode: 'IST', hotelPlaceQuery: 'Istanbul, Turkey', currencyCode: 'TRY'),
  'south africa': CountryGateway(flightIataCode: 'JNB', hotelPlaceQuery: 'Johannesburg, South Africa', currencyCode: 'ZAR'),
  'brazil': CountryGateway(flightIataCode: 'RIO', hotelPlaceQuery: 'Rio de Janeiro, Brazil', currencyCode: 'BRL'),
  'mexico': CountryGateway(flightIataCode: 'MEX', hotelPlaceQuery: 'Mexico City, Mexico', currencyCode: 'MXN'),
};

/// Matches a free-text destination (e.g. a trip's `destination` field --
/// "Tokyo, Japan", just "Japan", or "Kuala Lumpur, Malaysia") against
/// [kCountryGateways]'s keys: tries the whole string first, then the part
/// after the last comma (where a "City, Country" string's country usually
/// sits). Returns null when nothing matches a known country.
String? resolveCountryKey(String destinationText) {
  final whole = destinationText.trim().toLowerCase();
  if (whole.isEmpty) return null;
  if (kCountryGateways.containsKey(whole)) return whole;
  final lastPart = destinationText.split(',').last.trim().toLowerCase();
  if (kCountryGateways.containsKey(lastPart)) return lastPart;
  return null;
}

/// The local currency a receipt bought on this trip was most likely paid
/// in, guessed from the trip's own destination rather than trying to OCR a
/// currency symbol off a photo (which a printed receipt may not even show
/// clearly, and which this app doesn't otherwise attempt). Returns null
/// when the destination doesn't match a known country -- callers should
/// treat that the same as "assume MYR", same as before this existed.
String? currencyForDestination(String destinationText) {
  final key = resolveCountryKey(destinationText);
  return key == null ? null : kCountryGateways[key]!.currencyCode;
}
