import 'package:flutter/material.dart';

import '../../models/insurance_models.dart';
import '../../repositories/insurance_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';

// ---------------------------------------------------------------------
// Rider-facing Claim / Refund flow — reached from
// HistoryInsuranceDetailPage (via Profile > History, or a trip's own
// insurance card). Writes real documents into the same `claims`/`refunds`
// collections the insurance partner console already reads and manages
// (admin_web/partner/claims.html, claim-detail.html, refund-detail.html),
// so a claim/refund filed here shows up for the partner to review exactly
// like one they logged manually. Previously neither of these existed on
// the rider side at all — the collections and partner-side management
// were fully built, but nothing in the app could ever create one.
// ---------------------------------------------------------------------

/// Shared read-only summary of the real policy a claim/refund is against
/// — never re-typed, always the actual stored transaction.
Widget _policySummaryCard(InsuranceTransaction tx) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx.planName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text(tx.providerName.isNotEmpty ? tx.providerName : 'Insurance Partner',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        Text('Premium Paid: RM ${tx.premium.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ],
    ),
  );
}

/// Same look as TravellerDetailsPage's `_pickerField` — a tappable field
/// that opens a category picker instead of accepting free text.
Widget _categoryPickerField(String label, String? value, {required VoidCallback onTap}) {
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(value ?? label, style: TextStyle(fontSize: 13.5, color: value == null ? AppColors.textGrey : Colors.black)),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textGrey),
        ],
      ),
    ),
  );
}

/// A trip's bought insurance is visible to every trip member (see
/// GroupTripPage._insuranceRow), but a claim/refund pays back whoever
/// actually bought it — so a fellow trip member who isn't the buyer gets
/// a clear explanation here instead of reaching Firestore's own
/// permission-denied error after filling in the whole form (the `claims`/
/// `refunds` create rules only allow the real buyerId to write).
Widget _notBuyerNotice() {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        "Only the traveller who purchased this policy can file a claim or request a refund for it.",
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGrey),
      ),
    ),
  );
}

Future<String?> _pickCategoryFrom(BuildContext context, List<String> options, String title, String? current) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final option = options[i];
                return ListTile(
                  title: Text(option, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
                  trailing: option == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () => Navigator.of(context).pop(option),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// File a Claim
// ---------------------------------------------------------------------
class FileClaimPage extends StatefulWidget {
  final String transactionId;
  const FileClaimPage({super.key, required this.transactionId});

  @override
  State<FileClaimPage> createState() => _FileClaimPageState();
}

class _FileClaimPageState extends State<FileClaimPage> {
  bool _loading = true;
  InsuranceTransaction? _transaction;
  String? _category;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // getTransaction can throw (not just return null) when Firestore's
    // own read rule denies it — e.g. a fellow trip member who isn't the
    // buyer opening this from the trip's shared insurance card (see
    // insurance_transactions/{id}'s read rule in firestore.rules). Without
    // this catch, that throw would leave _loading stuck true forever —
    // an infinite spinner instead of a page. Treated the same as "not
    // found"/"not the buyer", both already handled by the build below.
    InsuranceTransaction? tx;
    try {
      tx = await InsuranceRepository.instance.getTransaction(widget.transactionId);
    } catch (_) {
      tx = null;
    }
    if (!mounted) return;
    setState(() {
      _transaction = tx;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // Guards against a fellow trip member (not the buyer) reaching this
  // form from the trip's shared insurance card — see _notBuyerNotice.
  bool get _isOwner => _transaction?.buyerId == AuthService.instance.currentUser?.uid;

  Future<void> _pickCategory() async {
    final picked = await _pickCategoryFrom(context, insuranceClaimCategories, 'Claim Category', _category);
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _submit() async {
    final tx = _transaction;
    if (tx == null || !_isOwner) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a claim category')));
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid claim amount')));
      return;
    }
    if (_descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe what happened')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final claimRef = await InsuranceRepository.instance.fileClaim(
        transaction: tx,
        category: _category!,
        amount: amount,
        description: _descriptionCtrl.text.trim(),
      );
      if (!mounted) return;
      showNiceInfoDialog(
        context: context,
        title: 'Claim Submitted',
        message: 'Your claim ($claimRef) has been sent to '
            '${tx.providerName.isNotEmpty ? tx.providerName : 'your insurer'} for review.',
        onDone: () => Navigator.of(context).pop(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit claim: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('File a Claim', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("This policy's purchase record couldn't be found.", textAlign: TextAlign.center),
                  ),
                )
              : !_isOwner
                  ? _notBuyerNotice()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              _policySummaryCard(_transaction!),
                              const SizedBox(height: 20),
                              _categoryPickerField('Claim Category', _category, onTap: _pickCategory),
                              const SizedBox(height: 12),
                              niceDialogField(_amountCtrl, 'Claim Amount (RM)',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                              niceDialogField(_descriptionCtrl, 'What happened?', maxLines: 4),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Submit Claim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// ---------------------------------------------------------------------
// Request Refund
// ---------------------------------------------------------------------
class RequestRefundPage extends StatefulWidget {
  final String transactionId;
  const RequestRefundPage({super.key, required this.transactionId});

  @override
  State<RequestRefundPage> createState() => _RequestRefundPageState();
}

class _RequestRefundPageState extends State<RequestRefundPage> {
  bool _loading = true;
  InsuranceTransaction? _transaction;
  String? _category;
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // getTransaction can throw (not just return null) when Firestore's
    // own read rule denies it — e.g. a fellow trip member who isn't the
    // buyer opening this from the trip's shared insurance card (see
    // insurance_transactions/{id}'s read rule in firestore.rules). Without
    // this catch, that throw would leave _loading stuck true forever —
    // an infinite spinner instead of a page. Treated the same as "not
    // found"/"not the buyer", both already handled by the build below.
    InsuranceTransaction? tx;
    try {
      tx = await InsuranceRepository.instance.getTransaction(widget.transactionId);
    } catch (_) {
      tx = null;
    }
    if (!mounted) return;
    setState(() {
      _transaction = tx;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // Mirrors InsuranceRepository.requestRefund's own eligibility check —
  // checked here too so the button can be disabled with an explanation
  // up front, instead of only failing after the rider fills in the form
  // and taps Submit. A transaction with no stored travel dates (bought
  // before that field existed) is treated as still eligible, same
  // reasoning as the repository method.
  bool get _eligible {
    final start = _transaction?.travelStart;
    if (start == null) return true;
    return DateTime.now().isBefore(start);
  }

  // Guards against a fellow trip member (not the buyer) reaching this
  // form from the trip's shared insurance card — see _notBuyerNotice.
  bool get _isOwner => _transaction?.buyerId == AuthService.instance.currentUser?.uid;

  Future<void> _pickCategory() async {
    final picked = await _pickCategoryFrom(context, insuranceRefundCategories, 'Refund Reason', _category);
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _submit() async {
    final tx = _transaction;
    if (tx == null || !_eligible || !_isOwner) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a reason category')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final refundRef = await InsuranceRepository.instance.requestRefund(
        transaction: tx,
        category: _category!,
        reason: _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      showNiceInfoDialog(
        context: context,
        title: 'Refund Requested',
        message: 'Your refund request ($refundRef) for RM ${tx.premium.toStringAsFixed(2)} has been sent to '
            '${tx.providerName.isNotEmpty ? tx.providerName : 'your insurer'} for review.',
        onDone: () => Navigator.of(context).pop(),
      );
    } on InsuranceEligibilityException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit refund request: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Request Refund', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("This policy's purchase record couldn't be found.", textAlign: TextAlign.center),
                  ),
                )
              : !_isOwner
                  ? _notBuyerNotice()
                  : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _policySummaryCard(_transaction!),
                          if (!_eligible) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(12)),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.redAccent),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "This policy's travel period has already begun, so it's no longer eligible for a refund.",
                                      style: TextStyle(fontSize: 12.5, color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          IgnorePointer(
                            ignoring: !_eligible,
                            child: Opacity(
                              opacity: _eligible ? 1 : 0.4,
                              child: Column(
                                children: [
                                  _categoryPickerField('Reason Category', _category, onTap: _pickCategory),
                                  const SizedBox(height: 12),
                                  niceDialogField(_reasonCtrl, 'Additional details (optional)', maxLines: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: (!_eligible || _submitting) ? null : _submit,
                          child: _submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_eligible ? 'Request Refund' : 'Not Eligible',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
