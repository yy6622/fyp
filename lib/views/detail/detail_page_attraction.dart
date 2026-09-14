import 'package:flutter/material.dart';

import '../../repositories/catalog_repository.dart';
import '../../theme.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Attraction detail
// ---------------------------------------------------------------------
// Attractions don't have a purchase flow like flights/hotels do (there's
// nothing to "book" — you just go), so the bottom bar here is a save
// toggle instead of [BookingBar]. Saving is scoped to whichever trip the
// attraction was opened from (see CatalogRepository's class doc); when
// there's no trip context (onToggleSave is null) the button is just
// disabled rather than silently doing nothing.
class DetailPageAttraction extends StatefulWidget {
  final CatalogAttraction attraction;
  final bool saved;
  final VoidCallback? onToggleSave;

  const DetailPageAttraction({
    super.key,
    required this.attraction,
    this.saved = false,
    this.onToggleSave,
  });

  @override
  State<DetailPageAttraction> createState() => _DetailPageAttractionState();
}

class _DetailPageAttractionState extends State<DetailPageAttraction> {
  late bool _saved = widget.saved;

  void _toggle() {
    setState(() => _saved = !_saved);
    widget.onToggleSave?.call();
  }

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context) {
    final a = widget.attraction;
    // Only the days that actually have hours set, in week order — used so
    // the last *rendered* row is the one without a bottom border, even if
    // a future attraction's schedule skips a day (e.g. closed Mondays)
    // instead of always assuming Sunday is present.
    final presentDays = _weekdays.where((d) => a.openingHoursByDay[d] != null).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            DetailHeader(title: a.name),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  Text(a.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  // Star sits right before the rating number (matching
                  // Hotel's rating row) — it used to float next to the
                  // title instead, which read as decoration rather than
                  // part of the rating.
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text('${a.rating} (${a.reviews} reviews)', style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Every category as its own chip — not one label joined
                  // with a "•" dot.
                  Wrap(spacing: 6, runSpacing: 6, children: a.categoryTags.map(tagChip).toList()),
                  if (a.location.isNotEmpty || a.address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(a.address.isNotEmpty ? a.address : a.location, style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
                      ],
                    ),
                  ],
                  if (a.gallery.length > 1) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: a.gallery.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(a.gallery[i], width: 120, height: 90, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 16),
                  const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 10),
                  Text(
                    'One of the popular ${a.category.toLowerCase()} spots on this trip. Save it to your plan and check '
                    'opening hours and directions closer to your visit date.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5),
                  ),
                  if (a.highlights.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...a.highlights.map(_bulletRow),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: InfoField(label: 'Entry Price', value: a.price)),
                            Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoField(
                                label: 'Duration',
                                value: a.recommendedDuration.isEmpty ? 'Flexible' : a.recommendedDuration,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: InfoField(label: 'Opening Hours', value: a.openingHours)),
                            Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
                            const SizedBox(width: 16),
                            Expanded(child: InfoField(label: 'Location', value: a.location.isEmpty ? 'Not specified' : a.location)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!a.fees.isEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Entry Fees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECECEC))),
                      child: Column(
                        children: [
                          if (a.fees.adult != null) _feeRow('Adult', a.fees.adult!, last: a.fees.child == null && a.fees.senior == null),
                          if (a.fees.child != null) _feeRow('Child', a.fees.child!, last: a.fees.senior == null),
                          if (a.fees.senior != null) _feeRow('Senior', a.fees.senior!, last: true),
                        ],
                      ),
                    ),
                  ],
                  if (a.openingHoursByDay.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Weekly Hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECECEC))),
                      child: Column(
                        children: [
                          for (int i = 0; i < presentDays.length; i++)
                            _hoursRow(presentDays[i], a.openingHoursByDay[presentDays[i]]!, last: i == presentDays.length - 1),
                        ],
                      ),
                    ),
                  ],
                  if (a.facilities.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Facilities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: a.facilities.map(_facilityChip).toList()),
                  ],
                  if (a.phone.isNotEmpty || a.website.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Contact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 12),
                    if (a.phone.isNotEmpty) _contactRow(Icons.phone_outlined, a.phone),
                    if (a.phone.isNotEmpty && a.website.isNotEmpty) const SizedBox(height: 10),
                    if (a.website.isNotEmpty) _contactRow(Icons.language_outlined, a.website),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Text('entry price', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved ? Colors.white : AppColors.primary,
                      side: _saved ? const BorderSide(color: AppColors.primary) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.onToggleSave == null ? null : _toggle,
                    icon: Icon(_saved ? Icons.favorite : Icons.favorite_border, size: 18, color: _saved ? AppColors.primary : Colors.white),
                    label: Text(
                      _saved ? 'Saved' : 'Save',
                      style: TextStyle(color: _saved ? AppColors.primary : Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.4))),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _hoursRow(String day, String hours, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          Text(hours, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _facilityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
      ],
    );
  }
}
