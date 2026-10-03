const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Stripe = require("stripe");

// Set once with: firebase functions:secrets:set STRIPE_SECRET_KEY
// Paste your Stripe TEST secret key (sk_test_...) when prompted — see
// README.md in this folder for the full walkthrough. NEVER a live
// sk_live_... key for this project, and never commit a key anywhere.
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

/**
 * Creates a Stripe PaymentIntent for a Flight/Hotel checkout
 * (lib/views/detail/booking_payment_page.dart calls this through
 * lib/services/stripe_service.dart's `createPaymentIntent` callable). The
 * secret key lives only here, pulled from Secret Manager at call time —
 * it never reaches the Flutter app, which only ever holds the
 * publishable key (see lib/config/secrets.dart).
 *
 * request.data: {
 *   amount: number     — minor currency units (e.g. sen/cents), > 0
 *   currency: string   — 3-letter ISO code, e.g. "myr"
 *   receiptEmail?: string
 * }
 * returns: { clientSecret: string }
 */
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

  const stripe = new Stripe(stripeSecretKey.value());
  let paymentIntent;
  try {
    paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount),
      currency: currency.toLowerCase(),
      receipt_email: typeof receiptEmail === "string" && receiptEmail.length > 0 ? receiptEmail : undefined,
      // Ties the charge back to the Voya user who made it, visible on the
      // PaymentIntent in the Stripe Dashboard — useful when checking test
      // charges against who triggered them.
      metadata: { uid: request.auth.uid },
      automatic_payment_methods: { enabled: true },
    });
  } catch (err) {
    // A real Stripe API error (bad key, Stripe outage, ...) — surfaced as
    // its own code rather than a generic 500 so the app can show something
    // more useful than "something went wrong".
    throw new HttpsError("internal", `Stripe error: ${err.message}`);
  }

  return { clientSecret: paymentIntent.client_secret };
});
