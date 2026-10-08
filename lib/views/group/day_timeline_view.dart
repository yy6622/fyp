import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/day_plan_models.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// The Day tab's edit-mode view: a vertical 24-hour time ruler with each
// activity positioned at its own time, which can be dragged up/down to
// reschedule it (release = new time, snapped to 5 minutes) — the
// Google-Calendar-style interaction the user sketched out, replacing the
// old "delete and re-add" as the only way to change an existing
// activity's time. Shown only while Day edit mode is on
// (group_trip_page.dart's `_dayEditMode`); the plain mode keeps the
// original simple list untouched.
// ---------------------------------------------------------------------

const double _hourHeight = 88.0;
const double _rulerWidth = 56.0;
const int _minutesPerDay = 24 * 60;
const int _snapMinutes = 5;
const int _maxMinutes = _minutesPerDay - _snapMinutes; // 23:55, last snappable slot

// Auto-scroll-while-dragging tuning: once a dragged chip gets within
// [_autoScrollEdge] px of the top/bottom of the visible timeline, the
// view starts scrolling toward that edge, picking up speed the closer
// the finger gets (up to [_autoScrollMaxSpeed] px per [_autoScrollTick]).
const double _autoScrollEdge = 64.0;
const double _autoScrollMaxSpeed = 14.0;
const Duration _autoScrollTick = Duration(milliseconds: 16);

double _minutesToY(int minutes) => minutes / 60 * _hourHeight;

int _yToMinutes(double y) => (y / _hourHeight * 60).round().clamp(0, _maxMinutes);

int _snap(int minutes) => ((minutes / _snapMinutes).round() * _snapMinutes).clamp(0, _maxMinutes);

int _hhmmToMinutes(String time24) {
  final parts = time24.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return (h * 60 + m).clamp(0, _maxMinutes);
}

String _minutesToHHMM(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Same conversion as group_trip_page.dart's own `_formatTime12h` — kept
/// as a standalone copy here (this file has no access to that private
/// method) rather than made public just for one other caller.
String _formatTime12h(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h24 >= 12 ? 'pm' : 'am';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h:${m.toString().padLeft(2, '0')} $suffix';
}

class DayTimelineView extends StatefulWidget {
  final List<ActivityItem> items;
  final void Function(ActivityItem item, String newTime24) onTimeChanged;
  final void Function(ActivityItem item) onDelete;

  const DayTimelineView({
    super.key,
    required this.items,
    required this.onTimeChanged,
    required this.onDelete,
  });

  @override
  State<DayTimelineView> createState() => _DayTimelineViewState();
}

class _DayTimelineViewState extends State<DayTimelineView> {
  final ScrollController _scroll = ScrollController();
  // Resolves the SingleChildScrollView's own RenderBox (the visible
  // viewport, not the scrolled content) so a dragging chip can tell how
  // close the finger is to the top/bottom edge in screen space.
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Opens roughly an hour above the earliest activity (or mid-morning
    // if the day has nothing yet) instead of always at 00:00 — nobody
    // plans a trip starting at midnight, so starting the scroll there
    // would mean an extra scroll on every single open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final earliest = widget.items.isEmpty
          ? 8 * 60
          : widget.items.map((it) => _hhmmToMinutes(it.time)).reduce((a, b) => a < b ? a : b);
      final target = _minutesToY((earliest - 60).clamp(0, _maxMinutes));
      _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const totalHeight = _minutesPerDay / 60 * _hourHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Drag an activity to change its time',
            style: TextStyle(fontSize: 11.5, color: AppColors.textGrey, fontStyle: FontStyle.italic),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: _viewportKey,
            controller: _scroll,
            child: SizedBox(
              height: totalHeight,
              child: Stack(
                children: [
                  for (var h = 0; h < 24; h++) _hourRow(h),
                  for (final item in widget.items)
                    _TimelineChip(
                      key: ValueKey(item.id),
                      item: item,
                      minutes: _hhmmToMinutes(item.time),
                      scrollController: _scroll,
                      viewportKey: _viewportKey,
                      onCommit: (minutes) => widget.onTimeChanged(item, _minutesToHHMM(minutes)),
                      onDelete: () => widget.onDelete(item),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hourRow(int hour) {
    return Positioned(
      top: hour * _hourHeight,
      left: 0,
      right: 0,
      child: SizedBox(
        height: _hourHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Full-hour line, labelled.
            Positioned(
              top: -7,
              left: 0,
              width: _rulerWidth,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textGrey),
              ),
            ),
            Positioned(top: 0, left: _rulerWidth, right: 0, child: Container(height: 1, color: AppColors.divider)),
            // Half-hour line, unlabelled and lighter.
            Positioned(
              top: _hourHeight / 2,
              left: _rulerWidth,
              right: 0,
              child: Container(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineChip extends StatefulWidget {
  final ActivityItem item;
  final int minutes;
  final ScrollController scrollController;
  final GlobalKey viewportKey;
  final void Function(int minutes) onCommit;
  final VoidCallback onDelete;

  const _TimelineChip({
    super.key,
    required this.item,
    required this.minutes,
    required this.scrollController,
    required this.viewportKey,
    required this.onCommit,
    required this.onDelete,
  });

  @override
  State<_TimelineChip> createState() => _TimelineChipState();
}

class _TimelineChipState extends State<_TimelineChip> {
  // Pixel offset while actively being dragged; null the rest of the
  // time, when the chip just sits at widget.minutes' canonical position.
  // Tracked as a raw pixel value (not minutes) so repeated small
  // onVerticalDragUpdate deltas don't compound rounding error the way
  // re-deriving minutes on every single update tick would.
  double? _dragTop;

  // Non-zero while the finger sits in the top/bottom edge zone of the
  // viewport during a drag — signed px-per-tick, applied by
  // [_autoScrollTimer] until the finger moves back away from the edge
  // or the drag ends.
  double _autoScrollDelta = 0;
  Timer? _autoScrollTimer;

  double get _canonicalTop => _minutesToY(widget.minutes);
  double get _effectiveTop => _dragTop ?? _canonicalTop;
  bool get _dragging => _dragTop != null;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  /// Re-checks how close [globalPosition] (the finger, in screen space)
  /// is to the viewport's top/bottom edge, and starts/stops/retargets
  /// the auto-scroll timer accordingly. Called on every drag update so
  /// the scroll speed keeps tracking the finger as it moves.
  void _updateAutoScroll(Offset globalPosition) {
    final viewportBox = widget.viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) {
      _stopAutoScroll();
      return;
    }
    final local = viewportBox.globalToLocal(globalPosition);
    final height = viewportBox.size.height;
    double delta = 0;
    if (local.dy < _autoScrollEdge) {
      final strength = ((_autoScrollEdge - local.dy) / _autoScrollEdge).clamp(0.0, 1.0);
      delta = -_autoScrollMaxSpeed * strength;
    } else if (local.dy > height - _autoScrollEdge) {
      final strength = ((local.dy - (height - _autoScrollEdge)) / _autoScrollEdge).clamp(0.0, 1.0);
      delta = _autoScrollMaxSpeed * strength;
    }
    _autoScrollDelta = delta;
    if (delta != 0) {
      _autoScrollTimer ??= Timer.periodic(_autoScrollTick, (_) => _tickAutoScroll());
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  /// One auto-scroll step: nudges the real scroll offset, then nudges
  /// the dragged chip's own content-space position by exactly the same
  /// amount actually applied (clamping may shrink it near either end of
  /// the list) — that's what keeps the chip sitting still under the
  /// finger while the timeline scrolls underneath it.
  void _tickAutoScroll() {
    if (!_dragging || _autoScrollDelta == 0 || !widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    final newOffset = (position.pixels + _autoScrollDelta).clamp(0.0, position.maxScrollExtent);
    final actualDelta = newOffset - position.pixels;
    if (actualDelta == 0) return;
    widget.scrollController.jumpTo(newOffset);
    setState(() {
      _dragTop = (_dragTop! + actualDelta).clamp(0.0, _minutesToY(_maxMinutes));
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollDelta = 0;
  }

  @override
  Widget build(BuildContext context) {
    final liveMinutes = _dragging ? _snap(_yToMinutes(_dragTop!)) : widget.minutes;
    return Positioned(
      top: _effectiveTop,
      left: _rulerWidth + 8,
      right: 0,
      child: GestureDetector(
        onVerticalDragStart: (details) {
          setState(() => _dragTop = _canonicalTop);
          _updateAutoScroll(details.globalPosition);
        },
        onVerticalDragUpdate: (details) {
          setState(() => _dragTop = (_dragTop! + details.delta.dy).clamp(0.0, _minutesToY(_maxMinutes)));
          _updateAutoScroll(details.globalPosition);
        },
        onVerticalDragEnd: (_) {
          _stopAutoScroll();
          final newMinutes = _snap(_yToMinutes(_dragTop!));
          setState(() => _dragTop = null);
          if (newMinutes != widget.minutes) widget.onCommit(newMinutes);
        },
        onVerticalDragCancel: () {
          _stopAutoScroll();
          setState(() => _dragTop = null);
        },
        child: Material(
          elevation: _dragging ? 6 : 0,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _dragging ? Colors.white : AppColors.divider,
              borderRadius: BorderRadius.circular(14),
              border: _dragging ? Border.all(color: AppColors.primary, width: 1.4) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
                  child: Icon(widget.item.icon, size: 16, color: AppColors.navy),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Live time while dragging, same spot a finger is
                        // already looking at — this is the "see it move
                        // between 10:00am-2:30am as you scroll" part of
                        // the sketch.
                        _formatTime12h(liveMinutes),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _dragging ? AppColors.primary : AppColors.textGrey,
                        ),
                      ),
                      Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy),
                      ),
                      if (widget.item.location.isNotEmpty)
                        Text(
                          widget.item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6, top: 2),
                    child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
