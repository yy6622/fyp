// Decisions the group made in the app for items the chat left undecided
// (Discussion summary card -> "Decide now"). Stored on the trip document:
//   trips/{tripId}.discussionDecisions.{proposalMessageId} =
//     { status: "confirmed" | "rejected" | "split" | "voting", byName, memberNames: [..], voteTitle, at }
// They override what the model concluded for that proposal, in the summary card
// and in AI Summarise.

/** confirmed / rejected / pending as the rest of the pipeline understands it. */
function effectiveStatus(decision, fallback) {
  if (!decision) return fallback;
  if (decision.status === "confirmed" || decision.status === "split") return "confirmed";
  if (decision.status === "rejected") return "rejected";
  return "pending"; // voting: still open until the poll is settled
}

/** Applies decisions to a summariseDiscussion response (in place) and returns it. */
function applyToSummary(result, decisions) {
  if (!decisions || !Object.keys(decisions).length) return result;
  const order = { confirmed: 0, pending: 1, rejected: 2 };
  for (const sec of result.sections) {
    for (const it of sec.items) {
      const d = decisions[it.messageId];
      if (!d) continue;
      it.status = effectiveStatus(d, it.status);
      it.decided = { status: d.status, byName: d.byName || "", memberNames: d.memberNames || [], voteTitle: d.voteTitle || "" };
    }
    sec.items.sort((a, b) => order[a.status] - order[b.status]);
  }
  const all = result.sections.flatMap((s) => s.items);
  result.pending = all.filter((it) => it.status === "pending");
  result.stats.confirmed = all.filter((it) => it.status === "confirmed").length;
  result.stats.pending = result.pending.length;
  return result;
}

module.exports = { effectiveStatus, applyToSummary };
