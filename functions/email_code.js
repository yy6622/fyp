// Email verification codes (FR04): one system for three jobs.
//
//  - signup:  a 6-digit code proves the traveller owns the email address.
//  - login:   on a device that is not trusted (new phone, or 30 days since the
//             last code) a code is needed before the app opens. A correct code
//             trusts that device for 30 days.
//  - step-up: payment, change password, change email and delete account ask for
//             a fresh code. A correct code allows that one action for 10 minutes;
//             createPaymentIntent refuses to charge without it.
//
// Codes are created and checked only here, on the server. Firestore keeps a
// SHA-256 hash of the code, never the code itself, and the security rules stop
// the app from reading or writing these documents.
const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");

if (getApps().length === 0) initializeApp();

const gmailUser = defineSecret("GMAIL_USER");
const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");

const CODE_TTL_MS = 10 * 60 * 1000;          // a code works for 10 minutes
const RESEND_AFTER_MS = 60 * 1000;           // one email per minute
const MAX_ATTEMPTS = 5;                      // then a new code is needed
const TRUST_DEVICE_MS = 30 * 24 * 60 * 60 * 1000;
const STEP_UP_MS = 10 * 60 * 1000;

const PURPOSES = ["signup", "login", "payment", "change_password", "change_email", "delete_account"];
const STEP_UP = ["payment", "change_password", "change_email", "delete_account"];

const PURPOSE_TEXT = {
  signup: "verify your email address",
  login: "sign in on a new device",
  payment: "confirm your payment",
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
    const given = Buffer.from(hashCode(uid, purpose, code));
    const expected = Buffer.from(saved.hash);
    if (given.length !== expected.length || !crypto.timingSafeEqual(given, expected)) {
      const left = MAX_ATTEMPTS - saved.attempts - 1;
      await ref.update({ attempts: saved.attempts + 1 });
      throw new HttpsError("permission-denied", left > 0 ? `Wrong code. ${left} attempt(s) left.` : "Wrong code. Tap Resend code for a new one.");
    }
    await ref.delete();

    const device = cleanDeviceId(deviceId);
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
    return { verified: true, trustedUntil: device && purpose !== "payment" ? t + TRUST_DEVICE_MS : null };
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
    sendMail: async (msg) => {
      const nodemailer = require("nodemailer");
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user: gmailUser.value(), pass: gmailAppPassword.value() },
      });
      try {
        await transporter.sendMail({ from: `"Voya" <${gmailUser.value()}>`, ...msg });
      } catch (err) {
        console.error("sendMail failed", err.message);
        throw new HttpsError("unavailable", "Could not send the email. Please try again in a moment.");
      }
    },
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
