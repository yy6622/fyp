const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Stripe = require("stripe");
const { initializeApp, getApps } = require("firebase-admin/app");

if (getApps().length === 0) initializeApp();

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

exports.createPaymentIntent = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before paying.");
  }

  const { amount, currency, receiptEmail } = request.data || {};
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "amount must be a positive number (minor currency units).");
  }
  if (typeof currency !== "string" || currency.length !== 3) {
    throw new HttpsError("invalid-argument", "currency must be a 3-letter ISO code, e.g. 'myr'.");
  }

  // FR04 is login-only 2FA (see functions/email_code.js) -- a payment
  // itself never needs its own extra email code, so this just creates
  // the PaymentIntent directly.
  const stripe = new Stripe(stripeSecretKey.value());
  let paymentIntent;
  try {
    paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount),
      currency: currency.toLowerCase(),
      receipt_email: typeof receiptEmail === "string" && receiptEmail.length > 0 ? receiptEmail : undefined,
      metadata: { uid: request.auth.uid },
      automatic_payment_methods: { enabled: true },
    });
  } catch (err) {
    throw new HttpsError("internal", `Stripe error: ${err.message}`);
  }

  return { clientSecret: paymentIntent.client_secret };
});

exports.generateItinerary = require("./itinerary").generateItinerary;

exports.optimiseItinerary = require("./optimise").optimiseItinerary;


exports.summariseDiscussion = require("./discussion_summary").summariseDiscussion;

const emailCode = require("./email_code");
exports.sendVerificationCode = emailCode.sendVerificationCode;
exports.verifyCode = emailCode.verifyCode;

exports.remindUnpaidExpenses = require("./expense_reminders").remindUnpaidExpenses;

exports.cleanupReadNotifications = require("./notification_cleanup").cleanupReadNotifications;

exports.sendPolicyEmail = require("./policy_email").sendPolicyEmail;

exports.notifyPostRejected = require("./post_rejected_email").notifyPostRejected;

exports.moderateText = require("./content_moderation").moderateText;

const paypal = require("./paypal");
exports.createPaypalOrder = paypal.createPaypalOrder;
exports.capturePaypalOrder = paypal.capturePaypalOrder;

const conditionWatch = require("./condition_watch");
exports.conditionWatch = conditionWatch.conditionWatch;

