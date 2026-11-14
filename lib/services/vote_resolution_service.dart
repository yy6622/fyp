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

/// Reads back the result of a "Decide Now -> Vote" poll and applies it to
/// [discussionDecisions] so AI Summarise (and, once a day & time is set via
/// Agree, Optimise) reflect the group's actual decision instead of leaving
/// it stuck at "voting" forever. Runs every time the discussion summary is
/// refreshed, not just while the Decide Now sheet happens to be open, so a
/// poll that nobody re-opens the sheet for still gets resolved.
///
/// A poll that ends in a tie, or whose winner disagrees with how the chat
/// itself leaned, is deliberately left alone -- that is a conflict only a
/// traveller should resolve, by tapping Agree/Skip/Vote again in Decide Now.
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
        // Still needs a day & time from a person before it's really
        // "confirmed" -- leave it at 'voting' so Decide Now keeps showing
        // the "tap Agree to give it a day & time" nudge. Optimise will see
        // it once that activity actually exists.
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
