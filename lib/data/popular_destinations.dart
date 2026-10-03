/// The fixed "popular destinations" Explore searches by default when no
/// trip is selected and nothing has been typed into the search box yet —
/// see [CatalogRepository.getPopularFlights]/[getPopularStays]. This is
/// NOT sample/placeholder content shown to the user: it's the query fed
/// into a live Duffel (flights) / RollingGo (hotels) search, so what
/// actually renders is always a real, current result for one of these
/// cities — the list below only picks *which* cities that default
/// search runs for.
class PopularDestination {
  final String label;

  /// IATA airport code, for the flights search.
  final String flightIataCode;

  /// Free-text place name, passed straight to the hotel search (see
  /// [RollingGoApiService.searchStays]).
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

/// This whole app is written for a Malaysia-based traveller (see the
/// doc comment on `AttractionFees` in explore_models.dart). A signed-in
/// person's real departure airport lives in `AppUser.homeAirportCode`
/// (Account Setting's Home Airport picker, see `location_service.dart`)
/// — this constant is only the fallback for someone who hasn't set one
/// yet, and for the shared "popular destinations" cache below, which is
/// intentionally not personalized per origin (see
/// [CatalogRepository.getPopularFlights]).
const String kDefaultHomeAirport = 'KUL';
