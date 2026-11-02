
function effectiveStatus(decision, fallback) {
  if (!decision) return fallback;
  if (decision.status === "confirmed" || decision.status === "split") return "confirmed";
  if (decision.status === "rejected") return "rejected";
  return "pending";
}

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
