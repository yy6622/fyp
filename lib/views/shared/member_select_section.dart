import 'package:flutter/material.dart';

import '../../theme.dart';

// ---------------------------------------------------------------------
// Inline "Who is this for?" member picker — dropped into
// FlightPassengerDetailsPage/HotelGuestDetailsPage whenever the trip being
// booked for has more than one member, so a flight/hotel added to a group
// trip's Plan can say who it actually applies to instead of leaving every
// member to guess whether a booking was for the whole group or just
// whoever happened to pay. The chosen set is stored on the resulting
// TripFlight/TripHotelStay (see TripFlight.forMemberUids) and shown on
// PlanFlightDetailPage/PlanHotelDetailPage and the trip Overview list, so
// it's visible to every member, not just whoever booked it.
// ---------------------------------------------------------------------
class MemberSelectSection extends StatelessWidget {
  /// uid -> display name, straight from [Trip.memberNames].
  final Map<String, String> memberNames;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const MemberSelectSection({
    super.key,
    required this.memberNames,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final members = memberNames.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who Is This For?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const Text('Everyone on this trip can see who a booking applies to.', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: members.map((e) {
            final uid = e.key;
            final name = e.value;
            final checked = selected.contains(uid);
            return GestureDetector(
              onTap: () {
                final next = {...selected};
                if (checked) {
                  // At least one member has to stay selected — this
                  // booking has to be "for" someone.
                  if (next.length > 1) next.remove(uid);
                } else {
                  next.add(uid);
                }
                onChanged(next);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: checked ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: checked ? AppColors.primary : const Color(0xFFECECEC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(checked ? Icons.check_circle : Icons.circle_outlined, size: 16, color: checked ? AppColors.primary : AppColors.textGrey),
                    const SizedBox(width: 6),
                    Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: checked ? AppColors.primary : Colors.black)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Short "For: Alice, Bob" label built from a [TripFlight.forMemberUids]/
/// [TripHotelStay.forMemberUids] list + the trip's [Trip.memberNames] —
/// shared by PlanFlightDetailPage, PlanHotelDetailPage and the trip
/// Overview list so the three render this identically. Returns '' (render
/// nothing) when [forMemberUids] is empty — a solo trip, or a booking
/// added before this field existed — or covers every member already,
/// since "For: everyone" says nothing a Plan viewer doesn't already
/// assume.
String forMembersLabel(List<String> forMemberUids, Map<String, String> memberNames) {
  if (forMemberUids.isEmpty || forMemberUids.length >= memberNames.length) return '';
  final names = forMemberUids.map((uid) => memberNames[uid]).whereType<String>().where((n) => n.isNotEmpty).toList();
  if (names.isEmpty) return '';
  return 'For: ${names.join(', ')}';
}
