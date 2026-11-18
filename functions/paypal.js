const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");

if (getApps().length === 0) initializeApp();

const paypalClientId = defineSecret("PAYPAL_CLIENT_ID");
const paypalClientSecret = defineSecret("PAYPAL_CLIENT_SECRET");

const PAYPAL_API_BASE = "https://api-m.sandbox.paypal.com";

const RETURN_URL = "voyaapp://paypal-return";
const CANCEL_URL = "voyaapp://paypal-cancel";

async function getAccessToken() {
  const id = paypalClientId.value();
  const secret = paypalClientSecret.value();
  const basicAuth = Buffer.from(`${id}:${secret}`).toString("base64");
  const res = await fetch(`${PAYPAL_API_BASE}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${basicAuth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) {
    throw new HttpsError("internal", `PayPal auth failed: ${data.error_description || res.status}`);
  }
  return data.access_token;
}

exports.createPaypalOrder = onCall({ secrets: [paypalClientId, paypalClientSecret] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before paying.");
  }
  const { amount, currency } = request.data || {};
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "amount must be a positive number (major currency units, e.g. 110.00).");
  }
  if (typeof currency !== "string" || currency.length !== 3) {
    throw new HttpsError("invalid-argument", "currency must be a 3-letter ISO code, e.g. 'MYR'.");
  }

  // FR04 is login-only 2FA (see functions/email_code.js) -- PayPal
  // checkout itself doesn't need its own extra email code either, same
  // as createPaymentIntent (Stripe) next door.
  const accessToken = await getAccessToken();
  const res = await fetch(`${PAYPAL_API_BASE}/v2/checkout/orders`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      intent: "CAPTURE",
      purchase_units: [
        {
          amount: { currency_code: currency.toUpperCase(), value: amount.toFixed(2) },
        },
      ],
      application_context: {
        return_url: RETURN_URL,
        cancel_url: CANCEL_URL,
        user_action: "PAY_NOW",
        shipping_preference: "NO_SHIPPING",
      },
    }),
  });
  const order = await res.json();
  if (!res.ok || !order.id) {
    throw new HttpsError("internal", `PayPal order creation failed: ${order.message || res.status}`);
  }
  const approveLink = (order.links || []).find((l) => l.rel === "payer-action" || l.rel === "approve");
  if (!approveLink) {
    throw new HttpsError("internal", "PayPal did not return an approval link.");
  }
  return { orderId: order.id, approveUrl: approveLink.href };
});

// Step 2: after the traveller approves in the WebView and it bounces back
// to RETURN_URL, the Flutter side calls this to actually capture the funds.
exports.capturePaypalOrder = onCall({ secrets: [paypalClientId, paypalClientSecret] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before paying.");
  }
  const { orderId } = request.data || {};
  if (typeof orderId !== "string" || orderId.length === 0) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  const accessToken = await getAccessToken();
  const res = await fetch(`${PAYPAL_API_BASE}/v2/checkout/orders/${orderId}/capture`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });
  const capture = await res.json();
  if (!res.ok) {
    throw new HttpsError("internal", `PayPal capture failed: ${capture.message || res.status}`);
  }
  const status = capture.status;
  const captureId = capture.purchase_units?.[0]?.payments?.captures?.[0]?.id || capture.id;
  if (status !== "COMPLETED") {
    throw new HttpsError("aborted", `PayPal payment not completed (status: ${status}).`);
  }
  return { captureId, status };
});
