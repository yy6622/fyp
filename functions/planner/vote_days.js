
const { norm, findPlaces } = require("./places");

/**
 * True exactly when lib/services/vote_resolution_service.dart's own
 * pollVerdict() would treat this poll as decided: at least one vote cast,
 * and no tie for first place. Deliberately ignores `deadline` the same way
 * that Dart logic does -- a vote is "the group's output" the moment a
 * clear leader emerges, not only once it closes.
 */
function leadingOptionOf(vote) {
  const options = Object.values((vote && vote.options) || {});
  let best = null;
  let bestCount = -1;
  let tie = false;
  for (const o of options) {
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

/**
 * Reads every resolved vote on a trip (trips/{tripId}/votes) and, wherever
 * a vote's title + winning option names both a day and a place Voya
 * already knows about, returns the day the group settled on for that
 * place -- e.g. a free-form poll titled "第几天去极乐寺" whose winning
 * option is "Day 3" resolves to { "极乐寺" -> 3 }.
 *
 * This exists because that kind of poll (lib/controllers/vote_controller.dart's
 * CreateVoteController) is never linked to any chat DiscussionItem, so
 * VoteResolutionService (and therefore trip.discussionDecisions, which
 * planner/decide.js reads) never sees it -- the only record of the
 * group's decision is the vote document itself. Used by both AI Summarise
 * (itinerary_engine.js) and Optimise (optimise_engine.js) so a vote result
 * is honoured the same way a clear chat decision already is.
 *
 * @returns Map<string, number> keyed by norm(place.name)
 */
function voteDayAssignments({ votes = [], known, days = [] }) {
  const out = new Map();
  if (!known || !Array.isArray(days) || !days.length) return out;
  // Lazy require: readDay lives in itinerary_engine.js, which itself pulls
  // in planner/decide.js etc. Requiring it lazily (same pattern already
  // used by planner/logistics_plan.js) avoids any load-order issue since
  // this module is required from inside both itinerary_engine.js and
  // optimise_engine.js.
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

module.exports = { voteDayAssignments, leadingOptionOf };
