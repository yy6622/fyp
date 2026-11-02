// Live third-party API checks - TC30 (Duffel flight search) and TC55 (AI
// Travel Assistant, OpenAI). These call the real services with the keys in
// lib/config/secrets.dart, so they need internet on the device and working
// keys. A missing key or an API outage makes them fail; that is reported as a
// real result.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/repositories/catalog_repository.dart';
import 'package:voya/services/attraction_chat_service.dart';
import 'package:voya/services/duffel_api_service.dart';

CatalogAttraction _place(String id, String name, String category) => CatalogAttraction(
      id: id,
      favoritedBy: const [],
      name: name,
      category: category,
      rating: '4.5',
      reviews: '100',
      price: 'Free',
      image: '',
      location: 'Kuala Lumpur',
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC30 Search flights KUL to BKK returns offers with price and times', (tester) async {
    final departure = DateTime.now().add(const Duration(days: 30));
    final offers = await DuffelApiService.instance
        .searchFlights(origin: 'Kuala Lumpur', destination: 'Bangkok', departureDate: departure, adults: 1);

    expect(offers, isNotEmpty);
    final first = offers.first;
    expect(first.totalAmount, greaterThan(0));
    expect(first.arrivalAt.isAfter(first.departureAt), isTrue);
    expect(first.airlineName, isNotEmpty);
    expect(offers.every((o) => o.stops >= 0), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('TC55 AI Travel Assistant recommends real attractions from the catalog', (tester) async {
    final candidates = [
      _place('aquaria', 'Aquaria KLCC', 'Aquarium'),
      _place('klbirdpark', 'KL Bird Park', 'Park'),
      _place('petronas', 'Petronas Twin Towers', 'Landmark'),
      _place('jalanalor', 'Jalan Alor', 'Food Street'),
    ];
    final reply = await AttractionChatService.instance.sendMessage(
      destination: 'Kuala Lumpur',
      candidates: candidates,
      history: const [],
      userMessage: 'Family-friendly places in KL for kids?',
    );

    expect(reply.reply.trim(), isNotEmpty);
    expect(reply.suggestedIds, isNotEmpty, reason: 'the assistant should point at real catalog places');
    final ids = candidates.map((c) => c.id).toSet();
    expect(reply.suggestedIds.every(ids.contains), isTrue, reason: 'it must not invent places: ${reply.suggestedIds}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
