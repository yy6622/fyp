import io

content = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Insurance Plan &mdash; Voya Insurance Partner</title>
<link rel="stylesheet" href="../css/tokens.css?v=20261006b" />
<link rel="stylesheet" href="../css/base.css?v=20261006b" />
<link rel="stylesheet" href="../css/layout.css?v=20261111a" />
<link rel="stylesheet" href="../css/components.css?v=20261106g" />
</head>
<body>
<div class="shell">
  <div class="sidebar-backdrop" id="sidebarBackdrop"></div>
  <aside class="sidebar" id="sidebar">
    <img class="sidebar-brand" src="../img/voya-logo-white.png" alt="Voya" />
    <div class="sidebar-user">
      <div class="name" id="sbUserName">Loading&hellip;</div>
      <div class="role" id="sbUserRole">Partner workspace</div>
    </div>
    <nav class="nav" id="sidebarNav"></nav>
    <button class="sidebar-logout" id="logoutBtn"><span data-icon="log-out"></span>Log out</button>
  </aside>

  <main class="content">
    <div class="topbar">
      <div>
        <button class="menu-toggle" id="menuToggle"><span data-icon="menu"></span></button>
        <a href="plans.html" class="inline-flex" id="backLink" style="color:var(--text-500);font-weight:700;font-size:13.5px;margin-bottom:10px;">
          <span data-icon="arrow-left" data-icon-size="14"></span>Back to Insurance Plans
        </a>
        <h1 class="h1" id="pageTitle">Add plan</h1>
        <p class="subtitle" id="pageSubtitle">Create and manage coverage for every journey</p>
      </div>
    </div>

    <div class="dev-tool-bar" id="approvalBar" style="display:none;">
      <span>Your organization is pending approval &mdash; you can't create or edit plans until an admin approves your account.</span>
    </div>

    <div class="dev-tool-bar" id="reviewBar" style="display:none;"></div>

    <div class="card card-pad">
      <div class="form-section">
        <div class="form-section-title"><span data-icon="briefcase"></span>Plan details</div>
        <div class="form-grid">
          <div class="field" style="grid-column:1/-1;"><label>Plan name</label><input class="input" id="fName" placeholder="e.g. Travel Care Premium" /></div>
          <div class="field" style="grid-column:1/-1;">
            <label>Description</label>
            <textarea class="input" id="fDescription" rows="2" placeholder="A short, honest summary a traveller sees before buying &mdash; what this plan is for and who it suits."></textarea>
          </div>
          <div class="field">
            <label>Trip type</label>
            <select class="select" id="fType"><option value="Basic">Basic</option><option value="Annual">Annual</option></select>
            <p class="hint" style="margin:6px 0 0;">Basic covers one trip's dates (priced per day). Annual covers unlimited trips within a year (flat yearly price).</p>
          </div>
          <div class="field">
            <label id="fPremiumLabel">Premium per traveller / day (RM)</label>
            <input class="input" id="fPremium" type="number" placeholder="12" />
          </div>
        </div>
      </div>

      <div class="form-section">
        <div class="form-section-title"><span data-icon="doc-text"></span>App content</div>
        <div class="field" style="margin-bottom:18px;">
          <label>Key coverage</label>
          <div class="chip-picker" id="coveragePresetsList" style="margin-bottom:10px;"></div>
          <div id="coverageItemsList"></div>
        </div>
        <div class="field">
          <label>Highlights</label>
          <div class="chip-picker" id="highlightsPresetsList"></div>
        </div>
      </div>

      <div class="form-section">
        <div class="form-section-title"><span data-icon="shield"></span>Eligibility</div>
        <div class="field" style="margin-bottom:18px;">
          <label>Destinations covered <span style="color:var(--danger-500,#D14343);">*</span></label>
          <p class="hint" style="margin:0 0 8px;">Required &mdash; pick every country this plan covers. Travellers searching a destination not picked here won't see this plan.</p>
          <div class="chip-picker" id="destinationsList"></div>
        </div>
        <div class="field" style="margin-bottom:18px;">
          <label>Eligible nationalities</label>
          <p class="hint" style="margin:0 0 8px;">The traveller's passport/citizenship. Leave all unpicked to allow every nationality.</p>
          <div class="chip-picker" id="eligibleCountriesList"></div>
        </div>
        <div class="field" style="margin-bottom:18px;">
          <label>Eligible residence countries</label>
          <p class="hint" style="margin:0 0 8px;">Where the traveller actually lives &mdash; a different thing from nationality above (e.g. a Malaysian passport holder living in Singapore). Leave all unpicked to allow every residence country.</p>
          <div class="chip-picker" id="residenceCountriesList"></div>
        </div>
        <div class="form-grid" style="margin-bottom:4px;">
          <div class="field">
            <label>Minimum age</label>
            <input class="input" id="fMinAge" type="number" min="0" placeholder="No minimum" />
          </div>
          <div class="field">
            <label>Maximum age</label>
            <input class="input" id="fMaxAge" type="number" min="0" placeholder="No maximum" />
          </div>
          <div class="field">
            <label>Minimum trip length (days)</label>
            <input class="input" id="fMinDuration" type="number" min="1" placeholder="No minimum" />
          </div>
          <div class="field">
            <label>Maximum trip length (days)</label>
            <input class="input" id="fMaxDuration" type="number" min="1" placeholder="No maximum" />
          </div>
        </div>
        <p class="hint">Age is checked against each traveller's date of birth as of their trip's start date. Trip length is mostly meaningful for Basic plans &mdash; leave both blank for no restriction.</p>
      </div>

      <div class="form-section">
        <div class="form-section-title"><span data-icon="clock"></span>Review status</div>
        <div id="statusBlock"></div>
      </div>

      <div class="form-actions" id="formActions">
        <a class="btn btn-outline" id="cancelLink" href="plans.html">Cancel</a>
      </div>
    </div>
  </main>
</div>

<script type="module">
import { requireRole } from "../js/auth-guard.js?v=20261106b";
import { mountSidebarNav, setSidebarUser } from "../js/sidebar.js?v=20261111a";
import { mountIcons } from "../js/icons.js?v=20261106c";
import { getPlan, createPlan, setPlanStatus, sendInsuranceChatPlan, serverTimestamp } from "../js/data.js?v=20261113a";
import { toast, setBusy, escapeHtml, statusBadge, confirmDialog } from "../js/ui.js?v=20261113a";
import { COUNTRY_OPTIONS } from "../js/countries.js?v=20261113a";

mountSidebarNav({ role: "partner", active: "plans" });
const editingId = new URLSearchParams(location.search).get("id");
// Set when this page was opened from a traveller's chat (message-detail.html's
// "+ Create new plan for this traveller" button) instead of from Plans ->
// Add -- on save, the new plan is sent straight into that thread and the
// partner lands back on the conversation instead of the plans list, so a
// bespoke plan for one traveller's requirement doesn't mean losing their
// place in the chat. This path deliberately skips the whole draft ->
// pending_review -> published review workflow below -- it's saved as a
// plain "draft" and sent straight into the chat, because
// InsuranceRepository.getPlan() (which fetches a chat-attached plan) never
// gates on status, same as it never gated on the old "inactive" before
// this review workflow existed. Making the recipient of a one-off quote
// wait on an unrelated admin review would defeat the point of the feature.
const returnChatId = new URLSearchParams(location.search).get("returnChatId");
document.getElementById("pageTitle").textContent = editingId ? "Edit plan" : (returnChatId ? "Create plan for this traveller" : "Add plan");
if (returnChatId) {
  const backHref = `message-detail.html?id=${encodeURIComponent(returnChatId)}`;
  document.getElementById("pageSubtitle").textContent = "This plan will be sent straight into your conversation once saved.";
  document.getElementById("backLink").href = backHref;
  document.getElementById("backLink").lastChild.textContent = "Back to conversation";
  document.getElementById("cancelLink").href = backHref;
}

const session = await requireRole("partner", "login.html");

// Draft state for the modal's repeatable "Key coverage" rows — edited in
// place by renderCoverageItems()'s own listeners, read back into the
// saved doc's `coverageItems` array on Save.
let coverageItemsDraft = [];
// A handful of coverage types almost every travel-insurance plan
// includes — tapping one just adds that label to coverageItemsDraft so
// the partner only has to type the RM amount. Anything not in this list
// is added as a blank custom row via the dashed "+" box at the end of
// the same chip row (mountChipRow below).
const COVERAGE_PRESETS = [
  "Medical Expenses (Overseas)",
  "Medical Expenses (Malaysia)",
  "Emergency Medical Evacuation & Repatriation",
  "Trip Cancellation",
  "Trip Curtailment",
  "Travel Delay Compensation",
  "Baggage Loss or Damage",
  "Personal Accident (Death & Disablement)",
  "Loss of Personal Money/Documents",
  "Personal Liability",
];
// Each one is its own badge on the app's plan detail page
// (InsurancePlan.highlights is a List<String>) -- unlike coverage these
// have no extra amount to fill in, so picking/typing one adds it
// straight away (see mountChipRow below).
const HIGHLIGHT_PRESETS = [
  "24/7 Support", "Cashless Claims", "Worldwide Coverage", "COVID-19 Coverage",
  "Instant Approval", "No Medical Checkup", "Family Discount", "Annual Multi-Trip",
];
let highlightsDraft = [];

// Same canonical list the app's own traveller-details picker uses
// (lib/controllers/insurance_controller.dart's nationalityOptions, minus
// "Other" -- restricting eligibility *to* "other" doesn't mean anything).
const NATIONALITY_OPTIONS = [
  "Malaysian", "Singaporean", "Indonesian", "Thai", "Filipino", "Vietnamese",
  "Bruneian", "Chinese", "Japanese", "South Korean", "Indian", "British",
  "American", "Australian",
];
let eligibleCountriesDraft = [];
let residenceCountriesDraft = [];

// Same real country list the traveller's own destination picker uses
// (InsuranceQuotePage, via lib/data/countries.dart's kCountries) -- now
// shared from js/countries.js so this, partner/register.html and
// partner/organization.html can never drift apart.
const DESTINATION_OPTIONS = COUNTRY_OPTIONS;
let destinationsDraft = [];

// Generic "pick a preset, or type your own" chip row: tap a chip to
// toggle it in `selected`, or type something not in the list into the
// dashed box at the end and press Enter -- used for Highlights and
// Eligible nationalities below (not Key coverage, which needs an RM
// amount per row rather than a plain on/off toggle). Mirrors
// admin/attraction-form.html's mountPresetPicker, minus the
// Firestore-backed shared-preset-list part this doesn't need.
function mountChipRow(boxId, presets, selected, onChange) {
  const box = document.getElementById(boxId);
  function render() {
    const options = [...presets];
    selected.forEach((s) => { if (!options.includes(s)) options.push(s); });
    box.innerHTML = options
      .map((opt) => `<button type="button" class="chip-toggle${selected.includes(opt) ? " active" : ""}" data-tag="${escapeHtml(opt)}">${escapeHtml(opt)}</button>`)
      .join("") + `<span class="chip-picker-add"><input placeholder="+ Add your own…" /></span>`;
    box.querySelectorAll("[data-tag]").forEach((btn) =>
      btn.addEventListener("click", () => {
        const tag = btn.dataset.tag;
        const i = selected.indexOf(tag);
        if (i === -1) selected.push(tag); else selected.splice(i, 1);
        onChange();
        render();
      }));
    const addInput = box.querySelector(".chip-picker-add input");
    addInput.addEventListener("keydown", (e) => {
      if (e.key !== "Enter") return;
      e.preventDefault();
      const value = addInput.value.trim();
      if (!value || selected.includes(value)) return;
      selected.push(value);
      onChange();
      render();
    });
  }
  render();
}

// List-only variant of mountChipRow -- no "+ Add your own" box, so the
// destination can only ever be one of the real countries in `presets`,
// never a free-typed (and possibly wrong/misspelled) one. A destination
// a plan doesn't cover at all simply isn't picked; there's no "custom"
// destination to add.
function mountFixedChipRow(boxId, presets, selected, onChange) {
  const box = document.getElementById(boxId);
  function render() {
    box.innerHTML = presets
      .map((opt) => `<button type="button" class="chip-toggle${selected.includes(opt) ? " active" : ""}" data-tag="${escapeHtml(opt)}">${escapeHtml(opt)}</button>`)
      .join("");
    box.querySelectorAll("[data-tag]").forEach((btn) =>
      btn.addEventListener("click", () => {
        const tag = btn.dataset.tag;
        const i = selected.indexOf(tag);
        if (i === -1) selected.push(tag); else selected.splice(i, 1);
        onChange();
        render();
      }));
  }
  render();
}

function renderDestinations() {
  mountFixedChipRow("destinationsList", DESTINATION_OPTIONS, destinationsDraft, () => {});
}

function renderEligibleCountries() {
  mountChipRow("eligibleCountriesList", NATIONALITY_OPTIONS, eligibleCountriesDraft, () => {});
}

function renderResidenceCountries() {
  mountFixedChipRow("residenceCountriesList", DESTINATION_OPTIONS, residenceCountriesDraft, () => {});
}

function renderHighlights() {
  mountChipRow("highlightsPresetsList", HIGHLIGHT_PRESETS, highlightsDraft, () => {});
}

function renderCoverageItems() {
  const list = document.getElementById("coverageItemsList");
  list.innerHTML = coverageItemsDraft.length
    ? coverageItemsDraft.map((item, i) => `
      <div style="display:flex; gap:8px; align-items:center; margin-bottom:8px;">
        <input class="input" style="flex:2;" placeholder="e.g. Medical Expenses (Overseas)" value="${escapeHtml(item.label || "")}" data-cov-label="${i}" />
        <input class="input" type="number" style="flex:1;" placeholder="RM amount" value="${item.amount ?? ""}" data-cov-amount="${i}" />
        <button type="button" class="btn btn-danger-outline btn-sm" data-cov-remove="${i}"><span data-icon="trash" data-icon-size="14"></span></button>
      </div>`).join("")
    : "";
  list.querySelectorAll("[data-cov-label]").forEach((el) =>
    el.addEventListener("input", (e) => { coverageItemsDraft[Number(el.dataset.covLabel)].label = e.target.value; }));
  list.querySelectorAll("[data-cov-amount]").forEach((el) =>
    el.addEventListener("input", (e) => { coverageItemsDraft[Number(el.dataset.covAmount)].amount = e.target.value; }));
  list.querySelectorAll("[data-cov-remove]").forEach((el) =>
    el.addEventListener("click", () => { coverageItemsDraft.splice(Number(el.dataset.covRemove), 1); renderCoverageItems(); }));
  mountIcons(list);
  renderCoveragePresets();
}

// Same preset-chip-row idea as mountChipRow, but each "chip" here adds a
// label+amount row below instead of just toggling a plain tag -- a
// selected preset shows as a disabled checkmark chip (it's already a row
// below), and the dashed "+" box adds a blank custom row.
function renderCoveragePresets() {
  const list = document.getElementById("coveragePresetsList");
  list.innerHTML = COVERAGE_PRESETS.map((label, i) => {
    const already = coverageItemsDraft.some((it) => (it.label || "").trim().toLowerCase() === label.toLowerCase());
    return `<button type="button" class="chip-toggle${already ? " active" : ""}" data-preset="${i}" ${already ? "disabled" : ""}>${already ? "✓" : "+"} ${escapeHtml(label)}</button>`;
  }).join("") + `<span class="chip-picker-add"><input placeholder="+ Add your own…" id="coverageCustomInput" /></span>`;
  list.querySelectorAll("[data-preset]").forEach((el) =>
    el.addEventListener("click", () => {
      const label = COVERAGE_PRESETS[Number(el.dataset.preset)];
      if (coverageItemsDraft.some((it) => (it.label || "").trim().toLowerCase() === label.toLowerCase())) return;
      coverageItemsDraft.push({ label, amount: "" });
      renderCoverageItems();
    }));
  const customInput = document.getElementById("coverageCustomInput");
  customInput.addEventListener("keydown", (e) => {
    if (e.key !== "Enter") return;
    e.preventDefault();
    const label = customInput.value.trim();
    if (!label || coverageItemsDraft.some((it) => (it.label || "").trim().toLowerCase() === label.toLowerCase())) return;
    coverageItemsDraft.push({ label, amount: "" });
    renderCoverageItems();
  });
}

// Only an approved partner may create/edit a plan — firestore.rules
// enforces this for real (insurance_plans create/update now check the
// partner's own status), this just keeps the UI from offering an action
// that would fail with a permission error (e.g. a direct link to this
// page while still pending).
const isApproved = session?.profile.status === "approved";

if (session) {
  setSidebarUser({ displayName: session.profile.companyName || "Partner", roleLabel: `${session.profile.companyName || "Insurance"} · Insurance Partner` });
  if (!isApproved) {
    document.getElementById("approvalBar").style.display = "flex";
  }
  await load();
}

// Basic plans charge per traveller per day of the actual trip
// (lib/controllers/insurance_controller.dart's PaymentMethodController
// multiplies this by the trip length), so the app's "pay" screen is only
// honest if partners know that's what they're pricing here. Annual plans
// cover unlimited trips within the year, so they stay a flat yearly price.
function updatePremiumLabel() {
  const isAnnual = document.getElementById("fType").value === "Annual";
  document.getElementById("fPremiumLabel").textContent = isAnnual
    ? "Premium per traveller / year (RM)"
    : "Premium per traveller / day (RM)";
}
document.getElementById("fType").addEventListener("change", updatePremiumLabel);

let currentPlan = null;

async function load() {
  const p = editingId ? await getPlan(editingId) : null;
  if (editingId && !p) {
    toast("Couldn't find that plan.", "error");
    location.href = "plans.html";
    return;
  }
  currentPlan = p;
  document.getElementById("fName").value = p?.name || "";
  document.getElementById("fDescription").value = p?.description || "";
  document.getElementById("fType").value = p?.tripType === "Annual" ? "Annual" : "Basic";
  document.getElementById("fPremium").value = p?.premium || "";
  document.getElementById("fMinAge").value = p?.minAge ?? "";
  document.getElementById("fMaxAge").value = p?.maxAge ?? "";
  document.getElementById("fMinDuration").value = p?.minTripDurationDays ?? "";
  document.getElementById("fMaxDuration").value = p?.maxTripDurationDays ?? "";
  updatePremiumLabel();
  coverageItemsDraft = (p?.coverageItems || []).map((it) => ({ label: it.label || "", amount: it.amount ?? "" }));
  renderCoverageItems();
  highlightsDraft = [...(p?.highlights || [])];
  renderHighlights();
  eligibleCountriesDraft = [...(p?.eligibleCountries || [])];
  renderEligibleCountries();
  residenceCountriesDraft = [...(p?.eligibleResidenceCountries || [])];
  renderResidenceCountries();
  destinationsDraft = [...(p?.eligibleDestinations || [])];
  renderDestinations();
  renderStatusAndActions();
  mountIcons(document);
}

/** Builds the "Review status" section and the form's action button(s) --
 * both depend on exactly where this plan currently sits in the
 * draft -> pending_review -> published/rejected -> suspended workflow
 * (see lib/models/insurance_models.dart's InsurancePlanStatus and
 * firestore.rules' insurance_plans rule for the same states enforced
 * server-side). Re-run after every load()/save() so the page always
 * reflects the plan's real current state. */
function renderStatusAndActions() {
  const statusBlock = document.getElementById("statusBlock");
  const actions = document.getElementById("formActions");
  const cancelHtml = `<a class="btn btn-outline" id="cancelLink" href="${returnChatId ? `message-detail.html?id=${encodeURIComponent(returnChatId)}` : "plans.html"}">Cancel</a>`;

  // The one-off chat-plan path never goes through review (see the
  // returnChatId doc comment above) -- a single plain Save button, same
  // as this page behaved before the review workflow existed.
  if (returnChatId) {
    statusBlock.innerHTML = `<p class="muted small">This is a one-off plan for a single traveller's chat -- it's sent directly, without going through admin review.</p>`;
    actions.innerHTML = cancelHtml + `<button class="btn btn-primary" id="saveBtn">Save &amp; send</button>`;
    wireSaveButton("draft");
    if (!isApproved) document.getElementById("saveBtn").style.display = "none";
    return;
  }

  const status = currentPlan?.status || "draft";
  let statusHtml = `<div style="margin-bottom:10px;">${statusBadge(status)}</div>`;
  if (status === "rejected" && currentPlan?.rejectionReason) {
    statusHtml += `<p class="small" style="color:var(--danger-500,#D14343);">${escapeHtml(currentPlan.rejectionReason)}</p>`;
  }
  if (!editingId) {
    statusHtml = `<p class="muted small">Not saved yet -- save as a draft to keep working on it, or submit it straight for review.</p>`;
  } else if (status === "draft") {
    statusHtml += `<p class="muted small">Only you can see this. Submit it for review once it's ready.</p>`;
  } else if (status === "pending_review") {
    statusHtml += `<p class="muted small">An admin is reviewing this plan. Saving keeps it in review.</p>`;
  } else if (status === "published") {
    statusHtml += `<p class="muted small">Live -- travellers can see and buy this plan. Editing it will send it back for re-review before the changes go live.</p>`;
  } else if (status === "suspended") {
    statusHtml += `<p class="muted small">Not visible to travellers right now. Save to resubmit it for review.</p>`;
  }
  statusBlock.innerHTML = statusHtml;

  let buttonsHtml = "";
  if (!editingId || status === "draft" || status === "rejected") {
    buttonsHtml = `<button class="btn btn-outline" id="saveDraftBtn">Save as draft</button><button class="btn btn-primary" id="saveBtn">Submit for review</button>`;
  } else if (status === "pending_review") {
    buttonsHtml = `<button class="btn btn-primary" id="saveBtn">Save changes</button>`;
  } else if (status === "published") {
    buttonsHtml = `<button class="btn btn-danger-outline" id="pauseBtn">Pause this plan</button><button class="btn btn-primary" id="saveBtn">Save changes</button>`;
  } else if (status === "suspended") {
    buttonsHtml = `<button class="btn btn-primary" id="saveBtn">Save &amp; resubmit for review</button>`;
  }
  actions.innerHTML = cancelHtml + buttonsHtml;

  if (!isApproved) {
    actions.querySelectorAll("button:not([data-close])").forEach((b) => { if (b.id !== "cancelLink") b.style.display = "none"; });
    return;
  }

  if (document.getElementById("saveDraftBtn")) wireSaveButton("draft", "saveDraftBtn");
  if (document.getElementById("saveBtn")) {
    const targetStatus = status === "pending_review" ? "pending_review" : (status === "draft" || status === "rejected" || !editingId) ? "pending_review" : status === "published" ? "pending_review" : "pending_review";
    wireSaveButton(targetStatus, "saveBtn", status === "published");
  }
  const pauseBtn = document.getElementById("pauseBtn");
  if (pauseBtn) {
    pauseBtn.addEventListener("click", async () => {
      const ok = await confirmDialog({ title: "Pause this plan?", body: "Travellers won't be able to buy it until you resubmit it for review.", confirmText: "Pause", danger: true });
      if (!ok) return;
      setBusy(pauseBtn, true, "Pausing…");
      try {
        await setPlanStatus(editingId, "suspended", {});
        toast("Plan paused.", "success");
        await load();
      } catch (err) {
        toast(err.message || "Couldn't pause plan.", "error");
        setBusy(pauseBtn, false);
      }
    });
  }
}

function collectFormData() {
  const name = document.getElementById("fName").value.trim();
  if (!name) { toast("Plan name is required.", "error"); return null; }
  const premium = Number(document.getElementById("fPremium").value);
  if (!premium || premium <= 0) { toast("Premium is required and must be more than 0.", "error"); return null; }

  if (!coverageItemsDraft.length) { toast("Add at least one Key coverage item.", "error"); return null; }
  const incompleteCoverage = coverageItemsDraft.some((it) => !(it.label || "").trim() || !(Number(it.amount) > 0));
  if (incompleteCoverage) { toast("Every Key coverage item needs both a label and an RM amount greater than 0.", "error"); return null; }
  const coverageItems = coverageItemsDraft.map((it) => ({ label: it.label.trim(), amount: Number(it.amount) }));

  if (!destinationsDraft.length) { toast("Pick at least one destination this plan covers.", "error"); return null; }

  const minAge = document.getElementById("fMinAge").value !== "" ? Number(document.getElementById("fMinAge").value) : null;
  const maxAge = document.getElementById("fMaxAge").value !== "" ? Number(document.getElementById("fMaxAge").value) : null;
  if (minAge !== null && maxAge !== null && minAge > maxAge) { toast("Minimum age can't be greater than maximum age.", "error"); return null; }
  const minDuration = document.getElementById("fMinDuration").value !== "" ? Number(document.getElementById("fMinDuration").value) : null;
  const maxDuration = document.getElementById("fMaxDuration").value !== "" ? Number(document.getElementById("fMaxDuration").value) : null;
  if (minDuration !== null && maxDuration !== null && minDuration > maxDuration) { toast("Minimum trip length can't be greater than maximum.", "error"); return null; }

  const highlights = [...highlightsDraft];

  const data = {
    name,
    description: document.getElementById("fDescription").value.trim(),
    tripType: document.getElementById("fType").value,
    // The headline coverage figure is always the real sum of the itemized
    // Key coverage list above — never a number typed in separately, so it
    // can never say more (or less) than what's actually covered.
    coverage: coverageItems.reduce((sum, it) => sum + it.amount, 0),
    premium,
    coverageItems,
    highlights,
    eligibleCountries: eligibleCountriesDraft,
    eligibleResidenceCountries: residenceCountriesDraft,
    eligibleDestinations: destinationsDraft,
    minAge, maxAge,
    minTripDurationDays: minDuration, maxTripDurationDays: maxDuration,
    partnerId: session.uid,
    providerName: session.profile.companyName || "Partner",
    // Denormalized from the partner's own profile (Organization Profile
    // page) so the rider's app can show the real logo on plan cards
    // without an extra read per plan — see
    // lib/repositories/insurance_repository.dart's _fromDoc.
    providerLogoUrl: session.profile.logoUrl || "",
  };
  return data;
}

/** Wires a Save button to collect the form, write it with the given
 * target review [status], and navigate away on success -- shared by
 * every button renderStatusAndActions() can show (Save as draft, Submit
 * for review, Save changes, Save & resubmit), so there's exactly one
 * place that actually writes the plan doc. [confirmRepublish] shows a
 * warning dialog first (used only for "Save changes" on an already-
 * published plan, since that one silently un-publishes it). */
function wireSaveButton(status, btnId = "saveBtn", confirmRepublish = false) {
  document.getElementById(btnId).addEventListener("click", async () => {
    const data = collectFormData();
    if (!data) return;
    if (confirmRepublish) {
      const ok = await confirmDialog({
        title: "Save changes?",
        body: "This plan is live. Saving will send it back for admin re-review, and travellers won't see it again until it's re-approved.",
        confirmText: "Save & resubmit", danger: false,
      });
      if (!ok) return;
    }
    const btn = document.getElementById(btnId);
    setBusy(btn, true, "Saving…");
    try {
      if (editingId) {
        await setPlanStatus(editingId, status, data);
        toast(status === "draft" ? "Saved as draft." : "Submitted for review.", "success");
        await load();
      } else {
        const payload = { ...data, status };
        if (status === "pending_review") payload.submittedAt = serverTimestamp();
        const ref = await createPlan(payload);
        if (returnChatId) {
          await sendInsuranceChatPlan(returnChatId, session.uid, { id: ref.id, name: data.name });
          toast("Plan created and sent.", "success");
          location.href = `message-detail.html?id=${encodeURIComponent(returnChatId)}`;
        } else {
          toast(status === "draft" ? "Saved as draft." : "Submitted for review.", "success");
          location.href = "plans.html";
        }
      }
    } catch (err) {
      toast(err.message || "Couldn't save plan.", "error");
      setBusy(btn, false);
    }
  });
}
</script>
</body>
</html>
'''

with io.open("new_plan_form.html", "w", encoding="utf-8") as f:
    f.write(content)

import re
m = re.search(r'<script type="module">(.*)</script>', content, re.S)
js = m.group(1)
print("div open", len(re.findall(r'<div', content)), "div close", len(re.findall(r'</div>', content)))
print("script braces", js.count('{'), js.count('}'))
print("script parens", js.count('('), js.count(')'))
print("script brackets", js.count('['), js.count(']'))
print("backticks", js.count(chr(96)))
