import 'package:flutter/material.dart';

import '../../controllers/vote_controller.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';

// ---------------------------------------------------------------------
// Vote tab — lives inside GroupTripPage. Shows every real poll created for
// this trip (`trips/{tripId}/votes`) — hotel picks, attraction picks,
// anything a member created via Create Vote.
//
// Each poll is a collapsible card (tap the header to fold/unfold), and
// each of its options is its own card: an option picked "From Saved" in
// Create Vote is matched back to the real hotel/attraction/restaurant/
// flight behind it (via VoteTabController) and shown with its real image,
// rating, location and price, not just its label text. An option typed
// by hand instead just shows its text — still styled the same way, it
// simply has nothing more than that to show.
// ---------------------------------------------------------------------
class VoteTab extends StatefulWidget {
  final String tripId;
  const VoteTab({super.key, required this.tripId});

  @override
  State<VoteTab> createState() => _VoteTabState();
}

class _VoteTabState extends State<VoteTab> {
  late final VoteTabController controller = VoteTabController(tripId: widget.tripId);

  /// A poll's collapsed state, once the person has tapped its header to
  /// fold/unfold it themselves — overrides [_defaultCollapsed] for that
  /// poll id for the rest of this screen's lifetime. A poll id absent
  /// from this map just uses the default: a closed poll starts folded
  /// (it doesn't need anyone's vote any more), and among open polls only
  /// the newest starts unfolded — if there are several open polls at
  /// once, the rest start folded too rather than filling the screen with
  /// every one of them expanded.
  final Map<String, bool> _collapsedOverride = {};

  bool _defaultCollapsed(TripVote vote) {
    if (vote.isClosed) return true;
    final openVotes = controller.votes.where((v) => !v.isClosed);
    if (openVotes.isEmpty) return false;
    // controller.votes is already newest-first (TripRepository.watchVotes
    // orders by createdAt descending), so the first open poll found is
    // the latest one.
    return vote.id != openVotes.first.id;
  }

  bool _isCollapsed(TripVote vote) => _collapsedOverride[vote.id] ?? _defaultCollapsed(vote);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (controller.votes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No polls yet — tap + to ask the group to vote on something (a hotel, an activity, anything).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
          children: controller.votes.map((v) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _voteCard(v))).toList(),
        );
      },
    );
  }

  // ---------------- Poll card (collapsible header + its option cards) ----------------
  Widget _voteCard(TripVote vote) {
    final collapsed = _isCollapsed(vote);
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _collapsedOverride[vote.id] = !collapsed),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(vote.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            ),
                            if (vote.isClosed)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(8)),
                                child: const Text('Closed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          vote.deadline != null
                              ? '${vote.allowMultipleChoice ? 'Multiple choice' : 'Single choice'} · ${_deadlineLabel(vote)}'
                              : (vote.allowMultipleChoice ? 'Multiple choice' : 'Single choice'),
                          style: TextStyle(fontSize: 10.5, color: vote.isClosed ? Colors.redAccent : AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(collapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: AppColors.textGrey),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  ...vote.options.map((o) => _optionCard(vote, o)),
                  if (vote.allowAddOptions && !vote.isClosed) _addOptionRow(vote),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Shown under a poll's option cards only when its creator turned on
  /// "Allow members to add options" and the poll is still open — the
  /// control [TripVote.allowAddOptions] actually enables now, after
  /// previously being stored on the vote but read nowhere.
  Widget _addOptionRow(TripVote vote) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _promptAddOption(vote),
        icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
        label: const Text('Add option', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _promptAddOption(TripVote vote) async {
    final textController = TextEditingController();
    final confirmed = await showNiceFormDialog(
      context: context,
      title: 'Add option',
      headerIcon: Icons.add_circle_outline,
      confirmLabel: 'Add',
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(textController, 'Option', icon: Icons.edit_outlined, autofocus: true),
      ],
    );
    if (confirmed != true) return;
    final ok = await controller.addOption(vote, textController.text);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter an option that isn't already on the list.")),
      );
    }
  }

  String _deadlineLabel(TripVote vote) {
    final d = vote.deadline!;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12 ? 'AM' : 'PM';
    final when = '${d.day} ${months[d.month]}, $hour12:${d.minute.toString().padLeft(2, '0')} $period';
    return vote.isClosed ? 'Voting closed $when' : 'Closes $when';
  }

  // ---------------- Option card ----------------
  // Dispatches to whichever saved-item shape (if any) this option's label
  // matches, each rendered as its own real-looking card; falls back to a
  // plain label card for a freely-typed option that matches nothing saved.
  Widget _optionCard(TripVote vote, VoteOption option) {
    final mineVoted = controller.votedByMe(option);
    final hotel = controller.hotelFor(option);
    final attraction = hotel == null ? controller.attractionFor(option) : null;
    final restaurant = hotel == null && attraction == null ? controller.restaurantFor(option) : null;
    final flight = hotel == null && attraction == null && restaurant == null ? controller.flightFor(option) : null;

    return GestureDetector(
      onTap: vote.isClosed ? null : () => controller.castVote(vote, option.id),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: mineVoted ? Colors.green : AppColors.border, width: mineVoted ? 1.6 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: hotel != null
                  ? _hotelBody(option, hotel)
                  : attraction != null
                      ? _attractionBody(option, attraction)
                      : restaurant != null
                          ? _restaurantBody(option, restaurant)
                          : flight != null
                              ? _flightBody(option, flight)
                              : _plainBody(option),
            ),
            if (mineVoted)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hotelBody(VoteOption option, CatalogHotel hotel) {
    final price = hotel.displayPrice(CurrencyService.instance.lastKnownUserCurrency);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumb(hotel.image, Icons.hotel_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hotel.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 4),
              if (hotel.rating.isNotEmpty) _ratingRow(hotel.rating, hotel.reviews),
              if (hotel.location.isNotEmpty) ...[const SizedBox(height: 4), _locationRow(hotel.location)],
              if (price.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('$price per night', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
              _footerRow(option),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attractionBody(VoteOption option, CatalogAttraction attraction) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumb(attraction.image, Icons.attractions_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(attraction.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 4),
              if (attraction.rating.isNotEmpty) _ratingRow(attraction.rating, attraction.reviews),
              const SizedBox(height: 4),
              _locationRow(attraction.location.isNotEmpty ? attraction.location : attraction.category),
              if (attraction.price.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(attraction.price, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
              _footerRow(option),
            ],
          ),
        ),
      ],
    );
  }

  Widget _restaurantBody(VoteOption option, CatalogRestaurant restaurant) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumb(restaurant.image, Icons.restaurant_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(restaurant.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 4),
              if (restaurant.rating.isNotEmpty) _ratingRow(restaurant.rating, restaurant.reviews),
              if (restaurant.location.isNotEmpty) ...[const SizedBox(height: 4), _locationRow(restaurant.location)],
              if (restaurant.priceRange.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(restaurant.priceRange, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
              _footerRow(option),
            ],
          ),
        ),
      ],
    );
  }

  Widget _flightBody(VoteOption option, CatalogFlight flight) {
    final price = flight.displayPrice(CurrencyService.instance.lastKnownUserCurrency);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.flight_outlined, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${flight.from} → ${flight.to}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 4),
              Text('${flight.depTime} - ${flight.arrTime} · ${flight.stops}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              if (price.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(price, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
              _footerRow(option),
            ],
          ),
        ),
      ],
    );
  }

  /// Fallback for an option that doesn't match anything saved for this
  /// trip — typically one typed by hand in Create Vote rather than
  /// picked "From Saved". Still a full card (border, padding, the same
  /// voted-state styling and footer), just without the image/rating/
  /// location/price a matched listing has to show.
  Widget _plainBody(VoteOption option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(option.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
        _footerRow(option),
      ],
    );
  }

  // ---------------- Shared pieces ----------------
  Widget _thumb(String url, IconData icon) {
    if (url.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.textGrey, size: 22),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.chipGrey, child: Icon(icon, color: AppColors.textGrey, size: 22)),
      ),
    );
  }

  Widget _ratingRow(String rating, String reviews) {
    return Row(
      children: [
        const Icon(Icons.star, size: 13, color: AppColors.orange),
        const SizedBox(width: 3),
        Text(rating, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black)),
        if (reviews.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text('($reviews)', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ],
    );
  }

  Widget _locationRow(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.place_outlined, size: 12, color: AppColors.textGrey),
        const SizedBox(width: 3),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textGrey))),
      ],
    );
  }

  /// The avatar stack + "voted/total" fraction shown under every option
  /// card, real photos included — [UserAvatar] already fetches each
  /// voter's current profile photo live by uid (see theme.dart), same as
  /// the Friends list does.
  Widget _footerRow(VoteOption option) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _voterAvatarStack(option.votedBy),
          const SizedBox(width: 6),
          Text('${option.votedBy.length}/${controller.totalMembers}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _voterAvatarStack(List<String> votedBy) {
    final shown = votedBy.length.clamp(0, 3);
    final extra = votedBy.length - shown;
    if (shown == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18.0 + (shown - 1) * 12.0,
          height: 18,
          child: Stack(
            children: [
              for (int i = 0; i < shown; i++)
                Positioned(
                  left: i * 12.0,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5))),
                    child: UserAvatar(uid: votedBy[i], radius: 9),
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('+$extra', style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
          ),
      ],
    );
  }
}
