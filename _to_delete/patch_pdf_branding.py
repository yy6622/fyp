import io

# ============================================================
# FILE 1: admin_web/admin/reports.html
# ============================================================
path = "admin_web/admin/reports.html"
with io.open(path, "r", encoding="utf-8") as f:
    content = f.read()

replacements = []

# 1) Add Chart.js CDN tag (right after xlsx)
replacements.append((
  '<script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>\n</head>',
  '<script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>\n<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js"></script>\n</head>',
))

# 2) loadPlatformOverview — add period
replacements.append((
  '''  data = {
    stats: { revenue, policiesSold: paid.length, approvalRate, activeTravellers },
    months, channelEntries, destRows,
  };
}''',
  '''  data = {
    stats: { revenue, policiesSold: paid.length, approvalRate, activeTravellers },
    months, channelEntries, destRows,
    period: { start: monthBounds(5).start, end: new Date() },
  };
}''',
))

# 3) loadInsuranceOperations — add period, claimStatusCounts, avgProcessingDaysAll
replacements.append((
  '''  data = {
    stats: { partners: partners.length, activePlans: activePlans.length, purchases: paid.length, value, pendingClaims, pendingRefunds },
    monthList, providerRows,
  };
}''',
  '''  data = {
    stats: { partners: partners.length, activePlans: activePlans.length, purchases: paid.length, value, pendingClaims, pendingRefunds },
    monthList, providerRows,
    period: { start: monthBounds(months - 1).start, end: new Date() },
    claimStatusCounts: claimCounts,
    avgProcessingDaysAll: avgProcessingDays([...claims, ...refunds]),
  };
}''',
))

# 4) loadCommunityPostAnalysis — add period
replacements.append((
  '''  data = {
    stats: { totalViews, totalUniqueViewers, totalPosts, avgRating },
    monthList, destEntries, detailRows,
    engagement: { viewToUserRatio, totalRatingResponses, reportedPostsCount, topDestination },
  };
}''',
  '''  data = {
    stats: { totalViews, totalUniqueViewers, totalPosts, avgRating },
    monthList, destEntries, detailRows,
    engagement: { viewToUserRatio, totalRatingResponses, reportedPostsCount, topDestination },
    period: { start: monthBounds(months - 1).start, end: new Date() },
  };
}''',
))

# 5) loadTravellerAccountReport — add period
replacements.append((
  '''  data = {
    stats: { totalTravellers, newRegistrationsYtd, activeUsers },
    months, statusEntries, detailRows,
  };
}''',
  '''  data = {
    stats: { totalTravellers, newRegistrationsYtd, activeUsers },
    months, statusEntries, detailRows,
    period: { start: ytdStart, end: now },
  };
}''',
))

# 6) loadPartnerAccountReport — add period
replacements.append((
  '''  data = {
    stats: { totalPartners, newRegistrationsYtd, activePartners },
    months, detailRows,
  };
}''',
  '''  data = {
    stats: { totalPartners, newRegistrationsYtd, activePartners },
    months, detailRows,
    period: { start: ytdStart, end: now },
  };
}''',
))

# 7) exportCommunityPostAnalysisPdf — full rewrite to the branded template
replacements.append((
  '''function exportCommunityPostAnalysisPdf() {
  exportReportPdf({
    filename: `voya-community-post-analysis-${new Date().toISOString().slice(0, 10)}`,
    title: "Community Post Analysis Report",
    subtitle: `As of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}`,
    stats: [
      { label: "Total post views", value: data.stats.totalViews },
      { label: "Unique viewers", value: data.stats.totalUniqueViewers },
      { label: "Published posts", value: data.stats.totalPosts },
      { label: "Average rating", value: data.stats.avgRating ? data.stats.avgRating.toFixed(1) : "—" },
      { label: "View-to-user ratio", value: data.engagement.viewToUserRatio ? data.engagement.viewToUserRatio.toFixed(1) : "—" },
      { label: "Reported posts", value: data.engagement.reportedPostsCount },
      { label: "Top destination", value: data.engagement.topDestination },
    ],
    tables: [
      {
        title: "Community Post Detail",
        head: ["Post title", "Destination", "Total views", "Unique viewers", "Rating", "User reports"],
        body: data.detailRows.map((r) => [r.title, r.destination, r.views, r.uniqueViewers, r.ratingCount ? `${r.avgRating.toFixed(1)} (${r.ratingCount})` : "—", r.reportCount]),
      },
    ],
  });
}''',
  '''function exportCommunityPostAnalysisPdf() {
  exportReportPdf({
    filename: `voya-community-post-analysis-${new Date().toISOString().slice(0, 10)}`,
    title: "Community Post Analysis Report",
    reportCode: "CPAR",
    period: data.period,
    stats: [
      { label: "Total Views", value: number(data.stats.totalViews) },
      { label: "Unique Viewers", value: number(data.stats.totalUniqueViewers) },
      { label: "Total Posts", value: number(data.stats.totalPosts) },
      { label: "Avg. Rating", value: data.stats.avgRating ? data.stats.avgRating.toFixed(1) : "—" },
    ],
    lineChart: {
      title: "Monthly Post Views",
      labels: data.monthList.map((m) => m.label),
      values: data.monthList.map((m) => m.views),
    },
    barChart: {
      title: "Views by Destination",
      labels: data.destEntries.map(([d]) => d),
      values: data.destEntries.map(([, v]) => v),
      horizontal: true,
    },
    table: {
      title: "Community Post Detail",
      head: ["Post title", "Destination", "Total views", "Unique viewers", "Rating", "User reports"],
      body: data.detailRows.map((r) => [r.title, r.destination, number(r.views), number(r.uniqueViewers), r.ratingCount ? `${r.avgRating.toFixed(1)} (${r.ratingCount})` : "—", number(r.reportCount)]),
    },
  });
}''',
))

# 8) exportInsuranceOperationsPdf — full rewrite
replacements.append((
  '''function exportInsuranceOperationsPdf() {
  exportReportPdf({
    filename: `voya-insurance-operations-admin-${new Date().toISOString().slice(0, 10)}`,
    title: "Insurance Operations Report — Administrator View",
    subtitle: `As of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}`,
    stats: [
      { label: "Registered partners", value: data.stats.partners },
      { label: "Active plans", value: data.stats.activePlans },
      { label: "Total purchases", value: data.stats.purchases },
      { label: "Transaction value", value: money(data.stats.value) },
      { label: "Pending reviews", value: data.stats.pendingClaims + data.stats.pendingRefunds },
    ],
    tables: [
      {
        title: "Insurance Provider Summary",
        head: ["Provider", "Active plans", "Purchases", "Value", "Claims", "Refunds", "Avg. processing"],
        body: data.providerRows.map((r) => [r.name, r.activePlans, r.purchases, moneyExact(r.value), r.claims, r.refunds, r.avgDays === null ? "—" : `${r.avgDays.toFixed(1)} days`]),
      },
    ],
  });
}''',
  '''function exportInsuranceOperationsPdf() {
  const totalClaims = data.providerRows.reduce((s, r) => s + r.claims, 0);
  const totalRefunds = data.providerRows.reduce((s, r) => s + r.refunds, 0);
  exportReportPdf({
    filename: `voya-insurance-operations-admin-${new Date().toISOString().slice(0, 10)}`,
    title: "Insurance Operations Report",
    reportCode: "IOR",
    period: data.period,
    stats: [
      { label: "Total Purchases", value: number(data.stats.purchases) },
      { label: "Transaction Value", value: money(data.stats.value) },
      { label: "Pending Claims", value: number(data.stats.pendingClaims) },
      { label: "Pending Refunds", value: number(data.stats.pendingRefunds) },
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
      title: "Insurance Operations Detail",
      head: ["Provider", "Active plans", "Purchases", "Value", "Claims", "Refunds", "Avg. processing"],
      body: data.providerRows.map((r) => [r.name, number(r.activePlans), number(r.purchases), moneyExact(r.value), number(r.claims), number(r.refunds), r.avgDays === null ? "—" : `${r.avgDays.toFixed(1)} days`]),
      totalRow: ["Total", "—", number(data.stats.purchases), moneyExact(data.stats.value), number(totalClaims), number(totalRefunds), data.avgProcessingDaysAll === null ? "—" : `${data.avgProcessingDaysAll.toFixed(1)} days`],
    },
  });
}''',
))

# 9) exportPlatformOverviewPdf — full rewrite
replacements.append((
  '''function exportPlatformOverviewPdf() {
  exportReportPdf({
    filename: `voya-platform-overview-${new Date().toISOString().slice(0, 10)}`,
    title: "Platform Overview Report",
    subtitle: `As of ${new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}`,
    stats: [
      { label: "Revenue", value: money(data.stats.revenue) },
      { label: "Policies sold", value: data.stats.policiesSold },
      { label: "Claims approved", value: `${data.stats.approvalRate}%` },
      { label: "Active travellers", value: data.stats.activeTravellers },
    ],
    tables: [
      {
        title: "Top Destinations",
        head: ["Destination", "Policies", "Revenue", "Share"],
        body: data.destRows.map((r) => [r.dest, r.policies, moneyExact(r.revenue), `${r.share.toFixed(1)}%`]),
      },
      {
        title: "Sales by Channel",
        head: ["Channel", "Policies"],
        body: data.channelEntries.map(([c, v]) => [c, v]),
      },
    ],
  });
}''',
  '''function exportPlatformOverviewPdf() {
  const totalPolicies = data.destRows.reduce((s, r) => s + r.policies, 0);
  const totalRevenue = data.destRows.reduce((s, r) => s + r.revenue, 0);
  exportReportPdf({
    filename: `voya-platform-overview-${new Date().toISOString().slice(0, 10)}`,
    title: "Platform Overview Report",
    reportCode: "POR",
    period: data.period,
    stats: [
      { label: "Revenue", value: money(data.stats.revenue) },
      { label: "Policies Sold", value: number(data.stats.policiesSold) },
      { label: "Claims Approved", value: `${data.stats.approvalRate}%` },
      { label: "Active Travellers", value: number(data.stats.activeTravellers) },
    ],
    lineChart: {
      title: "Revenue Trend",
      labels: data.months.map((m) => m.label),
      values: data.months.map((m) => m.revenue),
    },
    barChart: {
      title: "Sales by Channel",
      labels: data.channelEntries.map(([c]) => c),
      values: data.channelEntries.map(([, v]) => v),
      horizontal: true,
    },
    table: {
      title: "Top Destinations",
      head: ["Destination", "Policies", "Revenue", "Share"],
      body: data.destRows.map((r) => [r.dest, number(r.policies), moneyExact(r.revenue), `${r.share.toFixed(1)}%`]),
      totalRow: ["Total", number(totalPolicies), moneyExact(totalRevenue), "100.0%"],
    },
  });
}''',
))

# 10) exportTravellerAccountPdf — full rewrite
replacements.append((
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
  '''function exportTravellerAccountPdf() {
  const latest = data.detailRows[data.detailRows.length - 1] || { active: 0, inactive: 0, suspended: 0 };
  exportReportPdf({
    filename: `voya-traveller-account-report-${new Date().toISOString().slice(0, 10)}`,
    title: "User Account Report",
    reportCode: "UAR",
    period: data.period,
    stats: [
      { label: "Total Travellers", value: number(data.stats.totalTravellers) },
      { label: "New Registrations", value: number(data.stats.newRegistrationsYtd) },
      { label: "Active Users", value: number(data.stats.activeUsers) },
    ],
    lineChart: {
      title: "Monthly User Registrations",
      labels: data.months.map((m) => m.label.split(" ")[0]),
      values: data.months.map((m) => m.count),
    },
    table: {
      title: "User Account Activity Detail",
      head: ["Month", "New Registrations", "Active Users", "Inactive Users", "Suspended"],
      body: data.detailRows.map((r) => [r.label, number(r.newRegistrations), number(r.active), number(r.inactive), number(r.suspended)]),
      totalRow: ["Total", number(data.detailRows.reduce((s, r) => s + r.newRegistrations, 0)), number(latest.active), number(latest.inactive), number(latest.suspended)],
    },
  });
}''',
))

# 11) exportPartnerAccountPdf — full rewrite (find by reading remaining text)
with io.open(path, "r", encoding="utf-8") as f:
    pass  # body continues below after applying 1-10, then we locate 11/12 fresh

for i, (old, new) in enumerate(replacements):
    cnt = content.count(old)
    assert cnt == 1, f"admin replacement {i} count={cnt}"
    content = content.replace(old, new, 1)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("admin/reports.html pass 1 done, length", len(content))
