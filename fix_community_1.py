import io
path = "lib/models/community_models.dart"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:120]!r}")
    return s.replace(old, new, 1)

old = """  final int reportCount;

  final bool autoFlagged;"""
new = """  final int reportCount;

  // Whether the CURRENT signed-in user is one of the people who reported
  // this post -- read straight from Firestore's `reporterIds` array (see
  // CommunityRepository.reportPost/the _fromDoc-equivalent factory below),
  // not a per-screen session guess. Used by
  // CommunityController.recommendedPosts to stop recommending a post back
  // to someone who already flagged it, regardless of which page (the feed
  // itself, or the post's own detail page) they reported it from, and
  // regardless of whether they've since closed and reopened the app.
  final bool reportedByMe;

  final bool autoFlagged;"""
s = r1(old, new, s)

old = """    this.reportCount = 0,
    this.autoFlagged = false,"""
new = """    this.reportCount = 0,
    this.reportedByMe = false,
    this.autoFlagged = false,"""
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
