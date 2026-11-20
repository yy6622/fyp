import { db, storage, functions, auth } from "./firebase-config.js";
import {
  collection, collectionGroup, doc, getDoc, getDocs, addDoc, updateDoc, deleteDoc,
  setDoc, query, where, limit, serverTimestamp, deleteField, increment, arrayUnion,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";
export { serverTimestamp, deleteField };
import {
  ref as storageRef, uploadBytes, getDownloadURL, deleteObject,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-storage.js";
import { httpsCallable } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-functions.js";

const col = (name) => collection(db, name);

export function newClaimRef() {
  return `CLM-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 90000) + 10000)}`;
}
export function newRefundRef() {
  return `RFD-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 90000) + 10000)}`;
}
export function newTxnRef() {
  return `TXN-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 90000) + 10000)}`;
}

async function all(q) {
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

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
/** Backs admin/admin-profile.html — mirrors getPartnerProfile/savePartnerProfile's
 * shape below, but against the signed-in admin's own admins/{uid} doc. */
export async function getAdminProfile(uid) {
  const snap = await getDoc(doc(db, "admins", uid));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
export async function updateAdminProfile(uid, data) {
  await updateDoc(doc(db, "admins", uid), data);
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
/** Single plan by id — used by partner/plan-form.html's Edit path. */
export async function getPlan(id) {
  const snap = await getDoc(doc(db, "insurance_plans", id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
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
export async function setPlanStatus(id, status, extra = {}) {
  const payload = { status, ...extra, updatedAt: serverTimestamp() };
  if (status === "active") {
    payload.activatedAt = serverTimestamp();
  } else if (status === "suspended") {
    payload.suspendedAt = serverTimestamp();
  }
  await updateDoc(doc(db, "insurance_plans", id), payload);
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
  return addDoc(col("insurance_transactions"), {
    ...data,
    txnRef: data.txnRef || newTxnRef(),
    createdAt: serverTimestamp(),
  });
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
async function notifyUser(toUid, { type, title, body, data = {} }) {
  if (!toUid) return;
  try {
    await addDoc(collection(db, "users", toUid, "notifications"), {
      type,
      title,
      body,
      data,
      read: false,
      createdAt: serverTimestamp(),
    });
  } catch (_) {
  }
}

const CLAIM_STATUS_NOTICE = {
  approved: { type: "claim_approved", title: "Your claim was approved" },
  rejected: { type: "claim_rejected", title: "Your claim was rejected" },
  under_review: { type: "claim_info_requested", title: "More information needed for your claim" },
};

// The partner may set the assessed claim amount. Travellers never submit it.
export async function setClaimAmount(id, amount) {
  const current = await getClaim(id);
  if (!current || current.partnerId !== auth.currentUser?.uid) throw new Error('Not authorised to review this claim.');
  if (current.status === 'approved' || current.status === 'rejected') throw new Error('This claim is already final.');
  if (!Number.isFinite(amount) || amount <= 0) throw new Error('Enter a valid claim amount.');
  await updateDoc(doc(db, 'claims', id), { amount, amountSetByPartner: true, updatedAt: serverTimestamp() });
}

export async function updateClaimStatus(id, status, note = "", assessedAmount = null) {
  const current = await getClaim(id);
  if (!current || current.partnerId !== auth.currentUser?.uid) throw new Error('Not authorised to review this claim.');
  if (current.status === 'approved' || current.status === 'rejected') throw new Error('This claim is already final.');
  const amount = assessedAmount ?? (current.amountSetByPartner === true ? current.amount : null);
  if (status === 'approved' && (amount == null || !Number.isFinite(Number(amount)) || Number(amount) <= 0)) {
    throw new Error('Partner must enter a valid claim amount before approval.');
  }
  const timeline = [...(current.timeline || []), { status, at: new Date().toISOString(), note }];
  const patch = { status, timeline, updatedAt: serverTimestamp() };
  if (assessedAmount !== null) { patch.amount = Number(assessedAmount); patch.amountSetByPartner = true; }
  await updateDoc(doc(db, "claims", id), patch);
  const notice = CLAIM_STATUS_NOTICE[status];
  if (notice && current?.buyerId) {
    await notifyUser(current.buyerId, {
      type: notice.type,
      title: notice.title,
      body: note || notice.title,
      data: { claimId: id, claimRef: current.claimRef || "", status },
    });
  }
}

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
const REFUND_STATUS_NOTICE = {
  approved: { type: "refund_approved", title: "Your refund was approved" },
  rejected: { type: "refund_rejected", title: "Your refund was rejected" },
  under_review: { type: "refund_info_requested", title: "More information needed for your refund" },
};

export async function updateRefundStatus(id, status, note = "") {
  const current = await getRefund(id);
  const timeline = [...(current?.timeline || []), { status, at: new Date().toISOString(), note }];
  await updateDoc(doc(db, "refunds", id), { status, timeline, updatedAt: serverTimestamp() });
  const notice = REFUND_STATUS_NOTICE[status];
  if (notice && current?.buyerId) {
    await notifyUser(current.buyerId, {
      type: notice.type,
      title: notice.title,
      body: note || notice.title,
      data: { refundId: id, refundRef: current.refundRef || "", status },
    });
  }
}

export async function listInsuranceChats(partnerId) {
  const items = await all(query(col("insurance_chats"), where("partnerId", "==", partnerId)));
  return items
    .filter((c) => !!c.lastMessageAt)
    .sort((a, b) => (b.lastMessageAt?.seconds || 0) - (a.lastMessageAt?.seconds || 0));
}
export async function getInsuranceChat(id) {
  const snap = await getDoc(doc(db, "insurance_chats", id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}
export async function listInsuranceChatMessages(chatId) {
  const items = await all(query(collection(db, "insurance_chats", chatId, "messages")));
  return items.sort((a, b) => (a.createdAt?.seconds || 0) - (b.createdAt?.seconds || 0));
}
/** Sends as the partner side — senderId must be the signed-in partner's own uid (matches the security rule). */
export async function sendInsuranceChatMessage(chatId, senderId, text) {
  await addDoc(collection(db, "insurance_chats", chatId, "messages"), {
    senderId, senderRole: "partner", text, createdAt: serverTimestamp(),
  });
  await updateDoc(doc(db, "insurance_chats", chatId), {
    lastMessage: text,
    lastMessageAt: serverTimestamp(),
    lastSenderRole: "partner",
    unreadForTraveller: true,
    unreadForPartner: false,
  });
}
export async function sendInsuranceChatPlan(chatId, senderId, plan) {
  const text = `\ud83d\udcc4 Sent a plan: ${plan.name || "Insurance Plan"}`;
  await addDoc(collection(db, "insurance_chats", chatId, "messages"), {
    senderId, senderRole: "partner", text, createdAt: serverTimestamp(), attachedPlanId: plan.id,
  });
  await updateDoc(doc(db, "insurance_chats", chatId), {
    lastMessage: text,
    lastMessageAt: serverTimestamp(),
    lastSenderRole: "partner",
    unreadForTraveller: true,
    unreadForPartner: false,
  });
}
export async function markInsuranceChatReadByPartner(chatId) {
  await updateDoc(doc(db, "insurance_chats", chatId), { unreadForPartner: false });
}

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
/** The app's Explore screen finds attractions by an exact match on
 * destinationQuery (trimmed+lowercased destination text) -- without it an
 * attraction is saved but invisible to search. Every write path here
 * derives it from location so this can't be forgotten again. */
function withDestinationQuery(data) {
  if (data.destinationQuery || !data.location) return data;
  return { ...data, destinationQuery: data.location.trim().toLowerCase() };
}
export async function createAttraction(ref, data) {
  await setDoc(ref, {
    ...withDestinationQuery(data),
    favoritedBy: [],
    status: data.status || "active",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return ref;
}
export async function updateAttraction(id, data) {
  await updateDoc(doc(db, "catalog_attractions", id), { ...withDestinationQuery(data), updatedAt: serverTimestamp() });
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

export async function updateCatalogItemDescription(collectionName, id, description) {
  await updateDoc(doc(db, collectionName, id), { description, updatedAt: serverTimestamp() });
}

export async function fixCatalogItemName(collectionName, id, name) {
  await updateDoc(doc(db, collectionName, id), { name, updatedAt: serverTimestamp() });
}

export async function fixRestaurantName(id, name) {
  await updateDoc(doc(db, "catalog_restaurants", id), { name, updatedAt: serverTimestamp() });
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
    autoFlagged: deleteField(),
  });
}
export async function rejectPost(postId) {
  await deleteDoc(doc(db, "posts", postId));
}

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
export async function countFlaggedReviews() {
  const snap = await getDocs(query(collectionGroup(db, "reviews"), where("reported", "==", true)));
  return snap.size;
}

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

export async function rejectReview(review) {
  await deleteDoc(review.ref);
}

export async function listAllBookings() {
  const snap = await getDocs(collectionGroup(db, "bookings"));
  return snap.docs
    .map((d) => ({ id: d.id, uid: d.ref.parent.parent?.id || "", ...d.data() }))
    .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}

export async function listPostViewStats() {
  return all(query(col("post_view_stats")));
}
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

export async function sendVerificationCode(purpose) {
  const call = httpsCallable(functions, "sendVerificationCode");
  const res = await call({ purpose });
  return res.data;
}
export async function verifyEmailCode(purpose, code) {
  const call = httpsCallable(functions, "verifyCode");
  const res = await call({ purpose, code });
  return res.data;
}

export async function getTagPresets(key) {
  const snap = await getDoc(doc(db, "tag_presets", key));
  return snap.exists() ? (snap.data().tags || []) : [];
}
export async function addTagPreset(key, tag) {
  await setDoc(doc(db, "tag_presets", key), { tags: arrayUnion(tag) }, { merge: true });
}

export async function listDismissedNoticeKeys() {
  const snap = await getDocs(col("dismissed_notices"));
  return new Set(snap.docs.map((d) => d.id));
}
export async function dismissNotice(key) {
  await setDoc(doc(db, "dismissed_notices", key), { dismissedAt: serverTimestamp() });
}

export async function listPartnerDismissedNoticeKeys(partnerId) {
  const snap = await getDocs(col(`partner_dismissed_notices/${partnerId}/items`));
  return new Set(snap.docs.map((d) => d.id));
}
export async function dismissPartnerNotice(partnerId, key) {
  await setDoc(doc(db, "partner_dismissed_notices", partnerId, "items", key), { dismissedAt: serverTimestamp() });
}

export async function listSeenNoticeKeys() {
  const snap = await getDocs(col("seen_notices"));
  return new Map(snap.docs.map((d) => [d.id, d.data().seenAt || null]));
}
export async function markNoticeSeen(key) {
  await setDoc(doc(db, "seen_notices", key), { seenAt: serverTimestamp() }, { merge: true });
}
export async function listPartnerSeenNoticeKeys(partnerId) {
  const snap = await getDocs(col(`partner_seen_notices/${partnerId}/items`));
  return new Map(snap.docs.map((d) => [d.id, d.data().seenAt || null]));
}
export async function markPartnerNoticeSeen(partnerId, key) {
  await setDoc(doc(db, "partner_seen_notices", partnerId, "items", key), { seenAt: serverTimestamp() }, { merge: true });
}

export async function listPlaceSuggestions() {
  const items = await all(query(col("place_suggestions")));
  return items
    .filter((s) => s.status === "pending" || !s.status)
    .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}
export async function countPlaceSuggestions() {
  return (await listPlaceSuggestions()).length;
}
export async function rejectPlaceSuggestion(id) {
  await updateDoc(doc(db, "place_suggestions", id), { status: "rejected", decidedAt: serverTimestamp() });
}
export async function markPlaceSuggestionAdded(id, addedAs) {
  await updateDoc(doc(db, "place_suggestions", id), { status: "added", addedAs, decidedAt: serverTimestamp() });
}
