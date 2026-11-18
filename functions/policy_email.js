const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { gmailUser, gmailAppPassword, sendMail } = require("./mailer");

if (getApps().length === 0) initializeApp();

function money(n) {
  const v = Number(n) || 0;
  return `RM ${v.toFixed(2)}`;
}

exports.sendPolicyEmail = onCall({ secrets: [gmailUser, gmailAppPassword] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  // The recipient is always the signed-in user's own verified email — never
  // a client-supplied address, so this can't be used to spam someone else.
  const email = request.auth.token?.email;
  if (!email) throw new HttpsError("failed-precondition", "This account has no email address.");

  const data = request.data || {};
  const planName = typeof data.planName === "string" ? data.planName.trim() : "";
  if (!planName) throw new HttpsError("invalid-argument", "planName is required.");
  const provider = typeof data.provider === "string" ? data.provider.trim() : "";
  const policyNumber = typeof data.policyNumber === "string" ? data.policyNumber.trim() : "";
  const travellerCount = Number(data.travellerCount) || 1;
  const premium = Number(data.premium) || 0;
  const destination = typeof data.destination === "string" ? data.destination.trim() : "";
  const travelStart = typeof data.travelStart === "string" ? data.travelStart.trim() : "";
  const travelEnd = typeof data.travelEnd === "string" ? data.travelEnd.trim() : "";
  const dateLine = travelStart && travelEnd ? `${travelStart} - ${travelEnd}` : "";

  const subject = policyNumber ? `Your Voya insurance policy #${policyNumber}` : "Your Voya insurance policy";

  await sendMail({
    to: email,
    subject,
    text: [
      `Your ${planName} policy is confirmed.`,
      policyNumber ? `Policy number: ${policyNumber}` : null,
      provider ? `Provider: ${provider}` : null,
      `Traveller(s): ${travellerCount}`,
      `Premium paid: ${money(premium)}`,
      destination ? `Destination: ${destination}` : null,
      dateLine ? `Travel period: ${dateLine}` : null,
      "",
      "Keep this email as your proof of purchase.",
    ].filter(Boolean).join("\n"),
    html: `<div style="font-family:Arial,sans-serif;max-width:480px">
      <h2 style="color:#104259">Policy Confirmed</h2>
      <p>Your <b>${planName}</b> policy is confirmed.</p>
      <table style="font-size:14px;color:#333;border-collapse:collapse;margin-top:8px">
        ${policyNumber ? `<tr><td style="padding:4px 12px 4px 0;color:#888">Policy number</td><td><b>${policyNumber}</b></td></tr>` : ""}
        ${provider ? `<tr><td style="padding:4px 12px 4px 0;color:#888">Provider</td><td>${provider}</td></tr>` : ""}
        <tr><td style="padding:4px 12px 4px 0;color:#888">Traveller(s)</td><td>${travellerCount}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#888">Premium paid</td><td>${money(premium)}</td></tr>
        ${destination ? `<tr><td style="padding:4px 12px 4px 0;color:#888">Destination</td><td>${destination}</td></tr>` : ""}
        ${dateLine ? `<tr><td style="padding:4px 12px 4px 0;color:#888">Travel period</td><td>${dateLine}</td></tr>` : ""}
      </table>
      <p style="color:#666;margin-top:16px">Keep this email as your proof of purchase.</p>
    </div>`,
  });

  return { sent: true };
});
