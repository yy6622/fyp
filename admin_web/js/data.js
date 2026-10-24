// Voya — Firestore data-access layer shared by every admin & partner page.
// Existing collections (users, posts, catalog_attractions) are the SAME ones
// the Flutter app reads/writes — changes here are real and show up there too.
// New collections (admins, insurance_partners, insurance_plans, claims,
// insurance_transactions) exist only for this console.
import { db, storage } from "./firebase-config.js";
import {
  collection, collectionGroup, doc, getDoc, getDocs, addDoc, updateDoc, deleteDoc,
  setDoc, query, where, limit, serverTimestamp, deleteField, increment,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";
import {
  ref as storageRef, uploadBytes, getDownloadURL, deleteObject,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-storage.js";

const col = (name) => collection(db, name);

function refCode(prefix, digits = 5) {
  const n = Math.floor(Math.random() * 9 * 10 ** (digits - 1)) + 10 ** (digits - 1);
  return `${prefix}-${n}`;
}
export function newClaimRef() {
  return `CLM-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 90000) + 10000)}`;
}
export function newRefundRef() {
  return `RFD-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 90000) + 10000)}`;
}
export function newTxnRef() {
  return refCode("TXN");
}

async function all(q) {
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

// ==================== USERS (users/{uid}) ====================
// Sorted client-side rather than with orderBy("createdAt") — Firestore's
// orderBy silently drops any doc that's missing that field, and a handful
// of accounts may predate it being set on every signup.
export async function listUsers() {
  const items = await all(query(col("users")));
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
export async function setUserRoleStatus(uid, { role, status }) {
  const patch = {};
  if (role !== undefined) patch.role = role;
  if (status !== undefined) patch.status = status;
  await updateDoc(doc(db, "users", uid), patch);
}

// ==================== ADMINS (admins/{uid}) ====================
export async function isFirstAdminNeeded() {
  const snap = await getDocs(query(col("admins"), limit(1)));
  return snap.empty;
}
export async function listAdmins() {
  const items = await all(query(col("admins")));
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}

// ==================== INSURANCE PARTNERS (insurance_partners/{uid}) ====================
export async function getPartnerProfile(uid) {
  const snap = await getDoc(doc(db, "insurance_partners", uid));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
export async function savePartnerProfile(uid, data) {
  await setDoc(doc(db, "insurance_partners", uid), { ...data, updatedAt: serverTimestamp() }, { merge: true });
}
export async function listPartners() {
  const items = await all(query(col("insurance_partners")));
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
/**
 * `extra` is for anything a specific transition wants to attach (e.g.
 * { rejectionReason } when rejecting — see admin/insurance.html and
 * admin/insurance-partners.html). rejectedAt/blockedAt are stamped here,
 * not by the caller, so every reject/approve goes through the same
 * timestamp logic no matter which page triggered it:
 * - rejected → stamps rejectedAt (requireRole()'s auto-block check in
 *   auth-guard.js reads this to compute the 30-day countdown).
 * - approved → clears rejectionReason/rejectedAt/blockedAt, so a partner
 *   who gets re-approved after a rejection (or even after being
 *   auto-blocked) doesn't carry stale rejection data forward.
 */
export async function setPartnerStatus(uid, status, extra = {}) {
  const payload = { status, ...extra };
  if (status === "rejected") {
    payload.rejectedAt = serverTimestamp();
  } else if (status === "approved") {
    payload.approvedAt = serverTimestamp();
    payload.rejectionReason = deleteField();
    payload.rejectedAt = deleteField();
    payload.blockedAt = deleteField();
  }
  await updateDoc(doc(db, "insurance_partners", uid), payload);
}
/** Pending-partner count for the sidebar notification dot — "pending" or
 * no status at all (a brand-new self-registration hasn't necessarily had
 * the field set client-side the instant it lands, though registerWithRole
 * always does; kept as a defensive fallback matching renderPartners()'s
 * own `status === "pending" || !status` filter elsewhere). */
export async function countPendingPartners() {
  const items = await listPartners();
  return items.filter((p) => p.status === "pending" || !p.status).length;
}

// ==================== INSURANCE PLANS (insurance_plans/{id}) ====================
export async function listPlans(partnerId = null) {
  const q = partnerId
    ? query(col("insurance_plans"), where("partnerId", "==", partnerId))
    : query(col("insurance_plans"));
  const items = await all(q);
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
export async function createPlan(data) {
  return addDoc(col("insurance_plans"), { ...data, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
}
export async function updatePlan(id, data) {
  await updateDoc(doc(db, "insurance_plans", id), { ...data, updatedAt: serverTimestamp() });
}
export async function deletePlan(id) {
  await deleteDoc(doc(db, "insurance_plans", id));
}

// ==================== TRANSACTIONS (insurance_transactions/{id}) ====================
export async function listTransactions(partnerId = null) {
  const q = partnerId
    ? query(col("insurance_transactions"), where("partnerId", "==", partnerId))
    : query(col("insurance_transactions"));
  const items = await all(q);
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
export async function createTransaction(data) {
  return addDoc(col("insurance_transactions"), { ...data, createdAt: serverTimestamp() });
}
export async function updateTransactionStatus(id, status) {
  await updateDoc(doc(db, "insurance_transactions", id), { status });
}

// ==================== CLAIMS (claims/{id}) ====================
export async function listClaims(partnerId = null) {
  const q = partnerId ? query(col("claims"), where("partnerId", "==", partnerId)) : query(col("claims"));
  const items = await all(q);
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
export async function getClaim(id) {
  const snap = await getDoc(doc(db, "claims", id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
export async function createClaim(data) {
  return addDoc(col("claims"), {
    ...data,
    claimRef: data.claimRef || newClaimRef(),
    timeline: data.timeline || [{ status: "new", at: new Date().toISOString(), note: "Claim submitted" }],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}
export async function updateClaimStatus(id, status, note = "") {
  const current = await getClaim(id);
  const timeline = [...(current?.timeline || []), { status, at: new Date().toISOString(), note }];
  await updateDoc(doc(db, "claims", id), { status, timeline, updatedAt: serverTimestamp() });
}

// ==================== REFUNDS (refunds/{id}) — distinct from claims ====================
// A refund (premium refund, cancellation refund, duplicate payment, ...) is
// its own thing, not a claim against a policy — kept in its own collection
// so claim and refund counts/approval rates can be reported on separately.
// Same shape/lifecycle as claims above.
export async function listRefunds(partnerId = null) {
  const q = partnerId ? query(col("refunds"), where("partnerId", "==", partnerId)) : query(col("refunds"));
  const items = await all(q);
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
export async function getRefund(id) {
  const snap = await getDoc(doc(db, "refunds", id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
export async function createRefund(data) {
  return addDoc(col("refunds"), {
    ...data,
    refundRef: data.refundRef || newRefundRef(),
    timeline: data.timeline || [{ status: "new", at: new Date().toISOString(), note: "Refund requested" }],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}
export async function updateRefundStatus(id, status, note = "") {
  const current = await getRefund(id);
  const timeline = [...(current?.timeline || []), { status, at: new Date().toISOString(), note }];
  await updateDoc(doc(db, "refunds", id), { status, timeline, updatedAt: serverTimestamp() });
}

// ==================== ATTRACTIONS (catalog_attractions/{id}) — shared w/ mobile app ====================
// Field names here match lib/models/explore_models.dart's AttractionData /
// lib/repositories/catalog_repository.dart exactly, so what's saved here is
// what Explore actually reads (categories[], openingHoursByDay{}, facilities[],
// highlights[], images[], fees{adult,child,senior}, etc.) — not a console-only
// shape. `status` is the one field the mobile app does NOT read (Explore
// shows every doc in this collection regardless); it's kept here purely so
// the admin table can filter/tag rows.
export async function listAttractions() {
  return all(query(col("catalog_attractions")));
}
/** Single attraction by id — used by the Edit path of admin/attraction-form.html. */
export async function getAttraction(id) {
  const snap = await getDoc(doc(db, "catalog_attractions", id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
/** Pre-allocates a Firestore doc ref so its id is known before images upload. */
export function newAttractionRef() {
  return doc(col("catalog_attractions"));
}
export async function createAttraction(ref, data) {
  await setDoc(ref, {
    ...data,
    favoritedBy: [],
    status: data.status || "active",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return ref;
}
export async function updateAttraction(id, data) {
  await updateDoc(doc(db, "catalog_attractions", id), { ...data, updatedAt: serverTimestamp() });
}
export async function deleteAttraction(id) {
  await deleteDoc(doc(db, "catalog_attractions", id));
}
/** Uploads one picked image file under attraction_images/{attractionId}/… and returns its download URL. */
export async function uploadAttractionImage(attractionId, file, index = 0) {
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `attraction_images/${attractionId}/${Date.now()}_${index}_${safeName}`;
  const ref = storageRef(storage, path);
  await uploadBytes(ref, file);
  return getDownloadURL(ref);
}
/** Best-effort delete of a previously-uploaded attraction image (ignores errors — e.g. already gone). */
export async function deleteAttractionImage(url) {
  if (!url) return;
  try {
    await deleteObject(storageRef(storage, url));
  } catch (e) {
    debugIgnore(e);
  }
}
function debugIgnore(e) {
  // Swallow: the image may already be deleted, or the URL may not be a
  // Storage ref (e.g. a seeded Unsplash URL) — neither should block saving.
}

// ==================== CATALOG RESTAURANTS ====================
// Originally restaurants had no admin CRUD equivalent of
// listAttractions()/admin/attractions.html, since they have no
// curated-collection source like catalog_places (see
// lib/repositories/catalog_repository.dart) — admin/attractions.html (now
// a tabbed "Places Management" page) and admin/restaurant-form.html added
// that below, for the same reason attractions got one: an admin needs to
// add/fix a restaurant by hand sometimes, not just wait for the next live
// OSM refresh or bulk import.
// (Also used to back admin/translate-names.html, a one-click
// name-translation backfill tool — removed once the backfill finished; the
// name-translation logic itself stays live in
// lib/services/name_translation_service.dart +
// lib/repositories/catalog_repository.dart, which keeps auto-translating
// any new non-English name a future catalog refresh picks up.)
export async function listAllRestaurants() {
  return all(query(col("catalog_restaurants")));
}
/** Single restaurant by id — used by the Edit path of admin/restaurant-form.html. */
export async function getRestaurant(id) {
  const snap = await getDoc(doc(db, "catalog_restaurants", id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
/** Pre-allocates a Firestore doc ref so its id is known before save. */
export function newRestaurantRef() {
  return doc(col("catalog_restaurants"));
}
/** Writes admin/restaurant-form.html's fields in the SAME camelCase
 * convention lib/repositories/catalog_repository.dart's live-refresh path
 * (`_refreshRestaurants`) already writes — name/cuisineTags/location/
 * priceRange/openingHours/image/description — so a restaurant added or
 * edited here is read by watchRestaurants() exactly like one the app
 * found on OpenStreetMap, with no snake_case/GeoPoint quirks (see that
 * file's big comment on catalog_restaurants' two writer conventions). */
export async function createRestaurant(ref, data) {
  await setDoc(ref, {
    ...data,
    favoritedBy: [],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return ref;
}
export async function updateRestaurant(id, data) {
  await updateDoc(doc(db, "catalog_restaurants", id), { ...data, updatedAt: serverTimestamp() });
}
export async function deleteRestaurant(id) {
  await deleteDoc(doc(db, "catalog_restaurants", id));
}

// ==================== CONTENT MODERATION (posts/{id}) — shared w/ mobile app ====================
export async function listReportedPosts() {
  return all(query(col("posts"), where("reported", "==", true)));
}
export async function listAllPosts() {
  const items = await all(query(col("posts")));
  return items.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
export async function approvePostReport(postId) {
  await updateDoc(doc(db, "posts", postId), {
    reported: false, reportReason: deleteField(), reportedBy: deleteField(), reportedAt: deleteField(),
    // Also clears the AI content-filter hold (see
    // CommunityRepository.createPost / watchPosts in the Flutter app) —
    // without this, an approved post that was auto-flagged would stay
    // invisible to everyone but its author forever, even after approval.
    // Harmless no-op field delete on a post that was never auto-flagged.
    autoFlagged: deleteField(),
  });
}
export async function rejectPost(postId) {
  await deleteDoc(doc(db, "posts", postId));
}

// ==================== REPORTED REVIEWS (collectionGroup "reviews") ====================
// A review is reported the same way a whole post is (see
// review_helpers.dart's addReviewFor on the Flutter side), but it lives in
// a `reviews` subcollection under a catalog_hotels/catalog_restaurants/
// catalog_attractions/posts doc rather than being a top-level doc itself —
// a collectionGroup query is the only way to find every flagged one at
// once across all four parent collection types. Needs firestore.rules'
// per-collection `match /reviews/{reviewId}` admin bypass on update/delete
// (added alongside this feature) deployed before approve/reject will work.
export async function listFlaggedReviews() {
  const snap = await getDocs(query(collectionGroup(db, "reviews"), where("reported", "==", true)));
  return Promise.all(
    snap.docs.map(async (d) => {
      const parentRef = d.ref.parent.parent; // the hotel/restaurant/attraction/post doc this review is under
      const parentCollection = parentRef?.parent?.id || "";
      let parentName = "Unknown";
      if (parentRef) {
        try {
          const parentSnap = await getDoc(parentRef);
          const pd = parentSnap.exists() ? parentSnap.data() : null;
          parentName = pd?.name || pd?.title || "Untitled";
        } catch (_) {
          // Deleted/unreadable parent (e.g. the hotel/post was since
          // removed) — still show the review itself, just without context.
        }
      }
      return { id: d.id, ref: d.ref, parentRef, parentCollection, parentName, ...d.data() };
    })
  );
}
/** Cheap count for the sidebar notification dot — just `snap.size`, no
 * per-review parent-doc lookups (those are only needed to *display* a
 * review, in listFlaggedReviews() above; the dot only needs a number, and
 * this runs on every admin page load via mountSidebarNav()). */
export async function countFlaggedReviews() {
  const snap = await getDocs(query(collectionGroup(db, "reviews"), where("reported", "==", true)));
  return snap.size;
}

/** Clears the report/auto-flag fields on a review doc, and finishes the
 * rating-average write addReviewFor (Flutter side) deliberately deferred
 * for a flagged review: bumps ratingSum/ratingCount on the parent for a
 * hotel/restaurant/attraction, or sets ratings.<uid> directly for a
 * community post (posts track their average through a per-uid map, not a
 * summed pair — same split the Flutter addReviewFor/addReview already
 * make on write). [review] is one entry from listFlaggedReviews(). */
export async function approveReview(review) {
  await updateDoc(review.ref, {
    reported: false, reportReason: deleteField(), reportedBy: deleteField(), reportedAt: deleteField(),
    autoFlagged: deleteField(),
  });
  if (!review.parentRef) return;
  if (review.parentCollection === "posts") {
    await updateDoc(review.parentRef, { [`ratings.${review.authorId}`]: review.rating });
  } else {
    await updateDoc(review.parentRef, { ratingSum: increment(review.rating || 0), ratingCount: increment(1) });
  }
}

/** Deletes the review outright. No aggregate "undo" needed on the parent
 * — a flagged review's rating was never bumped into its average in the
 * first place (see addReviewFor's doc comment), so rejecting it just
 * removes the review doc, nothing more. */
export async function rejectReview(review) {
  await deleteDoc(review.ref);
}

// ==================== COMMUNITY POST ANALYSIS (posts/{id}, post_view_stats/{YYYY-MM}) ====================
// Backs admin/reports.html's Community Post Analysis Report. listAllPosts()
// above already returns every post with its viewCount/uniqueViewerCount/
// reportCount fields (see CommunityRepository.recordView/reportPost on the
// Flutter side) — the two functions below cover what that alone can't:
// the monthly trend (a separate small aggregate collection, since a post's
// current viewCount has no history) and the platform-wide unique-viewer
// count (a post's own uniqueViewerCount is per-post; a traveller who
// viewed 3 posts should only count once overall).
export async function listPostViewStats() {
  return all(query(col("post_view_stats")));
}
/** One entry per (postId, uid) view-ever pair, collectionGroup'd across
 * every posts/{id}/viewers subcollection — the caller dedupes by uid
 * (returned as each entry's doc id) to get the platform-wide unique-
 * viewer count. Not scoped to a single post; see listAllPosts() for
 * each post's own uniqueViewerCount instead. */
export async function listPostViewers() {
  const snap = await getDocs(collectionGroup(db, "viewers"));
  return snap.docs.map((d) => ({ id: d.id, firstViewedAt: d.data().firstViewedAt || null }));
}

/** Small audit trail so "Approved today" / "Rejected today" are real counts. */
export async function logModerationAction(action, postId, adminUid) {
  await addDoc(col("moderation_log"), { action, postId, adminUid, at: serverTimestamp() });
}
function dayBounds(daysAgo = 0) {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - daysAgo);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { start, end };
}
async function countModerationInRange(action, start, end) {
  const items = await all(query(col("moderation_log"), where("action", "==", action)));
  return items.filter((i) => {
    const t = i.at?.toDate ? i.at.toDate().getTime() : null;
    return t !== null && t >= start.getTime() && t < end.getTime();
  }).length;
}
export async function countModerationToday(action) {
  const { start, end } = dayBounds(0);
  return countModerationInRange(action, start, end);
}
/** Same day-before window, for a real "vs yesterday" delta instead of a
 * hardcoded percentage on the Content Moderation stat cards. */
export async function countModerationYesterday(action) {
  const { start, end } = dayBounds(1);
  return countModerationInRange(action, start, end);
}

// ==================== DASHBOARD AGGREGATES ====================
export async function loadAdminOverviewData() {
  const [users, attractions, plans, claims, txns] = await Promise.all([
    listUsers(), listAttractions(), listPlans(), listClaims(), listTransactions(),
  ]);
  return { users, attractions, plans, claims, txns };
}

// ==================== COUNTRY EMERGENCY INFO (country_emergency_info/{countryKey}) ====================
// Admin-entered reference data read by the Flutter app's Group > Emergency
// tab (see lib/repositories/country_emergency_repository.dart). The parent
// doc is destination-only (local police/ambulance/fire numbers — the same
// regardless of the trip member's own nationality), falling back to the
// static lib/data/emergency_info.dart maps for any destination not (yet)
// entered here. countryKey is the same lowercased country-name convention
// emergency_info.dart already uses (e.g. "south korea", "united kingdom").
export async function listCountryEmergencyInfo() {
  return all(query(col("country_emergency_info")));
}
export async function getCountryEmergencyInfo(countryKey) {
  const snap = await getDoc(doc(db, "country_emergency_info", countryKey));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
export async function saveCountryEmergencyInfo(countryKey, data) {
  await setDoc(doc(db, "country_emergency_info", countryKey), { ...data, updatedAt: serverTimestamp() }, { merge: true });
}
export async function deleteCountryEmergencyInfo(countryKey) {
  await deleteDoc(doc(db, "country_emergency_info", countryKey));
}

// ---- Embassies (country_emergency_info/{countryKey}/embassies/{homeCountryKey}) ----
// The app isn't used only by Malaysians, so a destination can have more
// than one home country's embassy on file — EmbassyPage looks up the
// SIGNED-IN USER'S OWN country (users/{uid}.country, Account Setting's
// "Country/Region") rather than always assuming Malaysia.
// homeCountryKey follows the same lowercased convention as countryKey.
function embassiesCol(countryKey) {
  return collection(db, "country_emergency_info", countryKey, "embassies");
}
export async function listEmbassies(countryKey) {
  return all(query(embassiesCol(countryKey)));
}
export async function getEmbassy(countryKey, homeCountryKey) {
  const snap = await getDoc(doc(embassiesCol(countryKey), homeCountryKey));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
export async function saveEmbassy(countryKey, homeCountryKey, data) {
  await setDoc(doc(embassiesCol(countryKey), homeCountryKey), { ...data, updatedAt: serverTimestamp() }, { merge: true });
}
export async function deleteEmbassy(countryKey, homeCountryKey) {
  await deleteDoc(doc(embassiesCol(countryKey), homeCountryKey));
}
/** Uploads one embassy photo per (destination, home country) pair,
 * overwriting any previous photo at the same path (same "one file per
 * entity" convention as partner_logos/avatars). */
export async function uploadEmbassyPhoto(countryKey, homeCountryKey, file) {
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
  const path = `country_emergency_photos/${countryKey}/${homeCountryKey}.${ext}`;
  const ref = storageRef(storage, path);
  await uploadBytes(ref, file);
  return getDownloadURL(ref);
}
