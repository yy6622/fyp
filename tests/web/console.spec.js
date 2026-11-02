// Executable test cases for the admin and insurance-partner web console:
// TC35, TC36, TC44, TC45, TC46, TC47, TC48, TC61 (admin side), TC67.
// Drives the real pages in a real browser against the Firebase emulators.
const { test, expect } = require("@playwright/test");
const emu = require("./emulator");

test.describe.configure({ mode: "default" });

const PW = "Test@1234";
const run = Date.now();
const users = {
  admin: { email: `admin.${run}@voya.test` },
  partner: { email: `partner.${run}@voya.test` },
  applicant: { email: `applicant.${run}@voya.test` },
  traveller: { email: `traveller.${run}@voya.test` },
};
let claimId = "claim1";

test.beforeAll(async () => {
  await emu.reset();
  for (const u of Object.values(users)) u.uid = await emu.createAuthUser(u.email, PW);
  await emu.setDoc(`admins/${users.admin.uid}`, { email: users.admin.email, name: "Admin Ada", role: "admin" });
  await emu.setDoc(`insurance_partners/${users.partner.uid}`, {
    companyName: "Safe Travels Bhd", email: users.partner.email, status: "approved", createdAt: new Date(),
  });
  await emu.setDoc(`insurance_partners/${users.applicant.uid}`, {
    companyName: "New Cover Sdn Bhd", email: users.applicant.email, registrationNumber: "202601234567",
    phone: "03-1234 5678", status: "pending", createdAt: new Date(),
  });
  await emu.setDoc(`users/${users.traveller.uid}`, {
    name: "Traveller Tom", email: users.traveller.email, status: "active", role: "user", createdAt: new Date(),
  });
  await emu.setDoc("country_emergency_info/thailand", { police: "191", ambulance: "1669", fire: "199" });
  await emu.setDoc(`claims/${claimId}`, {
    buyerId: users.traveller.uid, partnerId: users.partner.uid, transactionId: "txn1",
    providerName: "Safe Travels Bhd", planName: "Basic Travel Plan", policyholderName: "Traveller Tom",
    policyholderEmail: users.traveller.email, category: "Medical", amount: 320, description: "Clinic visit",
    documents: [], claimRef: "CLM-TEST-0001", status: "new",
    timeline: [{ status: "new", at: new Date().toISOString(), note: "Claim submitted" }],
    createdAt: new Date(), updatedAt: new Date(),
  });
});

async function login(page, role, who) {
  const base = role === "admin" ? "/admin/login.html" : "/partner/login.html";
  await page.goto(`${base}?emulator=1`);
  await page.fill("#email", who.email);
  await page.fill("#password", PW);
  await page.click("#submitBtn");
}

test("TC44 Admin logs in with a valid account", async ({ page }) => {
  await login(page, "admin", users.admin);
  await expect(page).toHaveURL(/admin\/overview\.html/, { timeout: 20_000 });
});

test("TC45 A traveller account cannot log in to the admin console", async ({ page }) => {
  await login(page, "admin", users.traveller);
  await expect(page.locator("#authError")).toContainText("isn't set up as an admin", { timeout: 20_000 });
  await expect(page).not.toHaveURL(/overview\.html/);
});

test("TC67 An insurance partner cannot open admin pages", async ({ page }) => {
  await login(page, "partner", users.partner);
  await expect(page).toHaveURL(/partner\/dashboard\.html/, { timeout: 20_000 });
  await page.goto("/admin/users.html");
  await expect(page).toHaveURL(/admin\/login\.html\?err=not-authorized/, { timeout: 20_000 });
});

test("TC61 Admin suspends a traveller account", async ({ page }) => {
  await login(page, "admin", users.admin);
  await expect(page).toHaveURL(/overview\.html/, { timeout: 20_000 });
  await page.goto("/admin/users.html");
  await page.locator(`[data-edit="${users.traveller.uid}"]`).click({ timeout: 20_000 });
  await page.selectOption("#statusSelect", "suspended");
  await page.click("#saveUserBtn");
  await expect.poll(async () => (await emu.getDoc(`users/${users.traveller.uid}`)).status, { timeout: 15_000 })
    .toBe("suspended");
});

test("TC35 Admin rejects a partner with a reason and the partner sees it", async ({ page, browser }) => {
  const reason = "Registration number could not be verified";
  await login(page, "admin", users.admin);
  await expect(page).toHaveURL(/overview\.html/, { timeout: 20_000 });
  await page.goto("/admin/insurance-partners.html");
  await page.locator(`[data-reject="${users.applicant.uid}"]`).click({ timeout: 20_000 });
  await page.fill("#promptDialogInput", reason);
  await page.locator(".modal [data-confirm]").click();
  await expect.poll(async () => (await emu.getDoc(`insurance_partners/${users.applicant.uid}`)).status, { timeout: 15_000 })
    .toBe("rejected");
  expect((await emu.getDoc(`insurance_partners/${users.applicant.uid}`)).rejectionReason).toBe(reason);

  const partnerPage = await (await browser.newContext()).newPage();
  await login(partnerPage, "partner", users.applicant);
  await expect(partnerPage).toHaveURL(/partner\/notifications\.html/, { timeout: 20_000 });
  await expect(partnerPage.locator("body")).toContainText(reason);
});

test("TC46 Admin edits emergency info for a country", async ({ page }) => {
  await login(page, "admin", users.admin);
  await expect(page).toHaveURL(/overview\.html/, { timeout: 20_000 });
  await page.goto("/admin/country-emergency-form.html?key=thailand");
  await expect(page.locator("#fPolice")).toHaveValue("191", { timeout: 20_000 });
  await page.fill("#fPolice", "1155");
  await page.click("#saveBtn");
  await expect.poll(async () => (await emu.getDoc("country_emergency_info/thailand")).police, { timeout: 15_000 })
    .toBe("1155");
});

test("TC47 Admin exports a report as PDF and Excel", async ({ page }) => {
  test.setTimeout(120_000);
  await login(page, "admin", users.admin);
  await expect(page).toHaveURL(/overview\.html/, { timeout: 20_000 });
  await page.goto("/admin/reports.html");
  // The export buttons do nothing until the report data has loaded (the page
  // keeps a live Firestore connection open, so "network idle" never comes).
  // Click until the download starts, for up to 40 seconds.
  async function download(button) {
    for (let i = 0; i < 20; i++) {
      const wait = page.waitForEvent("download", { timeout: 2_000 }).catch(() => null);
      await page.click(button);
      const d = await wait;
      if (d) return d;
    }
    throw new Error(`No download after clicking ${button}`);
  }
  const pdf = await download("#exportPdfBtn");
  expect(pdf.suggestedFilename()).toMatch(/\.pdf$/i);
  const xlsx = await download("#exportExcelBtn");
  expect(xlsx.suggestedFilename()).toMatch(/\.xlsx$/i);
});

test("TC48 Partner approves an insurance claim", async ({ page }) => {
  await login(page, "partner", users.partner);
  await expect(page).toHaveURL(/dashboard\.html/, { timeout: 20_000 });
  await page.goto(`/partner/claim-detail.html?id=${claimId}`);
  await page.click("#approveBtn", { timeout: 20_000 });
  await page.locator(".modal [data-confirm]").click();
  await expect.poll(async () => (await emu.getDoc(`claims/${claimId}`)).status, { timeout: 15_000 }).toBe("approved");
});

test("TC36 Admin suspends an approved partner", async ({ page }) => {
  await login(page, "admin", users.admin);
  await expect(page).toHaveURL(/overview\.html/, { timeout: 20_000 });
  await page.goto("/admin/insurance-partners.html");
  await page.locator(`[data-suspend="${users.partner.uid}"]`).click({ timeout: 20_000 });
  await page.locator(".modal [data-confirm]").click();
  await expect.poll(async () => (await emu.getDoc(`insurance_partners/${users.partner.uid}`)).status, { timeout: 15_000 })
    .toBe("suspended");
});
