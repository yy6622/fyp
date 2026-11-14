import io
path = "admin_web/js/sidebar.js"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

old = 'import { countPendingPartners, getPartnerProfile, listReportedPosts, countFlaggedReviews, countPlaceSuggestions, listInsuranceChats } from "./data.js?v=20261110c";'
new = 'import { countPendingPartners, countPendingPlans, getPartnerProfile, listReportedPosts, countFlaggedReviews, countPlaceSuggestions, listInsuranceChats } from "./data.js?v=20261113a";'
assert s.count(old) == 1
s = s.replace(old, new, 1)

old = '''  // them, same as the badge itself appearing on that page). Four
  // independent sources feed the Dashboard bell's own tooltip count: (1)
  // a new (pending) insurance-partner request, (2) a reported community
  // post, (3) a reported/auto-flagged review, (4) a traveller-submitted
  // new-place suggestion.'''
new = '''  // them, same as the badge itself appearing on that page) -- and also,
  // separately, on Insurance Management itself for the two sources that
  // live entirely inside that page (a pending partner, a plan awaiting
  // review). Five independent sources feed the Dashboard bell's own
  // tooltip count: (1) a new (pending) insurance-partner request, (2) a
  // plan submitted for review, (3) a reported community post, (4) a
  // reported/auto-flagged review, (5) a traveller-submitted new-place
  // suggestion.'''
assert s.count(old) == 1
s = s.replace(old, new, 1)

old = '''    Promise.all([
      countPendingPartners().catch(() => 0),
      listReportedPosts().then((p) => p.length).catch(() => 0),
      countFlaggedReviews().catch(() => 0),
      countPlaceSuggestions().catch(() => 0),
    ]).then(([pendingPartners, reportedPosts, flaggedReviews, placeSuggestions]) => {
      const moderationCount = reportedPosts + flaggedReviews;
      setNavBadge("overview", pendingPartners + moderationCount + placeSuggestions > 0);
      setNavBadge("moderation", moderationCount > 0);
      setNavBadge("attractions", placeSuggestions > 0);
    });'''
new = '''    Promise.all([
      countPendingPartners().catch(() => 0),
      countPendingPlans().catch(() => 0),
      listReportedPosts().then((p) => p.length).catch(() => 0),
      countFlaggedReviews().catch(() => 0),
      countPlaceSuggestions().catch(() => 0),
    ]).then(([pendingPartners, pendingPlans, reportedPosts, flaggedReviews, placeSuggestions]) => {
      const moderationCount = reportedPosts + flaggedReviews;
      setNavBadge("overview", pendingPartners + pendingPlans + moderationCount + placeSuggestions > 0);
      setNavBadge("moderation", moderationCount > 0);
      setNavBadge("attractions", placeSuggestions > 0);
      setNavBadge("insurance", pendingPartners + pendingPlans > 0);
    });'''
assert s.count(old) == 1
s = s.replace(old, new, 1)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
