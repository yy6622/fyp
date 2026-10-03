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
