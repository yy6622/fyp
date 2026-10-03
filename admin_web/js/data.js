// Voya — Firestore data-access layer shared by every admin & partner page.
// Existing collections (users, posts, catalog_attractions) are the SAME ones
// the Flutter app reads/writes — changes here are real and show up there too.
// New collections (admins, insurance_partners, insurance_plans, claims,
// insurance_transactions) exist only for this console.
import { db, storage } from "./firebase-config.js";
import {
  collection, doc, getDoc, getDocs, addDoc, updateDoc, deleteDoc,
  setDoc, query, where, limit, serverTimestamp, deleteField,
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
/** True if an attraction imported from this external-search result was already saved. */
export async function attractionExistsBySourcePlaceId(placeId) {
  if (!placeId) return false;
  const snap = await getDocs(query(col("catalog_attractions"), where("sourcePlaceId", "==", placeId)));
  return !snap.empty;
}
/** Bulk-writes already-mapped attraction objects (see js/places-import.js), skipping duplicates. */
export async function importAttractions(attractionDataList) {
  let imported = 0, skipped = 0;
  for (const data of attractionDataList) {
    if (await attractionExistsBySourcePlaceId(data.sourcePlaceId)) { skipped++; continue; }
    await createAttraction(newAttractionRef(), data);
    imported++;
  }
  return { imported, skipped };
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

/** Small audit trail so "Approved today" / "Rejected today" are real counts. */
export async function logModerationAction(action, postId, adminUid) {
  await addDoc(col("moderation_log"), { action, postId, adminUid, at: serverTimestamp() });
}
export async function countModerationToday(action) {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const items = await all(query(col("moderation_log"), where("action", "==", action)));
  return items.filter((i) => i.at?.toDate && i.at.toDate().getTime() >= startOfDay.getTime()).length;
}

// ==================== DASHBOARD AGGREGATES ====================
export async function loadAdminOverviewData() {
  const [users, attractions, plans, claims, txns] = await Promise.all([
    listUsers(), listAttractions(), listPlans(), listClaims(), listTransactions(),
  ]);
  return { users, attractions, plans, claims, txns };
}
