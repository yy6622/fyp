/// A representative "gateway" (flight IATA code + a hotel-search place
/// string) for each country in [kCountries] (`countries.dart`), keyed by
/// that exact country name, lowercased.
///
/// Trips store their destination as a bare country name — whatever the
/// person picked from [kCountries] in Create Plan or Group Setting (see
/// `create_plan_wizard.dart`/`group_trip_page.dart`'s destination
/// pickers) — never a city or an airport code. But Duffel's flight
/// search needs an IATA airport/city code, and Duffel Stays' geocoding
/// step works far better with a real place name than a whole country
/// (Nominatim will resolve "Japan" to *some* point inside it, but
/// there's no guarantee it lands anywhere near a city with hotels).
/// This map bridges both gaps for every country the picker offers, so a
/// trip-driven search — the common case, since it's how Explore's
/// default flight/hotel search is normally reached — always has a real
/// place to search with instead of a bare country name neither API
/// understands.
///
/// Each entry is the country's biggest/best-known international
/// gateway for a traveller, not a strict "capital city" mapping — e.g.
/// Indonesia points at Bali/DPS, not Jakarta, matching this app's own
/// headline destination for it (see [kPopularDestinations] in
/// `popular_destinations.dart`). Where an IATA CITY code exists
/// (covering every airport in that metro area, e.g. "TYO" for Tokyo's
/// NRT + HND), it's used in preference to one specific airport, since
/// Duffel's flight search accepts city codes too.
class CountryGateway {
  /// IATA airport or IATA city code, passed straight into a Duffel
  /// flight-search slice's origin/destination.
  final String flightIataCode;

  /// "City, Country" (or just "Country" for a city-state) text passed
  /// straight to the hotel search — see
  /// [RollingGoApiService.searchStays].
  final String hotelPlaceQuery;

  const CountryGateway({required this.flightIataCode, required this.hotelPlaceQuery});
}

const Map<String, CountryGateway> kCountryGateways = {
  'malaysia': CountryGateway(flightIataCode: 'KUL', hotelPlaceQuery: 'Kuala Lumpur, Malaysia'),
  'singapore': CountryGateway(flightIataCode: 'SIN', hotelPlaceQuery: 'Singapore'),
  'indonesia': CountryGateway(flightIataCode: 'DPS', hotelPlaceQuery: 'Bali, Indonesia'),
  'thailand': CountryGateway(flightIataCode: 'BKK', hotelPlaceQuery: 'Bangkok, Thailand'),
  'vietnam': CountryGateway(flightIataCode: 'SGN', hotelPlaceQuery: 'Ho Chi Minh City, Vietnam'),
  'philippines': CountryGateway(flightIataCode: 'MNL', hotelPlaceQuery: 'Manila, Philippines'),
  'japan': CountryGateway(flightIataCode: 'TYO', hotelPlaceQuery: 'Tokyo, Japan'),
  'south korea': CountryGateway(flightIataCode: 'SEL', hotelPlaceQuery: 'Seoul, South Korea'),
  'china': CountryGateway(flightIataCode: 'BJS', hotelPlaceQuery: 'Beijing, China'),
  'hong kong': CountryGateway(flightIataCode: 'HKG', hotelPlaceQuery: 'Hong Kong'),
  'taiwan': CountryGateway(flightIataCode: 'TPE', hotelPlaceQuery: 'Taipei, Taiwan'),
  'india': CountryGateway(flightIataCode: 'DEL', hotelPlaceQuery: 'Delhi, India'),
  'australia': CountryGateway(flightIataCode: 'SYD', hotelPlaceQuery: 'Sydney, Australia'),
  'new zealand': CountryGateway(flightIataCode: 'AKL', hotelPlaceQuery: 'Auckland, New Zealand'),
  'united kingdom': CountryGateway(flightIataCode: 'LON', hotelPlaceQuery: 'London, United Kingdom'),
  'ireland': CountryGateway(flightIataCode: 'DUB', hotelPlaceQuery: 'Dublin, Ireland'),
  'france': CountryGateway(flightIataCode: 'PAR', hotelPlaceQuery: 'Paris, France'),
  'germany': CountryGateway(flightIataCode: 'BER', hotelPlaceQuery: 'Berlin, Germany'),
  'italy': CountryGateway(flightIataCode: 'ROM', hotelPlaceQuery: 'Rome, Italy'),
  'spain': CountryGateway(flightIataCode: 'MAD', hotelPlaceQuery: 'Madrid, Spain'),
  'netherlands': CountryGateway(flightIataCode: 'AMS', hotelPlaceQuery: 'Amsterdam, Netherlands'),
  'switzerland': CountryGateway(flightIataCode: 'ZRH', hotelPlaceQuery: 'Zurich, Switzerland'),
  'united states': CountryGateway(flightIataCode: 'NYC', hotelPlaceQuery: 'New York, United States'),
  'canada': CountryGateway(flightIataCode: 'YTO', hotelPlaceQuery: 'Toronto, Canada'),
  'united arab emirates': CountryGateway(flightIataCode: 'DXB', hotelPlaceQuery: 'Dubai, United Arab Emirates'),
  'saudi arabia': CountryGateway(flightIataCode: 'RUH', hotelPlaceQuery: 'Riyadh, Saudi Arabia'),
  'turkey': CountryGateway(flightIataCode: 'IST', hotelPlaceQuery: 'Istanbul, Turkey'),
  'south africa': CountryGateway(flightIataCode: 'JNB', hotelPlaceQuery: 'Johannesburg, South Africa'),
  'brazil': CountryGateway(flightIataCode: 'RIO', hotelPlaceQuery: 'Rio de Janeiro, Brazil'),
  'mexico': CountryGateway(flightIataCode: 'MEX', hotelPlaceQuery: 'Mexico City, Mexico'),
};
