import io
path = "firestore.rules"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

old = """      //  - reported/reportedBy/reportReason/reportedAt/reportCount —
      //    bumped by CommunityRepository.reportPost, pinned to the
      //    reporter's own uid so no one can file a report "as" someone
      //    else. reportCount persists across moderation actions (unlike
      //    the other four, which approvePostReport clears) so it stays a
      //    true lifetime count for the report, even after a report is
      //    dismissed."""
new = """      //  - reported/reportedBy/reportReason/reportedAt/reportCount/
      //    reporterIds — bumped by CommunityRepository.reportPost, pinned
      //    to the reporter's own uid so no one can file a report "as"
      //    someone else. reportCount and reporterIds persist across
      //    moderation actions (unlike the other four, which
      //    approvePostReport clears) so reportCount stays a true
      //    lifetime count and reporterIds keeps remembering who's ever
      //    reported this post (CommunityPost.reportedByMe), even after a
      //    report is dismissed."""
assert s.count(old) == 1
s = s.replace(old, new, 1)

old = """        (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['reported', 'reportedBy', 'reportReason', 'reportedAt', 'reportCount']) &&
          request.resource.data.reportedBy == request.auth.uid)"""
new = """        (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['reported', 'reportedBy', 'reportReason', 'reportedAt', 'reportCount', 'reporterIds']) &&
          request.resource.data.reportedBy == request.auth.uid)"""
assert s.count(old) == 1
s = s.replace(old, new, 1)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
print("brackets", s.count("["), s.count("]"))
