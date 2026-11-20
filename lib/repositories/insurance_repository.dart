import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/insurance_models.dart';

class InsuranceEligibilityException implements Exception {
  final String message;
  const InsuranceEligibilityException(this.message);
  @override
  String toString() => message;
}

class InsuranceRepository {
  InsuranceRepository._();
  static final InsuranceRepository instance = InsuranceRepository._();

  CollectionReference<Map<String, dynamic>> get _plans => FirebaseFirestore.instance.collection('insurance_plans');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      FirebaseFirestore.instance.collection('insurance_transactions');
  CollectionReference<Map<String, dynamic>> get _claims => FirebaseFirestore.instance.collection('claims');
  CollectionReference<Map<String, dynamic>> get _refunds => FirebaseFirestore.instance.collection('refunds');

  CollectionReference<Map<String, dynamic>> get _partners =>
      FirebaseFirestore.instance.collection('insurance_partners');

  Stream<List<InsurancePartner>> watchApprovedPartners() {
    return _partners.where('status', isEqualTo: 'approved').snapshots().asyncMap((snap) async {
      final planCounts = await _activePlanCountsByPartner();
      return snap.docs.map((d) => _partnerFromDoc(d, planCounts[d.id] ?? 0)).toList()
        ..sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
    });
  }

  Future<Map<String, int>> _activePlanCountsByPartner() async {
    final snap = await _plans.where('status', whereIn: ['active', 'published']).get();
    final counts = <String, int>{};
    for (final d in snap.docs) {
      final partnerId = (d.data()['partnerId'] as String?) ?? '';
      if (partnerId.isEmpty) continue;
      counts[partnerId] = (counts[partnerId] ?? 0) + 1;
    }
    return counts;
  }

  InsurancePartner _partnerFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d, int activePlanCount) {
    final data = d.data();
    final companyName =
        (data['companyName'] as String?)?.trim().isNotEmpty == true ? (data['companyName'] as String).trim() : 'Insurance Partner';
    final logoUrl = (data['logoUrl'] as String?)?.trim();
    return InsurancePartner(
      id: d.id,
      companyName: companyName,
      logoText: _logoTextFor(companyName),
      logoColor: _logoColorFor(companyName),
      logoUrl: (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null,
      registrationNumber: (data['registrationNumber'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      supportEmail: (data['supportEmail'] as String?) ?? '',
      activePlanCount: activePlanCount,
    );
  }

  Stream<List<InsurancePlan>> watchPlans() {
    return _plans.where('status', whereIn: ['active', 'published']).snapshots().asyncMap((snap) async {
      final plans = snap.docs.map(_fromDoc).whereType<InsurancePlan>().toList();
      final hidden = await _partnersNotApproved(plans.map((p) => p.partnerId));
      return plans.where((p) => !hidden.contains(p.partnerId)).toList();
    });
  }

  Future<InsurancePlan?> getPlan(String id) async {
    final snap = await _plans.doc(id).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    // A traveller can land on a single plan directly -- most notably a
    // plan card a partner sent in chat -- without going through the
    // browse-list query above, which already filters to
    // whereIn: ['active', 'published']. Without the same filter here, a
    // plan the partner or admin has since suspended (or that was never
    // published) stayed fully viewable and buyable through that chat
    // link even though it correctly disappeared from the normal list.
    final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
    if (status != 'active' && status != 'published') return null;
    final partnerId = (data['partnerId'] as String?) ?? '';
    final hidden = await _partnersNotApproved([partnerId]);
    if (hidden.contains(partnerId)) return null;
    return _fromDoc(snap);
  }

  /// Partner ids (from [partnerIds]) whose status is set and is not "approved".
  Future<Set<String>> _partnersNotApproved(Iterable<String> partnerIds) async {
    final ids = partnerIds.where((id) => id.isNotEmpty).toSet().toList();
    final hidden = <String>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, min(i + 30, ids.length));
      try {
        final snap = await FirebaseFirestore.instance
            .collection('insurance_partners')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final status = (d.data()['status'] as String?)?.trim().toLowerCase();
          if (status != null && status.isNotEmpty && status != 'approved') hidden.add(d.id);
        }
      } catch (_) {
        // Partner status unavailable (e.g. offline): show the plans rather than none.
      }
    }
    return hidden;
  }

  InsurancePlan? _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    if (data == null) return null;
    final providerName = (data['providerName'] as String?)?.trim().isNotEmpty == true
        ? (data['providerName'] as String).trim()
        : 'Insurance Partner';
    final coverage = (data['coverage'] as num?)?.toInt() ?? 0;
    final premium = (data['premium'] as num?)?.toDouble() ?? 0;
    final logoUrl = (data['providerLogoUrl'] as String?)?.trim();
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
    final eligibleCountries = ((data['eligibleCountries'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final eligibleDestinations = ((data['eligibleDestinations'] as List?) ?? const [])
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
      category: insuranceCategoryFromTripType((data['tripType'] as String?) ?? 'Basic'),
      coverageItems: coverageItems,
      highlights: highlights,
      eligibleCountries: eligibleCountries,
      eligibleDestinations: eligibleDestinations,
      minAge: (data['minAge'] as num?)?.toInt(),
      maxAge: (data['maxAge'] as num?)?.toInt(),
      minTripDurationDays: (data['minTripDurationDays'] as num?)?.toInt(),
      maxTripDurationDays: (data['maxTripDurationDays'] as num?)?.toInt(),
    );
  }

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

  Future<String> recordPurchase({
    required InsurancePlan plan,
    required String buyerId,
    required String customerName,
    required String customerEmail,
    required double premium,
    String currencyCode = 'MYR',
    required DateTime travelStart,
    required DateTime travelEnd,
    String destination = '',
    String policyNumber = '',
    String coverage = '',
    String travellerName = '',
    String travellerIdNumber = '',
    String travellerEmail = '',
    String travellerPhone = '',
  }) async {
    final doc = await _transactions.add({
      'txnRef': _newRef('TXN'),
      'buyerId': buyerId,
      'planId': plan.id,
      'partnerId': plan.partnerId,
      'providerName': plan.provider,
      'planName': plan.name,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'premium': premium,
      'currencyCode': currencyCode,
      'status': 'paid',
      'destination': destination,
      'travelStart': Timestamp.fromDate(travelStart),
      'travelEnd': Timestamp.fromDate(travelEnd),
      'channel': 'Mobile App',
      'policyNumber': policyNumber,
      'coverage': coverage,
      'travellerName': travellerName,
      'travellerIdNumber': travellerIdNumber,
      'travellerEmail': travellerEmail,
      'travellerPhone': travellerPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  InsuranceTransaction _transactionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InsuranceTransaction(
      id: doc.id,
      buyerId: (data['buyerId'] as String?) ?? '',
      partnerId: (data['partnerId'] as String?) ?? '',
      providerName: (data['providerName'] as String?) ?? '',
      planName: (data['planName'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      customerEmail: (data['customerEmail'] as String?) ?? '',
      premium: (data['premium'] as num?)?.toDouble() ?? 0,
      currencyCode: (data['currencyCode'] as String?) ?? '',
      status: (data['status'] as String?) ?? '',
      destination: (data['destination'] as String?) ?? '',
      travelStart: (data['travelStart'] as Timestamp?)?.toDate(),
      travelEnd: (data['travelEnd'] as Timestamp?)?.toDate(),
      txnRef: (data['txnRef'] as String?) ?? '',
      policyNumber: (data['policyNumber'] as String?) ?? '',
      coverage: (data['coverage'] as String?) ?? '',
      travellerName: (data['travellerName'] as String?) ?? '',
      travellerIdNumber: (data['travellerIdNumber'] as String?) ?? '',
      travellerEmail: (data['travellerEmail'] as String?) ?? '',
      travellerPhone: (data['travellerPhone'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<InsuranceTransaction?> getTransaction(String id) async {
    final doc = await _transactions.doc(id).get();
    if (!doc.exists) return null;
    if (doc.data() == null) return null;
    return _transactionFromDoc(doc);
  }

  Stream<List<InsuranceTransaction>> watchTransactionsForBuyer(String buyerId) {
    return _transactions.where('buyerId', isEqualTo: buyerId).snapshots().map((snap) {
      final list = snap.docs.map(_transactionFromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  String _newRef(String prefix) {
    final year = DateTime.now().year;
    final n = 10000 + Random().nextInt(90000);
    return '$prefix-$year-$n';
  }

  /// An application is already filed even while the partner is reviewing it.
  /// Legacy records have random IDs; newer records use the transaction ID.
  Future<bool> hasClaimRequest(String transactionId) async {
    if (transactionId.isEmpty) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const InsuranceEligibilityException('Please sign in to review your insurance claim.');
    }
    if ((await _claims.doc(transactionId).get()).exists) return true;
    // Restrict the query by buyerId. The old transactionId-only query may be
    // denied by Firestore rules that permit a traveller to read only their own
    // documents. Filter by transactionId locally to avoid a composite index.
    final snap = await _claims.where('buyerId', isEqualTo: uid).get();
    return snap.docs.any((doc) => doc.data()['transactionId'] == transactionId);
  }

  Future<String> fileClaim({
    required InsuranceTransaction transaction,
    required String category,
    String description = '',
    List<String> documents = const [],
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != transaction.buyerId) {
      throw const InsuranceEligibilityException('Only the policy buyer can submit a claim.');
    }
    if (documents.where((url) => url.trim().isNotEmpty).isEmpty) {
      throw const InsuranceEligibilityException('Please upload at least one supporting document.');
    }
    // Check the older random-ID claims before attempting to create a new one.
    if (await hasClaimRequest(transaction.id)) {
      throw const InsuranceEligibilityException('A claim was already submitted for this policy. Open Claim Status to review it.');
    }
    final nowIso = DateTime.now().toIso8601String();
    final claimRef = _newRef('CLM');
    final claimDoc = _claims.doc(transaction.id);
    final transactionDoc = _transactions.doc(transaction.id);
    // A deterministic document ID prevents two concurrent submissions from
    // creating duplicate claims when both passed the earlier legacy check.
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final purchase = await tx.get(transactionDoc);
      final prior = await tx.get(claimDoc);
      final data = purchase.data();
      if (data == null || data['buyerId'] != uid) {
        throw const InsuranceEligibilityException('Insurance purchase not found for this user.');
      }
      if (prior.exists) {
        throw const InsuranceEligibilityException('A claim was already submitted for this policy.');
      }
      tx.set(claimDoc, {
        'buyerId': uid,
        'transactionId': transaction.id,
        'partnerId': data['partnerId'] ?? transaction.partnerId,
        'providerName': data['providerName'] ?? transaction.providerName,
        'policyholderName': data['customerName'] ?? transaction.customerName,
        'policyholderEmail': data['customerEmail'] ?? transaction.customerEmail,
        'planName': data['planName'] ?? transaction.planName,
        'category': category,
        'amount': null,
        'currencyCode': data['currencyCode'] ?? (transaction.currencyCode.isEmpty ? 'MYR' : transaction.currencyCode),
        'description': description,
        'documents': documents,
        'claimRef': claimRef,
        'status': 'new',
        'timeline': [{'status': 'new', 'at': nowIso, 'note': 'Claim submitted'}],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return claimRef;
  }

  Stream<List<ClaimOrRefundRecord>> watchClaimsForTransaction(String transactionId) {
    if (transactionId.isEmpty) return Stream.value(const []);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.error(StateError('Sign in to view your insurance claims.'));
    return _claims.where('buyerId', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs
          .where((doc) => doc.data()['transactionId'] == transactionId)
          .map((doc) => ClaimOrRefundRecord.fromDoc(doc, isRefund: false)).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Stream<List<ClaimOrRefundRecord>> watchRefundsForTransaction(String transactionId) {
    if (transactionId.isEmpty) return Stream.value(const []);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.error(StateError('Sign in to view your insurance refunds.'));
    return _refunds.where('buyerId', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs
          .where((doc) => doc.data()['transactionId'] == transactionId)
          .map((doc) => ClaimOrRefundRecord.fromDoc(doc, isRefund: true)).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Returns true for pending, approved, and rejected refunds.
  Future<bool> hasRefundRequest(String transactionId) async {
    if (transactionId.isEmpty) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const InsuranceEligibilityException('Please sign in to review your insurance refund.');
    }
    if ((await _refunds.doc(transactionId).get()).exists) return true;
    final existing = await _refunds.where('buyerId', isEqualTo: uid).get();
    return existing.docs.any((doc) => doc.data()['transactionId'] == transactionId);
  }

  Future<String> requestRefund({
    required InsuranceTransaction transaction,
    required String category,
    String reason = '',
    List<String> documents = const [],
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != transaction.buyerId) {
      throw const InsuranceEligibilityException('Only the policy buyer can request a refund.');
    }
    // Check historical refunds created by earlier app versions as well.
    if (await hasRefundRequest(transaction.id)) {
      throw const InsuranceEligibilityException('A refund request already exists for this policy.');
    }
    final transactionRef = _transactions.doc(transaction.id);
    // One refund document per transaction; two simultaneous submissions cannot
    // both create the same document through the transaction below.
    final refundDoc = _refunds.doc(transaction.id);
    final nowIso = DateTime.now().toIso8601String();
    final refundRef = _newRef('RFD');
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final saved = await tx.get(transactionRef);
      final existingRefund = await tx.get(refundDoc);
      final data = saved.data();
      if (data == null || data['buyerId'] != uid) {
        throw const InsuranceEligibilityException('Policy purchase not found for this buyer.');
      }
      if (existingRefund.exists) {
        throw const InsuranceEligibilityException('A refund request already exists for this policy.');
      }
      final start = (data['travelStart'] as Timestamp?)?.toDate();
      if (start != null && !DateTime.now().isBefore(start)) {
        throw const InsuranceEligibilityException(
          'This policy\'s travel period has already begun, so it can no longer be refunded.',
        );
      }
      tx.set(refundDoc, {
        'buyerId': uid,
        'transactionId': transaction.id,
        'partnerId': data['partnerId'] ?? transaction.partnerId,
        'providerName': data['providerName'] ?? transaction.providerName,
        'policyholderName': data['customerName'] ?? transaction.customerName,
        'policyholderEmail': data['customerEmail'] ?? transaction.customerEmail,
        'planName': data['planName'] ?? transaction.planName,
        'category': category,
        'amount': data['premium'] ?? transaction.premium,
        'currencyCode': data['currencyCode'] ?? (transaction.currencyCode.isEmpty ? 'MYR' : transaction.currencyCode),
        'reason': reason,
        'documents': documents,
        'refundRef': refundRef,
        'status': 'new',
        'timeline': [
          {'status': 'new', 'at': nowIso, 'note': 'Refund requested'}
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return refundRef;
  }

}
