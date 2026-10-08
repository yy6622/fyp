import io

# ============================================================
# FILE 1 continued: admin_web/admin/reports.html
# ============================================================
path = "admin_web/admin/reports.html"
with io.open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_partner_pdf = '''function exportPartnerAccountPdf() {
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
}'''
assert content.count(old_partner_pdf) == 1, f"old_partner_pdf count={content.count(old_partner_pdf)}"

new_partner_pdf = '''function exportPartnerAccountPdf() {
  exportReportPdf({
    filename: `voya-partner-account-report-${new Date().toISOString().slice(0, 10)}`,
    title: "User Account Report",
    reportCode: "UAR",
    period: data.period,
    extraLine: "Account Type: Insurance Partner",
    stats: [
      { label: "Total Insurance Partners", value: number(data.stats.totalPartners) },
      { label: "New Registrations", value: number(data.stats.newRegistrationsYtd) },
      { label: "Active Users", value: number(data.stats.activePartners) },
    ],
    lineChart: {
      title: "Monthly User Registrations",
      labels: data.months.map((m) => m.label.split(" ")[0]),
      values: data.months.map((m) => m.count),
    },
    table: {
      title: "User Account Activity Detail",
      head: ["Month", "New Registrations", "Active", "Inactive", "Rejected"],
      body: data.detailRows.map((r) => [r.label, number(r.newRegistrations), number(r.active), number(r.inactive), number(r.rejected)]),
      totalRow: [
        "Total",
        number(data.detailRows.reduce((s, r) => s + r.newRegistrations, 0)),
        number(data.detailRows.reduce((s, r) => s + r.active, 0)),
        number(data.detailRows.reduce((s, r) => s + r.inactive, 0)),
        number(data.detailRows.reduce((s, r) => s + r.rejected, 0)),
      ],
    },
  });
}'''

content = content.replace(old_partner_pdf, new_partner_pdf, 1)

# Bump cache-busting so every importer re-fetches the changed report-export.js
cnt_v = content.count("?v=20261007")
assert cnt_v > 0, "no ?v=20261007 occurrences found in admin/reports.html"
content = content.replace("?v=20261007", "?v=20261007c")

with io.open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("admin/reports.html pass 2 done, length", len(content), "version bumps:", cnt_v)

# ============================================================
# FILE 2: admin_web/partner/reports.html
# ============================================================
path2 = "admin_web/partner/reports.html"
with io.open(path2, "r", encoding="utf-8") as f:
    content2 = f.read()

reps2 = []

# 1) Add Chart.js CDN tag
reps2.append((
  '<script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>\n</head>',
  '<script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>\n<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js"></script>\n</head>',
))

# 2) data = {...} — add period + claimStatusCounts
reps2.append((
  '  data = { statGrid: { activePlans: activePlans.length, purchases: paid.length, value, pendingClaims, pendingRefunds }, monthList, claims, refunds, planRows, claimRate, refundRate };',
  '''  const periodStart = new Date(now.getFullYear(), now.getMonth() - (months - 1), 1);
  data = {
    statGrid: { activePlans: activePlans.length, purchases: paid.length, value, pendingClaims, pendingRefunds },
    monthList, claims, refunds, planRows, claimRate, refundRate,
    claimStatusCounts: claimCounts,
    period: { start: periodStart, end: now },
  };''',
))

# 3) exportPdfBtn click handler — full rewrite to the branded template
old_handler = '''document.getElementById("exportPdfBtn").addEventListener("click", () => {
  if (!data) return;
  try {
    exportReportPdf({
      filename: `voya-insurance-operations-${new Date().toISOString().slice(0, 10)}`,
      title: "Insurance Operations Report",
      subtitle: `${session.profile.companyName || "Insurance Partner"} · As of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}`,
      stats: [
        { label: "Active plans", value: data.statGrid.activePlans },
        { label: "Total purchases", value: data.statGrid.purchases },
        { label: "Transaction value", value: money(data.statGrid.value) },
        { label: "Pending claims", value: data.statGrid.pendingClaims },
        { label: "Pending refunds", value: data.statGrid.pendingRefunds },
        { label: "Claim approval rate", value: data.claimRate === null ? "\\u2014" : `${data.claimRate}%` },
        { label: "Refund approval rate", value: data.refundRate === null ? "\\u2014" : `${data.refundRate}%` },
      ],
      tables: [
        {
          title: "Insurance Plan Performance",
          head: ["Plan", "State", "Purchases", "Value", "Claims", "Refunds", "Avg. processing"],
          body: data.planRows.map((r) => [r.name, r.state, r.purchases, moneyExact(r.value), r.claims, r.refunds, r.avgDays === null ? "—" : `${r.avgDays.toFixed(1)} days`]),
        },
      ],
    });
  } catch (err) {
    alert(err.message || "Couldn't export PDF.");
  }
});'''
assert content2.count(old_handler) == 1, f"old_handler count={content2.count(old_handler)}"

new_handler = '''document.getElementById("exportPdfBtn").addEventListener("click", () => {
  if (!data) return;
  try {
    const avgDaysAll = avgProcessingDays([...data.claims, ...data.refunds]);
    exportReportPdf({
      filename: `voya-insurance-operations-${new Date().toISOString().slice(0, 10)}`,
      title: "Insurance Operations Report",
      reportCode: "IOR",
      period: data.period,
      extraLine: `Provider: ${session.profile.companyName || "Insurance Partner"}`,
      stats: [
        { label: "Total Purchases", value: number(data.statGrid.purchases) },
        { label: "Transaction Value", value: money(data.statGrid.value) },
        { label: "Pending Claims", value: number(data.statGrid.pendingClaims) },
        { label: "Pending Refunds", value: number(data.statGrid.pendingRefunds) },
      ],
      lineChart: {
        title: "Monthly Insurance Purchases",
        labels: data.monthList.map((m) => m.label),
        values: data.monthList.map((m) => m.count),
      },
      barChart: {
        title: "Claims by Status",
        labels: ["Pending", "In Progress", "Approved", "Rejected"],
        values: data.claimStatusCounts,
        horizontal: true,
      },
      table: {
        title: "Insurance Plan Performance",
        head: ["Insurance Plan", "Purchases", "Value (RM)", "Claims", "Refunds", "Avg. Processing Days"],
        body: data.planRows.map((r) => [r.name, number(r.purchases), moneyExact(r.value), number(r.claims), number(r.refunds), r.avgDays === null ? "—" : `${r.avgDays.toFixed(1)} days`]),
        totalRow: [
          "Total",
          number(data.statGrid.purchases),
          moneyExact(data.statGrid.value),
          number(data.claims.length),
          number(data.refunds.length),
          avgDaysAll === null ? "—" : `${avgDaysAll.toFixed(1)} days`,
        ],
      },
    });
  } catch (err) {
    alert(err.message || "Couldn't export PDF.");
  }
});'''

content2 = content2.replace(old_handler, new_handler, 1)

for i, (old, new) in enumerate(reps2):
    cnt = content2.count(old)
    assert cnt == 1, f"partner replacement {i} count={cnt}"
    content2 = content2.replace(old, new, 1)

cnt_v2 = content2.count("?v=20261007")
assert cnt_v2 > 0, "no ?v=20261007 occurrences found in partner/reports.html"
content2 = content2.replace("?v=20261007", "?v=20261007c")

with io.open(path2, "w", encoding="utf-8") as f:
    f.write(content2)
print("partner/reports.html done, length", len(content2), "version bumps:", cnt_v2)
