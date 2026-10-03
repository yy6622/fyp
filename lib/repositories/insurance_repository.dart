import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/insurance_models.dart';

/// Real Firestore-backed insurance catalogue. Plans are authored in the
/// admin/partner web console (admin_web/ — see
/// admin_web/partner/plans.html and admin_web/js/data.js's
/// createPlan/updatePlan/deletePlan); this repository only ever reads
/// them for the Flutter app.
///
/// Unlike [CatalogRepository]'s Explore catalogue, there is deliberately
/// no client-side seeding here: firestore.rules restricts `insurance_plans`
/// writes to a signed-in admin or the owning partner, so a rider's app
/// could never write one anyway. The console already ships its own demo
/// seeder for this (admin_web/js/seed.js's seedPartnerDemoData /
/// seedAdminDemoData, wired to a button on the partner dashboard and admin
/// insurance page) — that's the intended way to populate sample plans,
/// not a second copy of the same seed baked into the mobile app.
class InsuranceRepository {
  InsuranceRepository._();
  static final InsuranceRepository instance = InsuranceRepository._();

  CollectionReference<Map<String, dynamic>> get _plans => FirebaseFirestore.instance.collection('insurance_plans');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      FirebaseFirestore.instance.collection('insurance_transactions');

  /// Every currently-published plan, live. A partner's 'draft' plans are
  /// left out — those aren't ready for riders to see yet.
  Stream<List<InsurancePlan>> watchPlans() {
    return _plans.where('status', isEqualTo: 'active').snapshots().map(
          (snap) => snap.docs.map(_fromDoc).toList(),
        );
  }

  InsurancePlan _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final providerName = (data['providerName'] as String?)?.trim().isNotEmpty == true
        ? (data['providerName'] as String).trim()
        : 'Insurance Partner';
    final coverage = (data['coverage'] as num?)?.toInt() ?? 0;
    final premium = (data['premium'] as num?)?.toDouble() ?? 0;
    return InsurancePlan(
      id: d.id,
      partnerId: (data['partnerId'] as String?) ?? '',
      provider: providerName,
      logoText: _logoTextFor(providerName),
      logoColor: _logoColorFor(providerName),
      name: (data['name'] as String?)?.trim().isNotEmpty == true ? (data['name'] as String).trim() : providerName,
      coverage: 'Medical Coverage up to RM ${_formatThousands(coverage)}',
      price: 'RM ${premium % 1 == 0 ? premium.toStringAsFixed(0) : premium.toStringAsFixed(2)}',
      category: insuranceCategoryFromTripType((data['tripType'] as String?) ?? 'Single Trip'),
    );
  }

  /// The console doesn't store a logo glyph/color for a plan — the round
  /// badge on [InsurancePlanCard]/[InsurancePlanTile] needs *something*
  /// per plan, so both are derived deterministically from the provider's
  /// name, so the same provider always gets the same badge without a
  /// whole logo-upload feature.
  String _logoTextFor(String providerName) {
    final words = providerName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return words.take(2).map((w) => w.substring(0, 1).toUpperCase()).join();
  }

  static const _logoPalette = [
    Color(0xFF0B3B8C),
    Color(0xFF1E88C7),
    Color(0xFF3AA089),
    Color(0xFFC98A4B),
    Color(0xFFB05A7A),
    Color(0xFF4A78D0),
  ];

  Color _logoColorFor(String providerName) {
    final hash = providerName.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return _logoPalette[hash % _logoPalette.length];
  }

  String _formatThousands(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// Records a real purchase so it shows up in the partner console's
  /// Transactions list (admin_web/partner/transactions.html via
  /// listTransactions) — same collection/shape the console itself writes
  /// to for a manually-logged sale, just with `channel: 'Mobile App'` and
  /// a real `buyerId` linking it back to the rider who bought it here.
  Future<void> recordPurchase({
    required InsurancePlan plan,
    required String buyerId,
    required String customerName,
    required String customerEmail,
    required double premium,
    String destination = '',
  }) {
    return _transactions.add({
      'buyerId': buyerId,
      'planId': plan.id,
      'partnerId': plan.partnerId,
      'providerName': plan.provider,
      'planName': plan.name,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'premium': premium,
      'status': 'paid',
      'destination': destination,
      'channel': 'Mobile App',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
