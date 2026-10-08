import io

def read(path):
    with io.open(path, "r", encoding="utf-8") as f:
        return f.read()

def write(path, content):
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(content)

def replace_once(path, old, new, content=None):
    c = content if content is not None else read(path)
    n = c.count(old)
    assert n == 1, f"{path}: anchor count={n}\n----OLD----\n{old[:300]}"
    c = c.replace(old, new, 1)
    if content is None:
        write(path, c)
    return c

# ========================================================================
# 1. js/ui.js — shared real-delta helpers + statCard/plainCard
# ========================================================================
path = "admin_web/js/ui.js"
c = read(path)
anchor = '''export function renderComparisonBars(containerId, rows, series) {'''
assert c.count(anchor) == 1
addition = '''// ---------------- Real "vs last month" stat-card deltas ----------------
// Shared by every stat card across admin/partner pages — replaces what
// used to be a hardcoded "↑ 2.4% from last month" everywhere. A metric
// with no honest baseline to compare against (a "pending" queue, or a
// status with no date correlation at all) should render via plainCard()
// instead of statCard() rather than fake a delta for it.
export function monthBounds(monthsAgo = 0) {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - monthsAgo, 1);
  const end = new Date(now.getFullYear(), now.getMonth() - monthsAgo + 1, 1);
  return { start, end };
}
/** Sums valueFn(item) over items whose [dateField] Timestamp falls inside
 * the calendar month `monthsAgo` months before now (0 = this month, 1 =
 * last month) — the building block for every "monthly flow" delta. */
export function sumInMonth(items, dateField, valueFn, monthsAgo) {
  const { start, end } = monthBounds(monthsAgo);
  return items.reduce((s, item) => {
    const d = item[dateField]?.toDate ? item[dateField].toDate() : null;
    return d && d >= start && d < end ? s + valueFn(item) : s;
  }, 0);
}
export function countInMonth(items, dateField, monthsAgo) {
  return sumInMonth(items, dateField, () => 1, monthsAgo);
}
/** Sums valueFn(item) over items whose [dateField] Timestamp is strictly
 * before `cutoff` — the building block for every "cumulative total as of
 * a month ago" delta (total users, active plans, ...). */
export function sumBefore(items, dateField, valueFn, cutoff) {
  return items.reduce((s, item) => {
    const d = item[dateField]?.toDate ? item[dateField].toDate() : null;
    return d && d < cutoff ? s + valueFn(item) : s;
  }, 0);
}
export function countBefore(items, dateField, cutoff) {
  return sumBefore(items, dateField, () => 1, cutoff);
}
export function countBetween(items, dateField, start, end) {
  return items.filter((item) => {
    const d = item[dateField]?.toDate ? item[dateField].toDate() : null;
    return d && d >= start && d < end;
  }).length;
}
/** For a claim/refund-shaped item (status + a timeline[] of {status, at}),
 * the date it actually reached its CURRENT status — not when it was
 * created. Falls back to createdAt when there's no matching timeline
 * entry (e.g. still "new"). Lets a "claims approved this month" delta
 * bucket by when something was approved, not when it happened to be
 * filed. */
export function statusChangedAt(item) {
  const entry = (item.timeline || []).find((t) => t.status === item.status);
  if (entry) {
    const d = new Date(entry.at);
    if (!isNaN(d)) return d;
  }
  return item.createdAt?.toDate ? item.createdAt.toDate() : null;
}
export function countByStatusInMonth(items, status, monthsAgo) {
  const { start, end } = monthBounds(monthsAgo);
  return items.filter((item) => {
    if (item.status !== status) return false;
    const d = statusChangedAt(item);
    return d && d >= start && d < end;
  }).length;
}
export function rateOf(list, isMatch) {
  return list.length ? Math.round((list.filter(isMatch).length / list.length) * 1000) / 10 : null;
}
const NEW_LABEL = { "last month": "New this month", yesterday: "New today" };
/** Real relative delta for a stat card. `current`/`previous` are whatever
 * comparable pair the caller computed. Returns null when there's no
 * honest baseline, so the caller omits the delta line entirely. */
export function trendDelta(current, previous, comparisonLabel = "last month") {
  if (current === null || current === undefined || previous === null || previous === undefined) return null;
  if (previous === 0) return current === 0 ? null : { text: NEW_LABEL[comparisonLabel] || `New vs ${comparisonLabel}`, up: true };
  const pct = ((current - previous) / previous) * 100;
  if (Math.abs(pct) < 0.05) return { text: `No change from ${comparisonLabel}`, up: true };
  const up = pct > 0;
  return { text: `${up ? "↑" : "↓"} ${Math.abs(pct).toFixed(1)}% from ${comparisonLabel}`, up };
}
/** Same as [trendDelta], but for a value that's already a percentage
 * (e.g. an approval rate) — shown as a point difference rather than a
 * relative percentage change of a percentage. */
export function pointDelta(current, previous, comparisonLabel = "last month") {
  if (current === null || current === undefined || previous === null || previous === undefined) return null;
  const diff = current - previous;
  if (Math.abs(diff) < 0.05) return { text: `No change from ${comparisonLabel}`, up: true };
  const up = diff > 0;
  return { text: `${up ? "↑" : "↓"} ${Math.abs(diff).toFixed(1)} pts from ${comparisonLabel}`, up };
}
/** Stat card with an optional real delta line (pass null to omit it). */
export function statCard(label, value, icon, delta) {
  const deltaHtml = delta ? `<div class="stat-delta${delta.up === false ? " down" : ""}">${delta.text}</div>` : "";
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div>${deltaHtml}</div>`;
}
/** Stat card with no delta line at all — for a metric with no honest
 * baseline to compare against (a "pending" queue, a status with no real
 * temporal correlation, e.g. "Suspended"). */
export function plainCard(label, value) {
  return `<div class="card stat-card"><div class="stat-label">${label}</div><div class="stat-value">${value}</div></div>`;
}

export function renderComparisonBars(containerId, rows, series) {'''
c = replace_once(path, anchor, addition, c)
write(path, c)
print("ui.js patched, new length", len(c))

# ========================================================================
# 2. js/data.js — real "vs yesterday" moderation counts (was today-only)
# ========================================================================
path = "admin_web/js/data.js"
c = read(path)
old = '''/** Small audit trail so "Approved today" / "Rejected today" are real counts. */
export async function logModerationAction(action, postId, adminUid) {
  await addDoc(col("moderation_log"), { action, postId, adminUid, at: serverTimestamp() });
}
export async function countModerationToday(action) {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const items = await all(query(col("moderation_log"), where("action", "==", action)));
  return items.filter((i) => i.at?.toDate && i.at.toDate().getTime() >= startOfDay.getTime()).length;
}'''
new = '''/** Small audit trail so "Approved today" / "Rejected today" are real counts. */
export async function logModerationAction(action, postId, adminUid) {
  await addDoc(col("moderation_log"), { action, postId, adminUid, at: serverTimestamp() });
}
function dayBounds(daysAgo = 0) {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - daysAgo);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { start, end };
}
async function countModerationInRange(action, start, end) {
  const items = await all(query(col("moderation_log"), where("action", "==", action)));
  return items.filter((i) => {
    const t = i.at?.toDate ? i.at.toDate().getTime() : null;
    return t !== null && t >= start.getTime() && t < end.getTime();
  }).length;
}
export async function countModerationToday(action) {
  const { start, end } = dayBounds(0);
  return countModerationInRange(action, start, end);
}
/** Same day-before window, for a real "vs yesterday" delta instead of a
 * hardcoded percentage on the Content Moderation stat cards. */
export async function countModerationYesterday(action) {
  const { start, end } = dayBounds(1);
  return countModerationInRange(action, start, end);
}'''
c = replace_once(path, old, new, c)
write(path, c)
print("data.js patched, new length", len(c))

# ========================================================================
# 3. firestore.rules — moderation_log had NO rule at all (default-deny),
#    which silently breaks Content Moderation's stat cards: an unhandled
#    permission-denied rejection inside Promise.all([...]) means load()
#    never finishes and the page sits on its skeleton loader forever —
#    this is almost certainly the "load 很久出不来" the user hit.
# ========================================================================
path = "firestore.rules"
c = read(path)
anchor = '''    match /{path=**}/viewers/{uid} {
      allow read: if isAdmin();
    }
'''
assert c.count(anchor) == 1, f"viewers anchor count={c.count(anchor)}"
addition = anchor + '''
    // Audit trail for admin/content-moderation.html's approve/reject
    // actions (admin_web/js/data.js logModerationAction/countModerationToday)
    // — had NO rule at all before this, so every read/write silently hit
    // Firestore's default-deny and the page's stat cards never resolved.
    match /moderation_log/{id} {
      allow read: if isAdmin();
      allow create: if isAdmin() && request.resource.data.adminUid == request.auth.uid;
    }
'''
c = replace_once(path, anchor, addition, c)
write(path, c)
print("firestore.rules patched, new length", len(c))

# ========================================================================
# 4. admin/content-moderation.html — real "vs yesterday" deltas, Pending
#    review gets no delta (no honest baseline), and load() no longer
#    hangs forever on a permission error.
# ========================================================================
path = "admin_web/admin/content-moderation.html"
c = read(path)
old = '''import { listReportedPosts, approvePostReport, rejectPost, logModerationAction, countModerationToday } from "../js/data.js?v=20261007";
import { number, timeAgo, escapeHtml, toast, setBusy, confirmDialog, openModal, closeModal, wireModalDismiss } from "../js/ui.js?v=20261007";'''
new = '''import { listReportedPosts, approvePostReport, rejectPost, logModerationAction, countModerationToday, countModerationYesterday } from "../js/data.js?v=20261007e";
import { number, timeAgo, escapeHtml, toast, setBusy, confirmDialog, openModal, closeModal, wireModalDismiss, statCard, plainCard, trendDelta } from "../js/ui.js?v=20261007e";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  const [posts, approvedToday, rejectedToday] = await Promise.all([
    listReportedPosts(), countModerationToday("approved"), countModerationToday("rejected"),
  ]);
  reports = posts;
  document.getElementById("statGrid").innerHTML = [
    statCard("Pending review", number(reports.length), "clock"),
    statCard("Approved today", number(approvedToday), "file-check"),
    statCard("Rejected today", number(rejectedToday), "file-x"),
  ].join("");
  renderList();
  mountIcons(document);
}'''
new = '''async function load() {
  let posts, approvedToday, rejectedToday, approvedYesterday, rejectedYesterday;
  try {
    [posts, approvedToday, rejectedToday, approvedYesterday, rejectedYesterday] = await Promise.all([
      listReportedPosts(), countModerationToday("approved"), countModerationToday("rejected"),
      countModerationYesterday("approved"), countModerationYesterday("rejected"),
    ]);
  } catch (err) {
    document.getElementById("statGrid").innerHTML = "";
    document.getElementById("list").innerHTML = `<p class="muted small" style="padding:20px 0;">Couldn't load this report — ${escapeHtml(err.message || "missing or insufficient permissions")}.</p>`;
    return;
  }
  reports = posts;
  document.getElementById("statGrid").innerHTML = [
    plainCard("Pending review", number(reports.length)),
    statCard("Approved today", number(approvedToday), "file-check", trendDelta(approvedToday, approvedYesterday, "yesterday")),
    statCard("Rejected today", number(rejectedToday), "file-x", trendDelta(rejectedToday, rejectedYesterday, "yesterday")),
  ].join("");
  renderList();
  mountIcons(document);
}'''
c = replace_once(path, old, new, c)
write(path, c)
print("content-moderation.html patched, new length", len(c))

# ========================================================================
# 5. admin/insurance.html — clickable Reference -> detail modal, Insurance
#    partners (approve/suspend/reject) moved here from System Settings,
#    real deltas.
# ========================================================================
path = "admin_web/admin/insurance.html"
c = read(path)

# 5a. tiny inline style for the new reference-cell link button
old = '<link rel="stylesheet" href="../css/components.css?v=20261006b" />\n</head>'
new = '''<link rel="stylesheet" href="../css/components.css?v=20261006b" />
<style>.ref-link{background:none;border:none;padding:0;font:inherit;color:var(--teal-600);cursor:pointer;text-decoration:underline;font-weight:700;}</style>
</head>'''
c = replace_once(path, old, new, c)

# 5b. Insurance partners card — moved here from admin/settings.html, right
# above the transactions table (this IS Insurance Management, so partner
# approval belongs here, not under generic System Settings).
old = '''    <div class="stat-grid" id="statGrid"><div class="skeleton" style="height:90px;grid-column:1/-1;"></div></div>

    <div class="filter-bar">'''
new = '''    <div class="stat-grid" id="statGrid"><div class="skeleton" style="height:90px;grid-column:1/-1;"></div></div>

    <div class="card card-pad" style="margin-bottom:20px;">
      <div class="section-head"><h3 class="h3">Insurance partners</h3></div>
      <p class="subtitle" style="margin-bottom:16px;">New insurance partners land here as "Pending" until you approve them — approval is required before they can publish plans or handle claims.</p>
      <div class="table-wrap scroll-x">
        <table class="data-table">
          <thead><tr><th>Organization</th><th>Email</th><th>Registered</th><th>Status</th><th></th></tr></thead>
          <tbody id="partnersBody"><tr><td colspan="5"><div class="skeleton" style="height:36px;"></div></td></tr></tbody>
        </table>
      </div>
    </div>

    <div class="filter-bar">'''
c = replace_once(path, old, new, c)

# 5c. Transaction-detail modal
old = '''  </main>
</div>

<script type="module">
import { requireRole } from "../js/auth-guard.js?v=20261007";
import { mountSidebarNav, setSidebarUser } from "../js/sidebar.js?v=20261007";
import { mountIcons } from "../js/icons.js?v=20261007";
import { listTransactions, listClaims, listPartners } from "../js/data.js?v=20261007";
import { seedAdminDemoData } from "../js/seed.js?v=20261007";
import { money, moneyExact, number, statusBadge, escapeHtml, paginate, renderPager, toast, setBusy } from "../js/ui.js?v=20261007";

mountSidebarNav({ role: "admin", active: "insurance" });
const session = await requireRole("admin", "login.html");
let txns = [], filtered = [], page = 1;
const PAGE_SIZE = 8;

if (session) {
  setSidebarUser({ displayName: session.profile.name || "Admin", roleLabel: "Administrator" });
  await load();
}

function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  const [transactions, claims] = await Promise.all([listTransactions(), listClaims()]);
  txns = transactions;
  document.getElementById("devBar").style.display = txns.length ? "none" : "flex";

  const gross = txns.filter((t) => t.status === "paid").reduce((s, t) => s + (Number(t.premium) || 0), 0);
  const pendingClaims = claims.filter((c) => c.status === "new" || c.status === "under_review").length;
  const approvedCount = claims.filter((c) => c.status === "approved").length;
  const approvalRate = claims.length ? Math.round((approvedCount / claims.length) * 1000) / 10 : 0;

  document.getElementById("statGrid").innerHTML = [
    statCard("Gross premium", money(gross), "coin"),
    statCard("Policies sold", number(txns.filter((t) => t.status === "paid").length), "shield-check"),
    statCard("Pending claims", number(pendingClaims), "clock"),
    statCard("Approval rate", `${approvalRate}%`, "percent"),
  ].join("");
  applyFilters();
  mountIcons(document);
}'''
new = '''  </main>
</div>

<div class="modal-backdrop" id="txnModal">
  <div class="modal" style="max-width:560px;">
    <div class="modal-head"><h3 class="h2">Transaction detail</h3><button class="modal-close" data-close><span data-icon="x"></span></button></div>
    <div id="txnModalBody"></div>
  </div>
</div>

<script type="module">
import { requireRole } from "../js/auth-guard.js?v=20261007";
import { mountSidebarNav, setSidebarUser } from "../js/sidebar.js?v=20261007";
import { mountIcons } from "../js/icons.js?v=20261007";
import { listTransactions, listClaims, listPartners, setPartnerStatus } from "../js/data.js?v=20261007";
import { seedAdminDemoData } from "../js/seed.js?v=20261007";
import {
  money, moneyExact, number, statusBadge, escapeHtml, paginate, renderPager, toast, setBusy,
  fullDate, confirmDialog, openModal, closeModal, wireModalDismiss,
  statCard, plainCard, trendDelta, pointDelta, sumInMonth, countInMonth, monthBounds, rateOf,
} from "../js/ui.js?v=20261007";

mountSidebarNav({ role: "admin", active: "insurance" });
const session = await requireRole("admin", "login.html");
let txns = [], filtered = [], page = 1;
let insurancePartners = [];
const PAGE_SIZE = 8;

if (session) {
  setSidebarUser({ displayName: session.profile.name || "Admin", roleLabel: "Administrator" });
  wireModalDismiss();
  await load();
}

async function load() {
  const [transactions, claims, partnersList] = await Promise.all([listTransactions(), listClaims(), listPartners()]);
  txns = transactions;
  insurancePartners = partnersList;
  document.getElementById("devBar").style.display = txns.length ? "none" : "flex";

  const paid = txns.filter((t) => t.status === "paid");
  const gross = paid.reduce((s, t) => s + (Number(t.premium) || 0), 0);
  const pendingClaims = claims.filter((c) => c.status === "new" || c.status === "under_review").length;
  const approvedCount = claims.filter((c) => c.status === "approved").length;
  const approvalRate = claims.length ? Math.round((approvedCount / claims.length) * 1000) / 10 : 0;

  // Real month-over-month deltas (js/ui.js). Pending claims is a live
  // queue size, not a monthly flow, so it gets no honest delta and renders
  // as a plainCard — same treatment as every other "Pending …" card
  // across the console (see admin/reports.html's Insurance Operations tab).
  const grossDelta = trendDelta(
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 0),
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 1),
  );
  const soldDelta = trendDelta(countInMonth(paid, "createdAt", 0), countInMonth(paid, "createdAt", 1));
  const { start: thisMonthStart } = monthBounds(0);
  const { start: lastMonthStart, end: lastMonthEnd } = monthBounds(1);
  const claimDateOf = (c) => (c.createdAt?.toDate ? c.createdAt.toDate() : null);
  const claimsThisMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= thisMonthStart; });
  const claimsLastMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= lastMonthStart && d < lastMonthEnd; });
  const approvalRateDelta = pointDelta(rateOf(claimsThisMonth, (c) => c.status === "approved"), rateOf(claimsLastMonth, (c) => c.status === "approved"));

  document.getElementById("statGrid").innerHTML = [
    statCard("Gross premium", money(gross), "coin", grossDelta),
    statCard("Policies sold", number(paid.length), "shield-check", soldDelta),
    plainCard("Pending claims", number(pendingClaims)),
    statCard("Approval rate", `${approvalRate}%`, "percent", approvalRateDelta),
  ].join("");
  renderPartners();
  applyFilters();
  mountIcons(document);
}

function renderPartners() {
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
}

async function setPartnerStatusUi(uid, status, btn) {
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
c = replace_once(path, old, new, c)

# 5d. Reference cell -> clickable button opening the detail modal
old = '''    body.innerHTML = pageItems.map((t) => `
      <tr>
        <td class="cell-strong">${escapeHtml(t.txnRef || t.id)}</td>
        <td>${escapeHtml(t.customerName || "—")}</td>
        <td class="muted">${escapeHtml(t.providerName || "—")}</td>
        <td class="muted">${moneyExact(t.premium)}</td>
        <td>${statusBadge(t.status)}</td>
      </tr>`).join("");
  }
  document.getElementById("resultsLabel").textContent = total'''
new = '''    body.innerHTML = pageItems.map((t) => `
      <tr>
        <td class="cell-strong"><button class="ref-link" data-open-txn="${t.id}">${escapeHtml(t.txnRef || t.id)}</button></td>
        <td>${escapeHtml(t.customerName || "—")}</td>
        <td class="muted">${escapeHtml(t.providerName || "—")}</td>
        <td class="muted">${moneyExact(t.premium)}</td>
        <td>${statusBadge(t.status)}</td>
      </tr>`).join("");
    body.querySelectorAll("[data-open-txn]").forEach((b) => b.addEventListener("click", () => openTxnDetail(b.dataset.openTxn)));
  }
  document.getElementById("resultsLabel").textContent = total'''
c = replace_once(path, old, new, c)

# 5e. openTxnDetail() — right after renderTable()'s closing brace
old = '''  renderPager("pagination", { page, pages }, (n) => { page = n; renderTable(); });
  mountIcons(document);
}

document.getElementById("searchInput").addEventListener("input", applyFilters);
document.getElementById("statusFilter").addEventListener("change", applyFilters);'''
new = '''  renderPager("pagination", { page, pages }, (n) => { page = n; renderTable(); });
  mountIcons(document);
}

/** Shows everything we actually know about one transaction — the table
 * only has room for Reference/Customer/Provider/Premium/Status, but a
 * real insurance_transactions doc also carries the plan, destination,
 * sales channel, purchase date and (for a real mobile-app purchase) the
 * buyer's linked account — see js/data.js and
 * lib/repositories/insurance_repository.dart. */
function openTxnDetail(id) {
  const t = txns.find((x) => x.id === id);
  if (!t) return;
  const row = (label, value) => `<div class="field" style="margin-bottom:12px;"><label>${label}</label><p class="value">${value}</p></div>`;
  document.getElementById("txnModalBody").innerHTML = `
    <div class="form-grid">
      ${row("Reference", escapeHtml(t.txnRef || t.id))}
      ${row("Status", statusBadge(t.status))}
      ${row("Customer", escapeHtml(t.customerName || "—"))}
      ${row("Customer email", escapeHtml(t.customerEmail || "—"))}
      ${row("Provider", escapeHtml(t.providerName || "—"))}
      ${row("Plan", escapeHtml(t.planName || "—"))}
      ${row("Premium", moneyExact(t.premium))}
      ${row("Destination", escapeHtml(t.destination || "—"))}
      ${row("Channel", escapeHtml(t.channel || "—"))}
      ${row("Purchased", fullDate(t.createdAt))}
      ${row("Linked Voya account", t.buyerId ? "Yes — bought through the mobile app" : "No — logged manually (e.g. a walk-in customer)")}
    </div>
    ${t.isDemoSeed ? `<p class="muted small" style="margin-top:4px;">This is seeded demo data.</p>` : ""}`;
  mountIcons(document.getElementById("txnModalBody"));
  openModal("txnModal");
}

document.getElementById("searchInput").addEventListener("input", applyFilters);
document.getElementById("statusFilter").addEventListener("change", applyFilters);'''
c = replace_once(path, old, new, c)
write(path, c)
print("insurance.html patched, new length", len(c))

# ========================================================================
# 6. admin/settings.html — Partner approvals moved to Insurance Management
#    (admin/insurance.html, above) since that's where insurance partners
#    actually get managed; keeping it under generic System Settings never
#    made sense, per the user's own report.
# ========================================================================
path = "admin_web/admin/settings.html"
c = read(path)

old = '<p class="subtitle">Admin accounts, partner approvals, and platform info</p>'
new = '<p class="subtitle">Admin accounts and platform info</p>'
c = replace_once(path, old, new, c)

old = '''    <div class="card card-pad" style="margin-bottom:20px;">
      <div class="section-head"><h3 class="h3">Partner approvals</h3></div>
      <p class="subtitle" style="margin-bottom:16px;">New insurance partners land here as "Pending" until you approve them — approval is required before they can publish plans or handle claims.</p>
      <div class="table-wrap scroll-x">
        <table class="data-table">
          <thead><tr><th>Organization</th><th>Email</th><th>Registered</th><th>Status</th><th></th></tr></thead>
          <tbody id="partnersBody"><tr><td colspan="5"><div class="skeleton" style="height:36px;"></div></td></tr></tbody>
        </table>
      </div>
    </div>

    <div class="card card-pad" style="margin-bottom:20px;">
      <div class="section-head"><h3 class="h3">Admin accounts</h3></div>'''
new = '''    <div class="card card-pad" style="margin-bottom:20px;">
      <div class="section-head"><h3 class="h3">Admin accounts</h3></div>'''
c = replace_once(path, old, new, c)

old = '''import { listPartners, listAdmins, setPartnerStatus } from "../js/data.js?v=20261007";
import { clearDemoData } from "../js/seed.js?v=20261007";
import { fullDate, statusBadge, escapeHtml, toast, setBusy, confirmDialog } from "../js/ui.js?v=20261007";

mountSidebarNav({ role: "admin", active: "settings" });
const session = await requireRole("admin", "login.html");
let partners = [];

if (session) {
  setSidebarUser({ displayName: session.profile.name || "Admin", roleLabel: "Administrator" });
  document.getElementById("meLine").textContent = `${session.profile.name || "Admin"} · ${session.user.email}`;
  await load();
}

async function load() {
  const [p, a] = await Promise.all([listPartners(), listAdmins()]);
  partners = p;
  renderPartners();
  document.getElementById("adminsBody").innerHTML = a.length
    ? a.map((x) => `<tr><td class="cell-strong">${escapeHtml(x.name || "—")}</td><td class="muted">${escapeHtml(x.email || "—")}</td><td class="muted">${fullDate(x.createdAt)}</td></tr>`).join("")
    : `<tr><td colspan="3" class="muted" style="text-align:center;padding:24px 0;">No admin accounts found.</td></tr>`;
  mountIcons(document);
}

function renderPartners() {
  const body = document.getElementById("partnersBody");
  body.innerHTML = partners.length
    ? partners.map((p) => `
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
  body.querySelectorAll("[data-approve]").forEach((b) => b.addEventListener("click", () => setStatus(b.dataset.approve, "approved", b)));
  body.querySelectorAll("[data-suspend]").forEach((b) => b.addEventListener("click", () => setStatus(b.dataset.suspend, "suspended", b)));
  body.querySelectorAll("[data-reject]").forEach((b) => b.addEventListener("click", () => setStatus(b.dataset.reject, "rejected", b)));
}

document.getElementById("clearBtn").addEventListener("click", async (e) => {
  const ok = await confirmDialog({ title: "Clear all demo data?", body: "This deletes every sample plan, transaction and claim tagged as demo data across every partner. This can't be undone.", confirmText: "Clear demo data", danger: true });
  if (!ok) return;
  setBusy(e.currentTarget, true, "Clearing…");
  try {
    const count = await clearDemoData();
    toast(`Removed ${count} demo record(s).`, "success");
  } catch (err) {
    toast(err.message || "Couldn't clear demo data.", "error");
  } finally {
    setBusy(e.currentTarget, false);
  }
});

async function setStatus(uid, status, btn) {
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
    const p = partners.find((x) => x.id === uid);
    if (p) p.status = status;
    renderPartners();
    mountIcons(document);
    toast(status === "approved" ? "Partner approved." : status === "rejected" ? "Partner application rejected." : "Partner suspended.", "success");
  } catch (err) {
    toast(err.message || "Couldn't update partner.", "error");
    setBusy(btn, false);
  }
}'''
new = '''import { listAdmins } from "../js/data.js?v=20261007";
import { clearDemoData } from "../js/seed.js?v=20261007";
import { fullDate, escapeHtml, toast, setBusy, confirmDialog } from "../js/ui.js?v=20261007";

mountSidebarNav({ role: "admin", active: "settings" });
const session = await requireRole("admin", "login.html");

if (session) {
  setSidebarUser({ displayName: session.profile.name || "Admin", roleLabel: "Administrator" });
  document.getElementById("meLine").textContent = `${session.profile.name || "Admin"} · ${session.user.email}`;
  await load();
}

async function load() {
  const a = await listAdmins();
  document.getElementById("adminsBody").innerHTML = a.length
    ? a.map((x) => `<tr><td class="cell-strong">${escapeHtml(x.name || "—")}</td><td class="muted">${escapeHtml(x.email || "—")}</td><td class="muted">${fullDate(x.createdAt)}</td></tr>`).join("")
    : `<tr><td colspan="3" class="muted" style="text-align:center;padding:24px 0;">No admin accounts found.</td></tr>`;
  mountIcons(document);
}

document.getElementById("clearBtn").addEventListener("click", async (e) => {
  const ok = await confirmDialog({ title: "Clear all demo data?", body: "This deletes every sample plan, transaction and claim tagged as demo data across every partner. This can't be undone.", confirmText: "Clear demo data", danger: true });
  if (!ok) return;
  setBusy(e.currentTarget, true, "Clearing…");
  try {
    const count = await clearDemoData();
    toast(`Removed ${count} demo record(s).`, "success");
  } catch (err) {
    toast(err.message || "Couldn't clear demo data.", "error");
  } finally {
    setBusy(e.currentTarget, false);
  }
});'''
c = replace_once(path, old, new, c)
write(path, c)
print("settings.html patched, new length", len(c))

# ========================================================================
# 7. admin/analytics.html — same metrics as Platform Overview in
#    admin/reports.html, so real deltas use that exact same pairing.
# ========================================================================
path = "admin_web/admin/analytics.html"
c = read(path)
old = '''import { money, moneyExact, number, escapeHtml } from "../js/ui.js?v=20261007";'''
new = '''import { money, moneyExact, number, escapeHtml, statCard, trendDelta, pointDelta, sumInMonth, countInMonth, monthBounds, rateOf } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  const [txns, claims, users] = await Promise.all([listTransactions(), listClaims(), listUsers()]);
  allTxns = txns;
  const paid = txns.filter((t) => t.status === "paid");
  const revenue = paid.reduce((s, t) => s + (Number(t.premium) || 0), 0);
  const approvedCount = claims.filter((c) => c.status === "approved").length;
  const approvalRate = claims.length ? Math.round((approvedCount / claims.length) * 1000) / 10 : 0;

  document.getElementById("statGrid").innerHTML = [
    statCard("Revenue", money(revenue), "coin"),
    statCard("Policies sold", number(paid.length), "shield-check"),
    statCard("Claims approved", `${approvalRate}%`, "check-circle"),
    statCard("Active travellers", number(users.filter((u) => u.status !== "suspended").length), "user"),
  ].join("");'''
new = '''async function load() {
  const [txns, claims, users] = await Promise.all([listTransactions(), listClaims(), listUsers()]);
  allTxns = txns;
  const paid = txns.filter((t) => t.status === "paid");
  const revenue = paid.reduce((s, t) => s + (Number(t.premium) || 0), 0);
  const approvedCount = claims.filter((c) => c.status === "approved").length;
  const approvalRate = claims.length ? Math.round((approvedCount / claims.length) * 1000) / 10 : 0;
  const activeTravellers = users.filter((u) => u.status !== "suspended").length;

  // Real month-over-month deltas (js/ui.js) — same pairing as Platform
  // Overview's identical 4 metrics in admin/reports.html. Active
  // travellers has no historical status log to replay, so its delta
  // approximates "how many of today's active travellers had already
  // signed up before this month" using real signup dates.
  const { start: thisMonthStart } = monthBounds(0);
  const revenueDelta = trendDelta(
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 0),
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 1),
  );
  const policiesDelta = trendDelta(countInMonth(paid, "createdAt", 0), countInMonth(paid, "createdAt", 1));
  const { start: lastMonthStart, end: lastMonthEnd } = monthBounds(1);
  const claimDateOf = (c) => (c.createdAt?.toDate ? c.createdAt.toDate() : null);
  const claimsThisMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= thisMonthStart; });
  const claimsLastMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= lastMonthStart && d < lastMonthEnd; });
  const approvalRateDelta = pointDelta(rateOf(claimsThisMonth, (c) => c.status === "approved"), rateOf(claimsLastMonth, (c) => c.status === "approved"));
  const activeDelta = trendDelta(
    activeTravellers,
    users.filter((u) => {
      if (u.status === "suspended") return false;
      const d = u.createdAt?.toDate ? u.createdAt.toDate() : null;
      return d && d < thisMonthStart;
    }).length,
  );

  document.getElementById("statGrid").innerHTML = [
    statCard("Revenue", money(revenue), "coin", revenueDelta),
    statCard("Policies sold", number(paid.length), "shield-check", policiesDelta),
    statCard("Claims approved", `${approvalRate}%`, "check-circle", approvalRateDelta),
    statCard("Active travellers", number(activeTravellers), "user", activeDelta),
  ].join("");'''
c = replace_once(path, old, new, c)
write(path, c)
print("analytics.html patched, new length", len(c))

# ========================================================================
# 8. admin/attractions.html
# ========================================================================
path = "admin_web/admin/attractions.html"
c = read(path)
old = '''import { number, shortDate, statusBadge, escapeHtml, paginate, renderPager, toast, confirmDialog } from "../js/ui.js?v=20261007";'''
new = '''import { number, shortDate, statusBadge, escapeHtml, paginate, renderPager, toast, confirmDialog, statCard, plainCard, trendDelta, countBefore, monthBounds } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  items = await listAttractions();
  items.forEach((a) => (a.status = a.status || "active"));
  renderStats();
  applyFilters();
}

function renderStats() {
  const active = items.filter((a) => a.status === "active").length;
  const pending = items.filter((a) => a.status === "pending").length;
  const suspended = items.filter((a) => a.status === "suspended").length;
  document.getElementById("statGrid").innerHTML = [
    statCard("Attractions", number(items.length), "map-pin"),
    statCard("Active", number(active), "sparkle"),
    statCard("Pending", number(pending), "user-check"),
    statCard("Suspended", number(suspended), "user-x"),
  ].join("");
  mountIcons(document);
}'''
new = '''async function load() {
  items = await listAttractions();
  items.forEach((a) => (a.status = a.status || "active"));
  renderStats();
  applyFilters();
}

function renderStats() {
  const active = items.filter((a) => a.status === "active");
  const pending = items.filter((a) => a.status === "pending").length;
  const suspended = items.filter((a) => a.status === "suspended").length;
  // Real deltas (js/ui.js): Attractions/Active compare the current total
  // to how many existed before this month. Pending/Suspended are live
  // status snapshots with no honest baseline, so they're plainCards.
  const { start: thisMonthStart } = monthBounds(0);
  const totalDelta = trendDelta(items.length, countBefore(items, "createdAt", thisMonthStart));
  const activeDelta = trendDelta(active.length, countBefore(active, "createdAt", thisMonthStart));
  document.getElementById("statGrid").innerHTML = [
    statCard("Attractions", number(items.length), "map-pin", totalDelta),
    statCard("Active", number(active.length), "sparkle", activeDelta),
    plainCard("Pending", number(pending)),
    plainCard("Suspended", number(suspended)),
  ].join("");
  mountIcons(document);
}'''
c = replace_once(path, old, new, c)
write(path, c)
print("attractions.html patched, new length", len(c))

# ========================================================================
# 9. admin/overview.html
# ========================================================================
path = "admin_web/admin/overview.html"
c = read(path)
old = '''import { money, number } from "../js/ui.js?v=20261007";'''
new = '''import { money, number, statCard, plainCard, trendDelta, pointDelta, sumInMonth, sumBefore, countBefore, countBetween, monthBounds, rateOf } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `
    <div class="card stat-card">
      <div class="stat-top">
        <div class="stat-icon"><span data-icon="${icon}"></span></div>
        <div class="stat-label">${label}</div>
      </div>
      <div class="stat-value">${value}</div>
      <div class="stat-delta">↑ 2.4% from last month</div>
    </div>`;
}

async function loadOverview() {
  const [users, attractions, txns, claims] = await Promise.all([
    listUsers(), listAttractions(), listTransactions(), listClaims(),
  ]);

  // ---- Top stat row ----
  const thirtyDaysAgo = Date.now() - 30 * 86400000;
  const newSignups = users.filter((u) => u.createdAt?.toDate && u.createdAt.toDate().getTime() > thirtyDaysAgo).length;
  const suspended = users.filter((u) => u.status === "suspended").length;
  const active = users.length - suspended;

  document.getElementById("statGrid").innerHTML = [
    statCard("Total Users", number(users.length), "user"),
    statCard("New Sign-ups", number(newSignups), "sparkle"),
    statCard("Active Users", number(active), "user-check"),
    statCard("Suspended", number(suspended), "user-x"),
  ].join("");'''
new = '''async function loadOverview() {
  const [users, attractions, txns, claims] = await Promise.all([
    listUsers(), listAttractions(), listTransactions(), listClaims(),
  ]);

  // ---- Top stat row ----
  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 86400000);
  const sixtyDaysAgo = new Date(now.getTime() - 60 * 86400000);
  const newSignups = users.filter((u) => u.createdAt?.toDate && u.createdAt.toDate().getTime() > thirtyDaysAgo.getTime()).length;
  const suspended = users.filter((u) => u.status === "suspended").length;
  const active = users.length - suspended;

  // Real deltas (js/ui.js). New Sign-ups is a rolling 30-day window, so
  // it's compared to the 30 days before that rather than a calendar
  // month. Suspended has no honest baseline (not correlated with signup
  // date the way "active" roughly is), so it's a plainCard.
  const { start: thisMonthStart } = monthBounds(0);
  const totalDelta = trendDelta(users.length, countBefore(users, "createdAt", thisMonthStart));
  const newSignupsDelta = trendDelta(countBetween(users, "createdAt", thirtyDaysAgo, now), countBetween(users, "createdAt", sixtyDaysAgo, thirtyDaysAgo), "the previous 30 days");
  const activeDelta = trendDelta(
    active,
    users.filter((u) => {
      if (u.status === "suspended") return false;
      const d = u.createdAt?.toDate ? u.createdAt.toDate() : null;
      return d && d < thisMonthStart;
    }).length,
  );

  document.getElementById("statGrid").innerHTML = [
    statCard("Total Users", number(users.length), "user", totalDelta),
    statCard("New Sign-ups", number(newSignups), "sparkle", newSignupsDelta),
    statCard("Active Users", number(active), "user-check", activeDelta),
    plainCard("Suspended", number(suspended)),
  ].join("");'''
c = replace_once(path, old, new, c)

old = '''  // ---- Insurance overview ----
  const pendingClaims = claims.filter((c) => c.status === "new" || c.status === "under_review").length;
  const approvedCount = claims.filter((c) => c.status === "approved").length;
  const approvalRate = claims.length ? Math.round((approvedCount / claims.length) * 1000) / 10 : 0;
  const returned = txns.filter((t) => t.status === "rejected").reduce((sum, t) => sum + (Number(t.premium) || 0), 0);

  document.getElementById("insuranceStats").innerHTML = [
    statCard("Transactions", number(txns.length), "swap"),
    statCard("Pending Claims", number(pendingClaims), "clock"),
    statCard("Approved", `${approvalRate}%`, "file-check"),
    statCard("Returned", money(returned), "undo"),
  ].join("");'''
new = '''  // ---- Insurance overview ----
  const pendingClaims = claims.filter((c) => c.status === "new" || c.status === "under_review").length;
  const approvedCount = claims.filter((c) => c.status === "approved").length;
  const approvalRate = claims.length ? Math.round((approvedCount / claims.length) * 1000) / 10 : 0;
  const rejectedTxns = txns.filter((t) => t.status === "rejected");
  const returned = rejectedTxns.reduce((sum, t) => sum + (Number(t.premium) || 0), 0);

  const transactionsDelta = trendDelta(txns.length, countBefore(txns, "createdAt", thisMonthStart));
  const { start: lastMonthStart, end: lastMonthEnd } = monthBounds(1);
  const claimDateOf = (c) => (c.createdAt?.toDate ? c.createdAt.toDate() : null);
  const claimsThisMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= thisMonthStart; });
  const claimsLastMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= lastMonthStart && d < lastMonthEnd; });
  const approvalRateDelta = pointDelta(rateOf(claimsThisMonth, (c) => c.status === "approved"), rateOf(claimsLastMonth, (c) => c.status === "approved"));
  const returnedDelta = trendDelta(returned, sumBefore(rejectedTxns, "createdAt", (t) => Number(t.premium) || 0, thisMonthStart));

  document.getElementById("insuranceStats").innerHTML = [
    statCard("Transactions", number(txns.length), "swap", transactionsDelta),
    plainCard("Pending Claims", number(pendingClaims)),
    statCard("Approved", `${approvalRate}%`, "file-check", approvalRateDelta),
    statCard("Returned", money(returned), "undo", returnedDelta),
  ].join("");'''
c = replace_once(path, old, new, c)

# `now` is already declared earlier in this same loadOverview() scope (by
# the delta block just added above) — drop the later redeclaration so this
# isn't a duplicate-`const` SyntaxError.
old3 = '''  // ---- Bar chart: users joined per month (last 6 months) ----
  const months = [];
  const now = new Date();
  for (let i = 5; i >= 0; i--) {'''
new3 = '''  // ---- Bar chart: users joined per month (last 6 months) ----
  const months = [];
  for (let i = 5; i >= 0; i--) {'''
c = replace_once(path, old3, new3, c)

write(path, c)
print("overview.html patched, new length", len(c))

# ========================================================================
# 10. admin/users.html
# ========================================================================
path = "admin_web/admin/users.html"
c = read(path)
old = '''import { number, shortDate, statusBadge, initials, escapeHtml, paginate, renderPager, toast, setBusy } from "../js/ui.js?v=20261007";'''
new = '''import { number, shortDate, statusBadge, initials, escapeHtml, paginate, renderPager, toast, setBusy, statCard, plainCard, trendDelta, countBefore, monthBounds } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  users = await listUsers();
  users.forEach((u) => { u.status = u.status || "active"; u.role = u.role || "user"; });
  renderStats();
  applyFilters();
}

function renderStats() {
  const active = users.filter((u) => u.status === "active").length;
  const pending = users.filter((u) => u.status === "pending").length;
  const suspended = users.filter((u) => u.status === "suspended").length;
  document.getElementById("statGrid").innerHTML = [
    statCard("Total users", number(users.length), "user"),
    statCard("Active", number(active), "sparkle"),
    statCard("Pending", number(pending), "user-check"),
    statCard("Suspended", number(suspended), "user-x"),
  ].join("");
  mountIcons(document);
}'''
new = '''async function load() {
  users = await listUsers();
  users.forEach((u) => { u.status = u.status || "active"; u.role = u.role || "user"; });
  renderStats();
  applyFilters();
}

function renderStats() {
  const active = users.filter((u) => u.status === "active");
  const pending = users.filter((u) => u.status === "pending").length;
  const suspended = users.filter((u) => u.status === "suspended").length;
  // Real deltas (js/ui.js) — Pending/Suspended are live status snapshots
  // with no honest baseline, so they're plainCards.
  const { start: thisMonthStart } = monthBounds(0);
  const totalDelta = trendDelta(users.length, countBefore(users, "createdAt", thisMonthStart));
  const activeDelta = trendDelta(active.length, countBefore(active, "createdAt", thisMonthStart));
  document.getElementById("statGrid").innerHTML = [
    statCard("Total users", number(users.length), "user", totalDelta),
    statCard("Active", number(active.length), "sparkle", activeDelta),
    plainCard("Pending", number(pending)),
    plainCard("Suspended", number(suspended)),
  ].join("");
  mountIcons(document);
}'''
c = replace_once(path, old, new, c)
write(path, c)
print("users.html patched, new length", len(c))

# ========================================================================
# 11. partner/claims.html — claim/refund status cards. Uses
#     countByStatusInMonth (buckets by WHEN an item reached its current
#     status, via its timeline) so this is a genuine monthly flow, not a
#     queue snapshot — every card here gets a real delta.
# ========================================================================
path = "admin_web/partner/claims.html"
c = read(path)
old = '''import { number, moneyExact, statusBadge, escapeHtml, paginate, renderPager, toast, setBusy, openModal, closeModal, wireModalDismiss } from "../js/ui.js?v=20261007";'''
new = '''import { number, moneyExact, statusBadge, escapeHtml, paginate, renderPager, toast, setBusy, openModal, closeModal, wireModalDismiss, statCard, trendDelta, countByStatusInMonth } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

function setTab(nextType) {'''
new = '''function setTab(nextType) {'''
c = replace_once(path, old, new, c)

old = '''async function load() {
  items = type === "claim" ? await listClaims(session.uid) : await listRefunds(session.uid);
  const prefix = type === "claim" ? "New claims" : "New refunds";
  document.getElementById("statGrid").innerHTML = [
    statCard(prefix, number(items.filter((c) => c.status === "new").length), "flag"),
    statCard("Under review", number(items.filter((c) => c.status === "under_review").length), "clock"),
    statCard("Approved", number(items.filter((c) => c.status === "approved").length), "check-circle"),
    statCard("Rejected", number(items.filter((c) => c.status === "rejected").length), "x-circle"),
  ].join("");
  applyFilters();
  mountIcons(document);
}'''
new = '''async function load() {
  items = type === "claim" ? await listClaims(session.uid) : await listRefunds(session.uid);
  const prefix = type === "claim" ? "New claims" : "New refunds";
  // Real deltas (js/ui.js): bucketed by WHEN each item reached its
  // current status (its timeline), not when it was filed — so "Approved"
  // compares how many were approved this month vs last month, not how
  // many happen to have been created in each of those months.
  const newDelta = trendDelta(countByStatusInMonth(items, "new", 0), countByStatusInMonth(items, "new", 1));
  const reviewDelta = trendDelta(countByStatusInMonth(items, "under_review", 0), countByStatusInMonth(items, "under_review", 1));
  const approvedDelta = trendDelta(countByStatusInMonth(items, "approved", 0), countByStatusInMonth(items, "approved", 1));
  const rejectedDelta = trendDelta(countByStatusInMonth(items, "rejected", 0), countByStatusInMonth(items, "rejected", 1));
  document.getElementById("statGrid").innerHTML = [
    statCard(prefix, number(items.filter((c) => c.status === "new").length), "flag", newDelta),
    statCard("Under review", number(items.filter((c) => c.status === "under_review").length), "clock", reviewDelta),
    statCard("Approved", number(items.filter((c) => c.status === "approved").length), "check-circle", approvedDelta),
    statCard("Rejected", number(items.filter((c) => c.status === "rejected").length), "x-circle", rejectedDelta),
  ].join("");
  applyFilters();
  mountIcons(document);
}'''
c = replace_once(path, old, new, c)
write(path, c)
print("partner/claims.html patched, new length", len(c))

# ========================================================================
# 12. partner/dashboard.html — same shape as admin/insurance.html.
# ========================================================================
path = "admin_web/partner/dashboard.html"
c = read(path)
old = '''import { money, moneyExact, number, statusBadge, escapeHtml, timeAgo, toast, setBusy } from "../js/ui.js?v=20261007";'''
new = '''import { money, moneyExact, number, statusBadge, escapeHtml, timeAgo, toast, setBusy, statCard, plainCard, trendDelta, pointDelta, sumInMonth, countInMonth, monthBounds, rateOf } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  const [txns, claims, plans] = await Promise.all([
    listTransactions(session.uid), listClaims(session.uid), listPlans(session.uid),
  ]);
  document.getElementById("devBar").style.display = (!txns.length && !claims.length && !plans.length) ? "flex" : "none";

  const paid = txns.filter((t) => t.status === "paid");
  const gross = paid.reduce((s, t) => s + (Number(t.premium) || 0), 0);
  const pending = claims.filter((c) => c.status === "new" || c.status === "under_review").length;
  const approved = claims.filter((c) => c.status === "approved").length;
  const rate = claims.length ? Math.round((approved / claims.length) * 1000) / 10 : 0;

  document.getElementById("statGrid").innerHTML = [
    statCard("Gross premium", money(gross), "coin"),
    statCard("Policies sold", number(paid.length), "shield-check"),
    statCard("Pending claims", number(pending), "clock"),
    statCard("Approval rate", `${rate}%`, "percent"),
  ].join("");'''
new = '''async function load() {
  const [txns, claims, plans] = await Promise.all([
    listTransactions(session.uid), listClaims(session.uid), listPlans(session.uid),
  ]);
  document.getElementById("devBar").style.display = (!txns.length && !claims.length && !plans.length) ? "flex" : "none";

  const paid = txns.filter((t) => t.status === "paid");
  const gross = paid.reduce((s, t) => s + (Number(t.premium) || 0), 0);
  const pending = claims.filter((c) => c.status === "new" || c.status === "under_review").length;
  const approved = claims.filter((c) => c.status === "approved").length;
  const rate = claims.length ? Math.round((approved / claims.length) * 1000) / 10 : 0;

  const grossDelta = trendDelta(
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 0),
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 1),
  );
  const soldDelta = trendDelta(countInMonth(paid, "createdAt", 0), countInMonth(paid, "createdAt", 1));
  const { start: thisMonthStart } = monthBounds(0);
  const { start: lastMonthStart, end: lastMonthEnd } = monthBounds(1);
  const claimDateOf = (c) => (c.createdAt?.toDate ? c.createdAt.toDate() : null);
  const claimsThisMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= thisMonthStart; });
  const claimsLastMonth = claims.filter((c) => { const d = claimDateOf(c); return d && d >= lastMonthStart && d < lastMonthEnd; });
  const rateDelta = pointDelta(rateOf(claimsThisMonth, (c) => c.status === "approved"), rateOf(claimsLastMonth, (c) => c.status === "approved"));

  document.getElementById("statGrid").innerHTML = [
    statCard("Gross premium", money(gross), "coin", grossDelta),
    statCard("Policies sold", number(paid.length), "shield-check", soldDelta),
    plainCard("Pending claims", number(pending)),
    statCard("Approval rate", `${rate}%`, "percent", rateDelta),
  ].join("");'''
c = replace_once(path, old, new, c)
write(path, c)
print("partner/dashboard.html patched, new length", len(c))

# ========================================================================
# 13. partner/plans.html
# ========================================================================
path = "admin_web/partner/plans.html"
c = read(path)
old = '''import { money, moneyExact, number, statusBadge, escapeHtml, paginate, renderPager, toast, setBusy, openModal, closeModal, wireModalDismiss, confirmDialog } from "../js/ui.js?v=20261007";'''
new = '''import { money, moneyExact, number, statusBadge, escapeHtml, paginate, renderPager, toast, setBusy, openModal, closeModal, wireModalDismiss, confirmDialog, statCard, trendDelta, countBefore, sumBefore, monthBounds } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  items = await listPlans(session.uid);
  const active = items.filter((p) => p.status === "active").length;
  const draft = items.filter((p) => p.status === "draft").length;
  const coverage = items.reduce((s, p) => s + (Number(p.coverage) || 0), 0);
  document.getElementById("statGrid").innerHTML = [
    statCard("Active plans", number(active), "shield-check"),
    statCard("Drafts", number(draft), "doc-text"),
    statCard("Coverage sold", money(coverage), "coin"),
  ].join("");'''
new = '''async function load() {
  items = await listPlans(session.uid);
  const active = items.filter((p) => p.status === "active");
  const draft = items.filter((p) => p.status === "draft");
  const coverage = items.reduce((s, p) => s + (Number(p.coverage) || 0), 0);
  const { start: thisMonthStart } = monthBounds(0);
  const activeDelta = trendDelta(active.length, countBefore(active, "createdAt", thisMonthStart));
  const draftDelta = trendDelta(draft.length, countBefore(draft, "createdAt", thisMonthStart));
  const coverageDelta = trendDelta(coverage, sumBefore(items, "createdAt", (p) => Number(p.coverage) || 0, thisMonthStart));
  document.getElementById("statGrid").innerHTML = [
    statCard("Active plans", number(active.length), "shield-check", activeDelta),
    statCard("Drafts", number(draft.length), "doc-text", draftDelta),
    statCard("Coverage sold", money(coverage), "coin", coverageDelta),
  ].join("");'''
c = replace_once(path, old, new, c)
write(path, c)
print("partner/plans.html patched, new length", len(c))

# ========================================================================
# 14. partner/transactions.html
# ========================================================================
path = "admin_web/partner/transactions.html"
c = read(path)
old = '''import { money, moneyExact, number, statusBadge, escapeHtml, paginate, renderPager } from "../js/ui.js?v=20261007";'''
new = '''import { money, moneyExact, number, statusBadge, escapeHtml, paginate, renderPager, statCard, plainCard, trendDelta, countBefore, sumBefore, monthBounds } from "../js/ui.js?v=20261007";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}

async function load() {
  items = await listTransactions(session.uid);
  const paid = items.filter((t) => t.status === "paid");
  const pending = items.filter((t) => t.status === "pending");
  const gross = paid.reduce((s, t) => s + (Number(t.premium) || 0), 0);
  document.getElementById("statGrid").innerHTML = [
    statCard("Total transactions", number(items.length), "swap"),
    statCard("Paid", number(paid.length), "check-circle"),
    statCard("Pending", number(pending.length), "clock"),
    statCard("Gross premium", money(gross), "coin"),
  ].join("");'''
new = '''async function load() {
  items = await listTransactions(session.uid);
  const paid = items.filter((t) => t.status === "paid");
  const pending = items.filter((t) => t.status === "pending");
  const gross = paid.reduce((s, t) => s + (Number(t.premium) || 0), 0);
  const { start: thisMonthStart } = monthBounds(0);
  const totalDelta = trendDelta(items.length, countBefore(items, "createdAt", thisMonthStart));
  const paidDelta = trendDelta(paid.length, countBefore(paid, "createdAt", thisMonthStart));
  const grossDelta = trendDelta(gross, sumBefore(paid, "createdAt", (t) => Number(t.premium) || 0, thisMonthStart));
  document.getElementById("statGrid").innerHTML = [
    statCard("Total transactions", number(items.length), "swap", totalDelta),
    statCard("Paid", number(paid.length), "check-circle", paidDelta),
    plainCard("Pending", number(pending.length)),
    statCard("Gross premium", money(gross), "coin", grossDelta),
  ].join("");'''
c = replace_once(path, old, new, c)
write(path, c)
print("partner/transactions.html patched, new length", len(c))

# ========================================================================
# 15. partner/reports.html — top 5 stat cards (keeps its own local
#     statCard, just gives it a 4th `delta` param like admin/reports.html
#     already has).
# ========================================================================
path = "admin_web/partner/reports.html"
c = read(path)
old = '''import { money, moneyExact, number, escapeHtml, renderComparisonBars } from "../js/ui.js?v=20261007d";'''
new = '''import { money, moneyExact, number, escapeHtml, renderComparisonBars, trendDelta, pointDelta, sumInMonth, countInMonth, countBefore, monthBounds, rateOf } from "../js/ui.js?v=20261007d";'''
c = replace_once(path, old, new, c)

old = '''function statCard(label, value, icon) {
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div><div class="stat-delta">↑ 2.4% from last month</div></div>`;
}'''
new = '''function statCard(label, value, icon, delta) {
  const deltaHtml = delta ? `<div class="stat-delta${delta.up === false ? " down" : ""}">${delta.text}</div>` : "";
  return `<div class="card stat-card"><div class="stat-top"><div class="stat-icon"><span data-icon="${icon}"></span></div><div class="stat-label">${label}</div></div><div class="stat-value">${value}</div>${deltaHtml}</div>`;
}'''
c = replace_once(path, old, new, c)

old = '''  document.getElementById("statGrid").innerHTML = [
    statCard("Active plans", number(activePlans.length), "shield-check"),
    statCard("Total purchases", number(paid.length), "swap"),
    statCard("Transaction value", money(value), "coin"),
    statCard("Pending claims", number(pendingClaims), "clock"),
    statCard("Pending refunds", number(pendingRefunds), "clock"),
  ].join("");'''
new = '''  const { start: reportsThisMonthStart } = monthBounds(0);
  const activePlansDelta = trendDelta(activePlans.length, countBefore(activePlans, "createdAt", reportsThisMonthStart));
  const purchasesDelta = trendDelta(countInMonth(paid, "createdAt", 0), countInMonth(paid, "createdAt", 1));
  const valueDelta = trendDelta(
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 0),
    sumInMonth(paid, "createdAt", (t) => Number(t.premium) || 0, 1),
  );
  document.getElementById("statGrid").innerHTML = [
    statCard("Active plans", number(activePlans.length), "shield-check", activePlansDelta),
    statCard("Total purchases", number(paid.length), "swap", purchasesDelta),
    statCard("Transaction value", money(value), "coin", valueDelta),
    plainCard("Pending claims", number(pendingClaims)),
    plainCard("Pending refunds", number(pendingRefunds)),
  ].join("");'''
c = replace_once(path, old, new, c)
write(path, c)
print("partner/reports.html patched, new length", len(c))

# ========================================================================
# 16. Version bump every touched page's shared-JS query strings, so no
#     browser serves a stale cached ui.js/data.js missing the new exports.
#     Safe to run after the content edits above: the exact-quote-boundary
#     pattern below can't match a string that's already been bumped.
# ========================================================================
BUMP_FILES_07 = [
    "admin_web/admin/insurance.html", "admin_web/admin/settings.html",
    "admin_web/admin/content-moderation.html", "admin_web/admin/analytics.html",
    "admin_web/admin/attractions.html", "admin_web/admin/overview.html",
    "admin_web/admin/users.html", "admin_web/partner/claims.html",
    "admin_web/partner/dashboard.html", "admin_web/partner/plans.html",
    "admin_web/partner/transactions.html",
]
for path in BUMP_FILES_07:
    c = read(path)
    n = c.count('v=20261007"')
    assert n >= 1, f"{path}: no v=20261007 left to bump (n={n})"
    c = c.replace('v=20261007"', 'v=20261007e"')
    write(path, c)
    print(f"{path}: bumped {n} version tag(s) -> 20261007e")

BUMP_FILES_07D = ["admin_web/admin/reports.html", "admin_web/partner/reports.html"]
for path in BUMP_FILES_07D:
    c = read(path)
    n = c.count('v=20261007d"')
    assert n >= 1, f"{path}: no v=20261007d left to bump (n={n})"
    c = c.replace('v=20261007d"', 'v=20261007e"')
    write(path, c)
    print(f"{path}: bumped {n} version tag(s) -> 20261007e")

# ========================================================================
# 17. admin_web/README.md — the "decorative 2.4%" bullet is now stale,
#     since every stat card computes a real month-over-month (or
#     vs-yesterday) delta instead.
# ========================================================================
path = "admin_web/README.md"
c = read(path)
old = '''- The small "↑ 2.4% from last month" trend line on every stat card is
  decorative (matches the Figma mockup) — computing a real month-over-month
  delta needs daily snapshots this project doesn't keep.'''
new = '''- The trend line on every stat card (e.g. "↑ 4.2% from last month") is a
  real delta computed client-side from each record's own `createdAt`/
  `timeline` — see monthDelta/pointDelta/sumInMonth/countByStatusInMonth in
  `js/ui.js`. A metric with no honest baseline to compare against (a
  "Pending …" queue, a status with no real temporal correlation like
  "Suspended") renders as a plainCard with no delta instead of faking one.'''
c = replace_once(path, old, new, c)
write(path, c)
print("README.md patched, new length", len(c))

print("ALL PATCHES APPLIED OK")
