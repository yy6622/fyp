import io
path = "admin_web/admin/insurance.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()
old = '''  const rows = [
    { label: "Registration no.", value: escapeHtml(p.registrationNumber) },
    { label: "Email", value: escapeHtml(p.email) },
    { label: "Phone", value: escapeHtml(p.phone) },'''
new = '''  const rows = [
    { label: "Registration no.", value: escapeHtml(p.registrationNumber) },
    { label: "License no.", value: p.licenseNumber ? escapeHtml(p.licenseNumber) : "<span class=\\"muted\\">Not provided</span>" },
    { label: "Country of registration", value: p.countryOfRegistration ? escapeHtml(p.countryOfRegistration) : "<span class=\\"muted\\">Not provided</span>" },
    { label: "Website", value: p.website ? `<a href="${escapeHtml(p.website)}" target="_blank" rel="noopener">${escapeHtml(p.website)}</a>` : "<span class=\\"muted\\">Not provided</span>" },
    { label: "Email", value: escapeHtml(p.email) },
    { label: "Phone", value: escapeHtml(p.phone) },'''
assert s.count(old) == 1
s = s.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
