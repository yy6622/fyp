// Voya — auth/role helpers shared by every admin & partner page.
import { auth, db } from "./firebase-config.js";
import {
  onAuthStateChanged, signOut, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, sendPasswordResetEmail,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";
import {
  doc, getDoc, updateDoc, setDoc, serverTimestamp,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";

function waitForUser() {
  return new Promise((resolve) => {
    const unsub = onAuthStateChanged(auth, (u) => {
      unsub();
      resolve(u);
    });
  });
}

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * A rejected partner who's still rejected 30 days after admin rejected
 * them (admin/insurance.html or insurance-partners.html's Reject action,
 * which stamps rejectedAt — see js/data.js setPartnerStatus) gets
 * auto-blocked. There's no scheduled backend in this project to do this
 * on a timer, so it's checked lazily here instead, on every partner page
 * load (requireRole() calls this for role: "partner") — the first partner
 * page load after the 30 days are up is what actually flips the status.
 * The partner's own client does the write; insurance_partners/{uid}'s
 * rule already lets isOwner(uid) update their own doc.
 */
async function applyPartnerAutoBlock(uid, profile) {
  if (profile.status !== "rejected" || !profile.rejectedAt?.toMillis) return profile;
  const rejectedAtMs = profile.rejectedAt.toMillis();
  if (Date.now() - rejectedAtMs < THIRTY_DAYS_MS) return profile;
  try {
    await updateDoc(doc(db, "insurance_partners", uid), { status: "blocked", blockedAt: serverTimestamp() });
  } catch {
    return profile; // couldn't write (offline, rules hiccup) — leave as "rejected" for now, retried on next load
  }
  return { ...profile, status: "blocked" };
}

/**
 * Blocks page render until we know the signed-in user really has `role`
 * ('admin' | 'partner'). Redirects to `loginUrl` otherwise. Returns
 * { user, uid, profile } on success (profile = the admins/insurance_partners doc).
 *
 * For role: "partner", also redirects to partner/notifications.html when
 * their status is "rejected" or "blocked" — so no partner page (dashboard,
 * plans, claims, ...) is reachable while in either state, not just the
 * dashboard's old small banner. Pass { skipStatusGate: true } from
 * notifications.html itself, so that page can actually show the message
 * instead of redirecting to itself forever (notifications.html is also a
 * normal, always-reachable nav item for an approved/pending/suspended
 * partner — the gate only forces the redirect for rejected/blocked).
 */
export async function requireRole(role, loginUrl, { skipStatusGate = false } = {}) {
  const user = await waitForUser();
  if (!user) {
    location.replace(loginUrl);
    return null;
  }
  const col = role === "admin" ? "admins" : "insurance_partners";
  const snap = await getDoc(doc(db, col, user.uid));
  if (!snap.exists()) {
    await signOut(auth);
    location.replace(loginUrl + (loginUrl.includes("?") ? "&" : "?") + "err=not-authorized");
    return null;
  }
  let profile = snap.data();
  if (role === "partner" && !skipStatusGate) {
    profile = await applyPartnerAutoBlock(user.uid, profile);
    if (profile.status === "rejected" || profile.status === "blocked") {
      location.replace("notifications.html");
      return null;
    }
  }
  return { user, uid: user.uid, profile };
}

export async function loginWithEmail(email, password) {
  const cred = await signInWithEmailAndPassword(auth, email.trim(), password);
  return cred.user;
}

export async function resetPassword(email) {
  await sendPasswordResetEmail(auth, email.trim());
}

/** Registers a brand-new Firebase Auth account + role marker doc. */
export async function registerWithRole(role, email, password, profileData) {
  const cred = await createUserWithEmailAndPassword(auth, email.trim(), password);
  const col = role === "admin" ? "admins" : "insurance_partners";
  await setDoc(doc(db, col, cred.user.uid), {
    ...profileData,
    email: email.trim().toLowerCase(),
    createdAt: serverTimestamp(),
  });
  return cred.user;
}

export async function logout(loginUrl) {
  await signOut(auth);
  location.href = loginUrl;
}

export function authErrorMessage(err) {
  const code = err?.code || "";
  switch (code) {
    case "auth/invalid-email": return "That email address looks invalid.";
    case "auth/user-disabled": return "This account has been disabled.";
    case "auth/user-not-found": return "No account found for that email.";
    case "auth/wrong-password":
    case "auth/invalid-credential": return "Incorrect email or password.";
    case "auth/email-already-in-use": return "An account already exists for that email.";
    case "auth/weak-password": return "That password is too weak (use at least 6 characters).";
    case "auth/network-request-failed": return "Network error — check your connection and try again.";
    case "auth/too-many-requests": return "Too many attempts. Please wait a moment and try again.";
    case "permission-denied": return "You don't have permission to do that.";
    default: return err?.message || "Something went wrong. Please try again.";
  }
}
