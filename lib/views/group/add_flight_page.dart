import 'package:flutter/material.dart';

import '../../data/airlines.dart';
import '../../repositories/trip_repository.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/member_select_section.dart';
import '../shared/nice_dialog.dart';
import '../shared/nice_pickers.dart';
import 'group_trip_page.dart' show flightLocationOptions, extractAirportCode;

const _flightStatuses = ['Confirmed', 'Pending', 'Cancelled'];

/// A full page (not a cramped popup) for manually adding a flight to the
/// trip's itinerary — every field the flight detail page can show gets a
/// real place to be filled in here, including who the flight is for.
class AddFlightPage extends StatefulWidget {
  final Map<String, String> memberNames;
  const AddFlightPage({super.key, required this.memberNames});

  @override
  State<AddFlightPage> createState() => _AddFlightPageState();
}

class _AddFlightPageState extends State<AddFlightPage> {
  final _airline = TextEditingController();
  final _flightNumber = TextEditingController();
  final _fromCode = TextEditingController();
  final _toCode = TextEditingController();
  final _dateText = TextEditingController();
  final _timeText = TextEditingController();
  final _arrivalTimeText = TextEditingController();
  final _terminal = TextEditingController();
  final _bookingRef = TextEditingController();

  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  TimeOfDay? _pickedArrivalTime;
  String _status = 'Confirmed';
  late Set<String> _forMemberUids;

  @override
  void initState() {
    super.initState();
    _forMemberUids = widget.memberNames.keys.toSet();
    _airline.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _airline.removeListener(_refresh);
    for (final c in [_airline, _flightNumber, _fromCode, _toCode, _dateText, _timeText, _arrivalTimeText, _terminal, _bookingRef]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showVoyaDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      title: 'Flight Date',
    );
    if (d != null) setState(() {
      _pickedDate = d;
      _dateText.text = formatLongDate(d);
    });
  }

  Future<void> _pickTime() async {
    final t = await showVoyaTimePicker(context: context, initialTime: _pickedTime ?? TimeOfDay.now(), title: 'Departure Time');
    if (t != null) setState(() {
      _pickedTime = t;
      _timeText.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickArrivalTime() async {
    final t = await showVoyaTimePicker(context: context, initialTime: _pickedArrivalTime ?? TimeOfDay.now(), title: 'Arrival Time');
    if (t != null) setState(() {
      _pickedArrivalTime = t;
      _arrivalTimeText.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
                  for (final s in _flightStatuses)
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

  bool get _canSave => _airline.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    final from = _fromCode.text.trim().isEmpty ? '' : extractAirportCode(_fromCode.text);
    final to = _toCode.text.trim().isEmpty ? '' : extractAirportCode(_toCode.text);
    final route = from.isEmpty && to.isEmpty ? '' : '$from → $to';
    final dateTime = [
      if (_dateText.text.trim().isNotEmpty) _dateText.text.trim(),
      if (_timeText.text.trim().isNotEmpty) _timeText.text.trim(),
    ].join(', ');
    Navigator.of(context).pop(TripFlight(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      airline: _airline.text.trim(),
      flightNumber: _flightNumber.text.trim(),
      routeCode: route,
      routeCities: '',
      dateTime: dateTime,
      arrivalTime: _arrivalTimeText.text.trim(),
      terminal: _terminal.text.trim(),
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
        title: Text('Add Flight', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                niceAutocompleteField(_airline, 'Airline', options: kAirlines, icon: Icons.flight_outlined, autofocus: true),
                niceDialogField(_flightNumber, 'Flight Number (optional)', icon: Icons.confirmation_number_outlined),
                Row(
                  children: [
                    Expanded(child: niceAutocompleteField(_fromCode, 'From (city or airport)', options: flightLocationOptions, icon: Icons.flight_takeoff)),
                    const SizedBox(width: 10),
                    Expanded(child: niceAutocompleteField(_toCode, 'To (city or airport)', options: flightLocationOptions, icon: Icons.flight_land)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: niceDialogField(_dateText, 'Date', icon: Icons.event_outlined, readOnly: true, onTap: _pickDate)),
                    const SizedBox(width: 10),
                    Expanded(child: niceDialogField(_timeText, 'Departure Time', icon: Icons.access_time, readOnly: true, onTap: _pickTime)),
                  ],
                ),
                niceDialogField(_arrivalTimeText, 'Arrival Time (optional)', icon: Icons.flight_land, readOnly: true, onTap: _pickArrivalTime),
                niceDialogField(_terminal, 'Terminal (optional)', icon: Icons.meeting_room_outlined),
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
                child: const Text('Add Flight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
