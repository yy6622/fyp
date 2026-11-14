// Emails the author of a community post when an admin rejects (removes) it
// from the Content Moderation console — previously rejectPost() just
// silently deleted the post with no notification to the author at all.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { gmailUser, gmailAppPassword, sendMail } = require("./mailer");

if (getApps().length === 0) initializeApp();

function escapeHtml(s) {
  return String(s || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

exports.notifyPostRejected = onCall({ secrets: [gmailUser, gmailAppPassword] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");

  const db = getFirestore();
  // Only an admin (an admins/{uid} doc exists for the caller) may trigger
  // this — same check as firestore.rules' isAdmin() — so this can't be
  // abused to spam arbitrary users from a non-admin account.
  const adminSnap = await db.collection("admins").doc(request.auth.uid).get();
  if (!adminSnap.exists) throw new HttpsError("permission-denied", "Admins only.");

  const data = request.data || {};
  const authorId = typeof data.authorId === "string" ? data.authorId.trim() : "";
  if (!authorId) throw new HttpsError("invalid-argument", "authorId is required.");
  const title = typeof data.title === "string" ? data.title.trim() : "";
  const reportReason = typeof data.reportReason === "string" ? data.reportReason.trim() : "";

  const userSnap = await db.collection("users").doc(authorId).get();
  const email = userSnap.exists ? userSnap.data()?.email : null;
  // Best-effort — if the author has no email on file there's simply
  // nothing to send; this isn't an error, the post is still removed.
  if (!email) return { sent: false, reason: "no-email" };

  const postLabel = title || "Your post";

  await sendMail({
    to: email,
    subject: "Your Voya community post was removed",
    text: [
      `"${postLabel}" was reviewed by a Voya moderator and removed for not following our community guidelines.`,
      reportReason ? `Reason: ${reportReason}` : null,
      "",
      "If you believe this was a mistake, you can reply to this email or contact Voya support.",
    ].filter(Boolean).join("\n"),
    html: `<div style="font-family:Arial,sans-serif;max-width:480px">
      <h2 style="color:#104259">Post removed</h2>
      <p>"<b>${escapeHtml(postLabel)}</b>" was reviewed by a Voya moderator and removed for not following our community guidelines.</p>
      ${reportReason ? `<p style="color:#888;">Reason: ${escapeHtml(reportReason)}</p>` : ""}
      <p style="color:#666;margin-top:16px">If you believe this was a mistake, you can reply to this email or contact Voya support.</p>
    </div>`,
  });

  return { sent: true };
});
