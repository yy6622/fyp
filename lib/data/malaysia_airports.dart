/// Malaysia's airports with commercial passenger service, used by
/// [LocationService] to suggest the nearest one as a Home Airport (see
/// `account_setting_page.dart`) instead of always assuming
/// [kDefaultHomeAirport] (KUL) — e.g. someone in Penang should be
/// offered PEN, not sent across the country to KUL.
///
/// This app assumes a Malaysia-based traveller throughout (see the doc
/// comment on `kDefaultHomeAirport` in `popular_destinations.dart`), so
/// this list is domestic-only rather than a global airport database —
/// nearest-airport-in-Malaysia is the question that actually matters
/// here. Coordinates are each airport's approximate terminal location.
class MalaysiaAirport {
  final String iataCode;
  final String name;
  final String city;
  final double latitude;
  final double longitude;

  const MalaysiaAirport({
    required this.iataCode,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
  });
}

const List<MalaysiaAirport> kMalaysiaAirports = [
  MalaysiaAirport(iataCode: 'KUL', name: 'Kuala Lumpur International Airport', city: 'Sepang, Selangor', latitude: 2.7456, longitude: 101.7099),
  MalaysiaAirport(iataCode: 'SZB', name: 'Sultan Abdul Aziz Shah Airport (Subang)', city: 'Subang, Selangor', latitude: 3.1307, longitude: 101.5490),
  MalaysiaAirport(iataCode: 'PEN', name: 'Penang International Airport', city: 'Bayan Lepas, Penang', latitude: 5.2971, longitude: 100.2769),
  MalaysiaAirport(iataCode: 'JHB', name: 'Senai International Airport', city: 'Johor Bahru, Johor', latitude: 1.6412, longitude: 103.6698),
  MalaysiaAirport(iataCode: 'LGK', name: 'Langkawi International Airport', city: 'Langkawi, Kedah', latitude: 6.3297, longitude: 99.7286),
  MalaysiaAirport(iataCode: 'KCH', name: 'Kuching International Airport', city: 'Kuching, Sarawak', latitude: 1.4847, longitude: 110.3469),
  MalaysiaAirport(iataCode: 'BKI', name: 'Kota Kinabalu International Airport', city: 'Kota Kinabalu, Sabah', latitude: 5.9372, longitude: 116.0511),
  MalaysiaAirport(iataCode: 'KBR', name: 'Sultan Ismail Petra Airport', city: 'Kota Bharu, Kelantan', latitude: 6.1670, longitude: 102.2919),
  MalaysiaAirport(iataCode: 'AOR', name: 'Sultan Abdul Halim Airport', city: 'Alor Setar, Kedah', latitude: 6.1899, longitude: 100.3980),
  MalaysiaAirport(iataCode: 'IPH', name: 'Sultan Azlan Shah Airport', city: 'Ipoh, Perak', latitude: 4.5682, longitude: 101.0922),
  MalaysiaAirport(iataCode: 'KTE', name: 'Kerteh Airport', city: 'Kerteh, Terengganu', latitude: 4.5375, longitude: 103.4269),
  MalaysiaAirport(iataCode: 'TGG', name: 'Sultan Mahmud Airport', city: 'Kuala Terengganu, Terengganu', latitude: 5.3826, longitude: 103.1017),
  MalaysiaAirport(iataCode: 'KUA', name: 'Kuantan Airport', city: 'Kuantan, Pahang', latitude: 3.7759, longitude: 103.2079),
  MalaysiaAirport(iataCode: 'MYY', name: 'Miri Airport', city: 'Miri, Sarawak', latitude: 4.3216, longitude: 113.9877),
  MalaysiaAirport(iataCode: 'SBW', name: 'Sibu Airport', city: 'Sibu, Sarawak', latitude: 2.2614, longitude: 111.9853),
  MalaysiaAirport(iataCode: 'BTU', name: 'Bintulu Airport', city: 'Bintulu, Sarawak', latitude: 3.1234, longitude: 113.0201),
  MalaysiaAirport(iataCode: 'LBU', name: 'Labuan Airport', city: 'Labuan', latitude: 5.3006, longitude: 115.2502),
  MalaysiaAirport(iataCode: 'SDK', name: 'Sandakan Airport', city: 'Sandakan, Sabah', latitude: 5.9012, longitude: 118.0592),
  MalaysiaAirport(iataCode: 'TWU', name: 'Tawau Airport', city: 'Tawau, Sabah', latitude: 4.3208, longitude: 118.1279),
];
