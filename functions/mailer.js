// Shared Gmail-SMTP mailer used by the email-code system (email_code.js) and
// any other function that needs to send a real email to a user — keeps the
// Gmail secrets and transporter setup in one place instead of duplicated.
const { defineSecret } = require("firebase-functions/params");
const { HttpsError } = require("firebase-functions/v2/https");

const gmailUser = defineSecret("GMAIL_USER");
const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");

async function sendMail(msg) {
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
}

module.exports = { gmailUser, gmailAppPassword, sendMail };
