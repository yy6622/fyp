import { mountIcons } from "./icons.js?v=20261106c";
import { logout } from "./auth-guard.js?v=20261106b";
import { countPendingPartners, getPartnerProfile, listReportedPosts, countFlaggedReviews, countPlaceSuggestions, listInsuranceChats } from "./data.js?v=20261114c";
import { auth } from "./firebase-config.js?v=20261007";
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";

const ADMIN_NAV = [
  { key: "overview", label: "Dashboard", icon: "home", href: "overview.html" },
  { key: "users", label: "User Management", icon: "user", href: "users.html" },
  { key: "moderation", label: "Content Moderation", icon: "flag", href: "content-moderation.html" },
  { key: "attractions", label: "Places Management", icon: "map-pin", href: "attractions.html" },
  { key: "emergency", label: "Country Emergency Info", icon: "alert-triangle", href: "country-emergency.html" },
  { key: "insurance", label: "Insurance Management", icon: "shield", href: "insurance.html" },
  { key: "transactions", label: "Transactions", icon: "swap", href: "transactions.html" },
  { key: "reports", label: "Reports", icon: "bar-chart", href: "reports.html" },
];

const PARTNER_NAV = [
  { key: "dashboard", label: "Dashboard", icon: "home", href: "dashboard.html" },
  { key: "plans", label: "Insurance Plans", icon: "briefcase", href: "plans.html" },
  { key: "transactions", label: "Transactions", icon: "swap", href: "transactions.html" },
  { key: "claims", label: "Refunds & Claims", icon: "doc-text", href: "claims.html" },
  { key: "messages", label: "Messages", icon: "mail", href: "messages.html" },
  { key: "reports", label: "Reports", icon: "bar-chart", href: "reports.html" },
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

  // Admin-only — clicking the sidebar's own name/role block goes
  // straight to the Admin Profile page (Nov 2026: replaces a separate
  // "Admin Profile" sidebar nav item, which just duplicated this same
  // click target one row down).
  if (role === "admin" || role === "partner") {
    const userBlock = document.querySelector(".sidebar-user");
    if (userBlock) {
      const profileHref = role === "admin" ? "admin-profile.html" : "organization.html";
      // Same "active" treatment as a regular nav-item — admin-profile.html
      // still passes active: "settings" (its old nav key, now repurposed
      // for this), and organization.html passes active: "organization" —
      // this block is each page's only nav entry point now.
      const profileActiveKey = role === "admin" ? "settings" : "organization";
      userBlock.classList.add("sidebar-user--clickable");
      userBlock.title = role === "admin" ? "Admin Profile" : "Organization Profile";
      if (active === profileActiveKey) userBlock.classList.add("active");
      userBlock.addEventListener("click", () => { location.href = profileHref; });
    }
  }

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
  // not a dedicated sidebar tab), so the dot lands on the nav items that
  // actually DO something about each source: Dashboard (anything at all
  // — the bell button there is where the admin actually reviews it),
  // Content Moderation (reported posts/reviews — content people flagged
  // as a problem), and Places Management (traveller-submitted new-place
  // suggestions — these aren't a moderation report, they're a places-
  // catalogue task, so the dot follows the tab that actually handles
  // them, same as the badge itself appearing on that page) -- and also,
  // separately, on Insurance Management itself for the two sources that
  // live entirely inside that page (a pending partner, a plan awaiting
  // review). Five independent sources feed the Dashboard bell's own
  // tooltip count: (1) a new (pending) insurance-partner request, (2) a
  // plan submitted for review, (3) a reported community post, (4) a
  // reported/auto-flagged review, (5) a traveller-submitted new-place
  // suggestion.
  // Fire-and-forget: doesn't block the nav from rendering, and fails
  // silently (no badge) rather than breaking the page if one of these
  // reads has a problem.
  if (role === "admin") {
    // Each count is caught individually (falls back to 0) so one failing
    // source — e.g. countFlaggedReviews() before its collectionGroup
    // rule is deployed — can't silently blank out the whole badge for
    // every OTHER source too, the way a single un-caught Promise.all
    // rejection would.
    Promise.all([
      countPendingPartners().catch(() => 0),
      listReportedPosts().then((p) => p.length).catch(() => 0),
      countFlaggedReviews().catch(() => 0),
      countPlaceSuggestions().catch(() => 0),
    ]).then(([pendingPartners, reportedPosts, flaggedReviews, placeSuggestions]) => {
      const moderationCount = reportedPosts + flaggedReviews;
      setNavBadge("overview", pendingPartners + moderationCount + placeSuggestions > 0);
      setNavBadge("moderation", moderationCount > 0);
      setNavBadge("attractions", placeSuggestions > 0);
      // Plans no longer have a review queue -- they go live the moment
      // the partner saves them -- so this badge now only reflects
      // partner ACCOUNT applications waiting on approval, same source as
      // the Partners tab's own dot.
      setNavBadge("insurance", pendingPartners > 0);
    });
  }
  // Partner-only: a red dot on Dashboard whenever their account isn't in
  // good standing (anything other than "approved" — pending review,
  // suspended, or rejected all have something worth them reading
  // there). No separate "Notifications" nav item on this side
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
      const chats = await listInsuranceChats(user.uid).catch(() => []);
      // A count, not just a yes/no -- "2 travellers are waiting on a
      // reply" is worth knowing before even opening the Messages page.
      setNavBadge("messages", chats.filter((c) => c.unreadForPartner).length);
    });
  }
}

/** Shows/hides the small red notification dot on a sidebar nav item by its
 * `key` (same keys as ADMIN_NAV/PARTNER_NAV above). Safe to call before or
 * after mountSidebarNav() — if the dot element isn't in the DOM yet this
 * is just a no-op. `value` can be a plain boolean (a bare dot, the
 * original behavior) or a number (shows that count inside a slightly
 * bigger dot, "9+" past single digits, hidden entirely at 0). */
export function setNavBadge(key, value) {
  const dot = document.querySelector(`[data-nav-dot="${key}"]`);
  if (!dot) return;
  if (typeof value === "number") {
    const show = value > 0;
    dot.style.display = show ? "flex" : "none";
    dot.classList.toggle("nav-dot--count", show);
    dot.textContent = show ? (value > 9 ? "9+" : String(value)) : "";
  } else {
    dot.style.display = value ? "" : "none";
    dot.classList.remove("nav-dot--count");
    dot.textContent = "";
  }
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
