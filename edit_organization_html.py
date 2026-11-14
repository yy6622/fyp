import io
path = "admin_web/partner/organization.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:160]!r}")
    return s.replace(old, new, 1)

# 1. New card: Verification details (license/country/website), right
# after Company information.
old = '''    <div class="card form-card">
      <h3 class="h3" style="margin-bottom:18px;">Brand identity</h3>'''
new = '''    <div class="card form-card">
      <h3 class="h3" style="margin-bottom:18px;">Verification details</h3>
      <div class="form-grid">
        <div class="field"><label>Insurance license number</label><input class="input" id="licenseNumber" readonly /></div>
        <div class="field"><label>Country of registration</label><select class="select" id="countryOfRegistration" disabled><option value="">Select a country…</option></select></div>
        <div class="field"><label>Official website</label><input class="input" id="website" type="url" readonly placeholder="https://www.yourcompany.com" /></div>
      </div>
    </div>

    <div class="card form-card">
      <h3 class="h3" style="margin-bottom:18px;">Brand identity</h3>'''
s = r1(old, new, s)

# 2. EDITABLE_IDS + setEditing(): the select needs .disabled toggled, not
# .readOnly (selects don't have a readOnly property).
old = '''const EDITABLE_IDS = [
  "companyName", "registrationNumber", "supportEmail", "phone",
  "addrLine1", "addrCity", "addrState", "addrPostal",
  "contactName", "contactDesignation", "contactEmail", "contactPhone",
];

function setEditing(on) {
  EDITABLE_IDS.forEach((id) => { document.getElementById(id).readOnly = !on; });
  document.getElementById("logoFile").disabled = !on;'''
new = '''const EDITABLE_IDS = [
  "companyName", "registrationNumber", "supportEmail", "phone",
  "licenseNumber", "website",
  "addrLine1", "addrCity", "addrState", "addrPostal",
  "contactName", "contactDesignation", "contactEmail", "contactPhone",
];

function setEditing(on) {
  EDITABLE_IDS.forEach((id) => { document.getElementById(id).readOnly = !on; });
  document.getElementById("countryOfRegistration").disabled = !on;
  document.getElementById("logoFile").disabled = !on;'''
s = r1(old, new, s)

# 3. Import COUNTRY_OPTIONS and populate the select.
old = 'import { getPartnerProfile, savePartnerProfile } from "../js/data.js?v=20261113a";'
new = ('import { getPartnerProfile, savePartnerProfile } from "../js/data.js?v=20261113a";\n'
       'import { COUNTRY_OPTIONS } from "../js/countries.js?v=20261113a";')
s = r1(old, new, s)

# 4. load(): populate the new fields (select needs its options built once).
old = '''async function load() {
  profile = (await getPartnerProfile(session.uid)) || {};
  document.getElementById("companyName").value = profile.companyName || "";
  document.getElementById("registrationNumber").value = profile.registrationNumber || "";
  document.getElementById("supportEmail").value = profile.supportEmail || "";
  document.getElementById("phone").value = profile.phone || "";'''
new = '''async function load() {
  profile = (await getPartnerProfile(session.uid)) || {};
  document.getElementById("companyName").value = profile.companyName || "";
  document.getElementById("registrationNumber").value = profile.registrationNumber || "";
  document.getElementById("supportEmail").value = profile.supportEmail || "";
  document.getElementById("phone").value = profile.phone || "";
  document.getElementById("licenseNumber").value = profile.licenseNumber || "";
  document.getElementById("website").value = profile.website || "";
  const countrySelect = document.getElementById("countryOfRegistration");
  countrySelect.innerHTML = '<option value="">Select a country…</option>' + COUNTRY_OPTIONS.map((c) => `<option>${c}</option>`).join("");
  countrySelect.value = profile.countryOfRegistration || "";'''
s = r1(old, new, s)

# 5. Save: include the new fields in the write payload.
old = '''    const data = {
      companyName: document.getElementById("companyName").value.trim(),
      registrationNumber: document.getElementById("registrationNumber").value.trim(),
      supportEmail: document.getElementById("supportEmail").value.trim(),
      phone: document.getElementById("phone").value.trim(),
      logoUrl,'''
new = '''    const licenseNumber = document.getElementById("licenseNumber").value.trim();
    const countryOfRegistration = document.getElementById("countryOfRegistration").value;
    if (!licenseNumber) { toast("Insurance license number is required.", "error"); setBusy(btn, false); return; }
    if (!countryOfRegistration) { toast("Please select your country of registration.", "error"); setBusy(btn, false); return; }
    const data = {
      companyName: document.getElementById("companyName").value.trim(),
      registrationNumber: document.getElementById("registrationNumber").value.trim(),
      supportEmail: document.getElementById("supportEmail").value.trim(),
      phone: document.getElementById("phone").value.trim(),
      licenseNumber,
      countryOfRegistration,
      website: document.getElementById("website").value.trim(),
      logoUrl,'''
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
