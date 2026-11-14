import io
path = "lib/repositories/community_repository.dart"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:150]!r}")
    return s.replace(old, new, 1)

old = """  Future<void> reportPost(String postId, {required String reportedByUid, required String reason}) {
    return _posts.doc(postId).update({
      'reported': true,
      'reportedBy': reportedByUid,
      'reportReason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
      'reportCount': FieldValue.increment(1),
    });
  }"""
new = """  Future<void> reportPost(String postId, {required String reportedByUid, required String reason}) {
    return _posts.doc(postId).update({
      'reported': true,
      'reportedBy': reportedByUid,
      'reportReason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
      'reportCount': FieldValue.increment(1),
      // A separate running list of every uid that has ever reported this
      // post, alongside `reportedBy` above (which only ever holds the
      // MOST RECENT reporter, for admin's moderation display -- see
      // admin_web/js/ui.js's reporterLabel()). This is what
      // CommunityPost.reportedByMe checks, so "don't recommend a post
      // back to someone who reported it" is correct even after a second
      // person reports the same post and overwrites `reportedBy`.
      'reporterIds': FieldValue.arrayUnion([reportedByUid]),
    });
  }"""
s = r1(old, new, s)

old = """      reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
      autoFlagged: data['autoFlagged'] == true,"""
new = """      reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
      reportedByMe: (data['reporterIds'] as List?)?.contains(myUid) ?? false,
      autoFlagged: data['autoFlagged'] == true,"""
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
print("brackets", s.count("["), s.count("]"))
