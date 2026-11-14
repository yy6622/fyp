import io
path = "admin_web/partner/plans.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:160]!r}")
    return s.replace(old, new, 1)

# 1. Status + trip-type filter options
old = '''      <select class="select" id="statusFilter">
        <option value="">All status</option>
        <option value="active">Active</option>
        <option value="inactive">Inactive</option>
      </select>
      <select class="select" id="tripTypeFilter">
        <option value="">All trip types</option>
        <option value="Single Trip">Single Trip</option>
        <option value="Family">Family</option>
        <option value="Annual">Annual</option>
      </select>'''
new = '''      <select class="select" id="statusFilter">
        <option value="">All status</option>
        <option value="draft">Draft</option>
        <option value="pending_review">Pending review</option>
        <option value="published">Published</option>
        <option value="rejected">Rejected</option>
        <option value="suspended">Suspended</option>
      </select>
      <select class="select" id="tripTypeFilter">
        <option value="">All trip types</option>
        <option value="Basic">Basic</option>
        <option value="Annual">Annual</option>
      </select>'''
s = r1(old, new, s)

# 2. Imports: bump versions (already done by bump_versions.py), no new
# functions needed here -- plans.html only reads/deletes, doesn't change
# status itself (that's plan-form.html's job now).

# 3. Stat cards: Active/Inactive -> a status breakdown that matches the
# new workflow (Published/Pending review/Draft+Rejected+Suspended).
old = '''async function load() {
  items = await listPlans(session.uid);
  const active = items.filter((p) => p.status === "active");
  const inactive = items.filter((p) => p.status !== "active");
  const { start: thisMonthStart } = monthBounds(0);
  const activeDelta = trendDelta(active.length, countBefore(active, "createdAt", thisMonthStart));
  const inactiveDelta = trendDelta(inactive.length, countBefore(inactive, "createdAt", thisMonthStart));
  // "Policies sold" used to live here too, but it's a sales number, not a
  // plan-catalogue number — it already has a real home (and a matching
  // real trend) on the Transactions page, so showing it a second time
  // here was just duplication (Nov 2026).
  document.getElementById("statGrid").innerHTML = [
    statCard("Active plans", number(active.length), "shield-check", activeDelta),
    statCard("Inactive plans", number(inactive.length), "eye-off", inactiveDelta),
  ].join("");
  applyFilters();
  mountIcons(document);
}'''
new = '''async function load() {
  items = await listPlans(session.uid);
  const published = items.filter((p) => p.status === "published" || p.status === "active");
  const pendingReview = items.filter((p) => p.status === "pending_review");
  const needsAttention = items.filter((p) => p.status === "rejected" || p.status === "suspended");
  const { start: thisMonthStart } = monthBounds(0);
  const publishedDelta = trendDelta(published.length, countBefore(published, "createdAt", thisMonthStart));
  // "Policies sold" used to live here too, but it's a sales number, not a
  // plan-catalogue number — it already has a real home (and a matching
  // real trend) on the Transactions page, so showing it a second time
  // here was just duplication (Nov 2026).
  document.getElementById("statGrid").innerHTML = [
    statCard("Published plans", number(published.length), "shield-check", publishedDelta),
    plainCard("Pending review", number(pendingReview.length), "clock"),
    plainCard("Rejected / suspended", number(needsAttention.length), "x-circle"),
  ].join("");
  applyFilters();
  mountIcons(document);
}'''
s = r1(old, new, s)

# plainCard needs importing alongside statCard.
old = 'import { moneyExact, number, statusBadge, escapeHtml, paginate, renderPager, toast, confirmDialog, detailDialog, statCard, trendDelta, countBefore, monthBounds } from "../js/ui.js?v=20261113a";'
new = 'import { moneyExact, number, statusBadge, escapeHtml, paginate, renderPager, toast, confirmDialog, detailDialog, statCard, plainCard, trendDelta, countBefore, monthBounds } from "../js/ui.js?v=20261113a";'
s = r1(old, new, s)

# 4. premiumUnit(): Basic, not "default/else" branching off Annual -- same
# logic, just the comment's terminology.
old = '''// Single Trip / Family plans are priced per traveller per day of the trip
// (see plan-form.html); Annual is a flat per-traveller yearly price. Shown
// next to the premium everywhere it's listed so it's never read as a flat
// total.
function premiumUnit(tripType) {
  return tripType === "Annual" ? "/traveller/yr" : "/traveller/day";
}'''
new = '''// Basic plans are priced per traveller per day of the trip (see
// plan-form.html); Annual is a flat per-traveller yearly price. Shown
// next to the premium everywhere it's listed so it's never read as a flat
// total.
function premiumUnit(tripType) {
  return tripType === "Annual" ? "/traveller/yr" : "/traveller/day";
}'''
s = r1(old, new, s)

# 5. Row actions: editing/deleting is allowed regardless of status (the
# review workflow itself is enforced inside plan-form.html / firestore
# rules), but show the status badge + a rejection-reason hint directly in
# the table so a partner sees at a glance which plans need attention
# without opening each one.
old = '''        <td class="muted">${escapeHtml(p.tripType || "—")}</td>
        <td class="muted">${moneyExact(p.coverage)}</td>
        <td class="muted">${moneyExact(p.premium)} <span class="small">${premiumUnit(p.tripType)}</span></td>
        <td>${statusBadge(p.status)}</td>'''
new = '''        <td class="muted">${escapeHtml(p.tripType || "—")}</td>
        <td class="muted">${moneyExact(p.coverage)}</td>
        <td class="muted">${moneyExact(p.premium)} <span class="small">${premiumUnit(p.tripType)}</span></td>
        <td>${statusBadge(p.status || "draft")}</td>'''
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("ok")
