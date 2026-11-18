import 'package:flutter/material.dart';

import '../../models/day_plan_models.dart';
import '../../theme.dart';


const double _hourHeight = 88.0;
const double _rulerWidth = 56.0;
const int _minutesPerDay = 24 * 60;
const int _snapMinutes = 30;
const int _maxMinutes = _minutesPerDay - _snapMinutes;

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

String _formatTime12h(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h24 >= 12 ? 'pm' : 'am';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h:${m.toString().padLeft(2, '0')} $suffix';
}

// Public wrappers so GroupTripPage can turn a drag-drop's raw screen
// position into a time-of-day using this view's own hour-grid math,
// without duplicating the constants/rounding above.
int timelineYToMinutes(double y) => _snap(_yToMinutes(y));

String timelineMinutesToHHMM(int minutes) => _minutesToHHMM(minutes);

class DayTimelineView extends StatefulWidget {
  final List<ActivityItem> items;
  final void Function(ActivityItem item) onDelete;

  final String? emptyHint;

  final GlobalKey viewportKey;
  final ScrollController scrollController;

  final void Function(ActivityItem item)? onItemDragStarted;
  final void Function(Offset globalPosition)? onItemDragUpdate;
  final void Function(ActivityItem item)? onItemDragEnd;

  const DayTimelineView({
    super.key,
    required this.items,
    required this.onDelete,
    required this.viewportKey,
    required this.scrollController,
    this.emptyHint,
    this.onItemDragStarted,
    this.onItemDragUpdate,
    this.onItemDragEnd,
  });

  @override
  State<DayTimelineView> createState() => _DayTimelineViewState();
}

class _DayTimelineViewState extends State<DayTimelineView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.hasClients) return;
      final earliest = widget.items.isEmpty
          ? 8 * 60
          : widget.items.map((it) => _hhmmToMinutes(it.time)).reduce((a, b) => a < b ? a : b);
      final target = _minutesToY((earliest - 60).clamp(0, _maxMinutes));
      widget.scrollController.jumpTo(target.clamp(0, widget.scrollController.position.maxScrollExtent));
    });
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
            'Long-press an activity to drag it to a new time — hold near the left/right edge of the screen to move it to another day.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textGrey, fontStyle: FontStyle.italic),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                key: widget.viewportKey,
                controller: widget.scrollController,
                child: SizedBox(
                  height: totalHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Group items that land on the exact same time so they
                      // can be laid out side-by-side instead of one chip
                      // fully overlapping (and hiding) the other.
                      final byMinute = <int, List<ActivityItem>>{};
                      for (final it in widget.items) {
                        byMinute.putIfAbsent(_hhmmToMinutes(it.time), () => []).add(it);
                      }
                      final availableSpan =
                          (constraints.maxWidth - _rulerWidth - 8).clamp(0.0, double.infinity);
                      return Stack(
                        children: [
                          for (var h = 0; h < 24; h++) _hourRow(h),
                          for (final item in widget.items)
                            _buildChip(item, byMinute, availableSpan),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (widget.emptyHint != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          widget.emptyHint!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    ActivityItem item,
    Map<int, List<ActivityItem>> byMinute,
    double availableSpan,
  ) {
    final group = byMinute[_hhmmToMinutes(item.time)]!;
    final columnCount = group.length;
    final columnIndex = columnCount > 1 ? group.indexWhere((it) => it.id == item.id) : 0;
    final columnWidth = columnCount > 1 ? availableSpan / columnCount : null;
    final left = _rulerWidth + 8 + (columnWidth != null ? columnIndex * columnWidth : 0);
    final width = columnWidth != null ? (columnWidth - 6).clamp(0.0, double.infinity) : null;
    return _TimelineChip(
      key: ValueKey(item.id),
      item: item,
      minutes: _hhmmToMinutes(item.time),
      left: left,
      width: width,
      onDelete: () => widget.onDelete(item),
      onDragStarted: () => widget.onItemDragStarted?.call(item),
      onDragUpdate: (pos) => widget.onItemDragUpdate?.call(pos),
      onDragEnd: () => widget.onItemDragEnd?.call(item),
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

class _TimelineChip extends StatelessWidget {
  final ActivityItem item;
  final int minutes;
  final double left;
  final double? width;
  final VoidCallback onDelete;
  final VoidCallback? onDragStarted;
  final void Function(Offset globalPosition)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const _TimelineChip({
    super.key,
    required this.item,
    required this.minutes,
    required this.left,
    this.width,
    required this.onDelete,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    // GroupTripPage resolves every drop (same-day re-time, or a move to
    // another day) itself from the raw drag position, via onDragEnd —
    // this chip just reports drag lifecycle events upward and renders.
    return Positioned(
      top: _minutesToY(minutes),
      left: left,
      right: width == null ? 0 : null,
      width: width,
      child: LongPressDraggable<String>(
        data: item.id,
        hapticFeedbackOnStart: true,
        feedback: _chipCard(dragging: true),
        childWhenDragging: Opacity(opacity: 0.3, child: _chipCard(dragging: false)),
        onDragStarted: onDragStarted,
        onDragUpdate: (details) => onDragUpdate?.call(details.globalPosition),
        onDragEnd: (_) => onDragEnd?.call(),
        child: _chipCard(dragging: false),
      ),
    );
  }

  Widget _chipCard({required bool dragging}) {
    return Material(
      elevation: dragging ? 6 : 0,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: Container(
        width: dragging ? 240 : null,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dragging ? Colors.white : AppColors.divider,
          borderRadius: BorderRadius.circular(14),
          border: dragging ? Border.all(color: AppColors.primary, width: 1.4) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
              child: Icon(item.icon, size: 16, color: AppColors.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime12h(minutes),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: dragging ? AppColors.primary : AppColors.textGrey,
                    ),
                  ),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                  if (item.location.isNotEmpty)
                    Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
                    ),
                ],
              ),
            ),
            if (!dragging)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
