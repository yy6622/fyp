import io
path = "admin_web/partner/register.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:160]!r}")
    return s.replace(old, new, 1)

# 1. New fields in the form: License number + Country of registration
# (required) and Official website (optional) -- right after Registration
# number, before Phone.
old = '''        <div class="auth-field">
          <label for="registrationNumber">Registration number</label>
          <input class="input" id="registrationNumber" placeholder="Company registration number" required />
        </div>
        <div class="auth-field">
          <label for="phone">Phone</label>'''
new = '''        <div class="auth-field">
          <label for="registrationNumber">Registration number</label>
          <input class="input" id="registrationNumber" placeholder="Company registration number" required />
        </div>
        <div class="auth-field">
          <label for="licenseNumber">Insurance license number</label>
          <input class="input" id="licenseNumber" placeholder="Your regulator-issued license number" required />
        </div>
        <div class="auth-field">
          <label for="countryOfRegistration">Country of registration</label>
          <select class="select" id="countryOfRegistration" required><option value="">Select a country…</option></select>
        </div>
        <div class="auth-field">
          <label for="website">Official website <span class="muted small">(optional)</span></label>
          <input class="input" id="website" type="url" placeholder="https://www.yourcompany.com" />
        </div>
        <div class="auth-field">
          <label for="phone">Phone</label>'''
s = r1(old, new, s)

# 2. Script: import COUNTRY_OPTIONS, populate the select, validate +
# include the new fields in registerWithRole's payload.
old = 'import { mountIcons } from "../js/icons.js?v=20261106c";'
new = ('import { mountIcons } from "../js/icons.js?v=20261106c";\n'
       'import { COUNTRY_OPTIONS } from "../js/countries.js?v=20261113a";')
s = r1(old, new, s)

old = '''mountIcons(document);
wirePasswordToggle("password", "togglePassword");'''
new = '''mountIcons(document);
document.getElementById("countryOfRegistration").innerHTML =
  '<option value="">Select a country…</option>' + COUNTRY_OPTIONS.map((c) => `<option>${c}</option>`).join("");
wirePasswordToggle("password", "togglePassword");'''
s = r1(old, new, s)

old = '''  const companyName = document.getElementById("companyName").value.trim();
  const registrationNumber = document.getElementById("registrationNumber").value.trim();
  const phone = document.getElementById("phone").value.trim();'''
new = '''  const companyName = document.getElementById("companyName").value.trim();
  const registrationNumber = document.getElementById("registrationNumber").value.trim();
  const licenseNumber = document.getElementById("licenseNumber").value.trim();
  const countryOfRegistration = document.getElementById("countryOfRegistration").value;
  const website = document.getElementById("website").value.trim();
  const phone = document.getElementById("phone").value.trim();'''
s = r1(old, new, s)

old = '''  if (!isPlausiblePhone(phone)) {
    errBox.textContent = "That phone number doesn't look valid — numbers and spaces only.";
    errBox.classList.add("show");
    return;
  }'''
new = '''  if (!licenseNumber) {
    errBox.textContent = "Your insurance license number is required.";
    errBox.classList.add("show");
    return;
  }
  if (!countryOfRegistration) {
    errBox.textContent = "Please select your country of registration.";
    errBox.classList.add("show");
    return;
  }
  if (website && !/^https?:\\/\\/.+\\..+/i.test(website)) {
    errBox.textContent = "That website URL doesn't look valid -- include https://.";
    errBox.classList.add("show");
    return;
  }
  if (!isPlausiblePhone(phone)) {
    errBox.textContent = "That phone number doesn't look valid — numbers and spaces only.";
    errBox.classList.add("show");
    return;
  }'''
s = r1(old, new, s)

old = '''      companyName,
      providerId: companyName.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, ""),
      registrationNumber,
      phone,'''
new = '''      companyName,
      providerId: companyName.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, ""),
      registrationNumber,
      licenseNumber,
      countryOfRegistration,
      website,
      phone,'''
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
