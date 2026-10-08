# Voya — Admin & Insurance Partner Console

Plain HTML/CSS/JS, no build step, no framework. Opens as regular files —
in Android Studio it's just another folder in the project tree; to run it,
open any `.html` file in a browser (right-click → *Open in Browser*, or
double-click the file in File Explorer). It talks to the **same Firebase
project** (`voya-f69f0`) as the Flutter app, using the Firebase JS SDK
loaded straight from Google's CDN — nothing to install.

## What's here

- `index.html` — picks Admin Console or Insurance Partner Console.
- `admin/` — Dashboard, User Management, Content Moderation, Attraction
  Management, Insurance Management, Analytics & Reporting, System Settings.
- `partner/` — Dashboard, Insurance Plans, Transactions, Refunds & Claims
  (+ Claim Detail), Reports, Organization Profile, System Settings, plus
  `register.html` for partner self-registration.
- `setup-admin.html` — one-time tool to create your **first** admin account.
- `css/`, `js/` — shared design system and Firebase data layer. `js/data.js`
  is the one place that talks to Firestore; `js/seed.js` is the demo-data
  tool (mirrors the Flutter app's own `dev_seed_service.dart` pattern).

## One-time setup

1. **Enable Email/Password sign-in.** Firebase console → your project →
   Authentication → Sign-in method → enable *Email/Password* (the Flutter
   app already needs this, so it's likely on already).
2. **Deploy the updated security rules.** Two files at the *Voya project
   root* were updated to support this console (new collections, admin/partner
   roles): `firestore.rules` and `storage.rules`. Paste their contents into
   Firebase console → Firestore Database → Rules / Storage → Rules and
   publish, or run `firebase deploy --only firestore:rules,storage` from the
   project root if you have the Firebase CLI set up. **The console won't
   work correctly until these are deployed** — the old rules don't know
   about `admins`, `insurance_partners`, `insurance_plans`, `claims`, etc.
3. **Create your first admin account.** Open `setup-admin.html` in a
   browser, fill in your name/email/password, submit. Then delete this file
   (or at least stop linking to it) — anyone who can open it can create an
   admin account, since there's no server here to gate that more strictly
   (see the comment above `admins/{uid}` in `firestore.rules`).
4. **Log in** at `admin/login.html`. From *System Settings* you can approve
   Insurance Partner registrations (they self-register at
   `partner/register.html` → `login.html`, starting as "Pending" until you
   approve them).
5. **Seed demo data.** Claims, transactions, plans and partner
   organizations don't exist yet — the mobile app doesn't generate them.
   Use the "Seed demo data" button (Admin → Insurance Management, or
   Partner → Dashboard) to populate realistic sample rows so every screen
   has something to show. It never overwrites real data, and "Clear demo
   data" (System Settings, both sides) removes only what it created.

## What's real vs. what's a deliberate simplification

**Real, shared with the mobile app:**
- `users` (User Management edits real accounts — role/status only),
- `posts` (Content Moderation approves/removes real community posts),
- `catalog_attractions` (Attraction Management edits the same catalogue
  Explore reads from — add/edit/delete here shows up in the app),
- Firebase Auth (the same project; partner logos go to the same Storage
  bucket under `partner_logos/`).

**New collections, console-only for now:** `admins`, `insurance_partners`,
`insurance_plans`, `insurance_transactions`, `claims`, `moderation_log`.
These didn't exist before this console — the mobile app's insurance flow
still uses a hardcoded plan list (`lib/models/insurance_models.dart`) and
only writes a loosely-typed purchase record to `users/{uid}/bookings`
(title/subtitle/trailing strings, no structured premium/provider fields).
Rather than guess-parsing that string format, this console keeps its own
structured collections. **A natural next step** (not done here, to keep
this console's scope self-contained): wire the Flutter purchase flow to
also read plans from `insurance_plans` and write to
`insurance_transactions`, so a real in-app purchase shows up here too.

**Other simplifications, clearly flagged in the UI where relevant:**
- The trend line on every stat card (e.g. "↑ 4.2% from last month") is a
  real delta computed client-side from each record's own `createdAt`/
  `timeline` — see monthDelta/pointDelta/sumInMonth/countByStatusInMonth in
  `js/ui.js`. A metric with no honest baseline to compare against (a
  "Pending …" queue, a status with no real temporal correlation like
  "Suspended") renders as a plainCard with no delta instead of faking one.
- "Suspending" a user only sets a Firestore flag; the mobile app doesn't
  currently check it at login, so a suspended user isn't actually blocked
  yet (a real deployment would add that check to `auth_controller.dart`).
- Claims have no submission flow in the mobile app yet, so Partner →
  Refunds & Claims has a "New claim" button to file one manually (e.g. when
  a customer calls in) in addition to what the demo seeder creates.

## Design notes

Colors/typography were sampled from your Figma export (`Voya 9.zip`) —
navy `#0e3a52` sidebar, teal `#1c7d8c` accents, the same card/table/badge
language across every screen. Icons are a small hand-built inline-SVG set
(`js/icons.js`) — no icon font or extra CDN — which also fills in the
icon-less stat cards from the mockup (Insurance Management, Analytics &
Reporting, Insurance Plans, Refunds & Claims all had empty circles in the
Figma file).
