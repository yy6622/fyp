import io, glob

files = glob.glob("admin/*.html") + glob.glob("partner/*.html")
changed = []
for path in files:
    with io.open(path, encoding="utf-8") as f:
        s = f.read()
    orig = s
    s = s.replace("data.js?v=20261110c", "data.js?v=20261113a")
    s = s.replace("ui.js?v=20261110c", "ui.js?v=20261113a")
    if s != orig:
        with io.open(path, "w", encoding="utf-8") as f:
            f.write(s)
        changed.append(path)
print(len(changed), "files updated")
for p in changed:
    print(" ", p)
