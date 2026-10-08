// Voya — small shared UI helpers: toasts, a generic confirm/prompt modal,
// and formatting utilities used across every admin/partner page.
import { mountIcons } from "./icons.js";

let toastStack = null;
function ensureStack() {
  if (toastStack) return toastStack;
  toastStack = document.createElement("div");
  toastStack.className = "toast-stack";
  document.body.appendChild(toastStack);
  return toastStack;
}

export function toast(message, type = "default") {
  const stack = ensureStack();
  const el = document.createElement("div");
  el.className = `toast${type !== "default" ? " " + type : ""}`;
  el.textContent = message;
  stack.appendChild(el);
  setTimeout(() => {
    el.style.transition = "opacity .2s ease";
    el.style.opacity = "0";
    setTimeout(() => el.remove(), 220);
  }, 3200);
}

/** Generic confirm modal. Resolves true/false. */
export function confirmDialog({ title, body, confirmText = "Confirm", danger = false }) {
  return new Promise((resolve) => {
    const backdrop = document.createElement("div");
    backdrop.className = "modal-backdrop open";
    backdrop.innerHTML = `
      <div class="modal" role="dialog" aria-modal="true">
        <div class="modal-head">
          <h3 class="h2">${title}</h3>
          <button class="modal-close" data-close><span data-icon="x"></span></button>
        </div>
        <p class="muted" style="font-size:14px;line-height:1.55;">${body}</p>
        <div class="form-actions">
          <button class="btn btn-outline" data-cancel>Cancel</button>
          <button class="btn ${danger ? "btn-danger-outline" : "btn-primary"}" data-confirm>${confirmText}</button>
        </div>
      </div>`;
    document.body.appendChild(backdrop);
    mountIcons(backdrop);
    const close = (val) => {
      backdrop.remove();
      resolve(val);
    };
    backdrop.querySelector("[data-close]").onclick = () => close(false);
    backdrop.querySelector("[data-cancel]").onclick = () => close(false);
    backdrop.querySelector("[data-confirm]").onclick = () => close(true);
    backdrop.addEventListener("click", (e) => {
      if (e.target === backdrop) close(false);
    });
  });
}

export function openModal(id) {
  document.getElementById(id)?.classList.add("open");
}
export function closeModal(id) {
  document.getElementById(id)?.classList.remove("open");
}
export function wireModalDismiss(root = document) {
  root.querySelectorAll(".modal-backdrop").forEach((backdrop) => {
    backdrop.addEventListener("click", (e) => {
      if (e.target === backdrop) backdrop.classList.remove("open");
    });
    backdrop.querySelectorAll("[data-close]").forEach((btn) => {
      btn.addEventListener("click", () => backdrop.classList.remove("open"));
    });
  });
}

export function setBusy(btn, busy, labelBusy = "Please wait…") {
  if (!btn) return;
  if (busy) {
    btn.dataset.label = btn.dataset.label || btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = `<span class="spinner"></span> ${labelBusy}`;
  } else {
    btn.disabled = false;
    if (btn.dataset.label) btn.innerHTML = btn.dataset.label;
  }
}

// ---------------- Formatters ----------------
export function money(n) {
  const num = Number(n) || 0;
  if (Math.abs(num) >= 1_000_000) return `RM ${(num / 1_000_000).toFixed(1)}M`;
  if (Math.abs(num) >= 1_000) return `RM ${num.toLocaleString("en-MY", { maximumFractionDigits: 0 })}`;
  return `RM ${num.toLocaleString("en-MY", { maximumFractionDigits: 2 })}`;
}
export function moneyExact(n) {
  return `RM ${(Number(n) || 0).toLocaleString("en-MY", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}
export function number(n) {
  return (Number(n) || 0).toLocaleString("en-MY");
}
export function shortDate(d) {
  if (!d) return "—";
  const date = d.toDate ? d.toDate() : new Date(d);
  if (isNaN(date)) return "—";
  return date.toLocaleDateString("en-MY", { day: "numeric", month: "short" });
}
export function fullDate(d) {
  if (!d) return "—";
  const date = d.toDate ? d.toDate() : new Date(d);
  if (isNaN(date)) return "—";
  return date.toLocaleDateString("en-MY", { day: "numeric", month: "short", year: "numeric" });
}
export function timeAgo(d) {
  if (!d) return "—";
  const date = d.toDate ? d.toDate() : new Date(d);
  if (isNaN(date)) return "—";
  const secs = Math.max(0, (Date.now() - date.getTime()) / 1000);
  if (secs < 60) return "just now";
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  return `${Math.floor(secs / 86400)}d ago`;
}
export function initials(name) {
  const parts = (name || "").trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "?";
  return (parts[0][0] + (parts[1]?.[0] || "")).toUpperCase();
}

const STATUS_BADGE = {
  active: "green", approved: "green", paid: "green", "in force": "green",
  pending: "amber", "under review": "amber", "under_review": "amber", draft: "amber", new: "blue",
  suspended: "red", rejected: "red", removed: "red",
};
export function statusBadge(status) {
  const key = (status || "").toLowerCase().replace(/_/g, " ");
  const tone = STATUS_BADGE[key] || "gray";
  const label = key.replace(/\b\w/g, (c) => c.toUpperCase());
  return `<span class="badge badge-${tone}">${label || "—"}</span>`;
}

export function escapeHtml(str) {
  return String(str ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

/** Very small client-side paginator for an already-loaded array. */
export function paginate(items, page, pageSize) {
  const total = items.length;
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const safePage = Math.min(Math.max(1, page), pages);
  const start = (safePage - 1) * pageSize;
  return { pageItems: items.slice(start, start + pageSize), page: safePage, pages, total };
}

/**
 * Renders a pager into #<containerId>: prev/next arrows plus up to
 * `windowSize` page-number buttons (default 5), sliding so the current page
 * stays roughly centered instead of listing every page — a list with 26
 * pages only ever shows 5 numbers at once, not all 26. `onPage(n)` is
 * called with the target page when a number or an arrow is clicked; the
 * caller re-renders (table + pager) from there, same as before this existed.
 */
export function renderPager(containerId, { page, pages }, onPage, windowSize = 5) {
  const pager = document.getElementById(containerId);
  if (!pager) return;
  let start = Math.max(1, page - Math.floor(windowSize / 2));
  let end = Math.min(pages, start + windowSize - 1);
  start = Math.max(1, end - windowSize + 1);

  let html = `<button class="page-btn" data-page="prev" ${page === 1 ? "disabled" : ""}><span data-icon="chevron-left" data-icon-size="14"></span></button>`;
  for (let i = start; i <= end; i++) html += `<button class="page-btn${i === page ? " active" : ""}" data-page="${i}">${i}</button>`;
  html += `<button class="page-btn" data-page="next" ${page === pages ? "disabled" : ""}><span data-icon="chevron-right" data-icon-size="14"></span></button>`;
  pager.innerHTML = html;

  pager.querySelectorAll("[data-page]").forEach((b) => b.addEventListener("click", () => {
    const v = b.dataset.page;
    if (v === "prev") { if (page > 1) onPage(page - 1); }
    else if (v === "next") { if (page < pages) onPage(page + 1); }
    else onPage(Number(v));
  }));
  mountIcons(pager);
}

/**
 * Renders a dependency-free horizontal grouped-bar comparison chart into
 * #<containerId> — no chart library, just divs sized by percentage. `rows`
 * is [{ label, values: [n1, n2, ...] }], one entry per category (e.g. a
 * status); `series` is [{ label, color }] in the same order as each row's
 * `values` (e.g. Claims vs Refunds). All bars share one scale (the max
 * value across every row/series) so lengths stay comparable at a glance.
 * Used by the Report Design pages (admin/reports.html, partner/reports.html)
 * for things like "claims vs refunds by status" — a plain bar chart would
 * need a library this no-build-step project doesn't have; this is the
 * lightest thing that still reads as a chart.
 */
// ---------------- Real "vs last month" stat-card deltas ----------------
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

export function renderComparisonBars(containerId, rows, series) {
  const el = document.getElementById(containerId);
  if (!el) return;
  if (!rows.length) {
    el.innerHTML = `<p class="muted small" style="padding:20px 0;">No data yet.</p>`;
    return;
  }
  const max = Math.max(1, ...rows.flatMap((r) => r.values));
  const legend = series.map((s) => `
    <span style="display:inline-flex;align-items:center;gap:6px;">
      <span style="width:10px;height:10px;border-radius:3px;background:${s.color};display:inline-block;"></span>${escapeHtml(s.label)}
    </span>`).join("");
  const body = rows.map((r) => `
    <div style="margin-bottom:14px;">
      <p class="small muted" style="margin-bottom:6px;">${escapeHtml(r.label)}</p>
      ${r.values.map((v, i) => `
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px;">
          <div style="flex:1;background:#eef1f3;border-radius:6px;overflow:hidden;height:14px;">
            <div style="height:100%;width:${Math.max(0, (v / max) * 100)}%;background:${series[i]?.color || "#888"};border-radius:6px;"></div>
          </div>
          <span class="small" style="width:30px;text-align:right;">${number(v)}</span>
        </div>`).join("")}
    </div>`).join("");
  el.innerHTML = `<div style="display:flex;gap:16px;margin-bottom:14px;font-size:12px;">${legend}</div>${body}`;
}
