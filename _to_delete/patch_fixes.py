import io

# ============== 1. firestore.rules: fix collectionGroup("viewers") permission bug ==============
path_rules = "firestore.rules"
with io.open(path_rules, "r", encoding="utf-8") as f:
    rules = f.read()

anchor_rules = '''    match /post_view_stats/{monthKey} {
      allow read: if isAdmin();
      allow create, update: if isSignedIn();
      allow delete: if false;
    }

    match /posts/{postId} {'''
assert rules.count(anchor_rules) == 1, f"rules anchor count={rules.count(anchor_rules)}"

new_rules = '''    match /post_view_stats/{monthKey} {
      allow read: if isAdmin();
      allow create, update: if isSignedIn();
      allow delete: if false;
    }

    // Collection-group counterpart to the posts/{postId}/viewers/{uid}
    // rule nested below — that rule only covers reads scoped to a single
    // post's own subcollection path. admin_web's listPostViewers() runs a
    // collectionGroup("viewers") query spanning every post at once (for
    // the Community Post Analysis Report's platform-wide unique-viewer
    // count), and Firestore requires a separate {path=**} wildcard rule
    // to authorize that — without this, the query was being rejected
    // with "Missing or insufficient permissions" even though the nested
    // rule below looked like it already covered "viewers". Admin-only,
    // same as post_view_stats above.
    match /{path=**}/viewers/{uid} {
      allow read: if isAdmin();
    }

    match /posts/{postId} {'''

rules = rules.replace(anchor_rules, new_rules, 1)
with io.open(path_rules, "w", encoding="utf-8") as f:
    f.write(rules)
print("rules patched, new length", len(rules))

# ============== 2. admin_web/admin/reports.html: drop "2FA enabled" from the Traveller report ==============
path_html = "admin_web/admin/reports.html"
with io.open(path_html, "r", encoding="utf-8") as f:
    content = f.read()

replacements = []

# a) table header
replacements.append((
  '          <thead><tr><th>Month</th><th>New Registrations</th><th>Active Users</th><th>Inactive Users</th><th>Suspended</th><th>2FA Enabled</th></tr></thead>',
  '          <thead><tr><th>Month</th><th>New Registrations</th><th>Active Users</th><th>Inactive Users</th><th>Suspended</th></tr></thead>',
))

# b) drop the twoFactorCount stat declaration
replacements.append((
  '''  const suspendedUsers = users.filter((u) => statusOf(u) === "suspended").length;
  const twoFactorCount = users.filter((u) => u.twoFactorEnabled).length;''',
  '''  const suspendedUsers = users.filter((u) => statusOf(u) === "suspended").length;''',
))

# c) drop twoFactorDelta + fix the comment above it
replacements.append((
  '''  // Real month-over-month deltas (see monthDelta/monthBounds/countBefore/
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
  );''',
  '''  // Real month-over-month deltas (see monthDelta/monthBounds/countBefore/
  // countInMonth, defined above renderPlatformOverview). Active users has
  // no historical status log to replay, so its delta approximates "how
  // many of today's active travellers already had that same current
  // state before this month" — same approximation already used by
  // Platform Overview's Active travellers.
  const { start: travThisMonthStart } = monthBounds(0);
  const totalDelta = monthDelta(totalTravellers, countBefore(users, "createdAt", travThisMonthStart));
  const newRegDelta = monthDelta(countInMonth(users, "createdAt", 0), countInMonth(users, "createdAt", 1));
  const activeDelta = monthDelta(
    activeUsers,
    users.filter((u) => statusOf(u) === "active" && createdAtOf(u) && createdAtOf(u) < travThisMonthStart).length,
  );''',
))

# d) drop the 2FA stat card
replacements.append((
  '''  document.getElementById("travStatGrid").innerHTML = [
    statCard("Total travellers", number(totalTravellers), "user", totalDelta),
    statCard("New registrations (YTD)", number(newRegistrationsYtd), "user-plus", newRegDelta),
    statCard("Active users", number(activeUsers), "check-circle", activeDelta),
    statCard("2FA enabled", number(twoFactorCount), "shield-check", twoFactorDelta),
  ].join("");''',
  '''  document.getElementById("travStatGrid").innerHTML = [
    statCard("Total travellers", number(totalTravellers), "user", totalDelta),
    statCard("New registrations (YTD)", number(newRegistrationsYtd), "user-plus", newRegDelta),
    statCard("Active users", number(activeUsers), "check-circle", activeDelta),
  ].join("");''',
))

# e) detailRows / travLatest / table body — drop twoFactor column
replacements.append((
  '''  // Monthly detail — the last 4 columns approximate "as of end of that
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
        </tr>`;''',
  '''  // Monthly detail — the last 3 columns approximate "as of end of that
  // month" using each traveller's CURRENT status (no historical status
  // log exists to replay, same approximation as the deltas above). Total
  // row sums New Registrations but takes the LATEST value for the 3
  // cumulative columns, since those aren't additive across months.
  const detailRows = months.map((m) => ({
    label: m.label,
    newRegistrations: m.count,
    active: users.filter((u) => statusOf(u) === "active" && createdAtOf(u) && createdAtOf(u) < m.end).length,
    inactive: users.filter((u) => statusOf(u) === "pending" && createdAtOf(u) && createdAtOf(u) < m.end).length,
    suspended: users.filter((u) => statusOf(u) === "suspended" && createdAtOf(u) && createdAtOf(u) < m.end).length,
  }));
  const travLatest = detailRows[detailRows.length - 1] || { active: 0, inactive: 0, suspended: 0 };
  document.getElementById("travDetailBody").innerHTML = detailRows.map((r) => `
        <tr>
          <td class="cell-strong">${escapeHtml(r.label)}</td>
          <td class="muted">${number(r.newRegistrations)}</td>
          <td class="muted">${number(r.active)}</td>
          <td class="muted">${number(r.inactive)}</td>
          <td class="muted">${number(r.suspended)}</td>
        </tr>`).join("") + `
        <tr style="font-weight:600;">
          <td class="cell-strong">Total</td>
          <td>${number(detailRows.reduce((s, r) => s + r.newRegistrations, 0))}</td>
          <td>${number(travLatest.active)}</td>
          <td>${number(travLatest.inactive)}</td>
          <td>${number(travLatest.suspended)}</td>
        </tr>`;''',
))

# f) data.stats — drop twoFactorCount
replacements.append((
  '''  data = {
    stats: { totalTravellers, newRegistrationsYtd, activeUsers, twoFactorCount },
    months, statusEntries, detailRows,
  };
}

async function renderPartnerAccountReport() {''',
  '''  data = {
    stats: { totalTravellers, newRegistrationsYtd, activeUsers },
    months, statusEntries, detailRows,
  };
}

async function renderPartnerAccountReport() {''',
))

# g) exportTravellerAccountPdf
replacements.append((
  '''function exportTravellerAccountPdf() {
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
}''',
  '''function exportTravellerAccountPdf() {
  const latest = data.detailRows[data.detailRows.length - 1] || { active: 0, inactive: 0, suspended: 0 };
  exportReportPdf({
    filename: `voya-traveller-account-report-${new Date().toISOString().slice(0, 10)}`,
    title: "Traveller Account Report",
    subtitle: `Year to date — as of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}`,
    stats: [
      { label: "Total travellers", value: data.stats.totalTravellers },
      { label: "New registrations (YTD)", value: data.stats.newRegistrationsYtd },
      { label: "Active users", value: data.stats.activeUsers },
    ],
    tables: [
      {
        title: "Monthly Traveller Account Detail",
        head: ["Month", "New Registrations", "Active Users", "Inactive Users", "Suspended"],
        body: [
          ...data.detailRows.map((r) => [r.label, r.newRegistrations, r.active, r.inactive, r.suspended]),
          ["Total", data.detailRows.reduce((s, r) => s + r.newRegistrations, 0), latest.active, latest.inactive, latest.suspended],
        ],
      },
    ],
  });
}''',
))

# h) exportTravellerAccountExcel
replacements.append((
  '''function exportTravellerAccountExcel() {
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
}''',
  '''function exportTravellerAccountExcel() {
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
        ],
      },
      { name: "Monthly Registrations", rows: [["Month", "Registrations"], ...data.months.map((m) => [m.label, m.count])] },
      {
        name: "Account Detail",
        rows: [
          ["Month", "New Registrations", "Active Users", "Inactive Users", "Suspended"],
          ...data.detailRows.map((r) => [r.label, r.newRegistrations, r.active, r.inactive, r.suspended]),
        ],
      },
    ],
  });
}''',
))

for i, (old, new) in enumerate(replacements):
    cnt = content.count(old)
    assert cnt == 1, f"replacement {i} count={cnt}"
    content = content.replace(old, new, 1)

with io.open(path_html, "w", encoding="utf-8") as f:
    f.write(content)

# Sanity: no "twoFactor" or "2FA" references should remain in reports.html at all now.
assert "twoFactor" not in content, "twoFactor reference still present"
assert "2FA" not in content, "2FA reference still present"

print("reports.html patched, new length", len(content))
