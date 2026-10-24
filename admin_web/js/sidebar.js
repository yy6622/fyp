import { mountIcons } from "./icons.js";
import { logout } from "./auth-guard.js";
import { countPendingPartners, getPartnerProfile, listReportedPosts, countFlaggedReviews } from "./data.js";
import { auth } from "./firebase-config.js";
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";

const ADMIN_NAV = [
  { key: "overview", label: "Dashboard", icon: "home", href: "overview.html" },
  { key: "users", label: "User Management", icon: "user", href: "users.html" },
  { key: "moderation", label: "Content Moderation", icon: "flag", href: "content-moderation.html" },
  { key: "attractions", label: "Places Management", icon: "map-pin", href: "attractions.html" },
  { key: "emergency", label: "Country Emergency Info", icon: "alert-triangle", href: "country-emergency.html" },
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
        <a class="nav-item${item.key === active ? " active" : ""}" href="${item.href}" data-nav-key="${item.key}">
          <span class="nav-icon-wrap"><span data-icon="${item.icon}"></span><span class="nav-dot" data-nav-dot="${item.key}" style="display:none;"></span></span>${item.label}
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

  // Admin-only: a red dot wherever something is waiting on the admin —
  // same idea as a phone app's notification badge. No separate
  // "Notifications" nav item anymore (removed per the admin's own
  // request — they wanted this surfaced via the Dashboard's bell button,
  // not a dedicated sidebar tab), so the dot lands on the two nav items
  // that actually DO something about it: Dashboard (anything at all —
  // the bell button there is where the admin actually reviews it) and
  // Content Moderation (only the two moderation sources, since that's
  // the page that specifically handles reported posts/reviews). Three
  // independent sources feed this count, same as the Dashboard bell's
  // own tooltip: (1) a new (pending) insurance-partner request, (2) a
  // reported community post, (3) a reported/auto-flagged review.
  // Fire-and-forget: doesn't block the nav from rendering, and fails
  // silently (no badge) rather than breaking the page if one of these
  // reads has a problem.
  if (role === "admin") {
    Promise.all([
      countPendingPartners(),
      listReportedPosts().then((p) => p.length),
      countFlaggedReviews(),
    ])
      .then(([pendingPartners, reportedPosts, flaggedReviews]) => {
        const moderationCount = reportedPosts + flaggedReviews;
        setNavBadge("overview", pendingPartners + moderationCount > 0);
        setNavBadge("moderation", moderationCount > 0);
      })
      .catch(() => {});
  }
  // Partner-only: a red dot on Dashboard whenever their account isn't in
  // good standing (anything other than "approved" — pending review,
  // suspended, rejected, or blocked all have something worth them
  // reading there). No separate "Notifications" nav item on this side
  // either — same change as admin, for the same reason. waitForUser-
  // style one-shot check, not a lasting subscription — mirrors
  // requireRole()'s own pattern in auth-guard.js, kept separate (not
  // imported from there) to avoid a circular import (auth-guard.js
  // already doesn't depend on sidebar.js, and shouldn't start needing to).
  if (role === "partner") {
    const unsub = onAuthStateChanged(auth, async (user) => {
      unsub();
      if (!user) return;
      const profile = await getPartnerProfile(user.uid).catch(() => null);
      if (profile) setNavBadge("dashboard", profile.status !== "approved");
    });
  }
}

/** Shows/hides the small red notification dot on a sidebar nav item by its
 * `key` (same keys as ADMIN_NAV/PARTNER_NAV above). Safe to call before or
 * after mountSidebarNav() — if the dot element isn't in the DOM yet this
 * is just a no-op. */
export function setNavBadge(key, on) {
  const dot = document.querySelector(`[data-nav-dot="${key}"]`);
  if (dot) dot.style.display = on ? "" : "none";
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
