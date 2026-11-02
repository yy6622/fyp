// TC32 / TC33 against REAL Stripe test mode.
// Runs the real createPaymentIntent Cloud Function code with your Stripe TEST
// secret key, then confirms the PaymentIntent with Stripe's official test cards:
//   pm_card_visa            -> 4242 4242 4242 4242 (success)
//   pm_card_chargeDeclined  -> 4000 0000 0000 0002 (declined)
//
// Run (PowerShell):  $env:STRIPE_TEST_SECRET_KEY="sk_test_..."; node --test tests/live/
// Skipped automatically when the key is not set. Never use an sk_live_ key.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const path = require("path");
const Module = require("module");

const fnDir = path.join(__dirname, "..", "..", "functions");
const fnRequire = Module.createRequire(path.join(fnDir, "index.js"));
const key = process.env.STRIPE_TEST_SECRET_KEY || "";
const skip = !key.startsWith("sk_test_") && "set STRIPE_TEST_SECRET_KEY to a Stripe sk_test_ key to run";

let fns;
let stripe;
function load() {
  if (fns) return;
  process.env.STRIPE_SECRET_KEY = key;
  // The email-code step-up (FR04) is covered by tests/functions; here the
  // traveller is treated as having just confirmed the payment code.
  const fsPath = fnRequire.resolve("firebase-admin/firestore");
  const stepUp = { payment: Date.now() + 10 * 60 * 1000 };
  require.cache[fsPath] = {
    id: fsPath, filename: fsPath, loaded: true,
    exports: { getFirestore: () => ({ collection: () => ({ doc: () => ({ get: async () => ({ data: () => stepUp }) }) }) }) },
  };
  fns = fnRequire(path.join(fnDir, "index.js"));
  const Stripe = fnRequire("stripe");
  stripe = new Stripe(key);
}

async function payWith(paymentMethod) {
  load();
  const { clientSecret } = await fns.createPaymentIntent.run({
    auth: { uid: "tc-live-test" },
    data: { amount: 25000, currency: "myr", receiptEmail: "test@voya.app" },
  });
  const id = clientSecret.split("_secret_")[0];
  return stripe.paymentIntents.confirm(id, { payment_method: paymentMethod, return_url: "https://voya.test/return" });
}

test("TC32 Successful payment with test card 4242 4242 4242 4242 (live Stripe test mode)", { skip }, async () => {
  const pi = await payWith("pm_card_visa");
  assert.equal(pi.status, "succeeded");
  assert.equal(pi.amount, 25000);
  assert.equal(pi.currency, "myr");
  assert.equal(pi.metadata.uid, "tc-live-test");
});

test("TC33 Declined card 4000 0000 0000 0002 is refused (live Stripe test mode)", { skip }, async () => {
  await assert.rejects(payWith("pm_card_chargeDeclined"), (err) => {
    assert.equal(err.code, "card_declined");
    return true;
  });
});
