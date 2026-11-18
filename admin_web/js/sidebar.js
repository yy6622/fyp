import { mountIcons } from "./icons.js?v=20261106c";
import { logout } from "./auth-guard.js?v=20261106b";
import { countPendingPartners, getPartnerProfile, listReportedPosts, countFlaggedReviews, countPlaceSuggestions, listInsuranceChats } from "./data.js?v=20261117a";
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

  if (role === "admin" || role === "partner") {
    const userBlock = document.querySelector(".sidebar-user");
    if (userBlock) {
      const profileHref = role === "admin" ? "admin-profile.html" : "organization.html";
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

  if (role === "admin") {
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
      setNavBadge("insurance", pendingPartners > 0);
      const insuranceLink = document.querySelector('[data-nav-key="insurance"]');
      if (insuranceLink) insuranceLink.href = pendingPartners > 0 ? "insurance.html?tab=partners" : "insurance.html";
    });
  }
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

export function setSidebarUser({ displayName, roleLabel }) {
  const nameEl = document.getElementById("sbUserName");
  const roleEl = document.getElementById("sbUserRole");
  if (nameEl && displayName) nameEl.textContent = displayName;
  if (roleEl && roleLabel) roleEl.textContent = roleLabel;
}
