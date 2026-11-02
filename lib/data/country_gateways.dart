class CountryGateway {
  final String flightIataCode;

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
