// Voya — auth/role helpers shared by every admin & partner page.
import { auth, db } from "./firebase-config.js";
import {
  onAuthStateChanged, signOut, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, sendPasswordResetEmail,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";
import {
  doc, getDoc, setDoc, serverTimestamp,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";

function waitForUser() {
  return new Promise((resolve) => {
    const unsub = onAuthStateChanged(auth, (u) => {
      unsub();
      resolve(u);
    });
  });
}

/**
 * Blocks page render until we know the signed-in user really has `role`
 * ('admin' | 'partner'). Redirects to `loginUrl` otherwise. Returns
 * { user, uid, profile } on success (profile = the admins/insurance_partners doc).
 */
export async function requireRole(role, loginUrl) {
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
  return { user, uid: user.uid, profile: snap.data() };
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
