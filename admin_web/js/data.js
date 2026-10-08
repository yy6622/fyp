// Voya — Firestore data-access layer shared by every admin & partner page.
// Existing collections (users, posts, catalog_attractions) are the SAME ones
// the Flutter app reads/writes — changes here are real and show up there too.
// New collections (admins, insurance_partners, insurance_plans, claims,
// insurance_transactions) exist only for this console.
import { db, storage } from "./firebase-config.js";
import {
  collection, collectionGroup, doc, getDoc, getDocs, addDoc, updateDoc, deleteDoc,
  setDoc, query, where, limit, serverTimestamp, deleteField, writeBatch, getCountFromServer,
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
export async function setPartnerStatus(uid, status) {
  await updateDoc(doc(db, "insurance_partners", uid), { status });
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
  });
}
export async function rejectPost(postId) {
  await deleteDoc(doc(db, "posts", postId));
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

// ==================== CATALOG PLACES MIGRATION (one-off tool) ====================
// `places` is the pre-scraped OSM dataset CatalogRepository.refreshAttractions
// reads from (see lib/repositories/catalog_repository.dart) — never written by
// this console. `catalog_places` used to be a different, now-unused seeded
// collection from an earlier version of the app; nothing in the current
// Flutter codebase reads it any more. This is the one-off tool
// (admin/migrate-places.html) that retires the old catalog_places and
// promotes `places` to that name, matching the catalog_* naming convention
// every other collection here already follows (catalog_flights/_hotels/
// _attractions/_restaurants). Needs firestore.rules' catalog_places + places
// match blocks deployed first (admin create/delete on both) — see that
// file's comments.
const BATCH_LIMIT = 450; // Firestore's hard cap is 500 writes/batch; stay under it for headroom.

async function countDocs(name) {
  const snap = await getCountFromServer(col(name));
  return snap.data().count;
}

/** Counts for the confirmation screen, before anything destructive runs. */
export async function getPlacesMigrationCounts() {
  const [oldCatalogPlaces, places] = await Promise.all([countDocs("catalog_places"), countDocs("places")]);
  return { oldCatalogPlaces, places };
}

async function deleteAllDocs(name, onProgress) {
  const snap = await getDocs(col(name));
  const docs = snap.docs;
  for (let i = 0; i < docs.length; i += BATCH_LIMIT) {
    const batch = writeBatch(db);
    docs.slice(i, i + BATCH_LIMIT).forEach((d) => batch.delete(d.ref));
    await batch.commit();
    onProgress?.(Math.min(i + BATCH_LIMIT, docs.length), docs.length);
  }
  return docs.length;
}

/** Read-only: fetches the current catalog_places' raw docs so the caller can
 * trigger a local backup-file download BEFORE calling [runPlacesMigration]
 * below — kept as its own function (rather than folded into the migration
 * function and handed back at the end) specifically so that download can
 * happen first, before anything destructive runs. */
export async function backupCatalogPlaces() {
  const snap = await getDocs(col("catalog_places"));
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/** The destructive part of the migration — call only after the caller has
 * already backed up + downloaded the current catalog_places via
 * [backupCatalogPlaces] above. Deletes every existing catalog_places doc,
 * copies every `places` doc into catalog_places under the SAME doc id (so
 * anything that ever referenced a places doc id — e.g. catalog_attractions'
 * `place_<id>` doc ids — still lines up), then empties `places`. Each step
 * is batched (Firestore's 500-writes-per-batch limit). onProgress(stage,
 * current, total) is called throughout for a live progress UI. */
export async function runPlacesMigration(onProgress) {
  const oldCatalogPlacesDeleted = await deleteAllDocs("catalog_places", (done, total) => onProgress?.("deleting-old", done, total));

  const placesSnap = await getDocs(col("places"));
  const placesDocs = placesSnap.docs;
  onProgress?.("copying", 0, placesDocs.length);
  for (let i = 0; i < placesDocs.length; i += BATCH_LIMIT) {
    const batch = writeBatch(db);
    placesDocs.slice(i, i + BATCH_LIMIT).forEach((d) => batch.set(doc(db, "catalog_places", d.id), d.data()));
    await batch.commit();
    onProgress?.("copying", Math.min(i + BATCH_LIMIT, placesDocs.length), placesDocs.length);
  }

  onProgress?.("deleting-places", 0, placesDocs.length);
  await deleteAllDocs("places", (done, total) => onProgress?.("deleting-places", done, total));

  return { oldCatalogPlacesDeleted, copied: placesDocs.length };
}
