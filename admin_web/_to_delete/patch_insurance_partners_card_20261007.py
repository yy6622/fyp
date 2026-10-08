import io

path = "admin_web/admin/insurance.html"
with io.open(path, "r", encoding="utf-8") as f:
    c = f.read()

# ---- 1. Bump this file's own cache-busting suffix (its logic changes) ----
old_v = 'v=20261007e"'
n = c.count(old_v)
assert n == 6, f"version-string count={n}"
c = c.replace(old_v, 'v=20261007f"')

# ---- 2. Replace the static "Insurance partners" card markup with an empty
#      shell — renderPartners() now owns its entire contents, because it
#      needs to switch between two completely different layouts (a pending
#      table vs. a single "view all" button), not just fill a fixed table.
old_markup = '''    <div class="card card-pad" style="margin-bottom:20px;">
      <div class="section-head"><h3 class="h3">Insurance partners</h3></div>
      <p class="subtitle" style="margin-bottom:16px;">New insurance partners land here as "Pending" until you approve them — approval is required before they can publish plans or handle claims.</p>
      <div class="table-wrap scroll-x">
        <table class="data-table">
          <thead><tr><th>Organization</th><th>Email</th><th>Registered</th><th>Status</th><th></th></tr></thead>
          <tbody id="partnersBody"><tr><td colspan="5"><div class="skeleton" style="height:36px;"></div></td></tr></tbody>
        </table>
      </div>
    </div>'''
n = c.count(old_markup)
assert n == 1, f"markup anchor count={n}"
new_markup = '''    <div class="card card-pad" id="partnersCard" style="margin-bottom:20px;">
      <div class="skeleton" style="height:90px;"></div>
    </div>'''
c = c.replace(old_markup, new_markup, 1)

# ---- 3. renderPartners(): only show the card's table for partners that
#      actually need a decision ("pending" or missing status — a brand new
#      partner doc has no status field yet). If there's nothing pending,
#      collapse the card to a single button that goes to the full partner
#      directory (admin/insurance-partners.html) instead of always showing
#      every partner here regardless of whether anything needs attention.
old_fn = '''function renderPartners() {
  const body = document.getElementById("partnersBody");
  if (!body) return;
  body.innerHTML = insurancePartners.length
    ? insurancePartners.map((p) => `
        <tr>
          <td class="cell-strong">${escapeHtml(p.companyName || "—")}</td>
          <td class="muted">${escapeHtml(p.email || "—")}</td>
          <td class="muted">${fullDate(p.createdAt)}</td>
          <td>${statusBadge(p.status === "approved" ? "active" : p.status)}</td>
          <td>
            <div class="row-actions">
              ${p.status === "pending" || !p.status
                ? `<button class="btn btn-primary btn-sm" data-approve="${p.id}">Approve</button><button class="btn btn-danger-outline btn-sm" data-reject="${p.id}">Reject</button>`
                : p.status === "approved"
                  ? `<button class="btn btn-danger-outline btn-sm" data-suspend="${p.id}">Suspend</button>`
                  : p.status === "suspended"
                    ? `<button class="btn btn-primary btn-sm" data-approve="${p.id}">Re-approve</button>`
                    : ""}
            </div>
          </td>
        </tr>`).join("")
    : `<tr><td colspan="5" class="muted" style="text-align:center;padding:24px 0;">No insurance partners have registered yet.</td></tr>`;
  body.querySelectorAll("[data-approve]").forEach((b) => b.addEventListener("click", () => setPartnerStatusUi(b.dataset.approve, "approved", b)));
  body.querySelectorAll("[data-suspend]").forEach((b) => b.addEventListener("click", () => setPartnerStatusUi(b.dataset.suspend, "suspended", b)));
  body.querySelectorAll("[data-reject]").forEach((b) => b.addEventListener("click", () => setPartnerStatusUi(b.dataset.reject, "rejected", b)));
  mountIcons(body);
}'''
n = c.count(old_fn)
assert n == 1, f"renderPartners anchor count={n}"
new_fn = '''// "Insurance partners" here is a pending-requests inbox, not the full
// partner directory — it only shows up when something actually needs a
// decision. The full list (every partner, every status, Approve/Suspend/
// Reject/Re-approve) lives on its own page, admin/insurance-partners.html.
function renderPartners() {
  const card = document.getElementById("partnersCard");
  if (!card) return;
  const pending = insurancePartners.filter((p) => p.status === "pending" || !p.status);
  if (!pending.length) {
    card.innerHTML = `
      <div class="section-head"><h3 class="h3">Insurance partners</h3></div>
      <p class="subtitle" style="margin-bottom:0;">No new partner requests right now.</p>
      <a class="btn btn-outline" href="insurance-partners.html" style="margin-top:14px;"><span data-icon="building" data-icon-size="14"></span>View all insurance partners</a>`;
    mountIcons(card);
    return;
  }
  card.innerHTML = `
    <div class="section-head"><h3 class="h3">Insurance partners</h3></div>
    <p class="subtitle" style="margin-bottom:16px;">New insurance partners land here as "Pending" until you approve them — approval is required before they can publish plans or handle claims.</p>
    <div class="table-wrap scroll-x">
      <table class="data-table">
        <thead><tr><th>Organization</th><th>Email</th><th>Registered</th><th>Status</th><th></th></tr></thead>
        <tbody id="partnersBody">${pending.map((p) => `
          <tr>
            <td class="cell-strong">${escapeHtml(p.companyName || "—")}</td>
            <td class="muted">${escapeHtml(p.email || "—")}</td>
            <td class="muted">${fullDate(p.createdAt)}</td>
            <td>${statusBadge("pending")}</td>
            <td>
              <div class="row-actions">
                <button class="btn btn-primary btn-sm" data-approve="${p.id}">Approve</button>
                <button class="btn btn-danger-outline btn-sm" data-reject="${p.id}">Reject</button>
              </div>
            </td>
          </tr>`).join("")}</tbody>
      </table>
    </div>`;
  card.querySelectorAll("[data-approve]").forEach((b) => b.addEventListener("click", () => setPartnerStatusUi(b.dataset.approve, "approved", b)));
  card.querySelectorAll("[data-reject]").forEach((b) => b.addEventListener("click", () => setPartnerStatusUi(b.dataset.reject, "rejected", b)));
  mountIcons(card);
}'''
c = c.replace(old_fn, new_fn, 1)

# ---- 4. setPartnerStatusUi(): this card can now only ever call it with
#      "approved" or "rejected" (Suspend/Re-approve only exist on the full
#      insurance-partners.html page, which has its own copy of this logic),
#      so the dead "suspended" confirm branch and toast text are dropped.
old_status_fn = '''async function setPartnerStatusUi(uid, status, btn) {
  if (status === "suspended") {
    const ok = await confirmDialog({ title: "Suspend this partner?", body: "They'll lose access to publish plans or handle claims until re-approved.", confirmText: "Suspend", danger: true });
    if (!ok) return;
  }
  if (status === "rejected") {
    const ok = await confirmDialog({ title: "Reject this application?", body: "They won't be able to publish plans or handle claims. This can be undone later by approving them.", confirmText: "Reject", danger: true });
    if (!ok) return;
  }
  setBusy(btn, true, "Working…");
  try {
    await setPartnerStatus(uid, status);
    const p = insurancePartners.find((x) => x.id === uid);
    if (p) p.status = status;
    renderPartners();
    toast(status === "approved" ? "Partner approved." : status === "rejected" ? "Partner application rejected." : "Partner suspended.", "success");
  } catch (err) {
    toast(err.message || "Couldn't update partner.", "error");
    setBusy(btn, false);
  }
}'''
n = c.count(old_status_fn)
assert n == 1, f"setPartnerStatusUi anchor count={n}"
new_status_fn = '''async function setPartnerStatusUi(uid, status, btn) {
  if (status === "rejected") {
    const ok = await confirmDialog({ title: "Reject this application?", body: "They won't be able to publish plans or handle claims. This can be undone later by approving them.", confirmText: "Reject", danger: true });
    if (!ok) return;
  }
  setBusy(btn, true, "Working…");
  try {
    await setPartnerStatus(uid, status);
    const p = insurancePartners.find((x) => x.id === uid);
    if (p) p.status = status;
    renderPartners();
    toast(status === "approved" ? "Partner approved." : "Partner application rejected.", "success");
  } catch (err) {
    toast(err.message || "Couldn't update partner.", "error");
    setBusy(btn, false);
  }
}'''
c = c.replace(old_status_fn, new_status_fn, 1)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(c)
print("insurance.html partners-card patched, new length", len(c))
