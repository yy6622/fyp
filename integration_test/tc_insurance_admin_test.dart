// Insurance, Emergency and Administration data paths -
// TC34, TC36, TC36b, TC42, TC45, TC46, TC56, TC62, TC67, TC75 (FR77 claim), TC76 (refund window).
//
// The partner/admin side runs in the web console; here the same Firestore
// writes the console makes (status updates) are made as that signed-in role,
// so the real security rules decide what is allowed.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/repositories/catalog_repository.dart';
import 'package:voya/repositories/country_emergency_repository.dart';
import 'package:voya/repositories/insurance_repository.dart';

import 'helpers/test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestUser traveller, partner, admin;
  late String txnId;
  final insurance = InsuranceRepository.instance;
  late final db = FirebaseFirestore.instance; // created after initTestEnv()

  setUpAll(() async {
    await initTestEnv();
    await resetEmulators();
    admin = await createTraveller('Admin Ada');
    partner = await createTraveller('Partner Pat');
    traveller = await createTraveller('Traveller Tom');
    await seedDoc('admins/${admin.uid}', {'email': admin.email, 'role': 'admin'});
    await seedDoc('insurance_partners/${partner.uid}', {
      'companyName': 'Safe Travels Bhd',
      'email': partner.email,
      'status': 'approved',
    });
    await seedDoc('insurance_plans/plan1', {
      'name': 'Basic Travel Plan',
      'providerName': 'Safe Travels Bhd',
      'partnerId': partner.uid,
      'premium': 45.0,
      'coverage': 100000,
      'tripType': 'Single Trip',
      'status': 'active',
    });
    await seedDoc('country_emergency_info/thailand', {'police': '191', 'ambulance': '1669', 'fire': '199'});
  });

  testWidgets('TC34 A traveller buys a plan and the partner sees the transaction', (tester) async {
    await signInAs(traveller);
    final plans = await insurance.watchPlans().first;
    final plan = plans.firstWhere((p) => p.id == 'plan1');
    expect(plan.name, 'Basic Travel Plan');

    final start = DateTime.now().add(const Duration(days: 30));
    txnId = await insurance.recordPurchase(
      plan: plan,
      buyerId: traveller.uid,
      customerName: traveller.name,
      customerEmail: traveller.email,
      premium: 45,
      travelStart: start,
      travelEnd: start.add(const Duration(days: 4)),
      destination: 'Bangkok, Thailand',
    );
    final txn = await insurance.getTransaction(txnId);
    expect(txn?.status, 'paid');
    expect(txn?.partnerId, partner.uid);

    await signInAs(partner);
    final seen = await db.collection('insurance_transactions').doc(txnId).get();
    expect(seen.data()?['buyerId'], traveller.uid, reason: 'the partner console can read its own transaction');
  });

  testWidgets('TC75 A traveller files a claim and the partner approves it (FR77, FR90)', (tester) async {
    await signInAs(traveller);
    final txn = (await insurance.getTransaction(txnId))!;
    final ref = await insurance.fileClaim(transaction: txn, category: 'Medical', amount: 320, description: 'Clinic visit');
    expect(ref, startsWith('CLM'));

    final claims = await ownerList('claims');
    final claimId = claims.firstWhere((c) => c['claimRef'] == ref)['id'] as String;
    expect(claims.firstWhere((c) => c['id'] == claimId)['status'], 'new');

    await signInAs(partner);
    await db.collection('claims').doc(claimId).update({'status': 'approved'});

    await signInAs(traveller);
    final mine = await db.collection('claims').doc(claimId).get();
    expect(mine.data()?['status'], 'approved');
  });

  testWidgets('TC62 A partner approves a refund and the traveller sees it', (tester) async {
    await signInAs(traveller);
    final txn = (await insurance.getTransaction(txnId))!;
    final ref = await insurance.requestRefund(transaction: txn, category: 'Trip cancelled', reason: 'Flight cancelled');
    final refundId = (await ownerList('refunds')).firstWhere((r) => r['refundRef'] == ref)['id'] as String;

    await signInAs(partner);
    await db.collection('refunds').doc(refundId).update({'status': 'approved'});

    await signInAs(traveller);
    expect((await db.collection('refunds').doc(refundId).get()).data()?['status'], 'approved');
  });

  testWidgets('TC76 A refund is refused once the travel period has started', (tester) async {
    await signInAs(traveller);
    final plan = (await insurance.watchPlans().first).firstWhere((p) => p.id == 'plan1');
    final started = DateTime.now().subtract(const Duration(days: 1));
    final id = await insurance.recordPurchase(
      plan: plan,
      buyerId: traveller.uid,
      customerName: traveller.name,
      customerEmail: traveller.email,
      premium: 45,
      travelStart: started,
      travelEnd: started.add(const Duration(days: 3)),
    );
    final txn = (await insurance.getTransaction(id))!;
    await expectLater(
      insurance.requestRefund(transaction: txn, category: 'Changed mind'),
      throwsA(isA<InsuranceEligibilityException>()),
    );
  });

  testWidgets('TC36 A suspended partner cannot publish plans', (tester) async {
    await seedDoc('insurance_partners/${partner.uid}', {
      'companyName': 'Safe Travels Bhd',
      'email': partner.email,
      'status': 'suspended',
    });
    await signInAs(partner);
    await expectDenied(
      () => db.collection('insurance_plans').add({
        'name': 'New Plan',
        'partnerId': partner.uid,
        'premium': 30.0,
        'status': 'active',
      }),
      reason: 'suspended partner publishes a plan',
    );
  });

  testWidgets('TC36b A suspended partner\'s plans are hidden from travellers', (tester) async {
    // FR86 "disable insurance providers": plans are listed only while their
    // partner is approved (TC36 just suspended this partner).
    await signInAs(traveller);
    final plans = await insurance.watchPlans().first;
    expect(plans.map((p) => p.id), isNot(contains('plan1')));
  });

  testWidgets('TC42 Emergency numbers for the trip destination', (tester) async {
    await signInAs(traveller);
    final info = await CountryEmergencyRepository.instance.forDestination('Bangkok, Thailand');
    expect(info.police, '191');
    expect(info.ambulance, '1669');
    expect(info.isGenericFallback, isFalse);
  });

  testWidgets('TC46 Admin edits emergency info and travellers see the new number', (tester) async {
    await signInAs(traveller);
    await expectDenied(
      () => db.collection('country_emergency_info').doc('thailand').update({'police': '000'}),
      reason: 'a traveller edits emergency info',
    );

    await signInAs(admin);
    await db.collection('country_emergency_info').doc('thailand').update({'police': '1155'});

    await signInAs(traveller);
    final info = await CountryEmergencyRepository.instance.forDestination('Bangkok, Thailand');
    expect(info.police, '1155');
  });

  testWidgets('TC56 Reporting a new attraction stores it as pending', (tester) async {
    await signInAs(traveller);
    await CatalogRepository.instance.submitAttractionReport(
      authorId: traveller.uid,
      authorName: traveller.name,
      name: 'Hidden Waterfall',
      location: 'Gombak, Selangor',
      description: 'Small waterfall behind the village',
    );
    final reports = await ownerList('attraction_reports');
    final r = reports.firstWhere((x) => x['name'] == 'Hidden Waterfall');
    expect(r['status'], 'pending');
    expect(r['authorId'], traveller.uid);
  });

  testWidgets('TC45 / TC67 Admin-only data is refused to travellers and partners', (tester) async {
    for (final user in [traveller, partner]) {
      await signInAs(user);
      await expectDenied(() => db.collection('admins').doc(user.uid).set({'role': 'admin'}),
          reason: '${user.name} makes themselves admin');
      await expectDenied(() => db.collection('moderation_log').get(), reason: '${user.name} reads moderation log');
      await expectDenied(() => db.collection('post_view_stats').get(), reason: '${user.name} reads admin statistics');
    }
    await signInAs(admin);
    await db.collection('moderation_log').get();
    expect(FirebaseAuth.instance.currentUser?.uid, admin.uid);
  });
}
