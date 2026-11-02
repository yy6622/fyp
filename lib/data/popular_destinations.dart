class PopularDestination {
  final String label;

  final String flightIataCode;

  final String hotelPlaceQuery;

  const PopularDestination({required this.label, required this.flightIataCode, required this.hotelPlaceQuery});
}

const List<PopularDestination> kPopularDestinations = [
  PopularDestination(label: 'Tokyo', flightIataCode: 'NRT', hotelPlaceQuery: 'Tokyo, Japan'),
  PopularDestination(label: 'Bangkok', flightIataCode: 'BKK', hotelPlaceQuery: 'Bangkok, Thailand'),
  PopularDestination(label: 'Singapore', flightIataCode: 'SIN', hotelPlaceQuery: 'Singapore'),
  PopularDestination(label: 'Seoul', flightIataCode: 'ICN', hotelPlaceQuery: 'Seoul, South Korea'),
  PopularDestination(label: 'Bali', flightIataCode: 'DPS', hotelPlaceQuery: 'Bali, Indonesia'),
];

const String kDefaultHomeAirport = 'KUL';
