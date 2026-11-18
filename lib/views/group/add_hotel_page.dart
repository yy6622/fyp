import 'package:flutter/material.dart';

import '../../repositories/trip_repository.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/member_select_section.dart';
import '../shared/nice_dialog.dart';
import '../shared/nice_pickers.dart';

const _hotelStatuses = ['Confirmed', 'Pending', 'Cancelled'];

/// A full page (not a cramped popup) for manually adding a hotel stay to the
/// trip's itinerary — every field the hotel detail page can show gets a
/// real place to be filled in here, including who the stay is for.
class AddHotelPage extends StatefulWidget {
  final Map<String, String> memberNames;
  const AddHotelPage({super.key, required this.memberNames});

  @override
  State<AddHotelPage> createState() => _AddHotelPageState();
}

class _AddHotelPageState extends State<AddHotelPage> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _checkIn = TextEditingController();
  final _checkOut = TextEditingController();
  final _bookingRef = TextEditingController();

  DateTime? _pickedCheckIn;
  DateTime? _pickedCheckOut;
  String _status = 'Confirmed';
  late Set<String> _forMemberUids;

  @override
  void initState() {
    super.initState();
    _forMemberUids = widget.memberNames.keys.toSet();
    _name.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_refresh);
    for (final c in [_name, _location, _checkIn, _checkOut, _bookingRef]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStayDates() async {
    final now = DateTime.now();
    final range = await showVoyaDateRangePicker(
      context: context,
      initialStart: _pickedCheckIn,
      initialEnd: _pickedCheckOut,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      title: 'Check-in & Check-out',
    );
    if (range != null) setState(() {
      _pickedCheckIn = range.start;
      _pickedCheckOut = range.end;
      _checkIn.text = formatLongDate(range.start);
      _checkOut.text = formatLongDate(range.end);
    });
  }

  Future<void> _pickStatus() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _hotelStatuses)
                    ChoiceChip(
                      label: Text(s, style: TextStyle(fontSize: 12, color: s == _status ? Colors.white : AppColors.navy)),
                      selected: s == _status,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.chipGrey,
                      showCheckmark: false,
                      onSelected: (_) => Navigator.of(ctx).pop(s),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) setState(() => _status = choice);
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(TripHotelStay(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      location: _location.text.trim(),
      checkIn: _checkIn.text.trim(),
      checkOut: _checkOut.text.trim(),
      bookingRef: _bookingRef.text.trim(),
      status: _status,
      forMemberUids: _forMemberUids.length >= widget.memberNames.length ? const [] : _forMemberUids.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Add Hotel Stay', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                niceDialogField(_name, 'Hotel Name', icon: Icons.hotel_outlined, autofocus: true, required: true),
                niceDialogField(_location, 'Location', icon: Icons.place_outlined),
                Row(
                  children: [
                    Expanded(child: niceDialogField(_checkIn, 'Check-in', icon: Icons.login, readOnly: true, onTap: _pickStayDates)),
                    const SizedBox(width: 10),
                    Expanded(child: niceDialogField(_checkOut, 'Check-out', icon: Icons.logout, readOnly: true, onTap: _pickStayDates)),
                  ],
                ),
                niceDialogField(_bookingRef, 'Booking Reference (optional)', icon: Icons.confirmation_num_outlined),
                _statusRow(),
                if (widget.memberNames.length > 1) ...[
                  const SizedBox(height: 4),
                  MemberSelectSection(
                    memberNames: widget.memberNames,
                    selected: _forMemberUids,
                    onChanged: (v) => setState(() => _forMemberUids = v),
                  ),
                  const SizedBox(height: 12),
                ],
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
                onPressed: _canSave ? _save : null,
                child: const Text('Add Hotel Stay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickStatus,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 18, color: AppColors.textGrey),
            const SizedBox(width: 10),
            const Expanded(child: Text('Status', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey))),
            Text(_status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
