import 'package:flutter/material.dart';

import '../../controllers/saved_items_controller.dart';
import '../../controllers/vote_controller.dart' show PickedSavedItem;
import '../../repositories/catalog_repository.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// "Add from Saved" — a bottom sheet for Create Vote's option list, so an
// option can be picked from what's already saved for this trip (a
// shortlisted hotel, attraction, restaurant or flight) instead of being
// typed out by hand every time. Multi-select, across all four
// flights/hotels/attractions/restaurants tabs at once — confirming
// appends one option per thing picked.
//
// [PickedSavedItem] itself lives in vote_controller.dart (it's what
// CreateVoteController's option list is actually made of), not here —
// this sheet just builds instances of it from the catalog rows it shows.
// ---------------------------------------------------------------------

/// Opens the picker and returns whatever was picked (empty/null if the
/// sheet was dismissed without confirming anything). [alreadyAdded] is the
/// set of [PickedSavedItem.dedupeKey]s already sitting in Create Vote's
/// option list — those rows show as already-added and can't be picked
/// again, so the exact same saved listing can't end up as two separate
/// options.
Future<List<PickedSavedItem>?> showSavedItemPicker(
  BuildContext context, {
  required String tripId,
  Set<String> alreadyAdded = const {},
}) {
  return showModalBottomSheet<List<PickedSavedItem>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _SavedItemPickerSheet(tripId: tripId, alreadyAdded: alreadyAdded),
  );
}

enum _PickerTab { flights, hotels, attractions, restaurants }

class _SavedItemPickerSheet extends StatefulWidget {
  final String tripId;
  final Set<String> alreadyAdded;
  const _SavedItemPickerSheet({required this.tripId, required this.alreadyAdded});

  @override
  State<_SavedItemPickerSheet> createState() => _SavedItemPickerSheetState();
}

class _SavedItemPickerSheetState extends State<_SavedItemPickerSheet> {
  late final SavedItemsController controller = SavedItemsController(tripId: widget.tripId);
  _PickerTab _tab = _PickerTab.flights;

  // Selection is keyed by "<kind>:<id>" (== PickedSavedItem.dedupeKey) ->
  // the full picked item, so confirming just returns `_selected.values`
  // regardless of which tabs the picks came from.
  final Map<String, PickedSavedItem> _selected = {};

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _toggle(PickedSavedItem item) {
    if (widget.alreadyAdded.contains(item.dedupeKey)) return;
    setState(() {
      if (_selected.containsKey(item.dedupeKey)) {
        _selected.remove(item.dedupeKey);
      } else {
        _selected[item.dedupeKey] = item;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Add from Saved', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textGrey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(child: _tabButton('Flights', _PickerTab.flights)),
                  Expanded(child: _tabButton('Hotels', _PickerTab.hotels)),
                  Expanded(child: _tabButton('Attractions', _PickerTab.attractions)),
                  Expanded(child: _tabButton('Food', _PickerTab.restaurants)),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFECECEC)),
              Expanded(child: _body(scrollController)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.values.toList()),
                      child: Text(
                        _selected.isEmpty ? 'Select items to add' : 'Add ${_selected.length} Option${_selected.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Same shape as SavedItemsPage's own tab row (Expanded + bottom-border
  // underline) rather than fixed-width pill chips — four chips wide
  // enough to fit "Attractions" in full, side by side with no scrolling,
  // overflowed past the screen edge on a real phone. Expanded always
  // divides the available width evenly, so this can't overflow no matter
  // how long a label is.
  Widget _tabButton(String label, _PickerTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey),
        ),
      ),
    );
  }

  Widget _body(ScrollController scrollController) {
    switch (_tab) {
      case _PickerTab.flights:
        return _list(
          scrollController,
          loading: controller.loadingFlights,
          count: controller.flights.length,
          emptyMessage: 'No flights saved for this trip yet.',
          itemBuilder: (i) {
            final f = controller.flights[i];
            return _row(PickedSavedItem(
              kind: 'flight',
              id: f.id,
              label: '${f.from} → ${f.to}',
              subtitle: '${f.depTime} - ${f.arrTime} · ${f.stops}',
              fallbackIcon: Icons.flight_outlined,
            ));
          },
        );
      case _PickerTab.hotels:
        return _list(
          scrollController,
          loading: controller.loadingHotels,
          count: controller.hotels.length,
          emptyMessage: 'No hotels saved for this trip yet.',
          itemBuilder: (i) {
            final h = controller.hotels[i];
            return _row(PickedSavedItem(
              kind: 'hotel',
              id: h.id,
              label: h.name,
              subtitle: h.location,
              imageUrl: h.image,
              rating: h.rating,
              fallbackIcon: Icons.hotel_outlined,
            ));
          },
        );
      case _PickerTab.attractions:
        return _list(
          scrollController,
          loading: controller.loadingAttractions,
          count: controller.attractions.length,
          emptyMessage: 'No attractions saved for this trip yet.',
          itemBuilder: (i) {
            final a = controller.attractions[i];
            return _row(PickedSavedItem(
              kind: 'attraction',
              id: a.id,
              label: a.name,
              subtitle: a.category,
              imageUrl: a.image,
              rating: a.rating,
              fallbackIcon: Icons.attractions_outlined,
            ));
          },
        );
      case _PickerTab.restaurants:
        return _list(
          scrollController,
          loading: controller.loadingRestaurants,
          count: controller.restaurants.length,
          emptyMessage: 'No restaurants saved for this trip yet.',
          itemBuilder: (i) {
            final r = controller.restaurants[i];
            return _row(PickedSavedItem(
              kind: 'restaurant',
              id: r.id,
              label: r.name,
              subtitle: r.cuisineLabel,
              imageUrl: r.image,
              rating: r.rating,
              fallbackIcon: Icons.restaurant_outlined,
            ));
          },
        );
    }
  }

  Widget _list(
    ScrollController scrollController, {
    required bool loading,
    required int count,
    required String emptyMessage,
    required Widget Function(int) itemBuilder,
  }) {
    if (loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (count == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFECECEC)),
      itemBuilder: (context, i) => itemBuilder(i),
    );
  }

  Widget _row(PickedSavedItem item) {
    final alreadyAdded = widget.alreadyAdded.contains(item.dedupeKey);
    final checked = alreadyAdded || _selected.containsKey(item.dedupeKey);
    return InkWell(
      onTap: alreadyAdded ? null : () => _toggle(item),
      child: Opacity(
        opacity: alreadyAdded ? 0.45 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              _thumb(item.imageUrl, item.fallbackIcon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Already sitting in Create Vote's option list (picked in an
              // earlier "From Saved" trip to this sheet) — shown locked-in
              // rather than selectable, so the same listing can't become
              // two separate options.
              alreadyAdded
                  ? const Text('Added', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textGrey))
                  : Icon(
                      checked ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: checked ? AppColors.primary : const Color(0xFFD9D9D9),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(String? url, IconData fallbackIcon) {
    final hasUrl = (url ?? '').isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        color: AppColors.chipGrey,
        child: hasUrl
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 18, color: AppColors.textGrey),
              )
            : Icon(fallbackIcon, size: 18, color: AppColors.textGrey),
      ),
    );
  }
}
