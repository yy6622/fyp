import io
path = "lib/controllers/community_controller.dart"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:150]!r}")
    return s.replace(old, new, 1)

# 1. Remove the per-instance, non-persistent exclusion set -- it didn't
# survive navigating to a post's own detail page (CommunityPostDetailPage
# holds a completely separate CommunityController instance, so reporting
# from there never touched this Set at all) or an app restart. Replaced
# by CommunityPost.reportedByMe, parsed straight from Firestore's
# `reporterIds` (see community_repository.dart), which every
# CommunityController instance reads the same way regardless of which
# screen performed the report.
old = """  // Posts this device has reported in this app session. Reporting a post
  // doesn't (and shouldn't) hide it for everyone else right away -- that's
  // a moderation call, made once enough reports or an admin says so -- but
  // actively pushing that same post back at the person who just flagged it
  // under "Recommended for you" is a different thing, and purely a feed
  // decision this screen can make on its own.
  final Set<String> _reportedPostIds = {};

  String? _activeTagFilter;"""
new = """  String? _activeTagFilter;"""
s = r1(old, new, s)

# 2. recommendedPosts: filter by the persisted field instead.
old = """        .where((p) => !_reportedPostIds.contains(p.id) && p.tags.any(topTags.contains))"""
new = """        .where((p) => !p.reportedByMe && p.tags.any(topTags.contains))"""
s = r1(old, new, s)

# 3. reportPost(): no local Set to update -- the Firestore write's local
# cache echo comes straight back through the existing watchPosts()
# subscription (_sub) above, same as toggleLike() just below already
# relies on, so there's nothing left to do here but the write itself.
old = """      await CommunityRepository.instance.reportPost(post.id, reportedByUid: uid, reason: reason);
      _reportedPostIds.add(post.id);
      notifyListeners();
      return null;"""
new = """      await CommunityRepository.instance.reportPost(post.id, reportedByUid: uid, reason: reason);
      return null;"""
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
print("brackets", s.count("["), s.count("]"))
