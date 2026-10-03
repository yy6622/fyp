/// Well-known real cities/areas within each of [kCountries] — offered as
/// an optional second step after picking a country in Create Plan's
/// destination picker (see `create_plan_wizard.dart`'s `_pickDestination`),
/// so a trip can be scoped to e.g. "Beijing, China" instead of just
/// "China" when the traveller already knows where specifically they're
/// going. Picking one isn't required — skipping this step keeps the trip's
/// destination as the bare country name, exactly as it worked before this
/// existed.
///
/// Keyed the same way as [kCountryGateways] (the country name, lowercased)
/// so both stay easy to cross-reference. Not every country needs an entry:
/// Singapore is a city-state with nothing meaningful to narrow down to, so
/// it's left out entirely — the picker already treats "no entry here" as
/// "skip straight to using the country name", so leaving one out doesn't
/// need any special-casing elsewhere.
///
/// Real, well-known place names only (no made-up/placeholder areas) — a
/// handful of the most recognisable cities per country, not an exhaustive
/// gazetteer (a country's full list of administrative divisions would be a
/// much longer and, for a travel app, much less useful list).
const Map<String, List<String>> kCountryAreas = {
  'malaysia': ['Kuala Lumpur', 'Penang', 'Johor Bahru', 'Malacca', 'Kota Kinabalu', 'Langkawi'],
  'indonesia': ['Bali', 'Jakarta', 'Yogyakarta', 'Surabaya', 'Bandung', 'Lombok'],
  'thailand': ['Bangkok', 'Phuket', 'Chiang Mai', 'Pattaya', 'Krabi', 'Koh Samui'],
  'vietnam': ['Ho Chi Minh City', 'Hanoi', 'Da Nang', 'Hoi An', 'Nha Trang', 'Halong Bay'],
  'philippines': ['Manila', 'Cebu', 'Boracay', 'Palawan', 'Davao', 'Baguio'],
  'japan': ['Tokyo', 'Osaka', 'Kyoto', 'Hokkaido', 'Okinawa', 'Nagoya', 'Fukuoka'],
  'south korea': ['Seoul', 'Busan', 'Jeju Island', 'Incheon', 'Daegu'],
  'china': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen', 'Chengdu', "Xi'an", 'Hangzhou'],
  'hong kong': ['Hong Kong Island', 'Kowloon', 'Lantau Island', 'New Territories'],
  'taiwan': ['Taipei', 'Kaohsiung', 'Taichung', 'Tainan', 'Hualien'],
  'india': ['Delhi', 'Mumbai', 'Bangalore', 'Goa', 'Jaipur', 'Agra', 'Kolkata'],
  'australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Gold Coast', 'Cairns'],
  'new zealand': ['Auckland', 'Wellington', 'Queenstown', 'Christchurch', 'Rotorua'],
  'united kingdom': ['London', 'Edinburgh', 'Manchester', 'Liverpool', 'Birmingham', 'Glasgow'],
  'ireland': ['Dublin', 'Cork', 'Galway', 'Killarney'],
  'france': ['Paris', 'Nice', 'Lyon', 'Marseille', 'Bordeaux', 'Strasbourg'],
  'germany': ['Berlin', 'Munich', 'Frankfurt', 'Hamburg', 'Cologne'],
  'italy': ['Rome', 'Milan', 'Venice', 'Florence', 'Naples'],
  'spain': ['Madrid', 'Barcelona', 'Seville', 'Valencia', 'Granada'],
  'netherlands': ['Amsterdam', 'Rotterdam', 'The Hague', 'Utrecht'],
  'switzerland': ['Zurich', 'Geneva', 'Lucerne', 'Interlaken', 'Bern'],
  'united states': ['New York', 'Los Angeles', 'San Francisco', 'Las Vegas', 'Chicago', 'Miami', 'Hawaii'],
  'canada': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa'],
  'united arab emirates': ['Dubai', 'Abu Dhabi', 'Sharjah'],
  'saudi arabia': ['Riyadh', 'Jeddah', 'Mecca', 'Medina'],
  'turkey': ['Istanbul', 'Antalya', 'Cappadocia', 'Izmir', 'Ankara'],
  'south africa': ['Cape Town', 'Johannesburg', 'Durban', 'Pretoria'],
  'brazil': ['Rio de Janeiro', 'Sao Paulo', 'Salvador', 'Brasilia'],
  'mexico': ['Mexico City', 'Cancun', 'Guadalajara', 'Playa del Carmen', 'Tulum'],
};
