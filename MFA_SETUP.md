# Two-step verification (FR04) - setup

Voya always asks for a 6-digit code sent to the traveller's email:

| When | Code needed? |
| --- | --- |
| Sign up | Yes - the account cannot be used until the code is entered |
| Sign in on a phone trusted in the last 30 days | No - password only |
| Sign in on a new phone, or after 30 days | Yes - then that phone is trusted for 30 days |
| Payment, change password, change email, delete account | Yes - a fresh code each time |

Code: `functions/email_code.js` (Cloud Functions `sendVerificationCode`, `verifyCode`),
`lib/services/verification_service.dart`, `lib/views/auth/otp_verification_page.dart`.
Codes are stored only as SHA-256 hashes, expire after 10 minutes, can be re-sent
once a minute, and lock after 5 wrong tries. `createPaymentIntent` refuses to
charge without a payment code confirmed in the last 10 minutes.

## One-time setup

1. Pick the Gmail account that sends the codes (e.g. a new voya.noreply@gmail.com).
2. On that account turn on 2-Step Verification, then create an **App password**:
   Google Account > Security > App passwords. Copy the 16-character password.
3. In PowerShell, in this folder (paste the values when asked - never put them in code):
   ```
   firebase functions:secrets:set GMAIL_USER
   firebase functions:secrets:set GMAIL_APP_PASSWORD
   ```
4. Install packages and deploy:
   ```
   flutter pub get
   cd functions; npm install; cd ..
   firebase deploy --only functions,firestore:rules
   ```
5. Try it: sign up with a real email address; the code arrives within a few seconds
   (check Spam the first time).

Accounts created before this change will be asked to verify their email the next
time they sign in. Privacy and Security > "Sign Out of Trusted Devices" makes every
phone ask for a code again.
