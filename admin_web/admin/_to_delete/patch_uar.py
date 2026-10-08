import io

path = "reports.html"
with io.open(path, "r", encoding="utf-8") as f:
    content = f.read()

# ---- Step 1: insert countBetween + yearToDateMonths after countBefore, before plainCard ----
anchor1 = '''function countBefore(items, dateField, cutoff) {
  return items.filter((item) => {
    const d = item[dateField]?.toDate ? item[dateField].toDate() : null;
    return d && d < cutoff;
  }).length;
}
function plainCard(label, value) {'''
assert content.count(anchor1) == 1, f"anchor1 count={content.count(anchor1)}"

new_helpers = '''function countBefore(items, dateField, cutoff) {
  return items.filter((item) => {
    const d = item[dateField]?.toDate ? item[dateField].toDate() : null;
    return d && d < cutoff;
  }).length;
}

/** Counts items whose [dateField] Timestamp falls inside [start, end) —
 * used by User Account Reports' cohort/month-bucket logic below, where
 * countInMonth's fixed "N months ago" framing doesn't fit (that report is
 * year-to-date, not a rolling window). */
function countBetween(items, dateField, start, end) {
  return items.filter((item) => {
    const d = item[dateField]?.toDate ? item[dateField].toDate() : null;
    return d && d >= start && d < end;
  }).length;
}

/** January 1st of the current year through the start of the current month
 * — the annual framing User Account Reports uses (distinct from the 6/12
 * -month rolling window the other report tabs use), as one `{label, start,
 * end}` bound per month so callers can both count a monthly cohort and
 * sum/label a chart from the same list. */
function yearToDateMonths() {
  const now = new Date();
  const months = [];
  for (let m = 0; m <= now.getMonth(); m++) {
    const start = new Date(now.getFullYear(), m, 1);
    const end = new Date(now.getFullYear(), m + 1, 1);
    months.push({ label: start.toLocaleDateString("en-MY", { month: "short", year: "numeric" }), start, end });
  }
  return months;
}
function plainCard(label, value) {'''

content = content.replace(anchor1, new_helpers, 1)

# ---- Step 2: insert the full User Account Reports render/load/export block
# right before the exportPdfBtn click-handler wiring. ----
anchor2 = '''document.getElementById("exportPdfBtn").addEventListener("click", () => {
  if (!data) return;
  try {
    if (category === "overview") exportPlatformOverviewPdf();
    else if (category === "insurance") exportInsuranceOperationsPdf();
    else if (category === "posts") exportCommunityPostAnalysisPdf();
  } catch (err) {
    alert(err.message || "Couldn't export PDF.");
  }
});

document.getElementById("exportExcelBtn").addEventListener("click", () => {
  if (!data) return;
  try {
    if (category === "overview") exportPlatformOverviewExcel();
    else if (category === "insurance") exportInsuranceOperationsExcel();
    else if (category === "posts") exportCommunityPostAnalysisExcel();
  } catch (err) {
    alert(err.message || "Couldn't export Excel.");
  }
});'''
assert content.count(anchor2) == 1, f"anchor2 count={content.count(anchor2)}"

uar_block = '''/** User Account Reports — see Report Design spec. Traveller and Insurance
 * Partner stay on separate sub-pages (see `uarSubTab`) rather than one
 * combined table, since the two account types' volumes aren't comparable.
 * Framed year-to-date (Jan 1 of the current year through this month),
 * unlike the other three tabs' rolling 6/12-month window — matches the
 * spec's "annual" framing for this report. */
async function renderUserAccountReports() {
  document.getElementById("reportBody").innerHTML = `
    <div class="tabs" id="uarSubTabs" style="margin-bottom:20px;">
      <button class="tab-btn${uarSubTab === "traveller" ? " active" : ""}" data-sub="traveller">Traveller</button>
      <button class="tab-btn${uarSubTab === "partner" ? " active" : ""}" data-sub="partner">Insurance Partner</button>
    </div>
    <div id="uarSubBody"><div class="skeleton" style="height:200px;"></div></div>`;
  document.querySelectorAll("#uarSubTabs .tab-btn").forEach((b) => b.addEventListener("click", async () => {
    if (b.dataset.sub === uarSubTab) return;
    uarSubTab = b.dataset.sub;
    document.querySelectorAll("#uarSubTabs .tab-btn").forEach((t) => t.classList.toggle("active", t === b));
    data = null;
    await renderUserAccountSubPage();
  }));
  await renderUserAccountSubPage();
}

async function renderUserAccountSubPage() {
  if (uarSubTab === "traveller") await renderTravellerAccountReport();
  else await renderPartnerAccountReport();
}

async function renderTravellerAccountReport() {
  document.getElementById("uarSubBody").innerHTML = `
    <p class="small muted" style="margin-bottom:14px;">Year to date — as of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}</p>
    <div class="stat-grid" id="travStatGrid"><div class="skeleton" style="height:90px;grid-column:1/-1;"></div></div>
    <div style="display:grid;grid-template-columns:1.4fr 1fr;gap:20px;align-items:start;" class="detail-grid">
      <div class="card card-pad">
        <h3 class="h3" style="margin-bottom:18px;">Monthly Traveller Registrations</h3>
        <div class="bars" id="travTrendBars"></div>
        <div class="bars-labels" id="travTrendLabels"></div>
      </div>
      <div class="card card-pad">
        <h3 class="h3" style="margin-bottom:18px;">Year-End Account Status</h3>
        <div class="bars" id="travStatusBars"></div>
        <div class="bars-labels" id="travStatusLabels"></div>
      </div>
    </div>
    <div class="card card-pad" style="margin-top:20px;">
      <h3 class="h3" style="margin-bottom:16px;">Monthly Traveller Account Detail</h3>
      <div class="table-wrap scroll-x" style="border:none;">
        <table class="data-table">
          <thead><tr><th>Month</th><th>New Registrations</th><th>Active Users</th><th>Inactive Users</th><th>Suspended</th><th>2FA Enabled</th></tr></thead>
          <tbody id="travDetailBody"></tbody>
        </table>
      </div>
    </div>`;
  await loadTravellerAccountReport();
}

async function loadTravellerAccountReport() {
  let users;
  try {
    users = await listUsers();
  } catch (err) {
    renderLoadError(err);
    return;
  }
  const statusOf = (u) => u.status || "active";
  const createdAtOf = (u) => (u.createdAt?.toDate ? u.createdAt.toDate() : null);
  const totalTravellers = users.length;
  const activeUsers = users.filter((u) => statusOf(u) === "active").length;
  const inactiveUsers = users.filter((u) => statusOf(u) === "pending").length;
  const suspendedUsers = users.filter((u) => statusOf(u) === "suspended").length;
  const twoFactorCount = users.filter((u) => u.twoFactorEnabled).length;

  const now = new Date();
  const ytdStart = new Date(now.getFullYear(), 0, 1);
  const ytdEnd = new Date(now.getFullYear() + 1, 0, 1);
  const newRegistrationsYtd = countBetween(users, "createdAt", ytdStart, ytdEnd);

  // Real month-over-month deltas (see monthDelta/monthBounds/countBefore/
  // countInMonth, defined above renderPlatformOverview). Active users and
  // 2FA enabled have no historical status/flag log to replay, so each
  // delta approximates "how many of today's active/2FA-on travellers
  // already had that same current state before this month" — same
  // approximation already used by Platform Overview's Active travellers.
  const { start: travThisMonthStart } = monthBounds(0);
  const totalDelta = monthDelta(totalTravellers, countBefore(users, "createdAt", travThisMonthStart));
  const newRegDelta = monthDelta(countInMonth(users, "createdAt", 0), countInMonth(users, "createdAt", 1));
  const activeDelta = monthDelta(
    activeUsers,
    users.filter((u) => statusOf(u) === "active" && createdAtOf(u) && createdAtOf(u) < travThisMonthStart).length,
  );
  const twoFactorDelta = monthDelta(
    twoFactorCount,
    users.filter((u) => u.twoFactorEnabled && createdAtOf(u) && createdAtOf(u) < travThisMonthStart).length,
  );

  document.getElementById("travStatGrid").innerHTML = [
    statCard("Total travellers", number(totalTravellers), "user", totalDelta),
    statCard("New registrations (YTD)", number(newRegistrationsYtd), "user-plus", newRegDelta),
    statCard("Active users", number(activeUsers), "check-circle", activeDelta),
    statCard("2FA enabled", number(twoFactorCount), "shield-check", twoFactorDelta),
  ].join("");

  const months = yearToDateMonths();
  months.forEach((m) => { m.count = countBetween(users, "createdAt", m.start, m.end); });
  const maxCount = Math.max(1, ...months.map((m) => m.count));
  document.getElementById("travTrendBars").innerHTML = months.map((m, i) => `<div class="bar-col"><div class="bar${i % 2 ? " alt" : ""}" style="height:${Math.max(6, (m.count / maxCount) * 100)}%"></div></div>`).join("");
  document.getElementById("travTrendLabels").innerHTML = months.map((m) => `<span style="font-size:10.5px;">${m.label.split(" ")[0]}</span>`).join("");

  const statusEntries = [["Active", activeUsers], ["Inactive", inactiveUsers], ["Suspended", suspendedUsers]];
  const maxStatus = Math.max(1, ...statusEntries.map(([, v]) => v));
  document.getElementById("travStatusBars").innerHTML = statusEntries.map(([, v], i) => `<div class="bar-col"><div class="bar${i % 2 ? " alt" : ""}" style="height:${Math.max(6, (v / maxStatus) * 100)}%"></div></div>`).join("");
  document.getElementById("travStatusLabels").innerHTML = statusEntries.map(([label]) => `<span>${label}</span>`).join("");

  // Monthly detail — the last 4 columns approximate "as of end of that
  // month" using each traveller's CURRENT status/2FA state (no historical
  // status log exists to replay, same approximation as the deltas above).
  // Total row sums New Registrations but takes the LATEST value for the
  // 4 cumulative columns, since those aren't additive across months.
  const detailRows = months.map((m) => ({
    label: m.label,
    newRegistrations: m.count,
    active: users.filter((u) => statusOf(u) === "active" && createdAtOf(u) && createdAtOf(u) < m.end).length,
    inactive: users.filter((u) => statusOf(u) === "pending" && createdAtOf(u) && createdAtOf(u) < m.end).length,
    suspended: users.filter((u) => statusOf(u) === "suspended" && createdAtOf(u) && createdAtOf(u) < m.end).length,
    twoFactor: users.filter((u) => u.twoFactorEnabled && createdAtOf(u) && createdAtOf(u) < m.end).length,
  }));
  const travLatest = detailRows[detailRows.length - 1] || { active: 0, inactive: 0, suspended: 0, twoFactor: 0 };
  document.getElementById("travDetailBody").innerHTML = detailRows.map((r) => `
        <tr>
          <td class="cell-strong">${escapeHtml(r.label)}</td>
          <td class="muted">${number(r.newRegistrations)}</td>
          <td class="muted">${number(r.active)}</td>
          <td class="muted">${number(r.inactive)}</td>
          <td class="muted">${number(r.suspended)}</td>
          <td class="muted">${number(r.twoFactor)}</td>
        </tr>`).join("") + `
        <tr style="font-weight:600;">
          <td class="cell-strong">Total</td>
          <td>${number(detailRows.reduce((s, r) => s + r.newRegistrations, 0))}</td>
          <td>${number(travLatest.active)}</td>
          <td>${number(travLatest.inactive)}</td>
          <td>${number(travLatest.suspended)}</td>
          <td>${number(travLatest.twoFactor)}</td>
        </tr>`;

  mountIcons(document);

  data = {
    stats: { totalTravellers, newRegistrationsYtd, activeUsers, twoFactorCount },
    months, statusEntries, detailRows,
  };
}

async function renderPartnerAccountReport() {
  document.getElementById("uarSubBody").innerHTML = `
    <p class="small muted" style="margin-bottom:14px;">Year to date — as of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}</p>
    <div class="stat-grid" id="partStatGrid"><div class="skeleton" style="height:90px;grid-column:1/-1;"></div></div>
    <div class="card card-pad" style="margin-bottom:20px;">
      <h3 class="h3" style="margin-bottom:18px;">Monthly Insurance Partner Registrations</h3>
      <div class="bars" id="partTrendBars"></div>
      <div class="bars-labels" id="partTrendLabels"></div>
    </div>
    <div class="card card-pad">
      <h3 class="h3" style="margin-bottom:16px;">Monthly Insurance Partner Account Detail</h3>
      <div class="table-wrap scroll-x" style="border:none;">
        <table class="data-table">
          <thead><tr><th>Month</th><th>New Registrations</th><th>Active</th><th>Inactive</th><th>Rejected</th></tr></thead>
          <tbody id="partDetailBody"></tbody>
        </table>
      </div>
    </div>`;
  await loadPartnerAccountReport();
}

async function loadPartnerAccountReport() {
  let partners;
  try {
    partners = await listPartners();
  } catch (err) {
    renderLoadError(err);
    return;
  }
  // approved -> active; rejected -> rejected; pending/suspended (or no
  // status yet) -> inactive, matching settings.html's partner lifecycle.
  const bucketOf = (p) => (p.status === "approved" ? "active" : p.status === "rejected" ? "rejected" : "inactive");
  const createdAtOf = (p) => (p.createdAt?.toDate ? p.createdAt.toDate() : null);
  const totalPartners = partners.length;
  const activePartners = partners.filter((p) => bucketOf(p) === "active").length;

  const now = new Date();
  const ytdStart = new Date(now.getFullYear(), 0, 1);
  const ytdEnd = new Date(now.getFullYear() + 1, 0, 1);
  const newRegistrationsYtd = countBetween(partners, "createdAt", ytdStart, ytdEnd);

  const { start: partThisMonthStart } = monthBounds(0);
  const totalDelta = monthDelta(totalPartners, countBefore(partners, "createdAt", partThisMonthStart));
  const newRegDelta = monthDelta(countInMonth(partners, "createdAt", 0), countInMonth(partners, "createdAt", 1));
  const activeDelta = monthDelta(
    activePartners,
    partners.filter((p) => bucketOf(p) === "active" && createdAtOf(p) && createdAtOf(p) < partThisMonthStart).length,
  );

  document.getElementById("partStatGrid").innerHTML = [
    statCard("Total insurance partners", number(totalPartners), "briefcase", totalDelta),
    statCard("New registrations (YTD)", number(newRegistrationsYtd), "user-plus", newRegDelta),
    statCard("Active users", number(activePartners), "check-circle", activeDelta),
  ].join("");

  const months = yearToDateMonths();
  months.forEach((m) => { m.count = countBetween(partners, "createdAt", m.start, m.end); });
  const maxCount = Math.max(1, ...months.map((m) => m.count));
  document.getElementById("partTrendBars").innerHTML = months.map((m, i) => `<div class="bar-col"><div class="bar${i % 2 ? " alt" : ""}" style="height:${Math.max(6, (m.count / maxCount) * 100)}%"></div></div>`).join("");
  document.getElementById("partTrendLabels").innerHTML = months.map((m) => `<span style="font-size:10.5px;">${m.label.split(" ")[0]}</span>`).join("");

  // Cohort-based (not cumulative): each month's registrants bucketed by
  // CURRENT status, so Active+Inactive+Rejected reconciles exactly with
  // that month's own New Registrations total — unlike the traveller
  // table above, this doesn't need the "as of end of month" approximation
  // since every partner falls into exactly one bucket per cohort.
  const detailRows = months.map((m) => {
    const cohort = partners.filter((p) => createdAtOf(p) && createdAtOf(p) >= m.start && createdAtOf(p) < m.end);
    return {
      label: m.label,
      newRegistrations: cohort.length,
      active: cohort.filter((p) => bucketOf(p) === "active").length,
      inactive: cohort.filter((p) => bucketOf(p) === "inactive").length,
      rejected: cohort.filter((p) => bucketOf(p) === "rejected").length,
    };
  });
  document.getElementById("partDetailBody").innerHTML = detailRows.map((r) => `
        <tr>
          <td class="cell-strong">${escapeHtml(r.label)}</td>
          <td class="muted">${number(r.newRegistrations)}</td>
          <td class="muted">${number(r.active)}</td>
          <td class="muted">${number(r.inactive)}</td>
          <td class="muted">${number(r.rejected)}</td>
        </tr>`).join("") + `
        <tr style="font-weight:600;">
          <td class="cell-strong">Total</td>
          <td>${number(detailRows.reduce((s, r) => s + r.newRegistrations, 0))}</td>
          <td>${number(detailRows.reduce((s, r) => s + r.active, 0))}</td>
          <td>${number(detailRows.reduce((s, r) => s + r.inactive, 0))}</td>
          <td>${number(detailRows.reduce((s, r) => s + r.rejected, 0))}</td>
        </tr>`;

  mountIcons(document);

  data = {
    stats: { totalPartners, newRegistrationsYtd, activePartners },
    months, detailRows,
  };
}

function exportTravellerAccountPdf() {
  const latest = data.detailRows[data.detailRows.length - 1] || { active: 0, inactive: 0, suspended: 0, twoFactor: 0 };
  exportReportPdf({
    filename: `voya-traveller-account-report-${new Date().toISOString().slice(0, 10)}`,
    title: "Traveller Account Report",
    subtitle: `Year to date — as of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}`,
    stats: [
      { label: "Total travellers", value: data.stats.totalTravellers },
      { label: "New registrations (YTD)", value: data.stats.newRegistrationsYtd },
      { label: "Active users", value: data.stats.activeUsers },
      { label: "2FA enabled", value: data.stats.twoFactorCount },
    ],
    tables: [
      {
        title: "Monthly Traveller Account Detail",
        head: ["Month", "New Registrations", "Active Users", "Inactive Users", "Suspended", "2FA Enabled"],
        body: [
          ...data.detailRows.map((r) => [r.label, r.newRegistrations, r.active, r.inactive, r.suspended, r.twoFactor]),
          ["Total", data.detailRows.reduce((s, r) => s + r.newRegistrations, 0), latest.active, latest.inactive, latest.suspended, latest.twoFactor],
        ],
      },
    ],
  });
}

function exportTravellerAccountExcel() {
  exportReportExcel({
    filename: `voya-traveller-account-report-${new Date().toISOString().slice(0, 10)}`,
    sheets: [
      {
        name: "Summary",
        rows: [
          ["Metric", "Value"],
          ["Total travellers", data.stats.totalTravellers],
          ["New registrations (YTD)", data.stats.newRegistrationsYtd],
          ["Active users", data.stats.activeUsers],
          ["2FA enabled", data.stats.twoFactorCount],
        ],
      },
      { name: "Monthly Registrations", rows: [["Month", "Registrations"], ...data.months.map((m) => [m.label, m.count])] },
      {
        name: "Account Detail",
        rows: [
          ["Month", "New Registrations", "Active Users", "Inactive Users", "Suspended", "2FA Enabled"],
          ...data.detailRows.map((r) => [r.label, r.newRegistrations, r.active, r.inactive, r.suspended, r.twoFactor]),
        ],
      },
    ],
  });
}

function exportPartnerAccountPdf() {
  exportReportPdf({
    filename: `voya-partner-account-report-${new Date().toISOString().slice(0, 10)}`,
    title: "Insurance Partner Account Report",
    subtitle: `Year to date — as of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}`,
    stats: [
      { label: "Total insurance partners", value: data.stats.totalPartners },
      { label: "New registrations (YTD)", value: data.stats.newRegistrationsYtd },
      { label: "Active users", value: data.stats.activePartners },
    ],
    tables: [
      {
        title: "Monthly Insurance Partner Account Detail",
        head: ["Month", "New Registrations", "Active", "Inactive", "Rejected"],
        body: [
          ...data.detailRows.map((r) => [r.label, r.newRegistrations, r.active, r.inactive, r.rejected]),
          ["Total", data.detailRows.reduce((s, r) => s + r.newRegistrations, 0), data.detailRows.reduce((s, r) => s + r.active, 0), data.detailRows.reduce((s, r) => s + r.inactive, 0), data.detailRows.reduce((s, r) => s + r.rejected, 0)],
        ],
      },
    ],
  });
}

function exportPartnerAccountExcel() {
  exportReportExcel({
    filename: `voya-partner-account-report-${new Date().toISOString().slice(0, 10)}`,
    sheets: [
      {
        name: "Summary",
        rows: [
          ["Metric", "Value"],
          ["Total insurance partners", data.stats.totalPartners],
          ["New registrations (YTD)", data.stats.newRegistrationsYtd],
          ["Active users", data.stats.activePartners],
        ],
      },
      { name: "Monthly Registrations", rows: [["Month", "Registrations"], ...data.months.map((m) => [m.label, m.count])] },
      {
        name: "Account Detail",
        rows: [
          ["Month", "New Registrations", "Active", "Inactive", "Rejected"],
          ...data.detailRows.map((r) => [r.label, r.newRegistrations, r.active, r.inactive, r.rejected]),
        ],
      },
    ],
  });
}

document.getElementById("exportPdfBtn").addEventListener("click", () => {
  if (!data) return;
  try {
    if (category === "overview") exportPlatformOverviewPdf();
    else if (category === "insurance") exportInsuranceOperationsPdf();
    else if (category === "posts") exportCommunityPostAnalysisPdf();
    else if (category === "users") (uarSubTab === "traveller" ? exportTravellerAccountPdf : exportPartnerAccountPdf)();
  } catch (err) {
    alert(err.message || "Couldn't export PDF.");
  }
});

document.getElementById("exportExcelBtn").addEventListener("click", () => {
  if (!data) return;
  try {
    if (category === "overview") exportPlatformOverviewExcel();
    else if (category === "insurance") exportInsuranceOperationsExcel();
    else if (category === "posts") exportCommunityPostAnalysisExcel();
    else if (category === "users") (uarSubTab === "traveller" ? exportTravellerAccountExcel : exportPartnerAccountExcel)();
  } catch (err) {
    alert(err.message || "Couldn't export Excel.");
  }
});'''

content = content.replace(anchor2, uar_block, 1)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("ok, new length", len(content))
