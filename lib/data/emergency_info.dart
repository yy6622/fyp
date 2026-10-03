/// Real, static reference data for the Group Info > Emergency feature —
/// keyed by the exact country name a trip's `destination` is set to (see
/// `countries.dart`/`create_plan_wizard.dart`'s destination picker),
/// lowercased, the same convention `country_gateways.dart` already uses.
///
/// [kEmergencyNumbersByCountry] is each country's well-published local
/// emergency numbers (the same facts any travel guide or government
/// travel-advisory page lists) — not trip data, so there's nothing to
/// fetch per-trip; it just needs to be looked up by the trip's own
/// destination instead of a single number shown for every trip.
///
/// [kEmbassyInfoByCountry] is the nearest Malaysian embassy/consulate's
/// real contact details. Unlike the emergency numbers above, this isn't
/// something safe to fill in from general knowledge for every country —
/// wrong contact details for an actual emergency are worse than none — so
/// every entry here was copied verbatim from Wisma Putra's own official
/// mission directory (kln.gov.my/web/guest/overseas-missions, "OVERSEAS
/// MISSIONS — Total: 111 missions worldwide"), fetched live, not filled
/// in from general knowledge. Where a country has more than one Malaysian
/// mission (e.g. China has 6), the one in the country's main destination
/// city for this app is used — matching [kCountryGateways]' own city
/// choice where there's overlap (e.g. Beijing, not Hong Kong). [EmbassyPage]
/// falls back to a link to that same directory for any destination not in
/// this map (so far just 'malaysia' itself, which doesn't need one), never
/// guessing.
library;

class EmergencyNumbers {
  final String police;
  final String ambulance;
  final String fire;
  const EmergencyNumbers({required this.police, required this.ambulance, required this.fire});
}

const Map<String, EmergencyNumbers> kEmergencyNumbersByCountry = {
  'malaysia': EmergencyNumbers(police: '999', ambulance: '999', fire: '999'),
  'singapore': EmergencyNumbers(police: '999', ambulance: '995', fire: '995'),
  'indonesia': EmergencyNumbers(police: '110', ambulance: '119', fire: '113'),
  'thailand': EmergencyNumbers(police: '191', ambulance: '1669', fire: '199'),
  'vietnam': EmergencyNumbers(police: '113', ambulance: '115', fire: '114'),
  'philippines': EmergencyNumbers(police: '911', ambulance: '911', fire: '911'),
  'japan': EmergencyNumbers(police: '110', ambulance: '119', fire: '119'),
  'south korea': EmergencyNumbers(police: '112', ambulance: '119', fire: '119'),
  'china': EmergencyNumbers(police: '110', ambulance: '120', fire: '119'),
  'hong kong': EmergencyNumbers(police: '999', ambulance: '999', fire: '999'),
  'taiwan': EmergencyNumbers(police: '110', ambulance: '119', fire: '119'),
  'india': EmergencyNumbers(police: '112', ambulance: '102', fire: '101'),
  'australia': EmergencyNumbers(police: '000', ambulance: '000', fire: '000'),
  'new zealand': EmergencyNumbers(police: '111', ambulance: '111', fire: '111'),
  'united kingdom': EmergencyNumbers(police: '999', ambulance: '999', fire: '999'),
  'ireland': EmergencyNumbers(police: '112', ambulance: '112', fire: '112'),
  'france': EmergencyNumbers(police: '17', ambulance: '15', fire: '18'),
  'germany': EmergencyNumbers(police: '110', ambulance: '112', fire: '112'),
  'italy': EmergencyNumbers(police: '113', ambulance: '118', fire: '115'),
  'spain': EmergencyNumbers(police: '112', ambulance: '112', fire: '112'),
  'netherlands': EmergencyNumbers(police: '112', ambulance: '112', fire: '112'),
  'switzerland': EmergencyNumbers(police: '117', ambulance: '144', fire: '118'),
  'united states': EmergencyNumbers(police: '911', ambulance: '911', fire: '911'),
  'canada': EmergencyNumbers(police: '911', ambulance: '911', fire: '911'),
  'united arab emirates': EmergencyNumbers(police: '999', ambulance: '998', fire: '997'),
  'saudi arabia': EmergencyNumbers(police: '999', ambulance: '997', fire: '998'),
  'turkey': EmergencyNumbers(police: '112', ambulance: '112', fire: '112'),
  'south africa': EmergencyNumbers(police: '10111', ambulance: '10177', fire: '10177'),
  'brazil': EmergencyNumbers(police: '190', ambulance: '192', fire: '193'),
  'mexico': EmergencyNumbers(police: '911', ambulance: '911', fire: '911'),
};

/// Generic fallback for any destination not in the map above — 112 works
/// as an emergency number on most GSM phones worldwide even where it
/// isn't the official local number.
const kFallbackEmergencyNumbers = EmergencyNumbers(police: '112', ambulance: '112', fire: '112');

class EmbassyInfo {
  final String missionName;
  final String address;
  final List<String> officeLines;
  final String? emergencyPhone;
  final String email;
  const EmbassyInfo({
    required this.missionName,
    required this.address,
    required this.officeLines,
    this.emergencyPhone,
    required this.email,
  });
}

const Map<String, EmbassyInfo> kEmbassyInfoByCountry = {
  'singapore': EmbassyInfo(
    missionName: 'High Commission of Malaysia, Singapore',
    address: '301 Jervois Road, Singapore 249077',
    officeLines: ['+65 6235 0111', '+65 6887 6256'],
    email: 'mwsingapore@kln.gov.my',
  ),
  // No Malaysian mission in Bali (this app's gateway city) — nearest real
  // mission is the Embassy in Jakarta.
  'indonesia': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Jakarta',
    address: 'Jl. H.R. Rasuna Said Kav. X/6, No. 1-3, Kuningan, Jakarta Selatan 12950, Indonesia',
    officeLines: ['+62 21 522 4947'],
    emergencyPhone: '+62 813 8081 3036',
    email: 'mwjakarta@kln.gov.my',
  ),
  'thailand': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Bangkok',
    address: '33-35 South Sathorn Road, Tungmahamek, Sathorn, 10120 Bangkok, Thailand',
    officeLines: ['+66-2340-5720', '+66-2340-5731'],
    emergencyPhone: '+66-87-028-4659',
    email: 'mwbangkok@kln.gov.my',
  ),
  'vietnam': EmbassyInfo(
    missionName: 'Consulate General of Malaysia, Ho Chi Minh City',
    address: '109 Nguyen Van Huong, Thao Dien Ward, District 2, Ho Chi Minh City, Vietnam',
    officeLines: ['+84 (0)28-3829 9023'],
    emergencyPhone: '+84 (0)76 564 9660',
    email: 'mwhochiminh@kln.gov.my',
  ),
  'philippines': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Manila',
    address: '107 Tordesillas Street, Salcedo Village, Makati, Metro Manila, Philippines',
    officeLines: ['+63 2 8662 8200'],
    emergencyPhone: '+63 961 077 8113',
    email: 'MalaysianEmbassyPh@gmail.com',
  ),
  // Verified against the embassy's own page at kln.gov.my/web/jpn_tokyo.
  'japan': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Tokyo',
    address: '20-16, Nanpeidai-cho, Shibuya-ku, Tokyo 150-0036, Japan',
    officeLines: ['+81-3-3476-3840'],
    emergencyPhone: '+81-80-4322-3366',
    email: 'mwtokyo@kln.gov.my',
  ),
  'south korea': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Seoul',
    address: '129 Dokseodang-ro, Hannam-dong, Yongsan-gu, Seoul, Republic of Korea',
    officeLines: ['+82-2-2077 8600'],
    emergencyPhone: '+82 10 8974 8699',
    email: 'mwseoul@kln.gov.my',
  ),
  'china': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Beijing',
    address: "No. 2, Liang Ma Qiao Bei Jie, Chaoyang District, Beijing, People's Republic of China",
    officeLines: ['+86-10-6532-2531'],
    emergencyPhone: '+86 137 1894 2581',
    email: 'mwbeijing@kln.gov.my',
  ),
  'hong kong': EmbassyInfo(
    missionName: 'Consulate General of Malaysia, Hong Kong',
    address: '24th Floor, Malaysia Building, 47-50 Gloucester Road, Wanchai, Hong Kong',
    officeLines: ['+852 2821 0800'],
    emergencyPhone: '+852 6900 6390',
    email: 'mwhongkong@kln.gov.my',
  ),
  // Malaysia has no formal embassy in Taiwan — this is the real contact
  // point Wisma Putra's own directory lists there.
  'taiwan': EmbassyInfo(
    missionName: 'Malaysian Friendship and Trade Centre, Taipei',
    address: '8th Floor, San Ho Plastic Building, No. 102 Dunhua N. Road, Songshan District, Taipei City, Taiwan',
    officeLines: ['+886-2-2713 2626'],
    email: 'mwtaipei@kln.gov.my',
  ),
  'india': EmbassyInfo(
    missionName: 'High Commission of Malaysia, New Delhi',
    address: '50-M Satya Marg, Chanakyapuri, New Delhi, India',
    officeLines: ['+91-11-2415 9300'],
    email: 'mwdelhi@kln.gov.my',
  ),
  // No Malaysian mission in Sydney (this app's gateway city) — nearest
  // real mission is the High Commission in Canberra.
  'australia': EmbassyInfo(
    missionName: 'High Commission of Malaysia, Canberra',
    address: '7 Perth Avenue, Yarralumla, ACT 2600, Australia',
    officeLines: ['+61 2 6120 0300'],
    emergencyPhone: '+61 416 334 901',
    email: 'mwcanberra@kln.gov.my',
  ),
  // No Malaysian mission in Auckland (this app's gateway city) — nearest
  // real mission is the High Commission in Wellington.
  'new zealand': EmbassyInfo(
    missionName: 'High Commission of Malaysia, Wellington',
    address: '10 Washington Avenue, Brooklyn, Wellington, New Zealand',
    officeLines: ['+64-4-385 2439'],
    email: 'mwwellington@kln.gov.my',
  ),
  'united kingdom': EmbassyInfo(
    missionName: 'High Commission of Malaysia, London',
    address: '45-46 Belgrave Square, London SW1X 8QT, United Kingdom',
    officeLines: ['+44 (0)20 3931 6196'],
    email: 'mwlondon@kln.gov.my',
  ),
  'ireland': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Dublin',
    address: 'Level 3A-5A, Shelbourne House, Shelbourne Road, Ballsbridge, Dublin, Ireland',
    officeLines: ['+353-1-667 7280'],
    email: 'mwdublin@kln.gov.my',
  ),
  'france': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Paris',
    address: 'Tour Voltaire, 8th Floor, 1 Place des Degrés, Puteaux, France',
    officeLines: ['+33 1 45 53 11 85'],
    emergencyPhone: '+33 6 32 44 65 71',
    email: 'mwparis@kln.gov.my',
  ),
  'germany': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Berlin',
    address: 'Klingelhöferstraße 6, 10785 Berlin, Germany',
    officeLines: ['+49 (0)30 885 749-0'],
    emergencyPhone: '+49 (0)160 9188 3622',
    email: 'mwberlin@kln.gov.my',
  ),
  'italy': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Rome',
    address: 'Via Cimone 48, 00141 Roma, Italy',
    officeLines: ['+39-06-2418658'],
    email: 'mwrome@kln.gov.my',
  ),
  'spain': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Madrid',
    address: 'Avenida de los Madroños 63 bis, Madrid, Spain',
    officeLines: ['+34 91 555 0684'],
    emergencyPhone: '+34 659 89 49 43',
    email: 'mwmadrid@kln.gov.my',
  ),
  // No Malaysian mission in Amsterdam (this app's gateway city) — nearest
  // real mission is the Embassy in The Hague.
  'netherlands': EmbassyInfo(
    missionName: 'Embassy of Malaysia, The Hague',
    address: 'Rustenburgweg 2, Zuid-Holland, The Hague, Netherlands',
    officeLines: ['+31 70 350 6506'],
    emergencyPhone: '+31 6 3448 5289',
    email: 'mwthehague@kln.gov.my',
  ),
  // No Malaysian mission in Zurich (this app's gateway city) — nearest
  // real bilateral mission is the Embassy in Berne (Geneva only hosts
  // Malaysia's UN mission, not a general consular one).
  'switzerland': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Berne',
    address: 'Jungfraustrasse 1, CH-3005 Berne, Switzerland',
    officeLines: ['+41 (0)31 350 4700'],
    emergencyPhone: '+41 (0)78 222 4486',
    email: 'mwberne@kln.gov.my',
  ),
  'united states': EmbassyInfo(
    missionName: 'Consulate General of Malaysia, New York',
    address: '313 East 43rd Street, New York, NY 10017, USA',
    officeLines: ['+1 (212) 490-2722'],
    emergencyPhone: '+1 (929) 428-0794',
    email: 'mwnewyorkcg@kln.gov.my',
  ),
  // No Malaysian mission in Toronto (this app's gateway city) — nearest
  // real mission is the High Commission in Ottawa.
  'canada': EmbassyInfo(
    missionName: 'High Commission of Malaysia, Ottawa',
    address: '60 Boteler Street, Ottawa, Ontario K1N 8Y7, Canada',
    officeLines: ['+1 (613) 241-5182'],
    emergencyPhone: '+1 (343) 254-4333',
    email: 'mwottawa@kln.gov.my',
  ),
  'united arab emirates': EmbassyInfo(
    missionName: 'Consulate General of Malaysia, Dubai',
    address: 'Villa 83, Street 10D, Mankhool, Bur Dubai, United Arab Emirates',
    officeLines: ['+971-4-398 5843'],
    emergencyPhone: '+971 50 737 9196',
    email: 'dxb.cons@kln.gov.my',
  ),
  'saudi arabia': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Riyadh',
    address: 'Diplomatic Quarter, P.O. Box 94335, 11693 Riyadh, Saudi Arabia',
    officeLines: ['+966 11 488 7098'],
    email: 'mwriyadh@kln.gov.my',
  ),
  'turkey': EmbassyInfo(
    missionName: 'Consulate General of Malaysia, Istanbul',
    address: 'Esentepe Mah. Ali Kaya Sok. No:1/1B, Polat Plaza, B Blok, Kat 8, Levent/Şişli, Istanbul, Turkey',
    officeLines: ['+90-212 989 10 01'],
    emergencyPhone: '+90 531 716 05 51',
    email: 'mwistanbul@kln.gov.my',
  ),
  'south africa': EmbassyInfo(
    missionName: 'High Commission of Malaysia, Pretoria',
    address: '1007 Francis Baard Street, Arcadia, Pretoria 0083, South Africa',
    officeLines: ['+27 (0)12 763 0900'],
    email: 'mwpretoria@kln.gov.my',
  ),
  'brazil': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Brasília',
    address: 'SHIS QI 05, Chácara 62, Lago Sul, CEP 71615-904, Brasília-DF, Brazil',
    officeLines: ['+55 61 3248 5008'],
    email: 'mwbrasilia@kln.gov.my',
  ),
  'mexico': EmbassyInfo(
    missionName: 'Embassy of Malaysia, Mexico City',
    address: 'Monte Líbano 1015, Lomas de Chapultepec VIII Secc, Miguel Hidalgo, 11000 Ciudad de México, Mexico',
    officeLines: ['+52 55 5282 4656'],
    email: 'mwmexico@kln.gov.my',
  ),
};

/// Wisma Putra's own directory of every Malaysian mission abroad — the
/// honest fallback [EmbassyPage] links out to for a destination with no
/// verified entry above, instead of guessing contact details.
const kMalaysianMissionsDirectoryUrl = 'https://www.kln.gov.my/web/guest/overseas-missions';
