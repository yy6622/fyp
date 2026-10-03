import 'package:flutter/material.dart';

import '../../controllers/vote_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Vote tab — lives inside GroupTripPage. Shows every real poll created for
// this trip (`trips/{tripId}/votes`) — hotel picks, attraction picks,
// anything a member created via Create Vote.
// ---------------------------------------------------------------------
class VoteTab extends StatefulWidget {
  final String tripId;
  const VoteTab({super.key, required this.tripId});

  @override
  State<VoteTab> createState() => _VoteTabState();
}

class _VoteTabState extends State<VoteTab> {
  late final VoteTabController controller = VoteTabController(tripId: widget.tripId);

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

  Widget _voteCard(TripVote vote) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(vote.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ),
              if (vote.isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Closed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(vote.allowMultipleChoice ? 'Multiple choice' : 'Single choice',
              style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
          if (vote.deadline != null) ...[
            const SizedBox(height: 2),
            Text(_deadlineLabel(vote), style: TextStyle(fontSize: 10.5, color: vote.isClosed ? Colors.redAccent : AppColors.textGrey)),
          ],
          const SizedBox(height: 10),
          ...vote.options.map((o) => _optionRow(vote, o)),
        ],
      ),
    );
  }

  String _deadlineLabel(TripVote vote) {
    final d = vote.deadline!;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12 ? 'AM' : 'PM';
    final when = '${d.day} ${months[d.month]}, $hour12:${d.minute.toString().padLeft(2, '0')} $period';
    return vote.isClosed ? 'Voting closed $when' : 'Closes $when';
  }

  Widget _optionRow(TripVote vote, VoteOption option) {
    final mineVoted = controller.votedByMe(option);
    final maxVotes = vote.options.fold(0, (m, o) => o.votedBy.length > m ? o.votedBy.length : m);
    final fraction = maxVotes == 0 ? 0.0 : option.votedBy.length / maxVotes;
    return GestureDetector(
      onTap: vote.isClosed ? null : () => controller.castVote(vote, option.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: mineVoted ? AppColors.primary : const Color(0xFFECECEC), width: mineVoted ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(mineVoted ? Icons.check_circle : Icons.circle_outlined, color: mineVoted ? Colors.green : AppColors.textGrey, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: AppColors.chipGrey,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${option.votedBy.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
          ],
        ),
      ),
    );
  }
}
