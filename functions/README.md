# Voya Cloud Functions — Stripe (test mode)

One function, `createPaymentIntent`, so the Flutter app's Stripe *secret*
key never has to live inside the app (see `lib/config/secrets.dart`'s
comment on why that matters — a secret key shipped in the APK is a secret
key anyone can pull back out).

This is all done with Stripe's **test mode** — no real card is ever
charged, and no real money moves, no matter how many times you pay through
the app. You can use this safely for demos/marking without a real
merchant account.

## 1. Get your Stripe test keys

1. Go to https://dashboard.stripe.com/register and sign up (free, no
   business verification needed to use test mode).
2. Once in the Dashboard, make sure the **Test mode** toggle (top right) is
   ON.
3. Go to **Developers → API keys**. You'll see two keys:
   - **Publishable key** (`pk_test_...`) — paste this into
     `lib/config/secrets.dart`'s `stripePublishableKey`.
   - **Secret key** (`sk_test_...`) — do **not** put this in the Flutter
     app anywhere. It goes into this function's secret config in step 3
     below.

## 2. Make sure this Firebase project is on the Blaze plan

Cloud Functions need to make outbound calls to Stripe's API, which the
free Spark plan doesn't allow. In the
[Firebase Console](https://console.firebase.google.com/project/voya-f69f0/usage),
check the plan shown at the top. If it says Spark, click **Upgrade** and
switch to **Blaze** (pay-as-you-go — needs a credit card on file, but the
Cloud Functions free tier and Stripe test-mode calls used here won't
generate real charges at FYP/demo scale).

## 3. Install the Firebase CLI and log in

From this `functions/` folder's parent (the project root):

```bash
npm install -g firebase-tools
firebase login
```

`firebase login` opens a browser window for you to sign in with the
Google account that owns the `voya-f69f0` project — this step has to be
done by you interactively, it can't be scripted.

## 4. Set the secret key

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
```

Paste your `sk_test_...` key when prompted. This stores it in Google Cloud
Secret Manager, scoped to this project — it's never written to a file in
this repo, so it can't accidentally get committed.

## 5. Install dependencies and deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

The first deploy takes a minute or two. Once it finishes, the Flutter
app's "Pay" button (Flight/Hotel detail pages) will actually reach this
function.

## Testing a payment

Stripe's Payment Sheet (what the app shows when you tap Pay) accepts these
official test card numbers in test mode — any future expiry date, any
3-digit CVC, any postcode:

- `4242 4242 4242 4242` — succeeds
- `4000 0000 0000 0002` — declined (to test the failure path)

Full list: https://docs.stripe.com/testing#cards

## Updating later

If you ever change `functions/index.js`, redeploy with:

```bash
firebase deploy --only functions
```

You do **not** need to redeploy for a Flutter-only change (e.g. editing
`booking_payment_page.dart`) — only when `functions/` itself changes.
