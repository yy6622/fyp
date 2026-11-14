import io
path = "admin_web/partner/plans.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()
old = '''  detailDialog({
    title: p.name || "Untitled plan",
    subtitle: `${p.tripType || "Trip type not set"} · ${p.status === "active" ? "Active" : "Inactive"}`,
    rows: [
      { label: "Premium", value: `${moneyExact(p.premium)} ${premiumUnit(p.tripType)}` },
      { label: "Key coverage", value: coverageHtml, block: true },
      { label: "Highlights", value: highlightsHtml, block: true },
    ],
    actions: isApproved ? [{ text: "Edit", className: "btn-primary", onClick: () => { location.href = `plan-form.html?id=${id}`; } }] : [],'''
new = '''  const rows = [
    { label: "Premium", value: `${moneyExact(p.premium)} ${premiumUnit(p.tripType)}` },
    { label: "Description", value: p.description ? escapeHtml(p.description) : null, block: true },
    { label: "Key coverage", value: coverageHtml, block: true },
    { label: "Highlights", value: highlightsHtml, block: true },
  ];
  if ((p.status || "draft") === "rejected" && p.rejectionReason) {
    rows.push({ label: "Rejection reason", value: escapeHtml(p.rejectionReason) });
  }
  detailDialog({
    title: p.name || "Untitled plan",
    subtitle: `${p.tripType || "Trip type not set"} · ${(p.status || "draft").replace(/_/g, " ")}`,
    rows,
    actions: isApproved ? [{ text: "Edit", className: "btn-primary", onClick: () => { location.href = `plan-form.html?id=${id}`; } }] : [],'''
assert s.count(old) == 1
s = s.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
