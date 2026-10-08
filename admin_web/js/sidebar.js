import { mountIcons } from "./icons.js";
import { logout } from "./auth-guard.js";

const ADMIN_NAV = [
  { key: "overview", label: "Dashboard", icon: "home", href: "overview.html" },
  { key: "users", label: "User Management", icon: "user", href: "users.html" },
  { key: "moderation", label: "Content Moderation", icon: "flag", href: "content-moderation.html" },
  { key: "attractions", label: "Attraction Management", icon: "map-pin", href: "attractions.html" },
  { key: "insurance", label: "Insurance Management", icon: "shield", href: "insurance.html" },
  { key: "reports", label: "Reports", icon: "bar-chart", href: "reports.html" },
  { key: "settings", label: "System Settings", icon: "settings", href: "settings.html" },
];

const PARTNER_NAV = [
  { key: "dashboard", label: "Dashboard", icon: "home", href: "dashboard.html" },
  { key: "plans", label: "Insurance Plans", icon: "briefcase", href: "plans.html" },
  { key: "transactions", label: "Transactions", icon: "swap", href: "transactions.html" },
  { key: "claims", label: "Refunds & Claims", icon: "doc-text", href: "claims.html" },
  { key: "reports", label: "Reports", icon: "bar-chart", href: "reports.html" },
  { key: "organization", label: "Organization Profile", icon: "building", href: "organization.html" },
  { key: "settings", label: "System Settings", icon: "settings", href: "settings.html" },
];

/**
 * Renders the sidebar nav + wires the topbar/logout chrome. Call this
 * IMMEDIATELY at the top of a page's script, before `await requireRole(...)`
 * — `role`/`active` are already known statically (hardcoded per page), so
 * there's no reason the nav should sit empty while the auth round-trip
 * (waitForUser + a Firestore read) is in flight. Only the signed-in user's
 * own name/role label depends on that — see setSidebarUser() below — so
 * splitting the two means the sidebar renders once, correctly, and never
 * visibly changes shape after that (no empty-nav-then-pop-in flash).
 * Expects these ids to exist: sidebar, sidebarNav, sidebarBackdrop,
 * sbUserName, sbUserRole, logoutBtn, menuToggle.
 */
export function mountSidebarNav({ role, active }) {
  const nav = role === "admin" ? ADMIN_NAV : PARTNER_NAV;
  const navEl = document.getElementById("sidebarNav");
  if (navEl) {
    navEl.innerHTML = nav
      .map(
        (item) => `
        <a class="nav-item${item.key === active ? " active" : ""}" href="${item.href}">
          <span data-icon="${item.icon}"></span>${item.label}
        </a>`
      )
      .join("");
  }

  mountIcons(document);

  const sidebar = document.getElementById("sidebar");
  const backdrop = document.getElementById("sidebarBackdrop");
  const menuToggle = document.getElementById("menuToggle");
  const openSidebar = () => {
    sidebar?.classList.add("open");
    backdrop?.classList.add("open");
  };
  const closeSidebar = () => {
    sidebar?.classList.remove("open");
    backdrop?.classList.remove("open");
  };
  menuToggle?.addEventListener("click", openSidebar);
  backdrop?.addEventListener("click", closeSidebar);

  const logoutBtn = document.getElementById("logoutBtn");
  logoutBtn?.addEventListener("click", () => logout("login.html"));
}

/**
 * Fills in the signed-in user's name/role label once requireRole()
 * resolves. Text-only update — the sidebar's shape/nav never changes here,
 * so there's nothing for the user to see "pop in" besides a word or two of
 * text replacing the static "Loading…" placeholder already in the HTML.
 */
export function setSidebarUser({ displayName, roleLabel }) {
  const nameEl = document.getElementById("sbUserName");
  const roleEl = document.getElementById("sbUserRole");
  if (nameEl && displayName) nameEl.textContent = displayName;
  if (roleEl && roleLabel) roleEl.textContent = roleLabel;
}
