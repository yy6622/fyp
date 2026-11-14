import io, glob
files = glob.glob("admin/*.html") + glob.glob("partner/*.html")
changed = 0
for path in files:
    with io.open(path, encoding="utf-8") as f:
        s = f.read()
    new = s.replace("sidebar.js?v=20261111a", "sidebar.js?v=20261113a")
    if new != s:
        with io.open(path, "w", encoding="utf-8") as f:
            f.write(new)
        changed += 1
print(changed, "files updated")
