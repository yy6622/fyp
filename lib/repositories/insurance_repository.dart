import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/insurance_models.dart';

/// Thrown by [InsuranceRepository.requestRefund] when the stored travel
/// period rules the request out (already started/over) — distinct from a
/// generic Exception so the UI can show the real reason rather than a
/// bare "failed" message.
class InsuranceEligibilityException implements Exception {
  final String message;
  const InsuranceEligibilityException(this.message);
  @override
  String toString() => message;
}

/// Real Firestore-backed insurance catalogue. Plans are authored in the
/// admin/partner web console (admin_web/ — see
/// admin_web/partner/plans.html and admin_web/js/data.js's
/// createPlan/updatePlan/deletePlan); this repository only ever reads
/// them for the Flutter app.
///
/// Unlike [CatalogRepository]'s Explore catalogue, there is deliberately
/// no client-side seeding here: firestore.rules restricts `insurance_plans`
/// writes to a signed-in admin or the owning partner, so a rider's app
/// could never write one anyway. A partner populates real plans through
/// admin_web/partner/plans.html's own form — there is no demo seeder any
/// more (the console used to ship one; it was removed).
class InsuranceRepository {
  InsuranceRepository._();
  static final InsuranceRepository instance = InsuranceRepository._();

  CollectionReference<Map<String, dynamic>> get _plans => FirebaseFirestore.instance.collection('insurance_plans');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      FirebaseFirestore.instance.collection('insurance_transactions');
  // Same collections the partner console's admin_web/js/data.js
  // createClaim/createRefund write to and claim-detail.html/
  // refund-detail.html read from — see firestore.rules' claims/{id} and
  // refunds/{id} blocks for the access rules already written for them.
  CollectionReference<Map<String, dynamic>> get _claims => FirebaseFirestore.instance.collection('claims');
  CollectionReference<Map<String, dynamic>> get _refunds => FirebaseFirestore.instance.collection('refunds');

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
    final logoUrl = (data['providerLogoUrl'] as String?)?.trim();
    // Partner-authored on plans.html's "Key coverage" / "Highlights"
    // fields — a plan saved before those existed just has neither array
    // in Firestore at all, which the ?? const [] below treats the same
    // as a partner leaving them blank: hidden on the detail page, not
    // padded out with the old fixed 5-item list.
    final coverageItems = ((data['coverageItems'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => InsuranceCoverageItem(
              label: ((m['label'] as String?) ?? '').trim(),
              amount: (m['amount'] as num?)?.toDouble() ?? 0,
            ))
        .where((c) => c.label.isNotEmpty)
        .toList();
    final highlights = ((data['highlights'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return InsurancePlan(
      id: d.id,
      partnerId: (data['partnerId'] as String?) ?? '',
      provider: providerName,
      logoText: _logoTextFor(providerName),
      logoColor: _logoColorFor(providerName),
      logoUrl: (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null,
      name: (data['name'] as String?)?.trim().isNotEmpty == true ? (data['name'] as String).trim() : providerName,
      coverage: 'Medical Coverage up to RM ${_formatThousands(coverage)}',
      price: 'RM ${premium % 1 == 0 ? premium.toStringAsFixed(0) : premium.toStringAsFixed(2)}',
      category: insuranceCategoryFromTripType((data['tripType'] as String?) ?? 'Single Trip'),
      coverageItems: coverageItems,
      highlights: highlights,
    );
  }

  /// Fallback for when a partner hasn't uploaded a real logo (or a plan
  /// was saved before `providerLogoUrl` existed): the round badge on
  /// [InsurancePlanCard]/[InsurancePlanTile] still needs *something* per
  /// plan, so these are derived deterministically from the provider's
  /// name, so the same provider always gets the same badge.
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
  Future<String> recordPurchase({
    required InsurancePlan plan,
    required String buyerId,
    required String customerName,
    required String customerEmail,
    required double premium,
    // The real period this policy covers (see TravellerDetailsController),
    // stored so a later refund request can be checked against it instead
    // of trusting whatever the rider claims at refund time.
    required DateTime travelStart,
    required DateTime travelEnd,
    String destination = '',
  }) async {
    final doc = await _transactions.add({
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
      'travelStart': Timestamp.fromDate(travelStart),
      'travelEnd': Timestamp.fromDate(travelEnd),
      'channel': 'Mobile App',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // The new doc's id links this transaction back to the booking history
    // row (BookingEntry.transactionId) and the trip's insurance card
    // (TripInsurance.transactionId), so either entry point can later open
    // the real Claim/Refund flow against this exact purchase.
    return doc.id;
  }

  /// One real purchase, by id — used to pre-fill the Claim/Refund forms
  /// with real stored values (never re-typed) and to check refund
  /// eligibility against the real stored travel dates.
  Future<InsuranceTransaction?> getTransaction(String id) async {
    final doc = await _transactions.doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return InsuranceTransaction(
      id: doc.id,
      buyerId: (data['buyerId'] as String?) ?? '',
      partnerId: (data['partnerId'] as String?) ?? '',
      providerName: (data['providerName'] as String?) ?? '',
      planName: (data['planName'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      customerEmail: (data['customerEmail'] as String?) ?? '',
      premium: (data['premium'] as num?)?.toDouble() ?? 0,
      status: (data['status'] as String?) ?? '',
      destination: (data['destination'] as String?) ?? '',
      travelStart: (data['travelStart'] as Timestamp?)?.toDate(),
      travelEnd: (data['travelEnd'] as Timestamp?)?.toDate(),
    );
  }

  /// `CLM-<year>-<5 digits>` / `RFD-<year>-<5 digits>` — same shape as the
  /// partner console's own newClaimRef()/newRefundRef()
  /// (admin_web/js/data.js), generated here instead since a rider-filed
  /// claim/refund never goes through that JS helper. claim-detail.html/
  /// refund-detail.html display this ref with no fallback, so it must
  /// always be set.
  String _newRef(String prefix) {
    final year = DateTime.now().year;
    final n = 10000 + Random().nextInt(90000);
    return '$prefix-$year-$n';
  }

  /// Files a real claim against a real past purchase — writes to the same
  /// `claims` collection and shape the partner console's createClaim()
  /// writes (see admin_web/js/data.js), so it shows up in the partner's
  /// console exactly like a manually-logged one. [amount] is what the
  /// rider is claiming for this incident (medical bill, baggage loss,
  /// etc.) — a real figure they enter, validated as a positive number by
  /// the caller (see FileClaimPage._submit), never fabricated here. The
  /// partner reviews and approves/rejects every claim by hand regardless,
  /// same as a manually-entered one.
  Future<String> fileClaim({
    required InsuranceTransaction transaction,
    required String category,
    required double amount,
    String description = '',
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final claimRef = _newRef('CLM');
    await _claims.add({
      'buyerId': transaction.buyerId,
      'transactionId': transaction.id,
      'partnerId': transaction.partnerId,
      'providerName': transaction.providerName,
      'policyholderName': transaction.customerName,
      'policyholderEmail': transaction.customerEmail,
      'planName': transaction.planName,
      'category': category,
      'amount': amount,
      'description': description,
      'documents': const [],
      'claimRef': claimRef,
      'status': 'new',
      'timeline': [
        {'status': 'new', 'at': nowIso, 'note': 'Claim submitted'}
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // The human-readable ref (not the Firestore doc id) is what the rider
    // sees — it's the same CLM-year-##### shown throughout the partner
    // console, so a rider quoting it back to support actually means
    // something there.
    return claimRef;
  }

  /// Requests a refund for a real past purchase — only allowed strictly
  /// before the stored travel period begins (the user's own requirement:
  /// a refund makes sense before the trip, not mid-trip or after). A
  /// transaction with no stored travel dates (bought before that field
  /// existed) is let through rather than blocked outright — there's no
  /// real date to check it against, and the partner still reviews every
  /// request by hand on the console side, so this doesn't bypass any
  /// real control.
  ///
  /// [amount] is always the real premium actually paid — a refund gives
  /// back what was paid, not a rider-typed figure — so this repository
  /// takes it from [transaction] itself rather than a parameter.
  Future<String> requestRefund({
    required InsuranceTransaction transaction,
    required String category,
    String reason = '',
  }) async {
    final start = transaction.travelStart;
    if (start != null && !DateTime.now().isBefore(start)) {
      throw InsuranceEligibilityException(
        'This policy\'s travel period has already begun, so it can no longer be refunded.',
      );
    }
    final nowIso = DateTime.now().toIso8601String();
    final refundRef = _newRef('RFD');
    await _refunds.add({
      'buyerId': transaction.buyerId,
      'transactionId': transaction.id,
      'partnerId': transaction.partnerId,
      'providerName': transaction.providerName,
      'policyholderName': transaction.customerName,
      'policyholderEmail': transaction.customerEmail,
      'planName': transaction.planName,
      'category': category,
      'amount': transaction.premium,
      'reason': reason,
      'documents': const [],
      'refundRef': refundRef,
      'status': 'new',
      'timeline': [
        {'status': 'new', 'at': nowIso, 'note': 'Refund requested'}
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return refundRef;
  }
}
