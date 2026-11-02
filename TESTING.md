# Running Voya's test cases

Every test case in Chapter 5 (TC01-TC76) is executed by code, except seven
that need a human (listed at the end). Each test's name starts with its test
case ID, so the results map straight back to the test case table.

| Layer | Folder | What it runs | Needs |
| --- | --- | --- | --- |
| Dart unit | `test/unit/` | Expense split, recommendation, schedule conflicts, transport suggestion, sign-up and hotel-guest validation | Flutter |
| Flutter integration | `integration_test/` | Real repositories and controllers on an Android emulator, against the Firebase emulators with the real `firestore.rules` | Flutter, Android emulator, Firebase CLI, Java 21+ (Android Studio's bundled Java is used automatically) |
| Cloud Functions | `tests/functions/` | The 4 Cloud Functions with an in-memory Firestore and stubbed Stripe | Node.js |
| Web console | `tests/web/` | Admin and partner pages in Chrome via Playwright, against the Firebase emulators | Node.js, Firebase CLI, Java 21+ (Android Studio's bundled Java is used automatically) |
| Live API | `tests/live/`, `integration_test/tc_live_api_test.dart` | Stripe test-mode payments, Duffel flights, OpenAI assistant | Internet, API keys |

Nothing touches the live `voya-f69f0` database: the integration and web tests
run against the local Firebase emulators, which are wiped at the start of each
test file.

## One-time setup (Windows)

1. Java 21 or newer for the Firebase emulators. If your default Java is older, run_tests.ps1 uses the Java 21 bundled with Android Studio automatically.
2. Firebase CLI: `npm install -g firebase-tools` (already installed if you deploy from this PC).
3. In this folder: `flutter pub get`
4. Cloud Functions packages: `cd functions; npm ci; cd ..`
5. Playwright: `cd tests; npm install; npx playwright install chromium; cd ..`
6. Start an Android emulator from Android Studio (Device Manager > Play).

## Run everything

```powershell
.\run_tests.ps1
```

Or one layer at a time: `.\run_tests.ps1 -Only unit`, `-Only functions`, `-Only integration`, `-Only web`, `-Only live`.

On a real phone instead of the emulator, use your PC's LAN IP:
`.\run_tests.ps1 -Only integration -EmulatorHost 192.168.1.20` (phone and PC on the same Wi-Fi).

Stripe test-mode payments (TC32/TC33 for real): `$env:STRIPE_TEST_SECRET_KEY = "sk_test_..."` before running. Never use an `sk_live_` key.

## Results

`test_results\` gets:

- `by_test_case.csv` - one row per test case: Status, tests passed, how it was executed, Actual result. Paste into the test case table.
- `summary.md` - the same as a readable table.
- `summary.csv` - every individual test.
- `web-artifacts\` - screenshots of any failed web test.

## Manual test cases

These open screens outside Voya (Google's account picker, Android's permission
dialog, the phone dialer, the share sheet), which automation cannot drive:
TC04 (Google account picker), TC24 (location permission), TC59 (phone dialer), TC60 (share sheet).
Do them on the phone, write PASS or FAIL in `test_results\manual_results.csv`, then run
`node tools/collect_results.js` to add them to the summary.

TC08 (draft-save dialog), TC63 (screen response time) and TC68 (taps to each feature)
are automated in `integration_test/tc_ui_test.dart`.

## Expected failures

None. TC05 (FR04), TC27b, TC36b (FR86) and TC61 (FR96) used to fail on purpose;
those requirements are now implemented and the tests are expected to pass.
