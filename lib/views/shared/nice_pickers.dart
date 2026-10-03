import 'package:flutter/material.dart';

import '../../theme.dart';

// ---------------------------------------------------------------------
// Themed replacements for Flutter's default showDatePicker/showTimePicker
// system dialogs — rounded bottom sheets in the app's own navy/orange
// palette instead of the plain Material calendar/clock. showVoyaDatePicker
// and showVoyaDateRangePicker share one calendar widget (_VoyaCalendarSheet)
// so a range can be picked in a single flow (both ends highlighted with a
// connected pill, like a travel-booking calendar) instead of two separate
// dialogs chained together.
// ---------------------------------------------------------------------

/// What the calendar sheet pops with — kept private since callers only ever
/// see it through [showVoyaDatePicker]/[showVoyaDateRangePicker]'s own
/// return types ([DateTime]/[DateTimeRange]).
class _PickResult {
  final DateTime start;
  final DateTime? end;
  const _PickResult(this.start, [this.end]);
}

/// Single-date picker — e.g. date of birth, a one-off flight date.
Future<DateTime?> showVoyaDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Select Date',
}) async {
  final result = await showModalBottomSheet<_PickResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VoyaCalendarSheet(
      rangeMode: false,
      initialStart: initialDate,
      initialEnd: null,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    ),
  );
  return result?.start;
}

/// Two-date range picker — trip dates, hotel check-in/check-out. Both ends
/// are picked in one sheet (tap a start day, then an end day) instead of
/// two chained single-date dialogs.
Future<DateTimeRange?> showVoyaDateRangePicker({
  required BuildContext context,
  DateTime? initialStart,
  DateTime? initialEnd,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Select Dates',
}) async {
  final result = await showModalBottomSheet<_PickResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VoyaCalendarSheet(
      rangeMode: true,
      initialStart: initialStart,
      initialEnd: initialEnd,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    ),
  );
  if (result == null || result.end == null) return null;
  return DateTimeRange(start: result.start, end: result.end!);
}

class _VoyaCalendarSheet extends StatefulWidget {
  final bool rangeMode;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const _VoyaCalendarSheet({
    required this.rangeMode,
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  @override
  State<_VoyaCalendarSheet> createState() => _VoyaCalendarSheetState();
}

class _VoyaCalendarSheetState extends State<_VoyaCalendarSheet> {
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  late DateTime _firstDate;
  late DateTime _lastDate;
  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;
  bool _pickingYear = false;

  @override
  void initState() {
    super.initState();
    _firstDate = _dateOnly(widget.firstDate);
    _lastDate = _dateOnly(widget.lastDate);
    _start = widget.initialStart != null ? _clampToBounds(_dateOnly(widget.initialStart!)) : null;
    _end = widget.initialEnd != null ? _clampToBounds(_dateOnly(widget.initialEnd!)) : null;
    final anchor = _start ?? _dateOnly(DateTime.now());
    final anchorIdx = _monthIndex(anchor).clamp(_monthIndex(_firstDate), _monthIndex(_lastDate));
    _visibleMonth = _monthFromIndex(anchorIdx);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _clampToBounds(DateTime d) => d.isBefore(_firstDate) ? _firstDate : (d.isAfter(_lastDate) ? _lastDate : d);
  bool _isSame(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _inBounds(DateTime d) => !d.isBefore(_firstDate) && !d.isAfter(_lastDate);

  int _monthIndex(DateTime d) => d.year * 12 + (d.month - 1);
  DateTime _monthFromIndex(int idx) => DateTime(idx ~/ 12, idx % 12 + 1);

  bool get _canGoPrev => _monthIndex(_visibleMonth) > _monthIndex(_firstDate);
  bool get _canGoNext => _monthIndex(_visibleMonth) < _monthIndex(_lastDate);
  bool get _canConfirm => widget.rangeMode ? (_start != null && _end != null) : _start != null;

  void _changeMonth(int delta) {
    setState(() {
      final idx = (_monthIndex(_visibleMonth) + delta).clamp(_monthIndex(_firstDate), _monthIndex(_lastDate));
      _visibleMonth = _monthFromIndex(idx);
    });
  }

  void _jumpToYear(int year) {
    setState(() {
      final idx = _monthIndex(DateTime(year, _visibleMonth.month)).clamp(_monthIndex(_firstDate), _monthIndex(_lastDate));
      _visibleMonth = _monthFromIndex(idx);
      _pickingYear = false;
    });
  }

  void _selectDay(DateTime day) {
    if (!_inBounds(day)) return;
    setState(() {
      _visibleMonth = DateTime(day.year, day.month);
      if (!widget.rangeMode) {
        _start = day;
        return;
      }
      if (_start == null || _end != null) {
        // Nothing picked yet, or a full range was already picked — start over.
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  bool _cellHighlighted(DateTime day) {
    final isStart = _start != null && _isSame(day, _start!);
    final isEnd = _end != null && _isSame(day, _end!);
    final inRange = widget.rangeMode && _start != null && _end != null && day.isAfter(_start!) && day.isBefore(_end!);
    return isStart || isEnd || inRange;
  }

  String _formatDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 20, color: AppColors.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _pickingYear ? _buildYearGrid() : _buildCalendar(),
              if (!_pickingYear) ...[
                const SizedBox(height: 14),
                _buildSummary(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.chipGrey,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _canConfirm ? () => Navigator.of(context).pop(_PickResult(_start!, widget.rangeMode ? _end : null)) : null,
                    child: Text(
                      'Confirm',
                      style: TextStyle(color: _canConfirm ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    String text;
    if (!widget.rangeMode) {
      text = _start == null ? 'Pick a date' : _formatDate(_start!);
    } else if (_start != null && _end != null) {
      final nights = _end!.difference(_start!).inDays;
      text = '${_formatDate(_start!)}   →   ${_formatDate(_end!)}   ·   $nights night${nights == 1 ? '' : 's'}';
    } else if (_start != null) {
      text = '${_formatDate(_start!)}   →   pick an end date';
    } else {
      text = 'Pick a start and end date';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
    );
  }

  Widget _buildCalendar() {
    final weeks = _buildWeeks();
    return Column(
      children: [
        Row(
          children: [
            _navArrow(Icons.chevron_left, _canGoPrev ? () => _changeMonth(-1) : null),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _pickingYear = true),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more, size: 18, color: AppColors.navy),
                    ],
                  ),
                ),
              ),
            ),
            _navArrow(Icons.chevron_right, _canGoNext ? () => _changeMonth(1) : null),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: _weekdayLabels
              .map((l) => Expanded(child: Center(child: Text(l, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textGrey)))))
              .toList(),
        ),
        const SizedBox(height: 2),
        ...weeks.map(_buildWeekRow),
      ],
    );
  }

  Widget _navArrow(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, color: onTap == null ? AppColors.border : AppColors.navy),
      ),
    );
  }

  /// Always a full 6x7 block (padded with the previous/next month's
  /// overflow days) so the grid doesn't resize/jump between 4-, 5- and
  /// 6-row months.
  List<List<DateTime>> _buildWeeks() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leading = firstOfMonth.weekday % 7; // DateTime.weekday: Mon=1..Sun=7 -> want Sun=0..Sat=6
    final gridStart = firstOfMonth.subtract(Duration(days: leading));
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));
    return List.generate(6, (w) => days.sublist(w * 7, w * 7 + 7));
  }

  Widget _buildWeekRow(List<DateTime> days) {
    return Row(
      children: List.generate(7, (i) {
        final day = days[i];
        final inMonth = day.month == _visibleMonth.month;
        final inBounds = _inBounds(day);
        final isStart = _start != null && _isSame(day, _start!);
        final isEnd = _end != null && _isSame(day, _end!);
        final highlighted = _cellHighlighted(day);
        final isRangeEdge = isStart || isEnd;
        final isToday = _isSame(day, _dateOnly(DateTime.now()));

        // Whether this cell should visually merge with its row neighbour,
        // so a multi-day range reads as one continuous connected pill
        // instead of separate circles touching at their corners.
        final connectLeft = widget.rangeMode && highlighted && i > 0 && _cellHighlighted(days[i - 1]);
        final connectRight = widget.rangeMode && highlighted && i < 6 && _cellHighlighted(days[i + 1]);

        return Expanded(
          child: GestureDetector(
            onTap: inBounds ? () => _selectDay(day) : null,
            child: Container(
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: highlighted && !isRangeEdge ? AppColors.primary.withValues(alpha: 0.12) : null,
                borderRadius: BorderRadius.horizontal(
                  left: connectLeft ? Radius.zero : const Radius.circular(19),
                  right: connectRight ? Radius.zero : const Radius.circular(19),
                ),
              ),
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRangeEdge ? AppColors.primary : null,
                    border: isToday && !isRangeEdge ? Border.all(color: AppColors.primary, width: 1) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isRangeEdge ? FontWeight.bold : FontWeight.w500,
                      color: !inBounds
                          ? AppColors.border
                          : isRangeEdge
                              ? Colors.white
                              : !inMonth
                                  ? const Color(0xFFC9CDD3)
                                  : AppColors.navy,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildYearGrid() {
    final years = List.generate(_lastDate.year - _firstDate.year + 1, (i) => _firstDate.year + i);
    return SizedBox(
      height: 280,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6),
        itemCount: years.length,
        itemBuilder: (context, i) {
          final year = years[i];
          final selected = year == _visibleMonth.year;
          return GestureDetector(
            onTap: () => _jumpToYear(year),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.chipGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text('$year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.navy)),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Themed time picker — three scroll wheels (hour/minute/AM-PM) in a
// rounded sheet, in place of Flutter's default analogue/digital clock
// dialog.
// ---------------------------------------------------------------------

Future<TimeOfDay?> showVoyaTimePicker({
  required BuildContext context,
  TimeOfDay? initialTime,
  String title = 'Select Time',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VoyaTimeSheet(initialTime: initialTime ?? TimeOfDay.now(), title: title),
  );
}

class _VoyaTimeSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const _VoyaTimeSheet({required this.initialTime, required this.title});

  @override
  State<_VoyaTimeSheet> createState() => _VoyaTimeSheetState();
}

class _VoyaTimeSheetState extends State<_VoyaTimeSheet> {
  late int _hour12; // 1-12
  late int _minute; // 0-59
  late bool _isPm;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _periodCtrl;

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialTime.hour;
    _isPm = h24 >= 12;
    _hour12 = h24 % 12 == 0 ? 12 : h24 % 12;
    _minute = widget.initialTime.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _periodCtrl = FixedExtentScrollController(initialItem: _isPm ? 1 : 0);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _periodCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    final h24 = _isPm ? (_hour12 % 12) + 12 : (_hour12 % 12);
    return TimeOfDay(hour: h24, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy))),
                  GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, size: 20, color: AppColors.textGrey)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                    ),
                    Row(
                      children: [
                        Expanded(child: _wheel(_hourCtrl, 12, (i) => '${i + 1}'.padLeft(2, '0'), (i) => setState(() => _hour12 = i + 1))),
                        Expanded(child: _wheel(_minuteCtrl, 60, (i) => '$i'.padLeft(2, '0'), (i) => setState(() => _minute = i))),
                        Expanded(child: _wheel(_periodCtrl, 2, (i) => i == 0 ? 'AM' : 'PM', (i) => setState(() => _isPm = i == 1))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(_result),
                  child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wheel(FixedExtentScrollController ctrl, int count, String Function(int) label, ValueChanged<int> onChanged) {
    return ListWheelScrollView.useDelegate(
      controller: ctrl,
      itemExtent: 42,
      diameterRatio: 4,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Center(
          child: Text(label(i), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.navy)),
        ),
      ),
    );
  }
}
