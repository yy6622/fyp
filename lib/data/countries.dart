class Country {
  final String name;
  final String code;
  final String currencyCode; // ISO 4217
  final String currencySymbol;
  const Country({required this.name, required this.code, required this.currencyCode, required this.currencySymbol});
}

const List<Country> kCountries = [
  Country(name: 'Malaysia', code: 'MY', currencyCode: 'MYR', currencySymbol: 'RM'),
  Country(name: 'Singapore', code: 'SG', currencyCode: 'SGD', currencySymbol: 'S\$'),
  Country(name: 'Indonesia', code: 'ID', currencyCode: 'IDR', currencySymbol: 'Rp'),
  Country(name: 'Thailand', code: 'TH', currencyCode: 'THB', currencySymbol: '฿'),
  Country(name: 'Vietnam', code: 'VN', currencyCode: 'VND', currencySymbol: '₫'),
  Country(name: 'Philippines', code: 'PH', currencyCode: 'PHP', currencySymbol: '₱'),
  Country(name: 'Japan', code: 'JP', currencyCode: 'JPY', currencySymbol: '¥'),
  Country(name: 'South Korea', code: 'KR', currencyCode: 'KRW', currencySymbol: '₩'),
  Country(name: 'China', code: 'CN', currencyCode: 'CNY', currencySymbol: '¥'),
  Country(name: 'Hong Kong', code: 'HK', currencyCode: 'HKD', currencySymbol: 'HK\$'),
  Country(name: 'Taiwan', code: 'TW', currencyCode: 'TWD', currencySymbol: 'NT\$'),
  Country(name: 'India', code: 'IN', currencyCode: 'INR', currencySymbol: '₹'),
  Country(name: 'Australia', code: 'AU', currencyCode: 'AUD', currencySymbol: 'A\$'),
  Country(name: 'New Zealand', code: 'NZ', currencyCode: 'NZD', currencySymbol: 'NZ\$'),
  Country(name: 'United Kingdom', code: 'GB', currencyCode: 'GBP', currencySymbol: '£'),
  Country(name: 'Ireland', code: 'IE', currencyCode: 'EUR', currencySymbol: '€'),
  Country(name: 'France', code: 'FR', currencyCode: 'EUR', currencySymbol: '€'),
  Country(name: 'Germany', code: 'DE', currencyCode: 'EUR', currencySymbol: '€'),
  Country(name: 'Italy', code: 'IT', currencyCode: 'EUR', currencySymbol: '€'),
  Country(name: 'Spain', code: 'ES', currencyCode: 'EUR', currencySymbol: '€'),
  Country(name: 'Netherlands', code: 'NL', currencyCode: 'EUR', currencySymbol: '€'),
  Country(name: 'Switzerland', code: 'CH', currencyCode: 'CHF', currencySymbol: 'CHF'),
  Country(name: 'United States', code: 'US', currencyCode: 'USD', currencySymbol: '\$'),
  Country(name: 'Canada', code: 'CA', currencyCode: 'CAD', currencySymbol: 'C\$'),
  Country(name: 'United Arab Emirates', code: 'AE', currencyCode: 'AED', currencySymbol: 'AED'),
  Country(name: 'Saudi Arabia', code: 'SA', currencyCode: 'SAR', currencySymbol: 'SAR'),
  Country(name: 'Turkey', code: 'TR', currencyCode: 'TRY', currencySymbol: '₺'),
  Country(name: 'South Africa', code: 'ZA', currencyCode: 'ZAR', currencySymbol: 'R'),
  Country(name: 'Brazil', code: 'BR', currencyCode: 'BRL', currencySymbol: 'R\$'),
  Country(name: 'Mexico', code: 'MX', currencyCode: 'MXN', currencySymbol: 'MX\$'),
];

const Set<String> kCountriesWithCatalogData = {
  'MY', // Malaysia
  'SG', // Singapore
  'ID', // Indonesia
  'TH', // Thailand
  'VN', // Vietnam
  'JP', // Japan
  'KR', // South Korea
  'CN', // China
  'GB', // United Kingdom
  'DE', // Germany
  'IT', // Italy
  'ES', // Spain
  'NL', // Netherlands
  'TR', // Turkey
  'MX', // Mexico
};

List<Country> get kDestinationCountries => kCountries.where((c) => kCountriesWithCatalogData.contains(c.code)).toList();

class CurrencyOption {
  final String code;
  final String symbol;
  const CurrencyOption({required this.code, required this.symbol});
}

List<CurrencyOption> get kCurrencies {
  final seen = <String>{};
  final list = <CurrencyOption>[];
  for (final c in kCountries) {
    if (seen.add(c.currencyCode)) {
      list.add(CurrencyOption(code: c.currencyCode, symbol: c.currencySymbol));
    }
  }
  return list;
}
