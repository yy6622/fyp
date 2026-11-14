import io
path = "admin_web/admin/insurance.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:160]!r}")
    return s.replace(old, new, 1)

old = '''document.getElementById("partnerSearchInput").addEventListener("input", applyPartnerFilters);
document.getElementById("partnerStatusFilter").addEventListener("change", applyPartnerFilters);
</script>'''
new = '''document.getElementById("partnerSearchInput").addEventListener("input", applyPartnerFilters);
document.getElementById("partnerStatusFilter").addEventListener("change", applyPartnerFilters);

// ==================== Plans ====================
// Per-PLAN review queue -- distinct from the Partners tab above, which
// approves the ORGANIZATION itself. A plan only reaches travellers
// (InsuranceRepository.watchPlans()) once it's "published" here; a
// partner can only self-set draft/pending_review/suspended (see
// firestore.rules' insurance_plans rule) -- published/rejected only ever
// come from an admin action on this tab.

function populatePlanPartnerFilter() {
  const select = document.getElementById("planPartnerFilter");
  const names = [...new Set(plans.map((p) => (p.providerName || "").trim()).filter(Boolean))].sort();
  const current = select.value;
  select.innerHTML = '<option value="">All partners</option>' + names.map((n) => `<option value="${escapeHtml(n)}">${escapeHtml(n)}</option>`).join("");
  select.value = names.includes(current) ? current : "";
}

function planPremiumUnit(tripType) {
  return tripType === "Annual" ? "/traveller/yr" : "/traveller/day";
}

function applyPlanFilters() {
  const q = document.getElementById("planSearchInput").value.trim().toLowerCase();
  const status = document.getElementById("planStatusFilter").value;
  const partner = document.getElementById("planPartnerFilter").value;
  planFiltered = plans.filter((p) => {
    const matchesQ = !q || (p.name || "").toLowerCase().includes(q) || (p.providerName || "").toLowerCase().includes(q);
    const effectiveStatus = p.status || "draft";
    const matchesStatus = !status || effectiveStatus === status;
    const matchesPartner = !partner || (p.providerName || "").trim() === partner;
    return matchesQ && matchesStatus && matchesPartner;
  });
  planPage = 1;
  renderPlanTable();
}

/** Row actions for whatever state a plan is currently in -- mirrors
 * renderPartnerTable()'s own status-aware button set above. A plan that's
 * still a "draft" has nothing an admin can do yet (the partner hasn't
 * submitted it), so it shows no action at all here. */
function planRowActions(p) {
  const status = p.status || "draft";
  if (status === "pending_review") {
    return `<button class="btn btn-primary btn-sm" data-publish="${p.id}">Approve</button><button class="btn btn-danger-outline btn-sm" data-reject="${p.id}">Reject</button>`;
  }
  if (status === "published" || status === "active") {
    return `<button class="btn btn-danger-outline btn-sm" data-suspend="${p.id}">Suspend</button>`;
  }
  if (status === "suspended") {
    return `<button class="btn btn-primary btn-sm" data-publish="${p.id}">Publish</button>`;
  }
  return "";
}

function renderPlanTable() {
  const { pageItems, pages, total } = paginate(planFiltered, planPage, PAGE_SIZE);
  const body = document.getElementById("planTableBody");
  const empty = document.getElementById("planEmptyState");
  if (!pageItems.length) { body.innerHTML = ""; empty.style.display = "block"; }
  else {
    empty.style.display = "none";
    body.innerHTML = pageItems.map((p) => `
      <tr style="cursor:pointer;" data-open-plan="${p.id}">
        <td class="cell-strong">${escapeHtml(p.name || "—")}</td>
        <td class="muted">${escapeHtml(p.providerName || "—")}</td>
        <td class="muted">${escapeHtml(p.tripType || "—")}</td>
        <td class="muted">${moneyExact(p.premium)} <span class="small">${planPremiumUnit(p.tripType)}</span></td>
        <td>${statusBadge(p.status || "draft")}</td>
        <td><div class="row-actions">${planRowActions(p)}</div></td>
      </tr>`).join("");
    body.querySelectorAll("[data-open-plan]").forEach((row) => row.addEventListener("click", (e) => {
      if (e.target.closest(".row-actions")) return;
      openPlanDetail(row.dataset.openPlan);
    }));
    body.querySelectorAll("[data-publish]").forEach((b) => b.addEventListener("click", (e) => { e.stopPropagation(); setPlanStatusUi(b.dataset.publish, "published", b); }));
    body.querySelectorAll("[data-suspend]").forEach((b) => b.addEventListener("click", (e) => { e.stopPropagation(); setPlanStatusUi(b.dataset.suspend, "suspended", b); }));
    body.querySelectorAll("[data-reject]").forEach((b) => b.addEventListener("click", (e) => { e.stopPropagation(); setPlanStatusUi(b.dataset.reject, "rejected", b); }));
  }
  document.getElementById("planResultsLabel").textContent = total
    ? `Showing ${(planPage - 1) * PAGE_SIZE + 1} to ${Math.min(planPage * PAGE_SIZE, total)} of ${total} results` : "No results";
  renderPager("planPagination", { page: planPage, pages }, (n) => { planPage = n; renderPlanTable(); });
  mountIcons(document);
}

/** Read-only popup with everything a reviewer needs to actually decide --
 * eligibility rules included, since "does this plan's age/residence/
 * destination coverage make sense" is exactly what review is for, not
 * just "does the premium look reasonable". */
function openPlanDetail(id) {
  const p = plans.find((x) => x.id === id);
  if (!p) return;
  const status = p.status || "draft";
  const coverageHtml = (p.coverageItems || []).length
    ? p.coverageItems.map((it) => `
        <div style="display:flex;justify-content:space-between;gap:12px;padding:4px 0;">
          <span>${escapeHtml(it.label)}</span>
          <span class="cell-strong" style="flex:none;">${moneyExact(it.amount)}</span>
        </div>`).join("")
    : "—";
  const ageRange = (p.minAge || p.maxAge) ? `${p.minAge ?? "0"}–${p.maxAge ?? "no max"}` : "No restriction";
  const durationRange = (p.minTripDurationDays || p.maxTripDurationDays)
    ? `${p.minTripDurationDays ?? "0"}–${p.maxTripDurationDays ?? "no max"} day(s)` : "No restriction";
  const rows = [
    { label: "Partner", value: escapeHtml(p.providerName) },
    { label: "Trip type", value: escapeHtml(p.tripType) },
    { label: "Premium", value: `${moneyExact(p.premium)} ${planPremiumUnit(p.tripType)}` },
    { label: "Description", value: p.description ? escapeHtml(p.description) : "<span class=\\"muted\\">Not provided</span>", block: true },
    { label: "Key coverage", value: coverageHtml, block: true },
    { label: "Destinations covered", value: (p.eligibleDestinations || []).map(escapeHtml).join(", ") || "—" },
    { label: "Eligible nationalities", value: (p.eligibleCountries || []).map(escapeHtml).join(", ") || "Any" },
    { label: "Eligible residence countries", value: (p.eligibleResidenceCountries || []).map(escapeHtml).join(", ") || "Any" },
    { label: "Age eligibility", value: ageRange },
    { label: "Trip duration eligibility", value: durationRange },
    { label: "Status", value: statusBadge(status) },
  ];
  if (status === "rejected" && p.rejectionReason) {
    rows.push({ label: "Rejection reason", value: escapeHtml(p.rejectionReason) });
  }
  const actions = [];
  if (status === "pending_review") {
    actions.push({ text: "Reject", className: "btn-danger-outline", onClick: () => setPlanStatusUi(id, "rejected") });
    actions.push({ text: "Approve", className: "btn-primary", onClick: () => setPlanStatusUi(id, "published") });
  } else if (status === "published" || status === "active") {
    actions.push({ text: "Suspend", className: "btn-danger-outline", onClick: () => setPlanStatusUi(id, "suspended") });
  } else if (status === "suspended") {
    actions.push({ text: "Publish", className: "btn-primary", onClick: () => setPlanStatusUi(id, "published") });
  }
  detailDialog({ title: p.name || "Untitled plan", subtitle: `${p.providerName || "—"} · ${status}`, rows, actions });
}

async function setPlanStatusUi(id, status, btn) {
  let extra = { reviewedBy: session.uid };
  if (status === "suspended") {
    const ok = await confirmDialog({ title: "Suspend this plan?", body: "Travellers won't be able to buy it until it's republished.", confirmText: "Suspend", danger: true });
    if (!ok) return;
    extra = {};
  }
  if (status === "rejected") {
    const result = await promptDialog({
      title: "Reject this plan?",
      body: "The partner will see why and can edit it to resubmit. This can't be undone, but they can try again.",
      label: "Reason (shown to the partner)",
      placeholder: "e.g. Destinations covered doesn't match the policy document provided.",
      confirmText: "Reject", danger: true, required: true,
    });
    if (!result.confirmed) return;
    extra.rejectionReason = result.value;
  }
  setBusy(btn, true, "Working…");
  try {
    await setPlanStatus(id, status, extra);
    const p = plans.find((x) => x.id === id);
    if (p) { p.status = status; if (status === "rejected") p.rejectionReason = extra.rejectionReason; }
    const pendingPlanCount = plans.filter((x) => x.status === "pending_review").length;
    document.getElementById("plansTabDot").style.display = pendingPlanCount ? "" : "none";
    renderStats();
    applyPlanFilters();
    toast(status === "published" ? "Plan published." : status === "rejected" ? "Plan rejected." : "Plan suspended.", "success");
  } catch (err) {
    toast(err.message || "Couldn't update plan.", "error");
    if (btn) setBusy(btn, false);
  }
}

document.getElementById("planSearchInput").addEventListener("input", applyPlanFilters);
document.getElementById("planStatusFilter").addEventListener("change", applyPlanFilters);
document.getElementById("planPartnerFilter").addEventListener("change", applyPlanFilters);
</script>'''
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("step5 ok, len", len(s))
