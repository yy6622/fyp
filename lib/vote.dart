import 'package:flutter/material.dart';

import 'theme.dart';

// ---------------------------------------------------------------------
// Vote tab — lives inside GroupTripPage
// ---------------------------------------------------------------------
class VoteTab extends StatefulWidget {
  const VoteTab({super.key});

  @override
  State<VoteTab> createState() => _VoteTabState();
}

class _VoteTabState extends State<VoteTab> {
  int _hotelSelected = 0;
  bool _attractionExpanded = false;
  bool _flightExpanded = false;

  final _hotelOptions = const [
    ('L Hotel', '4.8(1.2k)', 'RM 899', 'Shinjoku, Tokyo', 3, 5),
    ('L Hotel', '4.8(1.2k)', 'RM 899', 'Shinjoku, Tokyo', 3, 5),
    ('L Hotel', '4.8(1.2k)', 'RM 899', 'Shinjoku, Tokyo', 3, 5),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      children: [
        const Text('New', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hotel Suggestion', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 10),
              ...List.generate(_hotelOptions.length, (i) => _hotelOption(i)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _accordionHeader('Attraction Suggestion', _attractionExpanded, () => setState(() => _attractionExpanded = !_attractionExpanded)),
        const SizedBox(height: 12),
        _accordionHeader('Flight Suggestion', _flightExpanded, () => setState(() => _flightExpanded = !_flightExpanded)),
      ],
    );
  }

  Widget _hotelOption(int index) {
    final option = _hotelOptions[index];
    final selected = _hotelSelected == index;
    return GestureDetector(
      onTap: () => setState(() => _hotelSelected = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFECECEC), width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Colors.green : AppColors.textGrey, size: 20),
            const SizedBox(width: 8),
            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(option.$1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(width: 6),
                      const Icon(Icons.star, size: 12, color: AppColors.orange),
                      Text(option.$2, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    ],
                  ),
                  Text(option.$4, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                  Row(
                    children: [
                      Text(option.$3, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const Text(' per night', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              height: 18,
              child: Stack(
                children: List.generate(option.$5, (i) => Positioned(left: i * 11.0, child: CircleAvatar(radius: 9, backgroundColor: Colors.primaries[i % Colors.primaries.length]))),
              ),
            ),
            Text('${option.$5}/${option.$6}', style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _accordionHeader(String label, bool expanded, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Create Vote
// ---------------------------------------------------------------------
class CreateVotePage extends StatefulWidget {
  const CreateVotePage({super.key});

  @override
  State<CreateVotePage> createState() => _CreateVotePageState();
}

class _CreateVotePageState extends State<CreateVotePage> {
  final List<String> _options = ['L Hotel · Shinjoku, Tokyo · RM 899/night', 'L Hotel · Shinjoku, Tokyo · RM 899/night', 'L Hotel · Shinjoku, Tokyo · RM 899/night'];
  bool _allowAddOptions = true;
  bool _allowMultipleChoice = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Create Vote', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                _boxField(hint: 'e.g. Which hotel should we book?'),
                const SizedBox(height: 20),
                const Text('Add Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                ..._options.asMap().entries.map((e) => _optionRow(e.key, e.value)),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Color(0xFFECECEC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _options.add('New option')),
                  icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
                  label: const Text('Add Options', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 20),
                const Text('Deadline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('10 May 2026, 23:59', style: TextStyle(fontSize: 13, color: Colors.black)),
                      Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textGrey),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _switchRow('Allow members to add options', _allowAddOptions, (v) => setState(() => _allowAddOptions = v)),
                _switchRow('Allow multiple choice', _allowMultipleChoice, (v) => setState(() => _allowMultipleChoice = v)),
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
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Create Vote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boxField({required String hint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGrey), border: InputBorder.none),
      ),
    );
  }

  Widget _optionRow(int index, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(6))),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11.5, color: Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis)),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.textGrey),
            onPressed: () => setState(() => _options.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black))),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
