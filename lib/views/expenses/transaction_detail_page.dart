import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/receipt_service.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Transaction detail
//
// - The receipt photo is the thumbnail at the top right of the card; tap it to see it full screen
//   (pinch to zoom).
// - "Paid by" and "Split between" show each person's real profile photo (UserAvatar).
// - The person who paid can edit the expense (pencil in the app bar): title, amount, category, note
//   and the receipt photo. Firestore rules only allow the payer to do this.
// - Live: reads the expense from Firestore, so an edit or a "Mark as paid" shows straight away.
// ---------------------------------------------------------------------
class TransactionDetailPage extends StatefulWidget {
  final TripExpense expense;
  const TransactionDetailPage({super.key, required this.expense});

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _categories = ['Food & Drinks', 'Transport', 'Accommodation', 'Activities', 'Shopping', 'Other'];

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  late final Stream<TripExpense?> _live = TripRepository.instance
      .watchExpenses(widget.expense.tripId)
      .map((list) => list.where((e) => e.id == widget.expense.id).firstOrNull);

  Future<void> _markPaid(ExpenseParticipant p) async {
    await TripRepository.instance.setParticipantPaid(widget.expense.tripId, widget.expense.id, p.uid, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid')));
  }

  String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TripExpense?>(
      stream: _live,
      builder: (context, snap) {
        final e = snap.data ?? widget.expense;
        final isOwner = e.paidBy == _uid && _uid.isNotEmpty;
        final myShare = e.participants.where((p) => p.uid == _uid).toList();
        final others = e.participants.where((p) => p.uid != _uid).toList();
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: VoyaAppBar(
            title: const Text('Transactions', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.navy),
                  onPressed: () => _openEditSheet(e),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(expenseLabel(e), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Paid by', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: UserAvatar(uid: e.paidBy, radius: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(isOwner ? '${e.paidByName} (you)' : e.paidByName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _receiptThumb(e),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _kv('Total Amount', 'RM ${e.amount.toStringAsFixed(2)}'),
                          if (e.date != null) _kv('Date', _date(e.date!)),
                          _kv('Category', e.category),
                          if (e.note.isNotEmpty) _kv('Note', e.note),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Split Between (${e.participants.length} members)', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    const SizedBox(height: 8),
                    for (final p in myShare) _memberRow(e, p, isMe: true),
                    for (final p in others) _memberRow(e, p, isMe: false),
                  ],
                ),
              ),
              if (myShare.any((p) => !p.paid) && e.paidBy != _uid)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _markPaid(myShare.first),
                      child: const Text('Mark as Paid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The receipt photo (tap = full screen). Without one: a plain placeholder.
  Widget _receiptThumb(TripExpense e) {
    const size = 84.0;
    if (e.receiptImageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: const Color(0xFFE2E2E2), borderRadius: BorderRadius.circular(14)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, color: AppColors.textGrey, size: 22),
            SizedBox(height: 4),
            Text('No receipt', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ReceiptViewer(url: e.receiptImageUrl))),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            e.receiptImageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: const Color(0xFFE2E2E2),
              child: const Icon(Icons.broken_image_outlined, color: AppColors.textGrey),
            ),
          ),
        ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black))),
        ],
      ),
    );
  }

  Widget _memberRow(TripExpense e, ExpenseParticipant p, {required bool isMe}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          UserAvatar(uid: p.uid, radius: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(isMe ? '${p.name} (you)' : p.name, style: const TextStyle(fontSize: 13, color: Colors.black))),
          Text('RM ${p.share.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Colors.black)),
          const SizedBox(width: 8),
          Text(p.paid ? 'Paid' : 'Pending',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.paid ? Colors.green : Colors.orange)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ edit (payer only)

  static String? _amountError(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'Enter an amount';
    final v = double.tryParse(t);
    if (v == null || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return 'Numbers only, up to 2 decimal places';
    if (v <= 0) return 'Amount must be more than RM 0';
    if (v > 1000000) return 'Amount can\'t be more than RM 1,000,000';
    return null;
  }

  Future<void> _openEditSheet(TripExpense e) async {
    final amount = TextEditingController(text: e.amount.toStringAsFixed(2));
    final note = TextEditingController(text: e.note);
    var category = e.category;
    // Once someone (other than the payer, whose own share counts as paid) has paid, the amount is
    // locked: changing it would change what they already paid for.
    final paidOthers = e.participants.where((p) => p.paid && p.uid != e.paidBy).map((p) => p.name).toList();
    final amountLocked = paidOthers.isNotEmpty;
    final lockReason = paidOthers.isEmpty
        ? ''
        : 'The amount can\'t be changed because ${paidOthers.length > 2 ? '${paidOthers.take(2).join(', ')} +${paidOthers.length - 2}' : paidOthers.join(' and ')} '
            '${paidOthers.length == 1 ? 'has' : 'have'} already paid their share.';
    File? newReceipt;
    var removeReceipt = false;
    var saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final amountProblem = amountLocked ? null : _amountError(amount.text);
          final hasReceipt = newReceipt != null || (!removeReceipt && e.receiptImageUrl.isNotEmpty);
          Future<void> pick(ImageSource source) async {
            final x = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1600);
            if (x != null) setSheet(() {
              newReceipt = File(x.path);
              removeReceipt = false;
            });
          }

          Future<void> save() async {
            if (amountProblem != null) return setSheet(() => error = amountProblem);
            setSheet(() {
              saving = true;
              error = null;
            });
            try {
              String? url;
              if (newReceipt != null) {
                url = await ReceiptService.instance.upload(e.tripId, _uid, newReceipt!);
              } else if (removeReceipt) {
                url = '';
              }
              await TripRepository.instance.updateExpense(
                e,
                title: note.text.trim(),
                amount: amountLocked ? e.amount : double.parse(double.parse(amount.text.trim()).toStringAsFixed(2)),
                category: category,
                note: note.text.trim(),
                receiptImageUrl: url,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense updated')));
            } catch (err) {
              setSheet(() {
                saving = false;
                error = 'Could not save: $err';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amount,
                    // read-only (not disabled), so the lock icon's tooltip can still be tapped
                    readOnly: amountLocked,
                    style: TextStyle(color: amountLocked ? AppColors.textGrey : Colors.black),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
                    onChanged: (_) => setSheet(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'RM ',
                      errorText: amount.text.isEmpty ? null : amountProblem,
                      helperText: amountLocked
                          ? null
                          : e.participants.length > 1
                              ? 'The split between members is updated to match.'
                              : null,
                      suffixIcon: amountLocked
                          ? Tooltip(
                              message: lockReason,
                              triggerMode: TooltipTriggerMode.tap,
                              showDuration: const Duration(seconds: 4),
                              child: const Icon(Icons.lock_outline, size: 18, color: AppColors.textGrey),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (amountLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppColors.orange),
                          const SizedBox(width: 6),
                          Expanded(child: Text(lockReason, style: const TextStyle(fontSize: 11.5, color: AppColors.orange, height: 1.3))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text('Category', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in {..._categories, category})
                        ChoiceChip(
                          label: Text(c, style: TextStyle(fontSize: 12, color: c == category ? Colors.white : AppColors.navy)),
                          selected: c == category,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.chipGrey,
                          showCheckmark: false,
                          onSelected: (_) => setSheet(() => category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: 'Note', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Receipt', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
                        clipBehavior: Clip.antiAlias,
                        child: newReceipt != null
                            ? Image.file(newReceipt!, fit: BoxFit.cover)
                            : hasReceipt
                                ? Image.network(e.receiptImageUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.textGrey))
                                : const Icon(Icons.receipt_long_outlined, color: AppColors.textGrey),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          children: [
                            TextButton(onPressed: saving ? null : () => pick(ImageSource.camera), child: const Text('Take photo')),
                            TextButton(onPressed: saving ? null : () => pick(ImageSource.gallery), child: const Text('Choose')),
                            if (hasReceipt)
                              TextButton(
                                onPressed: saving ? null : () => setSheet(() {
                                  newReceipt = null;
                                  removeReceipt = true;
                                }),
                                child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'Saving...' : 'Save changes',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    amount.dispose();
    note.dispose();
  }
}

/// Full-screen receipt: black background, pinch to zoom, tap X to close.
class _ReceiptViewer extends StatelessWidget {
  final String url;
  const _ReceiptViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Receipt', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const CircularProgressIndicator(color: Colors.white),
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}
