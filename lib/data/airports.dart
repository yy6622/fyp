/// Global airport dataset, replacing the old Malaysia-only list.
///
/// Covers every country in `kCountries` (2026-11-17 "go global" request) with
/// 1-4 major/representative airports each, real IATA codes and lat/lng.
/// Used for: the profile "Home Airport" picker (ranked by distance, scoped to
/// the user's selected country first), and the "From/To" autocomplete on the
/// manual Add Flight page.
class Airport {
  final String iataCode;
  final String name;
  final String city;
  final String country; // matches a `Country.name` in countries.dart exactly
  final double latitude;
  final double longitude;

  const Airport({
    required this.iataCode,
    required this.name,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
  });
}

const List<Airport> kAirports = [
  // Malaysia
  Airport(iataCode: 'KUL', name: 'Kuala Lumpur International Airport', city: 'Sepang, Selangor', country: 'Malaysia', latitude: 2.7456, longitude: 101.7099),
  Airport(iataCode: 'SZB', name: 'Sultan Abdul Aziz Shah Airport (Subang)', city: 'Subang, Selangor', country: 'Malaysia', latitude: 3.1307, longitude: 101.5490),
  Airport(iataCode: 'PEN', name: 'Penang International Airport', city: 'Bayan Lepas, Penang', country: 'Malaysia', latitude: 5.2971, longitude: 100.2769),
  Airport(iataCode: 'JHB', name: 'Senai International Airport', city: 'Johor Bahru, Johor', country: 'Malaysia', latitude: 1.6412, longitude: 103.6698),
  Airport(iataCode: 'LGK', name: 'Langkawi International Airport', city: 'Langkawi, Kedah', country: 'Malaysia', latitude: 6.3297, longitude: 99.7286),
  Airport(iataCode: 'KCH', name: 'Kuching International Airport', city: 'Kuching, Sarawak', country: 'Malaysia', latitude: 1.4847, longitude: 110.3469),
  Airport(iataCode: 'BKI', name: 'Kota Kinabalu International Airport', city: 'Kota Kinabalu, Sabah', country: 'Malaysia', latitude: 5.9372, longitude: 116.0511),
  Airport(iataCode: 'KBR', name: 'Sultan Ismail Petra Airport', city: 'Kota Bharu, Kelantan', country: 'Malaysia', latitude: 6.1670, longitude: 102.2919),
  Airport(iataCode: 'AOR', name: 'Sultan Abdul Halim Airport', city: 'Alor Setar, Kedah', country: 'Malaysia', latitude: 6.1899, longitude: 100.3980),
  Airport(iataCode: 'IPH', name: 'Sultan Azlan Shah Airport', city: 'Ipoh, Perak', country: 'Malaysia', latitude: 4.5682, longitude: 101.0922),
  Airport(iataCode: 'KTE', name: 'Kerteh Airport', city: 'Kerteh, Terengganu', country: 'Malaysia', latitude: 4.5375, longitude: 103.4269),
  Airport(iataCode: 'TGG', name: 'Sultan Mahmud Airport', city: 'Kuala Terengganu, Terengganu', country: 'Malaysia', latitude: 5.3826, longitude: 103.1017),
  Airport(iataCode: 'KUA', name: 'Kuantan Airport', city: 'Kuantan, Pahang', country: 'Malaysia', latitude: 3.7759, longitude: 103.2079),
  Airport(iataCode: 'MYY', name: 'Miri Airport', city: 'Miri, Sarawak', country: 'Malaysia', latitude: 4.3216, longitude: 113.9877),
  Airport(iataCode: 'SBW', name: 'Sibu Airport', city: 'Sibu, Sarawak', country: 'Malaysia', latitude: 2.2614, longitude: 111.9853),
  Airport(iataCode: 'BTU', name: 'Bintulu Airport', city: 'Bintulu, Sarawak', country: 'Malaysia', latitude: 3.1234, longitude: 113.0201),
  Airport(iataCode: 'LBU', name: 'Labuan Airport', city: 'Labuan', country: 'Malaysia', latitude: 5.3006, longitude: 115.2502),
  Airport(iataCode: 'SDK', name: 'Sandakan Airport', city: 'Sandakan, Sabah', country: 'Malaysia', latitude: 5.9012, longitude: 118.0592),
  Airport(iataCode: 'TWU', name: 'Tawau Airport', city: 'Tawau, Sabah', country: 'Malaysia', latitude: 4.3208, longitude: 118.1279),

  // Singapore
  Airport(iataCode: 'SIN', name: 'Singapore Changi Airport', city: 'Singapore', country: 'Singapore', latitude: 1.3644, longitude: 103.9915),

  // Indonesia
  Airport(iataCode: 'CGK', name: 'Soekarno-Hatta International Airport', city: 'Jakarta', country: 'Indonesia', latitude: -6.1256, longitude: 106.6559),
  Airport(iataCode: 'DPS', name: 'Ngurah Rai International Airport', city: 'Denpasar, Bali', country: 'Indonesia', latitude: -8.7482, longitude: 115.1671),
  Airport(iataCode: 'SUB', name: 'Juanda International Airport', city: 'Surabaya', country: 'Indonesia', latitude: -7.3798, longitude: 112.7869),

  // Thailand
  Airport(iataCode: 'BKK', name: 'Suvarnabhumi Airport', city: 'Bangkok', country: 'Thailand', latitude: 13.6900, longitude: 100.7501),
  Airport(iataCode: 'DMK', name: 'Don Mueang International Airport', city: 'Bangkok', country: 'Thailand', latitude: 13.9126, longitude: 100.6067),
  Airport(iataCode: 'HKT', name: 'Phuket International Airport', city: 'Phuket', country: 'Thailand', latitude: 8.1132, longitude: 98.3169),
  Airport(iataCode: 'CNX', name: 'Chiang Mai International Airport', city: 'Chiang Mai', country: 'Thailand', latitude: 18.7669, longitude: 98.9626),

  // Vietnam
  Airport(iataCode: 'SGN', name: 'Tan Son Nhat International Airport', city: 'Ho Chi Minh City', country: 'Vietnam', latitude: 10.8188, longitude: 106.6520),
  Airport(iataCode: 'HAN', name: 'Noi Bai International Airport', city: 'Hanoi', country: 'Vietnam', latitude: 21.2212, longitude: 105.8072),
  Airport(iataCode: 'DAD', name: 'Da Nang International Airport', city: 'Da Nang', country: 'Vietnam', latitude: 16.0439, longitude: 108.1994),

  // Philippines
  Airport(iataCode: 'MNL', name: 'Ninoy Aquino International Airport', city: 'Manila', country: 'Philippines', latitude: 14.5086, longitude: 121.0194),
  Airport(iataCode: 'CEB', name: 'Mactan-Cebu International Airport', city: 'Cebu', country: 'Philippines', latitude: 10.3075, longitude: 123.9792),

  // Japan
  Airport(iataCode: 'HND', name: 'Haneda Airport', city: 'Tokyo', country: 'Japan', latitude: 35.5494, longitude: 139.7798),
  Airport(iataCode: 'NRT', name: 'Narita International Airport', city: 'Tokyo', country: 'Japan', latitude: 35.7647, longitude: 140.3864),
  Airport(iataCode: 'KIX', name: 'Kansai International Airport', city: 'Osaka', country: 'Japan', latitude: 34.4320, longitude: 135.2304),
  Airport(iataCode: 'FUK', name: 'Fukuoka Airport', city: 'Fukuoka', country: 'Japan', latitude: 33.5859, longitude: 130.4506),

  // South Korea
  Airport(iataCode: 'ICN', name: 'Incheon International Airport', city: 'Seoul', country: 'South Korea', latitude: 37.4602, longitude: 126.4407),
  Airport(iataCode: 'GMP', name: 'Gimpo International Airport', city: 'Seoul', country: 'South Korea', latitude: 37.5583, longitude: 126.7906),
  Airport(iataCode: 'PUS', name: 'Gimhae International Airport', city: 'Busan', country: 'South Korea', latitude: 35.1795, longitude: 128.9382),

  // China
  Airport(iataCode: 'PEK', name: 'Beijing Capital International Airport', city: 'Beijing', country: 'China', latitude: 40.0799, longitude: 116.6031),
  Airport(iataCode: 'PVG', name: 'Shanghai Pudong International Airport', city: 'Shanghai', country: 'China', latitude: 31.1443, longitude: 121.8083),
  Airport(iataCode: 'CAN', name: 'Guangzhou Baiyun International Airport', city: 'Guangzhou', country: 'China', latitude: 23.3924, longitude: 113.2988),
  Airport(iataCode: 'SZX', name: "Shenzhen Bao'an International Airport", city: 'Shenzhen', country: 'China', latitude: 22.6393, longitude: 113.8107),

  // Hong Kong
  Airport(iataCode: 'HKG', name: 'Hong Kong International Airport', city: 'Hong Kong', country: 'Hong Kong', latitude: 22.3080, longitude: 113.9185),

  // Taiwan
  Airport(iataCode: 'TPE', name: 'Taiwan Taoyuan International Airport', city: 'Taipei', country: 'Taiwan', latitude: 25.0797, longitude: 121.2342),
  Airport(iataCode: 'KHH', name: 'Kaohsiung International Airport', city: 'Kaohsiung', country: 'Taiwan', latitude: 22.5771, longitude: 120.3500),

  // India
  Airport(iataCode: 'DEL', name: 'Indira Gandhi International Airport', city: 'Delhi', country: 'India', latitude: 28.5562, longitude: 77.1000),
  Airport(iataCode: 'BOM', name: 'Chhatrapati Shivaji Maharaj International Airport', city: 'Mumbai', country: 'India', latitude: 19.0896, longitude: 72.8656),
  Airport(iataCode: 'BLR', name: 'Kempegowda International Airport', city: 'Bangalore', country: 'India', latitude: 13.1989, longitude: 77.7068),

  // Australia
  Airport(iataCode: 'SYD', name: 'Sydney Kingsford Smith Airport', city: 'Sydney', country: 'Australia', latitude: -33.9399, longitude: 151.1753),
  Airport(iataCode: 'MEL', name: 'Melbourne Airport', city: 'Melbourne', country: 'Australia', latitude: -37.6733, longitude: 144.8433),
  Airport(iataCode: 'BNE', name: 'Brisbane Airport', city: 'Brisbane', country: 'Australia', latitude: -27.3842, longitude: 153.1175),
  Airport(iataCode: 'PER', name: 'Perth Airport', city: 'Perth', country: 'Australia', latitude: -31.9385, longitude: 115.9672),

  // New Zealand
  Airport(iataCode: 'AKL', name: 'Auckland Airport', city: 'Auckland', country: 'New Zealand', latitude: -37.0082, longitude: 174.7850),
  Airport(iataCode: 'CHC', name: 'Christchurch Airport', city: 'Christchurch', country: 'New Zealand', latitude: -43.4894, longitude: 172.5320),

  // United Kingdom
  Airport(iataCode: 'LHR', name: 'London Heathrow Airport', city: 'London', country: 'United Kingdom', latitude: 51.4700, longitude: -0.4543),
  Airport(iataCode: 'LGW', name: 'London Gatwick Airport', city: 'London', country: 'United Kingdom', latitude: 51.1537, longitude: -0.1821),
  Airport(iataCode: 'MAN', name: 'Manchester Airport', city: 'Manchester', country: 'United Kingdom', latitude: 53.3537, longitude: -2.2750),

  // Ireland
  Airport(iataCode: 'DUB', name: 'Dublin Airport', city: 'Dublin', country: 'Ireland', latitude: 53.4213, longitude: -6.2701),

  // France
  Airport(iataCode: 'CDG', name: 'Charles de Gaulle Airport', city: 'Paris', country: 'France', latitude: 49.0097, longitude: 2.5479),
  Airport(iataCode: 'ORY', name: 'Orly Airport', city: 'Paris', country: 'France', latitude: 48.7262, longitude: 2.3652),
  Airport(iataCode: 'NCE', name: "Nice Cote d'Azur Airport", city: 'Nice', country: 'France', latitude: 43.6584, longitude: 7.2159),

  // Germany
  Airport(iataCode: 'FRA', name: 'Frankfurt Airport', city: 'Frankfurt', country: 'Germany', latitude: 50.0379, longitude: 8.5622),
  Airport(iataCode: 'MUC', name: 'Munich Airport', city: 'Munich', country: 'Germany', latitude: 48.3538, longitude: 11.7861),
  Airport(iataCode: 'BER', name: 'Berlin Brandenburg Airport', city: 'Berlin', country: 'Germany', latitude: 52.3667, longitude: 13.5033),

  // Italy
  Airport(iataCode: 'FCO', name: 'Rome Fiumicino Airport', city: 'Rome', country: 'Italy', latitude: 41.8003, longitude: 12.2389),
  Airport(iataCode: 'MXP', name: 'Milan Malpensa Airport', city: 'Milan', country: 'Italy', latitude: 45.6306, longitude: 8.7281),

  // Spain
  Airport(iataCode: 'MAD', name: 'Adolfo Suarez Madrid-Barajas Airport', city: 'Madrid', country: 'Spain', latitude: 40.4983, longitude: -3.5676),
  Airport(iataCode: 'BCN', name: 'Barcelona-El Prat Airport', city: 'Barcelona', country: 'Spain', latitude: 41.2974, longitude: 2.0833),

  // Netherlands
  Airport(iataCode: 'AMS', name: 'Amsterdam Airport Schiphol', city: 'Amsterdam', country: 'Netherlands', latitude: 52.3086, longitude: 4.7639),

  // Switzerland
  Airport(iataCode: 'ZRH', name: 'Zurich Airport', city: 'Zurich', country: 'Switzerland', latitude: 47.4647, longitude: 8.5492),
  Airport(iataCode: 'GVA', name: 'Geneva Airport', city: 'Geneva', country: 'Switzerland', latitude: 46.2370, longitude: 6.1092),

  // United States
  Airport(iataCode: 'JFK', name: 'John F. Kennedy International Airport', city: 'New York', country: 'United States', latitude: 40.6413, longitude: -73.7781),
  Airport(iataCode: 'LAX', name: 'Los Angeles International Airport', city: 'Los Angeles', country: 'United States', latitude: 33.9416, longitude: -118.4085),
  Airport(iataCode: 'ORD', name: "O'Hare International Airport", city: 'Chicago', country: 'United States', latitude: 41.9742, longitude: -87.9073),
  Airport(iataCode: 'SFO', name: 'San Francisco International Airport', city: 'San Francisco', country: 'United States', latitude: 37.6213, longitude: -122.3790),

  // Canada
  Airport(iataCode: 'YYZ', name: 'Toronto Pearson International Airport', city: 'Toronto', country: 'Canada', latitude: 43.6777, longitude: -79.6248),
  Airport(iataCode: 'YVR', name: 'Vancouver International Airport', city: 'Vancouver', country: 'Canada', latitude: 49.1939, longitude: -123.1844),

  // United Arab Emirates
  Airport(iataCode: 'DXB', name: 'Dubai International Airport', city: 'Dubai', country: 'United Arab Emirates', latitude: 25.2532, longitude: 55.3657),
  Airport(iataCode: 'AUH', name: 'Abu Dhabi International Airport', city: 'Abu Dhabi', country: 'United Arab Emirates', latitude: 24.4330, longitude: 54.6511),

  // Saudi Arabia
  Airport(iataCode: 'RUH', name: 'King Khalid International Airport', city: 'Riyadh', country: 'Saudi Arabia', latitude: 24.9576, longitude: 46.6988),
  Airport(iataCode: 'JED', name: 'King Abdulaziz International Airport', city: 'Jeddah', country: 'Saudi Arabia', latitude: 21.6796, longitude: 39.1565),

  // Turkey
  Airport(iataCode: 'IST', name: 'Istanbul Airport', city: 'Istanbul', country: 'Turkey', latitude: 41.2753, longitude: 28.7519),

  // South Africa
  Airport(iataCode: 'JNB', name: 'O. R. Tambo International Airport', city: 'Johannesburg', country: 'South Africa', latitude: -26.1392, longitude: 28.2460),
  Airport(iataCode: 'CPT', name: 'Cape Town International Airport', city: 'Cape Town', country: 'South Africa', latitude: -33.9648, longitude: 18.6017),

  // Brazil
  Airport(iataCode: 'GRU', name: 'Sao Paulo-Guarulhos International Airport', city: 'Sao Paulo', country: 'Brazil', latitude: -23.4356, longitude: -46.4731),
  Airport(iataCode: 'GIG', name: 'Rio de Janeiro-Galeao International Airport', city: 'Rio de Janeiro', country: 'Brazil', latitude: -22.8099, longitude: -43.2506),

  // Mexico
  Airport(iataCode: 'MEX', name: 'Mexico City International Airport', city: 'Mexico City', country: 'Mexico', latitude: 19.4363, longitude: -99.0721),
  Airport(iataCode: 'CUN', name: 'Cancun International Airport', city: 'Cancun', country: 'Mexico', latitude: 21.0365, longitude: -86.8771),
];

/// Airports grouped by `Airport.country`, in the same order [kAirports] lists
/// them (so Malaysia's full state-by-state list stays first).
Map<String, List<Airport>> get kAirportsByCountry {
  final map = <String, List<Airport>>{};
  for (final a in kAirports) {
    (map[a.country] ??= []).add(a);
  }
  return map;
}

String airportLabel(String iataCode) {
  for (final a in kAirports) {
    if (a.iataCode == iataCode) return '${a.city.split(',').first} (${a.iataCode})';
  }
  return iataCode;
}
