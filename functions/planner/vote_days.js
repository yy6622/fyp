
const { norm, findPlaces } = require("./places");

function leadingOptionOf(vote) {
  const entries = Object.entries((vote && vote.options) || {});
  // The group can settle a tie directly (see ai_itinerary_sheet.dart's
  // tie-break buttons / TripRepository.decideVote) instead of it being
  // forced through another single-choice ballot, which would just hit
  // "you have already voted" for whoever is doing the settling. That
  // writes decidedOptionId on the vote doc -- once set, it's the decisive
  // answer regardless of ballot counts, same as a real majority would be.
  const decidedId = vote && vote.decidedOptionId;
  if (decidedId) {
    const decided = entries.find(([id]) => id === decidedId);
    if (decided) return decided[1];
  }
  let best = null;
  let bestCount = -1;
  let tie = false;
  for (const [, o] of entries) {
    const count = Array.isArray(o && o.votedBy) ? o.votedBy.length : 0;
    if (count > bestCount) {
      best = o;
      bestCount = count;
      tie = false;
    } else if (count === bestCount && count > 0) {
      tie = true;
    }
  }
  if (!best || bestCount <= 0 || tie) return null;
  return best;
}

// True only for a genuine tie between two or more options that each got at
// least one vote -- NOT for a poll nobody has voted on yet (that's just
// "no result", not a tie). Callers use this to tell the two apart: a poll
// with zero votes stays silent (nothing to act on), a real tie gets
// surfaced so the group can break it instead of the app guessing.
function voteTie(vote) {
  if (vote && vote.decidedOptionId) return false; // settled directly -- no longer a tie
  const options = Object.values((vote && vote.options) || {});
  let bestCount = -1;
  let tie = false;
  for (const o of options) {
    const count = Array.isArray(o && o.votedBy) ? o.votedBy.length : 0;
    if (count > bestCount) {
      bestCount = count;
      tie = false;
    } else if (count === bestCount && count > 0) {
      tie = true;
    }
  }
  return bestCount > 0 && tie;
}

function voteDayAssignments({ votes = [], known, days = [] }) {
  const out = new Map();
  if (!known || !Array.isArray(days) || !days.length) return out;
  const { readDay } = require("../itinerary_engine");
  for (const vote of votes) {
    const leader = leadingOptionOf(vote);
    if (!leader) continue;
    const text = `${(vote && vote.title) || ""} ${leader.label || ""}`.trim();
    if (!text) continue;
    const day = readDay(text, days);
    if (!day) continue; // no day mentioned anywhere in this vote -- not a "which day" poll, skip it
    const hits = findPlaces(text, known, []);
    for (const h of hits) {
      if (h.negated || h.compare) continue;
      out.set(norm(h.place.name), day);
    }
  }
  return out;
}

module.exports = { voteDayAssignments, leadingOptionOf, voteTie };
