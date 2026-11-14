import io
path = "admin_web/js/ui.js"
with io.open(path, encoding="utf-8") as f:
    s = f.read()
old = """const STATUS_BADGE = {
  active: "green", approved: "green", paid: "green", "in force": "green", confirmed: "green",
  pending: "amber", "under review": "amber", "under_review": "amber", draft: "amber", new: "blue",
  suspended: "red", rejected: "red", removed: "red", cancelled: "red", inactive: "gray",
};"""
new = """const STATUS_BADGE = {
  active: "green", approved: "green", paid: "green", "in force": "green", confirmed: "green", published: "green",
  pending: "amber", "under review": "amber", "under_review": "amber", draft: "amber", new: "blue",
  "pending review": "amber",
  suspended: "red", rejected: "red", removed: "red", cancelled: "red", inactive: "gray", expired: "gray",
};"""
assert s.count(old) == 1
s = s.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("ok")
