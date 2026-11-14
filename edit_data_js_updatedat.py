import io
path = "admin_web/js/data.js"
with io.open(path, encoding="utf-8") as f:
    s = f.read()
old = "export async function setPlanStatus(id, status, extra = {}) {\n  const payload = { status, ...extra };"
new = "export async function setPlanStatus(id, status, extra = {}) {\n  const payload = { status, ...extra, updatedAt: serverTimestamp() };"
assert s.count(old) == 1
s = s.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("ok2")
