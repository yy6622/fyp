library;

class CountryDialCode {
  final String name;
  final String iso2;
  final String dialCode; // without the leading '+'
  const CountryDialCode({required this.name, required this.iso2, required this.dialCode});

  String get flag {
    final codeUnits = iso2.toUpperCase().codeUnits;
    if (codeUnits.length != 2) return '🏳';
    const base = 0x1F1E6 - 0x41; // offset from 'A'
    return String.fromCharCodes(codeUnits.map((c) => base + c));
  }

  String get display => '$flag +$dialCode';
}

const List<CountryDialCode> kCountryDialCodes = [
  CountryDialCode(name: 'Malaysia', iso2: 'MY', dialCode: '60'),
  CountryDialCode(name: 'Singapore', iso2: 'SG', dialCode: '65'),
  CountryDialCode(name: 'Indonesia', iso2: 'ID', dialCode: '62'),
  CountryDialCode(name: 'Thailand', iso2: 'TH', dialCode: '66'),
  CountryDialCode(name: 'Vietnam', iso2: 'VN', dialCode: '84'),
  CountryDialCode(name: 'Philippines', iso2: 'PH', dialCode: '63'),
  CountryDialCode(name: 'Japan', iso2: 'JP', dialCode: '81'),
  CountryDialCode(name: 'South Korea', iso2: 'KR', dialCode: '82'),
  CountryDialCode(name: 'China', iso2: 'CN', dialCode: '86'),
  CountryDialCode(name: 'Hong Kong', iso2: 'HK', dialCode: '852'),
  CountryDialCode(name: 'Taiwan', iso2: 'TW', dialCode: '886'),
  CountryDialCode(name: 'India', iso2: 'IN', dialCode: '91'),
  CountryDialCode(name: 'Australia', iso2: 'AU', dialCode: '61'),
  CountryDialCode(name: 'New Zealand', iso2: 'NZ', dialCode: '64'),
  CountryDialCode(name: 'United Kingdom', iso2: 'GB', dialCode: '44'),
  CountryDialCode(name: 'Ireland', iso2: 'IE', dialCode: '353'),
  CountryDialCode(name: 'France', iso2: 'FR', dialCode: '33'),
  CountryDialCode(name: 'Germany', iso2: 'DE', dialCode: '49'),
  CountryDialCode(name: 'Italy', iso2: 'IT', dialCode: '39'),
  CountryDialCode(name: 'Spain', iso2: 'ES', dialCode: '34'),
  CountryDialCode(name: 'Netherlands', iso2: 'NL', dialCode: '31'),
  CountryDialCode(name: 'Switzerland', iso2: 'CH', dialCode: '41'),
  CountryDialCode(name: 'United States', iso2: 'US', dialCode: '1'),
  CountryDialCode(name: 'Canada', iso2: 'CA', dialCode: '1'),
  CountryDialCode(name: 'United Arab Emirates', iso2: 'AE', dialCode: '971'),
  CountryDialCode(name: 'Saudi Arabia', iso2: 'SA', dialCode: '966'),
  CountryDialCode(name: 'Turkey', iso2: 'TR', dialCode: '90'),
  CountryDialCode(name: 'South Africa', iso2: 'ZA', dialCode: '27'),
  CountryDialCode(name: 'Brazil', iso2: 'BR', dialCode: '55'),
  CountryDialCode(name: 'Mexico', iso2: 'MX', dialCode: '52'),
];

const CountryDialCode kDefaultDialCode = CountryDialCode(name: 'Malaysia', iso2: 'MY', dialCode: '60');

CountryDialCode? matchDialCodePrefix(String digitsOnly) {
  final sorted = [...kCountryDialCodes]..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
  for (final c in sorted) {
    if (digitsOnly.startsWith(c.dialCode)) return c;
  }
  return null;
}
