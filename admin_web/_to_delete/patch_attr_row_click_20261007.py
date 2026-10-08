import io

path = "admin_web/admin/attractions.html"
with io.open(path, "r", encoding="utf-8") as f:
    c = f.read()

old = '''    body.innerHTML = pageItems.map((a) => `
      <tr>
        <td class="cell-strong">${escapeHtml(a.name || "—")}</td>
        <td class="muted">${escapeHtml(a.category || "—")}</td>
        <td class="muted">${escapeHtml(a.location || "—")}</td>
        <td class="muted">${shortDate(a.updatedAt)}</td>
        <td>${statusBadge(a.status)}</td>
        <td>
          <div class="row-actions">
            <button class="btn btn-outline btn-sm" data-edit="${a.id}"><span data-icon="edit" data-icon-size="14"></span></button>
            <button class="btn btn-danger-outline btn-sm" data-del="${a.id}"><span data-icon="trash" data-icon-size="14"></span></button>
          </div>
        </td>
      </tr>`).join("");
    body.querySelectorAll("[data-edit]").forEach((b) => b.addEventListener("click", () => {
      location.href = `attraction-form.html?id=${encodeURIComponent(b.dataset.edit)}`;
    }));
    body.querySelectorAll("[data-del]").forEach((b) => b.addEventListener("click", () => remove(b.dataset.del)));'''
n = c.count(old)
assert n == 1, f"anchor count={n}"
new = '''    body.innerHTML = pageItems.map((a) => `
      <tr style="cursor:pointer;" data-open="${a.id}">
        <td class="cell-strong">${escapeHtml(a.name || "—")}</td>
        <td class="muted">${escapeHtml(a.category || "—")}</td>
        <td class="muted">${escapeHtml(a.location || "—")}</td>
        <td class="muted">${shortDate(a.updatedAt)}</td>
        <td>${statusBadge(a.status)}</td>
        <td>
          <div class="row-actions">
            <button class="btn btn-outline btn-sm" data-edit="${a.id}"><span data-icon="edit" data-icon-size="14"></span></button>
            <button class="btn btn-danger-outline btn-sm" data-del="${a.id}"><span data-icon="trash" data-icon-size="14"></span></button>
          </div>
        </td>
      </tr>`).join("");
    // Click anywhere on the row to view/edit this attraction's full detail
    // (attraction-form.html doubles as the detail view) — not just the
    // small edit icon. Clicks inside .row-actions (edit/delete buttons)
    // are excluded so the delete button doesn't also trigger a navigation.
    body.querySelectorAll("[data-open]").forEach((row) => row.addEventListener("click", (e) => {
      if (e.target.closest(".row-actions")) return;
      location.href = `attraction-form.html?id=${encodeURIComponent(row.dataset.open)}`;
    }));
    body.querySelectorAll("[data-edit]").forEach((b) => b.addEventListener("click", () => {
      location.href = `attraction-form.html?id=${encodeURIComponent(b.dataset.edit)}`;
    }));
    body.querySelectorAll("[data-del]").forEach((b) => b.addEventListener("click", () => remove(b.dataset.del)));'''
c = c.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(c)
print("attractions.html row-click patched, new length", len(c))

# ========================================================================
# admin/insurance.html — whole transaction row opens the detail modal
# (previously only the small Reference link did).
# ========================================================================
path = "admin_web/admin/insurance.html"
with io.open(path, "r", encoding="utf-8") as f:
    c = f.read()

old = '''    body.innerHTML = pageItems.map((t) => `
      <tr>
        <td class="cell-strong"><button class="ref-link" data-open-txn="${t.id}">${escapeHtml(t.txnRef || t.id)}</button></td>
        <td>${escapeHtml(t.customerName || "—")}</td>
        <td class="muted">${escapeHtml(t.providerName || "—")}</td>
        <td class="muted">${moneyExact(t.premium)}</td>
        <td>${statusBadge(t.status)}</td>
      </tr>`).join("");
    body.querySelectorAll("[data-open-txn]").forEach((b) => b.addEventListener("click", () => openTxnDetail(b.dataset.openTxn)));'''
n = c.count(old)
assert n == 1, f"insurance.html anchor count={n}"
new = '''    body.innerHTML = pageItems.map((t) => `
      <tr style="cursor:pointer;" data-open-txn="${t.id}">
        <td class="cell-strong"><span class="ref-link">${escapeHtml(t.txnRef || t.id)}</span></td>
        <td>${escapeHtml(t.customerName || "—")}</td>
        <td class="muted">${escapeHtml(t.providerName || "—")}</td>
        <td class="muted">${moneyExact(t.premium)}</td>
        <td>${statusBadge(t.status)}</td>
      </tr>`).join("");
    body.querySelectorAll("[data-open-txn]").forEach((row) => row.addEventListener("click", () => openTxnDetail(row.dataset.openTxn)));'''
c = c.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(c)
print("insurance.html row-click patched, new length", len(c))

# ========================================================================
# admin/content-moderation.html — whole reported-post card opens the
# review modal (previously only the "Review" button did), excluding
# clicks on the Reject/Approve buttons.
# ========================================================================
path = "admin_web/admin/content-moderation.html"
with io.open(path, "r", encoding="utf-8") as f:
    c = f.read()

old = '''  list.innerHTML = filtered.map((p) => `
    <div class="card report-card" style="margin-bottom:16px;">
      <div class="report-thumb" style="${p.images?.[0] ? `background-image:url('${p.images[0]}');background-size:cover;background-position:center;` : ""}"></div>
      <div class="report-body">
        <div class="report-title">${escapeHtml(p.title || "Untitled post")}</div>
        <div class="report-meta">Reported by ${escapeHtml(p.reportedBy || "a traveller")} · ${timeAgo(p.reportedAt)} · ${escapeHtml(p.reportReason || "No reason given")}</div>
        <div class="report-desc">Review the reported content and choose the appropriate action.</div>
      </div>
      <div class="report-actions">
        <button class="btn btn-outline btn-sm" data-review="${p.id}"><span data-icon="eye" data-icon-size="14"></span>Review</button>
        <button class="btn btn-danger-outline btn-sm" data-reject="${p.id}"><span data-icon="x" data-icon-size="14"></span>Reject</button>
        <button class="btn btn-primary btn-sm" data-approve="${p.id}"><span data-icon="check-circle" data-icon-size="14"></span>Approve</button>
      </div>
    </div>`).join("");
  mountIcons(document);
  list.querySelectorAll("[data-review]").forEach((b) => b.addEventListener("click", () => review(b.dataset.review)));
  list.querySelectorAll("[data-reject]").forEach((b) => b.addEventListener("click", () => act("reject", b.dataset.reject, b)));
  list.querySelectorAll("[data-approve]").forEach((b) => b.addEventListener("click", () => act("approve", b.dataset.approve, b)));'''
n = c.count(old)
assert n == 1, f"content-moderation.html anchor count={n}"
new = '''  list.innerHTML = filtered.map((p) => `
    <div class="card report-card" style="margin-bottom:16px;cursor:pointer;" data-open-report="${p.id}">
      <div class="report-thumb" style="${p.images?.[0] ? `background-image:url('${p.images[0]}');background-size:cover;background-position:center;` : ""}"></div>
      <div class="report-body">
        <div class="report-title">${escapeHtml(p.title || "Untitled post")}</div>
        <div class="report-meta">Reported by ${escapeHtml(p.reportedBy || "a traveller")} · ${timeAgo(p.reportedAt)} · ${escapeHtml(p.reportReason || "No reason given")}</div>
        <div class="report-desc">Review the reported content and choose the appropriate action.</div>
      </div>
      <div class="report-actions">
        <button class="btn btn-outline btn-sm" data-review="${p.id}"><span data-icon="eye" data-icon-size="14"></span>Review</button>
        <button class="btn btn-danger-outline btn-sm" data-reject="${p.id}"><span data-icon="x" data-icon-size="14"></span>Reject</button>
        <button class="btn btn-primary btn-sm" data-approve="${p.id}"><span data-icon="check-circle" data-icon-size="14"></span>Approve</button>
      </div>
    </div>`).join("");
  mountIcons(document);
  // Click anywhere on the card to open the review modal — not just the
  // small "Review" button. Clicks inside .report-actions (Review/Reject/
  // Approve) are excluded so they keep their own distinct behavior.
  list.querySelectorAll("[data-open-report]").forEach((card) => card.addEventListener("click", (e) => {
    if (e.target.closest(".report-actions")) return;
    review(card.dataset.openReport);
  }));
  list.querySelectorAll("[data-review]").forEach((b) => b.addEventListener("click", () => review(b.dataset.review)));
  list.querySelectorAll("[data-reject]").forEach((b) => b.addEventListener("click", () => act("reject", b.dataset.reject, b)));
  list.querySelectorAll("[data-approve]").forEach((b) => b.addEventListener("click", () => act("approve", b.dataset.approve, b)));'''
c = c.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(c)
print("content-moderation.html row-click patched, new length", len(c))
