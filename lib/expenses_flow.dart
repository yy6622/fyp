import 'package:flutter/material.dart';

import 'group_trip.dart';
import 'theme.dart';

// ---------------------------------------------------------------------
// Expenses tab (Groups / Personal) — lives inside GroupTripPage
// ---------------------------------------------------------------------
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  bool _personal = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      children: [
        _segmentToggle(),
        const SizedBox(height: 16),
        _personal ? _personalSummary() : _groupSummary(),
        const SizedBox(height: 20),
        if (!_personal) ...[
          const Text('Spending Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 4),
          const Text('Consumer Spending 2023 vs. 2024', style: TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
          const Text('Percentage change by month (from baseline value)', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
          const SizedBox(height: 8),
          SizedBox(height: 150, child: CustomPaint(painter: _TrendChartPainter(), size: Size.infinite)),
          const SizedBox(height: 20),
        ] else ...[
          const Text('Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 10),
          ...List.generate(4, (i) => _categoryRow('Transport', 1130.20, 0.18)),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            Text('View all', style: TextStyle(fontSize: 12, color: Color(0xFF0015FF))),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(3, (i) => _transactionRow(context, personal: _personal, settled: i != 1)),
      ],
    );
  }

  Widget _segmentToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          _segmentButton('Groups', !_personal),
          _segmentButton('Personal', _personal),
        ],
      ),
    );
  }

  Widget _segmentButton(String label, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _personal = label == 'Personal'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey)),
        ),
      ),
    );
  }

  Widget _groupSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Expenses', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    SizedBox(height: 4),
                    Text('RM 5503.20', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    SizedBox(height: 4),
                    Text('View Detail >', style: TextStyle(fontSize: 11, color: Color(0xFF0015FF))),
                  ],
                ),
              ),
              SizedBox(width: 70, height: 70, child: CustomPaint(painter: _PiePainter())),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statTile('Remaining budget', 'RM 20.50'),
              _statTile('Per Person Average', 'RM 33.50'),
              _statTile('Unsettled bill', '5'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _personalSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Expenses', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    SizedBox(height: 4),
                    Text('RM 120.30', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    SizedBox(height: 4),
                    Text('View Detail >', style: TextStyle(fontSize: 11, color: Color(0xFF0015FF))),
                  ],
                ),
              ),
              const Icon(Icons.account_balance_wallet, size: 44, color: AppColors.orange),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statTile('You Owe', 'RM 20.50'),
              _statTile("You're Owed", 'RM 33.50'),
              _statTile('Pending Bills', '3'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _categoryRow(String label, double amount, double pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black)),
                    Text('RM ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: AppColors.chipGrey, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _transactionRow(BuildContext context, {required bool personal, required bool settled}) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionDetailPage())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFFDFDE0)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Transport', style: TextStyle(fontSize: 13, color: Colors.black)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  personal ? (settled ? 'Paid' : 'Unpaid') : (settled ? 'Settle' : 'Unsettle'),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: settled ? Colors.green : Colors.red),
                ),
                const Text('RM 28.63', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paintGreen = Paint()..color = const Color(0xFF6FCF97);
    final paintPink = Paint()..color = const Color(0xFFE0708A);
    const total = 6.28318530718; // 2*pi
    const splitAt = 0.78 * total;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708, splitAt, true, paintGreen);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708 + splitAt, total - splitAt, true, paintPink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const values2023 = [3.0, -1.0, 9.0, 4.0, 16.0, 1.0];
    const values2024 = [0.0, 5.0, 16.0, 16.0, 21.0, 9.0];
    _drawLine(canvas, size, values2023, Colors.orange);
    _drawLine(canvas, size, values2024, Colors.red);
  }

  void _drawLine(Canvas canvas, Size size, List<double> values, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const min = -5.0, max = 25.0;
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - min) / (max - min);
      final y = size.height * (1 - normalized);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------
// Add Expense flow
// ---------------------------------------------------------------------
class AddExpenseChoicePage extends StatelessWidget {
  const AddExpenseChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Add Expenses', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          _tile(context, 'Upload Receipt', 'Take photo or upload',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ItemizedSplitPage()))),
          _tile(context, 'Manual Entry', 'Enter expenses manually',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpenseDetailsFormPage()))),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFDFDE0), borderRadius: BorderRadius.circular(22))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

class ItemizedSplitPage extends StatefulWidget {
  const ItemizedSplitPage({super.key});

  @override
  State<ItemizedSplitPage> createState() => _ItemizedSplitPageState();
}

class _ItemizedSplitPageState extends State<ItemizedSplitPage> {
  final Map<String, int> _peopleCount = {'Food 1': 5, 'Drink 1': 2};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Add Expenses', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Split With', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 14),
                ..._peopleCount.entries.map((e) => _itemRow(e.key, e.value)),
              ],
            ),
          ),
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
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpenseDetailsFormPage())),
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(String label, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text('$label ------------------------- RM 18.60', style: const TextStyle(fontSize: 12.5, color: Colors.black))),
        ],
      ),
    ).let((row) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row,
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    height: 30,
                    child: Stack(
                      children: List.generate(count, (i) {
                        return Positioned(left: i * 20.0, child: CircleAvatar(radius: 15, backgroundColor: Colors.primaries[i % Colors.primaries.length]));
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openFriendPicker(label),
                    child: const CircleAvatar(radius: 15, backgroundColor: AppColors.chipGrey, child: Icon(Icons.add, size: 16, color: AppColors.navy)),
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  void _openFriendPicker(String itemLabel) {
    showDialog(
      context: context,
      builder: (_) => FriendPickerDialog(
        initialSelected: _peopleCount[itemLabel] ?? 0,
        onConfirm: (n) => setState(() => _peopleCount[itemLabel] = n),
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class FriendPickerDialog extends StatefulWidget {
  final int initialSelected;
  final ValueChanged<int> onConfirm;
  const FriendPickerDialog({super.key, required this.initialSelected, required this.onConfirm});

  @override
  State<FriendPickerDialog> createState() => _FriendPickerDialogState();
}

class _FriendPickerDialogState extends State<FriendPickerDialog> {
  late Set<int> _selected = Set<int>.from(List.generate(widget.initialSelected, (i) => i));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selected (${_selected.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(20)),
              child: const TextField(
                decoration: InputDecoration(hintText: 'Search friends', border: InputBorder.none, isDense: true),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: 7,
                itemBuilder: (context, i) {
                  final checked = _selected.contains(i);
                  return CheckboxListTile(
                    value: checked,
                    activeColor: Colors.green,
                    secondary: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFDFDE0)),
                    title: const Text('James Chew', style: TextStyle(fontSize: 13)),
                    onChanged: (v) => setState(() => v! ? _selected.add(i) : _selected.remove(i)),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  widget.onConfirm(_selected.length);
                  Navigator.of(context).pop();
                },
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple full-page friend checklist, used e.g. for "Split Method: Equally".
class SplitFriendsPage extends StatefulWidget {
  const SplitFriendsPage({super.key});

  @override
  State<SplitFriendsPage> createState() => _SplitFriendsPageState();
}

class _SplitFriendsPageState extends State<SplitFriendsPage> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Split With', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 6,
              itemBuilder: (context, i) {
                final checked = _selected.contains(i);
                return CheckboxListTile(
                  value: checked,
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFD9D9D9)),
                  title: const Text('Yeoh Li Mei', style: TextStyle(fontSize: 14, color: Colors.black)),
                  onChanged: (v) => setState(() => v! ? _selected.add(i) : _selected.remove(i)),
                );
              },
            ),
          ),
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
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseDetailsFormPage extends StatefulWidget {
  const ExpenseDetailsFormPage({super.key});

  @override
  State<ExpenseDetailsFormPage> createState() => _ExpenseDetailsFormPageState();
}

class _ExpenseDetailsFormPageState extends State<ExpenseDetailsFormPage> {
  bool _reminder = true;
  String _location = 'NewYork';
  String _category = 'Food & Drinks';
  String _note = 'Day1 Drinks';

  void _editField(String label, String current, ValueChanged<String> onSaved) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $label', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onSaved(ctrl.text.trim().isEmpty ? current : ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Add Expenses', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(color: const Color(0xFFECECEC), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textGrey)),
                ),
                const SizedBox(height: 20),
                const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 8),
                _row('Title', 'Starbucks Coffee'),
                _row('Price', 'RM 36.8'),
                _row('Date', '14 June 2026 14:35'),
                _row('Location', _location, onTap: () => _editField('Location', _location, (v) => setState(() => _location = v))),
                _row('Category', _category, onTap: () => _editField('Category', _category, (v) => setState(() => _category = v))),
                _row('Note', _note, onTap: () => _editField('Note', _note, (v) => setState(() => _note = v))),
                _row('Split Method', 'Equally',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SplitFriendsPage()))),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reminder', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                      Switch(value: _reminder, activeColor: AppColors.primary, onChanged: (v) => setState(() => _reminder = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                onPressed: () => Navigator.of(context).popUntil((r) => r.settings.name == GroupTripPage.routeName),
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            Row(
              children: [
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Transaction detail
// ---------------------------------------------------------------------
class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final members = List.generate(6, (i) => i);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Transactions', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
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
                        children: const [
                          Text('Paid by', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          Spacer(),
                          CircleAvatar(radius: 14, backgroundColor: Color(0xFFD9D9D9)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Yy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                      const SizedBox(height: 12),
                      _kv('Total Amount', 'RM 200.00'),
                      _kv('Date', '14 June 2026'),
                      _kv('Category', 'Food & Drinks'),
                      _kv('Note', 'Mei Seafood'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Split Between (${members.length + 1} members)', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                const SizedBox(height: 8),
                _memberRow('Yy(you)', 'RM 23.60', null),
                for (final i in members) _memberRow('Yy', 'RM 23.60', i.isEven ? 'Pending' : 'Paid'),
              ],
            ),
          ),
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as paid')),
                  );
                  Navigator.of(context).maybePop();
                },
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

  Widget _memberRow(String name, String amount, String? status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.black))),
          Text(amount, style: const TextStyle(fontSize: 13, color: Colors.black)),
          const SizedBox(width: 8),
          if (status != null)
            Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status == 'Paid' ? Colors.green : Colors.orange)),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }
}
