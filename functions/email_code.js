// Email verification codes (FR04): one system for three jobs.
//
//  - signup:  a 6-digit code proves the traveller owns the email address.
//  - login:   on a device that is not trusted (new phone, or 30 days since the
//             last code) a code is needed before the app opens. A correct code
//             trusts that device for 30 days.
//  - step-up: change password, change email and delete account ask for a
//             fresh code. A correct code allows that one action for 10
//             minutes. (Payment deliberately does NOT use this -- FR04 is
//             login-only 2FA; see the Nov 2026 session doc for why an
//             earlier version of this app wrongly gated every payment
//             behind a code too.)
//
// Codes are created and checked only here, on the server. Firestore keeps a
// SHA-256 hash of the code, never the code itself, and the security rules stop
// the app from reading or writing these documents.
const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { gmailUser, gmailAppPassword, sendMail } = require("./mailer");

if (getApps().length === 0) initializeApp();

const CODE_TTL_MS = 10 * 60 * 1000;          // a code works for 10 minutes
const RESEND_AFTER_MS = 60 * 1000;           // one email per minute
const MAX_ATTEMPTS = 5;                      // then a new code is needed
const TRUST_DEVICE_MS = 30 * 24 * 60 * 60 * 1000;
const STEP_UP_MS = 10 * 60 * 1000;

const PURPOSES = ["signup", "login", "change_password", "change_email", "delete_account"];
const STEP_UP = ["change_password", "change_email", "delete_account"];

const PURPOSE_TEXT = {
  signup: "verify your email address",
  login: "sign in on a new device",
  change_password: "change your password",
  change_email: "change your email address",
  delete_account: "delete your account",
};

const hashCode = (uid, purpose, code) =>
  crypto.createHash("sha256").update(`${uid}:${purpose}:${code}`).digest("hex");
const newCode = () => String(crypto.randomInt(0, 1000000)).padStart(6, "0");
const cleanDeviceId = (v) => (typeof v === "string" && /^[A-Za-z0-9_-]{8,64}$/.test(v) ? v : null);

function checkPurpose(purpose) {
  if (!PURPOSES.includes(purpose)) {
    throw new HttpsError("invalid-argument", `purpose must be one of: ${PURPOSES.join(", ")}`);
  }
}

// Kept separate from the onCall wrappers so tests can inject Firestore, Auth,
// the mailer and the clock.
function makeHandlers({ db, auth, sendMail, now = () => Date.now() }) {
  async function send(uid, email, purpose) {
    checkPurpose(purpose);
    if (!email) throw new HttpsError("failed-precondition", "This account has no email address.");
    const ref = db.collection("verification_codes").doc(`${uid}_${purpose}`);
    const existing = (await ref.get()).data();
    const t = now();
    if (existing && t - existing.sentAt < RESEND_AFTER_MS) {
      const wait = Math.ceil((RESEND_AFTER_MS - (t - existing.sentAt)) / 1000);
      throw new HttpsError("resource-exhausted", `Please wait ${wait} s before asking for another code.`);
    }
    const code = newCode();
    await ref.set({ uid, purpose, hash: hashCode(uid, purpose, code), sentAt: t, expiresAt: t + CODE_TTL_MS, attempts: 0 });
    await sendMail({
      to: email,
      subject: `Your Voya code: ${code}`,
      text: `Your Voya verification code is ${code}.\n\nUse it to ${PURPOSE_TEXT[purpose]}. It expires in 10 minutes.\n\nIf you did not ask for this code, you can ignore this email and consider changing your password.`,
      html: `<div style="font-family:Arial,sans-serif;max-width:420px">
        <h2 style="color:#104259">Voya verification code</h2>
        <p>Use this code to ${PURPOSE_TEXT[purpose]}:</p>
        <p style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#104259">${code}</p>
        <p style="color:#666">It expires in 10 minutes. If you did not ask for it, ignore this email.</p></div>`,
    });
    return { sent: true, expiresInSeconds: CODE_TTL_MS / 1000 };
  }

  async function verify(uid, purpose, code, deviceId, deviceName) {
    checkPurpose(purpose);
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Enter the 6-digit code.");
    }
    const ref = db.collection("verification_codes").doc(`${uid}_${purpose}`);
    const saved = (await ref.get()).data();
    const t = now();
    if (!saved) throw new HttpsError("not-found", "No code was requested. Tap Resend code.");
    if (t > saved.expiresAt) {
      await ref.delete();
      throw new HttpsError("deadline-exceeded", "This code has expired. Tap Resend code.");
    }
    if (saved.attempts >= MAX_ATTEMPTS) {
      await ref.delete();
      throw new HttpsError("resource-exhausted", "Too many wrong codes. Tap Resend code for a new one.");
    }
    // saved.hash should always be a 64-char hex string written by send()
    // above, but "|| \"\"" keeps Buffer.from from throwing outright if a
    // record is ever malformed -- that just reads as a wrong code instead
    // of crashing the whole call as an opaque "internal" error.
    const given = Buffer.from(hashCode(uid, purpose, code));
    const expected = Buffer.from(saved.hash || "");
    if (given.length !== expected.length || !crypto.timingSafeEqual(given, expected)) {
      const left = MAX_ATTEMPTS - saved.attempts - 1;
      // set({merge:true}), not update() -- update() throws if this record
      // was deleted by a concurrent request (expiry, max-attempts, or a
      // resend racing this same call) in between the get() above and here.
      await ref.set({ attempts: saved.attempts + 1 }, { merge: true });
      throw new HttpsError("permission-denied", left > 0 ? `Wrong code. ${left} attempt(s) left.` : "Wrong code. Tap Resend code for a new one.");
    }

    // The code itself was right. Everything below is bookkeeping, not
    // verification -- if any of it throws, the code record is deliberately
    // kept (not deleted) so a retry of this same, still-correct code
    // succeeds once the underlying hiccup clears, instead of leaving the
    // traveller stuck needing a brand new code for a problem resending
    // can't fix.
    const device = cleanDeviceId(deviceId);
    try {
      if (purpose === "signup") {
        await auth.updateUser(uid, { emailVerified: true });
        await db.collection("users").doc(uid).set({ emailVerified: true }, { merge: true });
      }
      if ((purpose === "signup" || purpose === "login") && device) {
        await db.collection("users").doc(uid).collection("trusted_devices").doc(device).set({
          name: typeof deviceName === "string" ? deviceName.slice(0, 60) : "Phone",
          trustedAt: t,
          trustedUntil: t + TRUST_DEVICE_MS,
        });
      }
      if (STEP_UP.includes(purpose)) {
        await db.collection("step_up").doc(uid).set({ [purpose]: t + STEP_UP_MS }, { merge: true });
      }
    } catch (err) {
      console.error(`verifyCode: code was correct (uid=${uid}, purpose=${purpose}) but finishing up failed`, err);
      throw new HttpsError("internal", "Your code was right -- please try again in a moment. You do not need a new code.");
    }
    await ref.delete();
    return { verified: true, trustedUntil: device ? t + TRUST_DEVICE_MS : null };
  }

  // Used by createPaymentIntent (and anything else that must not run without a code).
  async function hasStepUp(uid, purpose) {
    const data = (await db.collection("step_up").doc(uid).get()).data() || {};
    return typeof data[purpose] === "number" && data[purpose] > now();
  }

  return { send, verify, hasStepUp };
}

function liveHandlers() {
  const { getFirestore } = require("firebase-admin/firestore");
  const { getAuth } = require("firebase-admin/auth");
  return makeHandlers({
    db: getFirestore(),
    auth: getAuth(),
    sendMail,
  });
}

const sendVerificationCode = onCall({ secrets: [gmailUser, gmailAppPassword] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const { purpose } = request.data || {};
  return liveHandlers().send(request.auth.uid, request.auth.token?.email, purpose);
});

const verifyCode = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const { purpose, code, deviceId, deviceName } = request.data || {};
  return liveHandlers().verify(request.auth.uid, purpose, code, deviceId, deviceName);
});

module.exports = {
  sendVerificationCode,
  verifyCode,
  makeHandlers,
  liveHandlers,
  constants: { CODE_TTL_MS, RESEND_AFTER_MS, MAX_ATTEMPTS, TRUST_DEVICE_MS, STEP_UP_MS },
};
