import 'package:flutter/material.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Transaction detail
// ---------------------------------------------------------------------
class TransactionDetailPage extends StatefulWidget {
  final TripExpense expense;
  const TransactionDetailPage({super.key, required this.expense});

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  Future<void> _markPaid(ExpenseParticipant p) async {
    await TripRepository.instance.setParticipantPaid(widget.expense.tripId, widget.expense.id, p.uid, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid')));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final myShare = e.participants.where((p) => p.uid == _uid).toList();
    final others = e.participants.where((p) => p.uid != _uid).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Transactions', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Paid by', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          const Spacer(),
                          const CircleAvatar(radius: 14, backgroundColor: Color(0xFFD9D9D9)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(e.paidBy == _uid ? '${e.paidByName} (you)' : e.paidByName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                      const SizedBox(height: 12),
                      _kv('Total Amount', 'RM ${e.amount.toStringAsFixed(2)}'),
                      if (e.date != null) _kv('Date', '${e.date!.day}/${e.date!.month}/${e.date!.year}'),
                      _kv('Category', e.category),
                      if (e.note.isNotEmpty) _kv('Note', e.note),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Split Between (${e.participants.length} members)', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                const SizedBox(height: 8),
                for (final p in myShare) _memberRow(context, e, p, isMe: true),
                for (final p in others) _memberRow(context, e, p, isMe: false),
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
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _memberRow(BuildContext context, TripExpense e, ExpenseParticipant p, {required bool isMe}) {
    final status = p.paid ? 'Paid' : 'Pending';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
          const SizedBox(width: 12),
          Expanded(child: Text(isMe ? '${p.name} (you)' : p.name, style: const TextStyle(fontSize: 13, color: Colors.black))),
          Text('RM ${p.share.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Colors.black)),
          const SizedBox(width: 8),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.paid ? Colors.green : Colors.orange)),
        ],
      ),
    );
  }
}
