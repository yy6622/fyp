import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/insurance_models.dart';
import '../../repositories/insurance_repository.dart';
import '../../services/auth_service.dart';
import '../../services/claim_document_service.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';


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
        Text(
          'Premium Paid: ${CurrencyService.instance.displayLabel(tx.currencyCode.isEmpty ? 'MYR' : tx.currencyCode)} ${tx.premium.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    ),
  );
}

Widget _categoryPickerField(String label, String? value, {required VoidCallback onTap, bool required = true}) {
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: value != null
                ? Text(value, style: const TextStyle(fontSize: 13.5, color: Colors.black))
                : Text.rich(
                    TextSpan(text: label, children: [
                      if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                    ]),
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textGrey),
                  ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textGrey),
        ],
      ),
    ),
  );
}

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

enum _DocSource { camera, gallery, file }

Future<_DocSource?> _pickDocumentSource(BuildContext context) {
  return showModalBottomSheet<_DocSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
            title: const Text('Take a Photo'),
            onTap: () => Navigator.of(ctx).pop(_DocSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(ctx).pop(_DocSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
            title: const Text('Choose a PDF File'),
            onTap: () => Navigator.of(ctx).pop(_DocSource.file),
          ),
        ],
      ),
    ),
  );
}

Widget _documentsSection({
  required List<String> urls,
  required bool uploading,
  required VoidCallback onAdd,
  required ValueChanged<int> onRemove,
  bool required = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(required ? 'Supporting Documents * (Required)' : 'Supporting Documents (Optional)',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
      const SizedBox(height: 4),
      const Text('Receipts, medical reports or other proof can help your insurer review this faster. Photos or PDF, up to 5MB each.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < urls.length; i++)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  // A PDF download URL can't be decoded as an image --
                  // Image.network would just show a broken-image icon, so
                  // give a PDF its own recognizable tile instead.
                  child: urls[i].toLowerCase().contains('.pdf')
                      ? Container(
                          width: 72,
                          height: 72,
                          color: AppColors.chipGrey,
                          alignment: Alignment.center,
                          child: const Icon(Icons.picture_as_pdf_outlined, size: 28, color: AppColors.textGrey),
                        )
                      : Image.network(urls[i], width: 72, height: 72, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: uploading ? null : onAdd,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.chipGrey,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: uploading
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.add_a_photo_outlined, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    ],
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

class FileClaimPage extends StatefulWidget {
  final String transactionId;
  const FileClaimPage({super.key, required this.transactionId});

  @override
  State<FileClaimPage> createState() => _FileClaimPageState();
}

class _FileClaimPageState extends State<FileClaimPage> {
  bool _loading = true;
  InsuranceTransaction? _transaction;
  String? _loadError;
  String? _category;
  final TextEditingController _descriptionCtrl = TextEditingController();
  bool _submitting = false;
  List<String> _documents = [];
  bool _uploadingDoc = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    InsuranceTransaction? tx;
    String? err;
    try {
      tx = await InsuranceRepository.instance.getTransaction(widget.transactionId);
      if (tx == null) err = 'No transaction exists with id "${widget.transactionId}".';
    } catch (e) {
      tx = null;
      err = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _transaction = tx;
      _loadError = err;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  bool get _isOwner => _transaction?.buyerId == AuthService.instance.currentUser?.uid;

  Future<void> _pickCategory() async {
    final picked = await _pickCategoryFrom(context, insuranceClaimCategories, 'Claim Category', _category);
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _addDocument() async {
    final choice = await _pickDocumentSource(context);
    if (choice == null || !mounted) return;
    XFile? imageFile;
    PickedDocument? document;
    if (choice == _DocSource.file) {
      document = await ClaimDocumentService.instance.pickPdf();
      if (document == null || !mounted) return;
    } else {
      imageFile = await ClaimDocumentService.instance.pick(choice == _DocSource.camera ? ImageSource.camera : ImageSource.gallery);
      if (imageFile == null || !mounted) return;
    }
    final uid = AuthService.instance.currentUser?.uid ?? '';
    setState(() => _uploadingDoc = true);
    try {
      final url = await ClaimDocumentService.instance.upload(kind: 'claim', uid: uid, file: imageFile, document: document);
      if (!mounted) return;
      setState(() {
        _documents = [..._documents, url];
        _uploadingDoc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingDoc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ClaimDocumentTooLargeException ? e.toString() : 'Upload failed: $e')),
      );
    }
  }

  void _removeDocument(int index) {
    setState(() => _documents = [..._documents]..removeAt(index));
  }

  Future<void> _submit() async {
    final tx = _transaction;
    if (tx == null || !_isOwner) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a claim category')));
      return;
    }
    if (_descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe what happened')));
      return;
    }
    if (_documents.isEmpty || _uploadingDoc) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one supporting document is required.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final claimRef = await InsuranceRepository.instance.fileClaim(
        transaction: tx,
        category: _category!,
        description: _descriptionCtrl.text.trim(),
        documents: _documents,
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("This policy's purchase record couldn't be found.", textAlign: TextAlign.center),
                        if (_loadError != null) ...[
                          const SizedBox(height: 10),
                          Text(_loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                        ],
                      ],
                    ),
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
                              const Text('Claim amount will be assessed and entered by the insurance partner.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                              niceDialogField(_descriptionCtrl, 'What happened?', maxLines: 4, required: true),
                              const SizedBox(height: 16),
                              _documentsSection(
                                urls: _documents,
                                uploading: _uploadingDoc,
                                onAdd: _addDocument,
                                onRemove: _removeDocument,
                                required: true,
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
                              onPressed: (_submitting || _uploadingDoc || _documents.isEmpty) ? null : _submit,
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

class RequestRefundPage extends StatefulWidget {
  final String transactionId;
  const RequestRefundPage({super.key, required this.transactionId});

  @override
  State<RequestRefundPage> createState() => _RequestRefundPageState();
}

class _RequestRefundPageState extends State<RequestRefundPage> {
  bool _loading = true;
  InsuranceTransaction? _transaction;
  String? _loadError;
  String? _category;
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _submitting = false;
  List<String> _documents = [];
  bool _uploadingDoc = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    InsuranceTransaction? tx;
    String? err;
    try {
      tx = await InsuranceRepository.instance.getTransaction(widget.transactionId);
      if (tx == null) err = 'No transaction exists with id "${widget.transactionId}".';
    } catch (e) {
      tx = null;
      err = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _transaction = tx;
      _loadError = err;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _eligible {
    final start = _transaction?.travelStart;
    if (start == null) return true;
    return DateTime.now().isBefore(start);
  }

  bool get _isOwner => _transaction?.buyerId == AuthService.instance.currentUser?.uid;

  Future<void> _pickCategory() async {
    final picked = await _pickCategoryFrom(context, insuranceRefundCategories, 'Refund Reason', _category);
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _addDocument() async {
    final choice = await _pickDocumentSource(context);
    if (choice == null || !mounted) return;
    XFile? imageFile;
    PickedDocument? document;
    if (choice == _DocSource.file) {
      document = await ClaimDocumentService.instance.pickPdf();
      if (document == null || !mounted) return;
    } else {
      imageFile = await ClaimDocumentService.instance.pick(choice == _DocSource.camera ? ImageSource.camera : ImageSource.gallery);
      if (imageFile == null || !mounted) return;
    }
    final uid = AuthService.instance.currentUser?.uid ?? '';
    setState(() => _uploadingDoc = true);
    try {
      final url = await ClaimDocumentService.instance.upload(kind: 'refund', uid: uid, file: imageFile, document: document);
      if (!mounted) return;
      setState(() {
        _documents = [..._documents, url];
        _uploadingDoc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingDoc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ClaimDocumentTooLargeException ? e.toString() : 'Upload failed: $e')),
      );
    }
  }

  void _removeDocument(int index) {
    setState(() => _documents = [..._documents]..removeAt(index));
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
        documents: _documents,
      );
      if (!mounted) return;
      showNiceInfoDialog(
        context: context,
        title: 'Refund Requested',
        message: 'Your refund request ($refundRef) for '
            '${CurrencyService.instance.displayLabel(tx.currencyCode.isEmpty ? 'MYR' : tx.currencyCode)} ${tx.premium.toStringAsFixed(2)} has been sent to '
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("This policy's purchase record couldn't be found.", textAlign: TextAlign.center),
                        if (_loadError != null) ...[
                          const SizedBox(height: 10),
                          Text(_loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                        ],
                      ],
                    ),
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
                                  const SizedBox(height: 16),
                                  _documentsSection(
                                    urls: _documents,
                                    uploading: _uploadingDoc,
                                    onAdd: _addDocument,
                                    onRemove: _removeDocument,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: StreamBuilder<List<ClaimOrRefundRecord>>(
                        stream: InsuranceRepository.instance.watchRefundsForTransaction(widget.transactionId),
                        builder: (context, snapshot) {
                          final hasRequest = (snapshot.data ?? const <ClaimOrRefundRecord>[]).isNotEmpty;
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: (!_eligible || _submitting || !snapshot.hasData || hasRequest) ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(hasRequest ? 'Refund Already Requested' : (_eligible ? 'Request Refund' : 'Not Eligible'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
