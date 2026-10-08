import io

path = "admin_web/admin/attractions.html"
with io.open(path, "r", encoding="utf-8") as f:
    c = f.read()

# ---- 1. Add the read-only detail modal markup, right after the closing
#      </div> of .shell and before the <script> tag (same placement as
#      insurance.html's #txnModal / content-moderation.html's #reviewModal).
old_markup = '''    <div class="table-foot">
      <p class="small muted" id="resultsLabel"></p>
      <div class="pagination" id="pagination"></div>
    </div>
  </main>
</div>

<script type="module">'''
n = c.count(old_markup)
assert n == 1, f"markup anchor count={n}"
new_markup = '''    <div class="table-foot">
      <p class="small muted" id="resultsLabel"></p>
      <div class="pagination" id="pagination"></div>
    </div>
  </main>
</div>

<div class="modal-backdrop" id="attractionModal">
  <div class="modal" style="max-width:600px;">
    <div class="modal-head"><h3 class="h2">Attraction detail</h3><button class="modal-close" data-close><span data-icon="x"></span></button></div>
    <div id="attractionModalBody"></div>
  </div>
</div>

<script type="module">'''
c = c.replace(old_markup, new_markup, 1)

# ---- 2. Import openModal/closeModal/wireModalDismiss + fullDate alongside
#      the helpers this page already imports from ui.js.
old_import = '''import { number, shortDate, statusBadge, escapeHtml, paginate, renderPager, toast, confirmDialog, statCard, plainCard, trendDelta, countBefore, monthBounds } from "../js/ui.js?v=20261007e";'''
n = c.count(old_import)
assert n == 1, f"import anchor count={n}"
new_import = '''import {
  number, shortDate, fullDate, statusBadge, escapeHtml, paginate, renderPager, toast, confirmDialog,
  statCard, plainCard, trendDelta, countBefore, monthBounds, openModal, closeModal, wireModalDismiss,
} from "../js/ui.js?v=20261007e";'''
c = c.replace(old_import, new_import, 1)

# ---- 3. Wire modal-dismiss (click backdrop / X / Esc to close) once, same
#      spot every other page on this console does it.
old_init = '''if (session) {
  setSidebarUser({ displayName: session.profile.name || "Admin", roleLabel: "Administrator" });
  await load();
}'''
n = c.count(old_init)
assert n == 1, f"init anchor count={n}"
new_init = '''if (session) {
  setSidebarUser({ displayName: session.profile.name || "Admin", roleLabel: "Administrator" });
  wireModalDismiss();
  await load();
}'''
c = c.replace(old_init, new_init, 1)

# ---- 4. Row click now opens the read-only detail popup instead of
#      navigating to attraction-form.html. The small pencil icon
#      (data-edit) is untouched and is still the only way to reach the
#      actual edit form — exactly like insurance.html's Reference link vs.
#      row click, and content-moderation.html's card click vs. its buttons.
old_renderTable = '''    // Click anywhere on the row to view/edit this attraction's full detail
    // (attraction-form.html doubles as the detail view) — not just the
    // small edit icon. Clicks inside .row-actions (edit/delete buttons)
    // are excluded so the delete button doesn't also trigger a navigation.
    body.querySelectorAll("[data-open]").forEach((row) => row.addEventListener("click", (e) => {
      if (e.target.closest(".row-actions")) return;
      location.href = `attraction-form.html?id=${encodeURIComponent(row.dataset.open)}`;
    }));'''
n = c.count(old_renderTable)
assert n == 1, f"renderTable anchor count={n}"
new_renderTable = '''    // Click anywhere on the row to view the attraction's full detail in a
    // popup — not a separate page. Clicks inside .row-actions (the edit
    // pencil / delete trash buttons) are excluded so they keep their own
    // behavior (edit still opens attraction-form.html; delete still deletes).
    body.querySelectorAll("[data-open]").forEach((row) => row.addEventListener("click", (e) => {
      if (e.target.closest(".row-actions")) return;
      openAttractionDetail(row.dataset.open);
    }));'''
c = c.replace(old_renderTable, new_renderTable, 1)

# ---- 5. The detail-popup function itself, plus a helper to render a
#      label/value row (same shape as insurance.html's openTxnDetail).
#      Shows every field a catalog_attractions doc can actually carry (see
#      js/data.js + attraction-form.html), not just what fits the table.
old_remove_fn = '''async function remove(id) {'''
n = c.count(old_remove_fn)
assert n == 1, f"remove() anchor count={n}"
new_detail_fn = '''/** Shows everything we know about one attraction — the table only has
 * room for Attraction/Category/Location/Updated/Status, but a real
 * catalog_attractions doc also carries address, fees, hours, contact
 * details, facilities and highlights — see attraction-form.html. */
function openAttractionDetail(id) {
  const a = items.find((x) => x.id === id);
  if (!a) return;
  const row = (label, value) => `<div class="field" style="margin-bottom:12px;"><label>${label}</label><p class="value">${value}</p></div>`;
  const extraCategories = (a.categories || []).filter((cat) => cat !== (a.category || ""));
  const categoryLine = extraCategories.length
    ? `${escapeHtml(a.category || "—")} <span class="muted small">(+ ${extraCategories.map(escapeHtml).join(", ")})</span>`
    : escapeHtml(a.category || "—");
  const isFree = a.price === "Free entry" || (!a.fees?.adult && !a.fees?.child && !a.fees?.senior && !a.price);
  const feeLine = isFree
    ? "Free entry"
    : [a.fees?.adult && `Adult ${a.fees.adult}`, a.fees?.child && `Child ${a.fees.child}`, a.fees?.senior && `Senior ${a.fees.senior}`].filter(Boolean).join(" · ") || "—";
  document.getElementById("attractionModalBody").innerHTML = `
    ${a.image ? `<img src="${a.image}" style="width:100%;border-radius:12px;margin-bottom:16px;max-height:220px;object-fit:cover;" />` : ""}
    <div class="form-grid">
      ${row("Name", escapeHtml(a.name || "—"))}
      ${row("Status", statusBadge(a.status))}
      ${row("Category", categoryLine)}
      ${row("Location", escapeHtml(a.location || "—"))}
      ${row("Full address", escapeHtml(a.address || "—"))}
      ${row("Recommended duration", escapeHtml(a.recommendedDuration || "—"))}
      ${row("Entry fee", feeLine)}
      ${row("Opening hours", escapeHtml(a.openingHours || "—"))}
      ${row("Phone", escapeHtml(a.phone || "—"))}
      ${row("Website", a.website ? `<a href="${escapeHtml(/^https?:\\/\\//i.test(a.website) ? a.website : `https://${a.website}`)}" target="_blank" rel="noopener">${escapeHtml(a.website)}</a>` : "—")}
      ${row("Rating", a.rating ? `${escapeHtml(String(a.rating))}${a.reviews ? ` <span class="muted small">(${escapeHtml(String(a.reviews))} reviews)</span>` : ""}` : "—")}
      ${row("Facilities", (a.facilities || []).length ? a.facilities.map(escapeHtml).join(", ") : "—")}
      ${row("Highlights", (a.highlights || []).length ? a.highlights.map(escapeHtml).join(", ") : "—")}
      ${row("Last updated", shortDate(a.updatedAt))}
      ${row("Added", fullDate(a.createdAt))}
    </div>
    <div class="form-actions">
      <button class="btn btn-outline" data-modal-edit="${a.id}"><span data-icon="edit" data-icon-size="14"></span>Edit</button>
    </div>`;
  mountIcons(document.getElementById("attractionModalBody"));
  document.getElementById("attractionModalBody").querySelector("[data-modal-edit]").onclick = () => {
    closeModal("attractionModal");
    location.href = `attraction-form.html?id=${encodeURIComponent(a.id)}`;
  };
  openModal("attractionModal");
}

async function remove(id) {'''
c = c.replace(old_remove_fn, new_detail_fn, 1)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(c)
print("attractions.html detail-popup patched, new length", len(c))
