import '../repositories/discussion_decisions.dart';
import '../repositories/trip_repository.dart';
import 'discussion_summary_service.dart';

const _planCategories = {'ATTRACTION', 'TRANSPORT'};

class VoteResolutionOutcome {
  /// True when at least one pending item moved from 'voting' to a resolved
  /// status (confirmed/rejected) during this pass, meaning the caller's
  /// summary data is stale and should be re-fetched.
  final bool anyResolved;

  /// How many items are stuck at 'voting' with no automatic answer -- a tie,
  /// or the poll disagreeing with how the chat leaned -- and need a person
  /// to pick one via Decide Now.
  final int conflictCount;

  const VoteResolutionOutcome({required this.anyResolved, required this.conflictCount});
}

class VoteResolutionService {
  VoteResolutionService._();
  static final VoteResolutionService instance = VoteResolutionService._();

  bool _textMatches(String optionLabel, String display) {
    final a = optionLabel.replaceAll('…', '').trim().toLowerCase();
    final b = display.trim().toLowerCase();
    return b.startsWith(a) || a.startsWith(b);
  }

  /// Whether the poll's current leading option amounts to "go with it"
  /// (true), "skip it" (false), or there's no usable result yet -- no
  /// votes, or a tie (null). A tie never resolves itself, by definition.
  bool? pollVerdict(DiscussionItem it, TripVote vote) {
    if (!vote.hasAnyVotes || vote.isTie) return null;
    final leader = vote.leading;
    if (leader == null) return null;
    final label = leader.label.trim().toLowerCase();
    if (label.startsWith('yes')) return true;
    if (label.startsWith('no')) return false;
    return _textMatches(leader.label, it.display);
  }

  bool? chatLean(DiscussionItem it) =>
      it.support.length == it.against.length ? null : it.support.length > it.against.length;

  Future<VoteResolutionOutcome> resolvePending(String tripId, List<DiscussionItem> pending) async {
    var anyResolved = false;
    var conflictCount = 0;
    for (final it in pending) {
      final d = it.decided;
      if (d == null || d.status != 'voting' || d.voteId.isEmpty) continue;
      TripVote? vote;
      try {
        vote = await TripRepository.instance.watchVoteById(tripId, d.voteId).first;
      } catch (_) {
        continue;
      }
      if (vote == null) continue;
      if (vote.isTie) {
        conflictCount++;
        continue;
      }
      final pollAgrees = pollVerdict(it, vote);
      if (pollAgrees == null) continue; // no votes cast yet
      final chatAgrees = chatLean(it);
      if (chatAgrees != null && chatAgrees != pollAgrees) {
        conflictCount++;
        continue;
      }
      if (pollAgrees && _planCategories.contains(it.category)) {
        continue;
      }
      await TripRepository.instance.recordDiscussionDecision(
        tripId,
        it.messageId,
        status: pollAgrees ? 'confirmed' : 'rejected',
        byUid: 'system',
        byName: 'Poll result',
        voteTitle: d.voteTitle,
        voteId: d.voteId,
      );
      anyResolved = true;
    }
    return VoteResolutionOutcome(anyResolved: anyResolved, conflictCount: conflictCount);
  }
}
