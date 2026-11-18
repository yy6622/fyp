import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/receipt_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import 'friend_picker_dialog.dart';

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

  Future<void> _confirmDelete(TripExpense e) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Delete Expense',
      message: 'This permanently deletes this expense for everyone in the trip. This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await TripRepository.instance.deleteExpense(e.tripId, e.id, actorUid: _uid);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $err')));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted')));
  }

  Future<void> _remindUnpaid() async {
    final count = await TripRepository.instance.sendPaymentReminder(widget.expense.tripId, widget.expense.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count == 0 ? 'Everyone has already paid their share' : 'Reminded $count ${count == 1 ? 'person' : 'people'} to pay'),
    ));
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
              if (isOwner)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(e),
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
              if (isOwner && others.any((p) => !p.paid))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _remindUnpaid,
                      icon: const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 18),
                      label: const Text('Remind to Pay', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

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
          child: CachedNetworkImage(
            imageUrl: e.receiptImageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: size, height: size, color: const Color(0xFFE2E2E2)),
            errorWidget: (_, __, ___) => Container(
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
    final theirItems = e.items.where((i) => i.assigneeUids.contains(p.uid)).toList();
    final canOpen = theirItems.isNotEmpty;
    return InkWell(
      onTap: canOpen
          ? () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _MemberItemsPage(participant: p, isMe: isMe, items: theirItems)))
          : null,
      child: Padding(
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
            if (canOpen) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
            ],
          ],
        ),
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
    final paidOthers = e.participants.where((p) => p.paid && p.uid != e.paidBy).map((p) => p.name).toList();
    // The amount can't change once someone else has paid their share --
    // and for an itemized expense, editing the items (which is how the
    // amount is derived) is blocked for the same reason.
    final amountLocked = paidOthers.isNotEmpty;
    final lockReason = paidOthers.isEmpty
        ? ''
        : 'The amount can\'t be changed because ${paidOthers.length > 2 ? '${paidOthers.take(2).join(', ')} +${paidOthers.length - 2}' : paidOthers.join(' and ')} '
            '${paidOthers.length == 1 ? 'has' : 'have'} already paid their share.';
    final isItemized = e.items.isNotEmpty;
    final itemsEditable = isItemized && !amountLocked;
    // For an itemized expense, Amount is always derived from the items --
    // it's shown read-only here too (matching how adding an expense shows
    // it), and the Items section below is where the owner actually edits
    // the breakdown or reassigns an item to someone else.
    final amountReadOnly = amountLocked || isItemized;
    File? newReceipt;
    var removeReceipt = false;
    var saving = false;
    String? error;
    var items = List<ExpenseLineItem>.from(e.items);
    Trip? trip;
    if (isItemized) {
      try {
        trip = await TripRepository.instance.getTrip(e.tripId, _uid);
      } catch (_) {
        trip = null;
      }
    }
    if (!mounted) return;

    String? itemProblem(String labelText, String priceText) {
      final priceValue = double.tryParse(priceText);
      if (labelText.trim().isEmpty) return 'Give the item a name';
      // Allows an optional leading "-": a voucher/loyalty discount line
      // (ReceiptOcrService.discount, applied in
      // AddExpenseController.scanReceipt) is stored as a negative-price
      // item on purpose -- split equally across members the same way tax
      // is -- so re-saving it here, even unchanged, must not be rejected
      // by a positive-only price format.
      if (priceValue == null || !RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(priceText)) {
        return 'Price: numbers only, up to 2 decimal places';
      }
      if (priceValue == 0) return 'Price can\'t be RM 0';
      if (priceValue.abs() > 1000000) return 'Price can\'t be more than RM 1,000,000';
      return null;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final amountProblem = amountReadOnly ? null : _amountError(amount.text);
          final hasReceipt = newReceipt != null || (!removeReceipt && e.receiptImageUrl.isNotEmpty);

          void refreshAmountFromItems() {
            amount.text = items.fold(0.0, (s, i) => s + i.price).toStringAsFixed(2);
          }

          Future<void> editItem(int index) async {
            if (!itemsEditable) return;
            final item = items[index];
            final label = TextEditingController(text: item.label);
            final price = TextEditingController(text: item.price.toStringAsFixed(2));
            final result = await showNiceFormDialog(
              context: ctx,
              title: 'Edit Item',
              headerIcon: Icons.edit_outlined,
              confirmLabel: 'Save',
              fieldsBuilder: (dctx, dSetState) => [
                niceDialogField(label, 'Item', icon: Icons.label_outline, autofocus: true, required: true),
                niceDialogField(price, 'Price (RM)', icon: Icons.payments_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), required: true),
              ],
            );
            if (result != true) return;
            final problem = itemProblem(label.text, price.text.trim());
            if (problem != null) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(problem)));
              return;
            }
            setSheet(() {
              items[index] = ExpenseLineItem(label: label.text.trim(), price: double.parse(price.text.trim()), assigneeUids: item.assigneeUids);
              refreshAmountFromItems();
            });
          }

          void reassignItem(int index) {
            if (!itemsEditable || trip == null) return;
            final item = items[index];
            showDialog(
              context: ctx,
              builder: (_) => FriendPickerDialog(
                trip: trip!,
                initialSelectedUids: item.assigneeUids.toSet(),
                onConfirm: (uids) => setSheet(() {
                  items[index] = ExpenseLineItem(label: item.label, price: item.price, assigneeUids: uids.toList());
                }),
              ),
            );
          }

          Widget itemRow(int index) {
            final item = items[index];
            final names = item.assigneeUids.map((uid) => trip?.memberNames[uid] ?? '?').toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => editItem(index),
                    child: Text('${item.label} — RM ${item.price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12.5, color: itemsEditable ? Colors.black : AppColors.textGrey)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          names.isEmpty ? 'Nobody assigned yet' : 'Split with: ${names.join(', ')}',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
                        ),
                      ),
                      if (itemsEditable)
                        GestureDetector(
                          onTap: () => reassignItem(index),
                          child: const CircleAvatar(
                              radius: 13, backgroundColor: AppColors.chipGrey, child: Icon(Icons.person_add_alt, size: 14, color: AppColors.navy)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }

          Future<void> pick(ImageSource source) async {
            final x = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1600);
            if (x != null) setSheet(() {
              newReceipt = File(x.path);
              removeReceipt = false;
            });
          }

          Future<void> save() async {
            if (amountProblem != null) return setSheet(() => error = amountProblem);
            if (itemsEditable && items.any((i) => i.assigneeUids.isEmpty)) {
              return setSheet(() => error = 'Every item needs someone to pay for it.');
            }
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
                amount: isItemized
                    ? items.fold(0.0, (s, i) => s + i.price)
                    : (amountLocked ? e.amount : double.parse(double.parse(amount.text.trim()).toStringAsFixed(2))),
                category: category,
                note: note.text.trim(),
                receiptImageUrl: url,
                items: itemsEditable ? items : null,
                memberNames: trip?.memberNames ?? const {},
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
                    readOnly: amountReadOnly,
                    style: TextStyle(color: amountReadOnly ? AppColors.textGrey : Colors.black),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
                    onChanged: (_) => setSheet(() {}),
                    decoration: InputDecoration(
                      label: Text.rich(TextSpan(text: 'Amount', children: const [
                        TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                      ])),
                      prefixText: 'RM ',
                      errorText: amount.text.isEmpty ? null : amountProblem,
                      helperText: amountLocked
                          ? null
                          : isItemized
                              ? 'Calculated from the items below.'
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
                  if (isItemized) ...[
                    const SizedBox(height: 16),
                    const Text('Items', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                    const SizedBox(height: 6),
                    for (int i = 0; i < items.length; i++) itemRow(i),
                  ],
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
                                ? CachedNetworkImage(imageUrl: e.receiptImageUrl, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.textGrey))
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
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Receipt', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, u) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}

class _MemberItemsPage extends StatelessWidget {
  final ExpenseParticipant participant;
  final bool isMe;
  final List<ExpenseLineItem> items;
  const _MemberItemsPage({required this.participant, required this.isMe, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(isMe ? 'Your Items' : "${participant.name}'s Items",
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              UserAvatar(uid: participant.uid, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(isMe ? '${participant.name} (you)' : participant.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              Text('RM ${participant.share.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Items (${items.length})', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
          const SizedBox(height: 8),
          for (final item in items) _itemShareRow(item),
        ],
      ),
    );
  }

  Widget _itemShareRow(ExpenseLineItem item) {
    final shared = item.assigneeUids.length > 1;
    final yourShare = item.price / item.assigneeUids.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                if (shared) ...[
                  const SizedBox(height: 3),
                  Text('RM ${item.price.toStringAsFixed(2)} split with ${item.assigneeUids.length} people',
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ],
            ),
          ),
          Text('RM ${yourShare.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }
}
