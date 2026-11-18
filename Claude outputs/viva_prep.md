# Voya — Viva Prep: Algorithms & File Guide

Written 2026-11-16. Scope: where the 5 submitted FYP algorithms actually live in the
code, exactly how each one works, plus a file-by-file map of the whole codebase
(`lib/`, `functions/`, `admin_web/`) so you can point to any file during questioning.

---

## Part 1 — The 5 algorithms (matched to your submitted documentation)

These were explicitly audited against your submitted algorithm doc on 2026-10-24 and
corrected until they matched exactly. This is the order examiners usually ask in
(Expense → Vote → Recommendation → Optimise → AI-Summarise).

### 1. Shared-Expense Distribution (splitting a bill)

**File:** `lib/repositories/trip_repository.dart` (top-level functions, ~line 600-665)

- `splitExpenseEqual(totalAmount, memberUids)` — **integer-cents + largest-remainder
  method**:
  1. Convert RM to cents: `totalCents = round(totalAmount * 100)` (`_expenseToCents`).
  2. `baseShare = totalCents ~/ n` (integer division), `remainder = totalCents % n`.
  3. The first `remainder` members (by list order) get `baseShare + 1` cents; everyone
     else gets `baseShare`. This guarantees the shares sum to *exactly* the total cent
     for cent — no floating-point drift from naive `total / n` division.
- `splitExpenseCustom(totalAmount, customShares)` — validates the user-entered shares
  sum to the total (in cents) before accepting them; throws otherwise.
- `splitExpenseItemized(items)` — same largest-remainder method, but run *per line
  item* (each item's price split only among its own assignees), then the per-person
  cents are summed across all items.
- `addExpense` / `updateExpense` write the result atomically via a Firestore batch.

**Why this matters for viva:** naive splitting (`amount / n` as a double, formatted to
2dp) loses or gains cents when `n` doesn't divide evenly — e.g. RM10 / 3 = RM3.33,
3.33×3 = RM9.99, 1 cent vanishes. The largest-remainder method is the standard
apportionment algorithm (used in real-world seat-apportionment problems) that
guarantees the parts sum exactly to the whole.

### 2. Group Voting (polls)

**Files:** `lib/repositories/trip_repository.dart` (`castVote`, ~line 1340),
`lib/controllers/vote_controller.dart`, `lib/views/vote/vote_tab.dart`,
`firestore.rules`

- `castVote` runs inside a **Firestore `runTransaction`** (not a plain write) so the
  check-then-write is atomic against concurrent voters:
  1. Re-read the live poll doc and trip doc *inside* the transaction (never trust
     cached state).
  2. Reject if the poll doesn't exist, or is closed.
  3. Reject if the caller isn't an active member of the trip.
  4. Reject if the option no longer exists.
  5. Duplicate-vote rule: **single-choice** polls reject if the member voted for *any*
     option already; **multi-choice** polls only reject a repeat of the *same* option
     (so they can still tick other options).
  6. On success: `arrayUnion` the uid into that option's `votedBy` and
     `increment(1)` its `voteCount` — both in the same transactional update.
- A rejected transaction surfaces as a `SnackBar` in `vote_tab.dart`'s `_castVote`
  handler, instead of failing silently.
- `firestore.rules`: a vote-cast update is restricted to `hasOnly(['options'])` — a
  voter's write can never also rewrite the poll's title/deadline.

**Why this matters:** a plain (non-transactional) read-modify-write has a race
condition — two members voting at the same instant can both read `voteCount: 3` and
both write `4`, losing one vote. The transaction forces Firestore to retry on
conflict so this can't happen.

### 3. AI-Based Attraction Recommendation — **this is the Explore ranking you asked about**

**Files:**
- `lib/services/recommendation_service.dart` — the scoring/ranking algorithm itself.
- `lib/services/opening_hours.dart` — "is this place open right now" helper.
- `lib/repositories/catalog_repository.dart` — writes `distanceKm`, `lat`/`lng`,
  `facilities`, and tracks the per-user **affinity** counters.
- `lib/views/explore/explore_page.dart` (`_visibleAttractions` getter, ~line 317) —
  where it's actually called from.
- `lib/views/filter/filter_page.dart`, `lib/controllers/filter_controller.dart` —
  "Open now" / "Wheelchair accessible" toggles that feed the mandatory constraints.

**How it works, step by step:**

1. **Mandatory constraints first** (`passesMandatoryConstraints`) — a place that fails
   any of these is **dropped entirely**, never just ranked lower:
   - Over budget (`withinBudget`, from the price filter).
   - `requireAccessible` is on and the place has no `"Wheelchair accessible"` facility
     (from OSM's `wheelchair` tag).
   - `requireOpenNow` is on and `isOpenNow()` returns `false` (parses OSM
     `opening_hours` syntax, e.g. `Mo-Fr 09:00-18:00`, falling back to this app's own
     `"Daily, 9 AM - 6 PM"` text; returns `null` — treated as "don't know, don't
     exclude" — when it genuinely can't tell).
2. **Weighted score** for every survivor:

   ```
   Score(a) = 0.30·Preference + 0.25·Rating + 0.20·Distance + 0.15·Budget + 0.10·Schedule
   ```

   (weights sum to 1; this is `RecommendationWeights` and is identical in shape for
   restaurants — cuisine affinity instead of category affinity — and hotels, which
   drop Distance/Schedule since there's no real signal for either and use
   0.40/0.35/0.25 across Preference/Rating/Budget instead.)

   - **Preference** = `Σ affinity[tag] for tag in place.categoryTags`, normalised by
     the single highest affinity value the user currently has (`maxAffinity`), clamped
     to [0,1]. 0.5 (neutral) if the user has no affinity data yet.
   - **Rating** = `rating / 5.0`, clamped. 0.5 if unrated.
   - **Distance** = `1 / (1 + km/10)` — a decay curve: 0km → 1.0, 10km → 0.5, 100km →
     ~0.09. 0.5 if no coordinates known.
   - **Budget** = 1.0 if within budget, else 0.0 (redundant with the mandatory filter
     above but kept so the *margin* between two in-budget places still reflects it if
     the formula is reused standalone).
   - **Schedule** = 1.0 if open now, 0.0 if closed, 0.5 if unknown.
3. **Sort** descending by score; ties break by original catalog order (stable sort via
   index as a tiebreaker) so the ranking is deterministic.

**Where the "Preference" affinity numbers come from** (the personalisation signal):
`lib/repositories/catalog_repository.dart` keeps a per-user Firestore counter
(`users/{uid}.attractionCategoryAffinity`, a `Map<String tag, int count>`):
- **+1** every time the user opens an attraction's detail page (`recordAttractionView`).
- **+5** every time the user favorites one (`_bumpAffinity`, `_favoriteAffinityWeight`)
  — a deliberate signal than a view: a favorite is explicit intent, a view might just
  be curiosity.
`lib/controllers/explore_controller.dart` subscribes to this via
`watchAttractionCategoryAffinity(uid)` and blends in the trip's declared interests
(Beach/City/Nature/Culture/...) from `interest_mapping.dart`'s
`blendInterestsIntoAffinity` as an extra tiebreaker, so a brand-new user with zero
browsing history still gets something non-random based on what they picked when
creating the trip.

**One-sentence answer if asked "what kind of recommender system is this":** a
**weighted linear scoring model with hard (mandatory) constraint filtering applied
first** — not collaborative filtering (no other users' data is used) and not a
trained ML ranking model; it's a transparent, explainable multi-criteria formula,
which is a deliberate choice for an explainable "why am I seeing this" UX.

### 4. Optimised Itinerary Generation ("Optimise" button)

**Files:** `functions/optimise.js` (Cloud Function entry point),
`functions/optimise_engine.js` (the actual algorithm), `functions/maps_service.js`
(distance/time estimator), `lib/services/itinerary_optimise_service.dart` (client call),
`lib/views/group/optimise_sheet.dart` (UI)

This is a **real two-opt local-search algorithm**, not an AI call — "Optimise" has
never called an LLM; the FYP doc's "Maps service" dependency is satisfied by
`maps_service.js`, a small haversine-distance module shaped like a swappable
Maps-API abstraction (so it could later be replaced by a real paid Google Maps Distance
Matrix call without touching any caller).

**`functions/maps_service.js`:**
- `kmBetween(a, b)` — haversine-style great-circle distance from two `{lat, lng}`.
- `estimateTravelMinutes(a, b)` — real distance ÷ 25 km/h average speed (min 10 min)
  **if both points have coordinates**; otherwise falls back to a same-district /
  different-district heuristic (15 min / 30 min), or 20 min if even the district is
  unknown.

**`functions/optimise_engine.js` — the scheduling pipeline:**
1. `profile(item, known)` — classifies every activity: is it a meal, a fixed booking
   (flight/hotel check-in), time-bound (sunrise/sunset/night-only), a full-day place,
   or "daytime-only" (museums/temples/gardens — via a keyword/slot check)? Also reads
   its preferred time slot and visit duration from a gazetteer/alias lookup.
2. **Whole-trip mode** does, in order:
   - a full-day place claims its own day;
   - a day that's too short hands activities to the day with the most free time;
   - `fixLate` moves anything that would start at/after 17:30 (or past day-end) to a
     day it actually fits in;
   - places sharing a district are grouped onto the same day (never splitting a
     district group unless a day already has >3 sights, `MAX_SIGHTS`);
   - `fixLate` runs a second time to catch anything the balancing step displaced.
3. **Within a day**, activities are grouped into contiguous **blocks** by district
   (`toBlocks`); anchors (meals, sunrise/sunset/night slots, full-day places) are never
   moved.
4. **`twoOptReorder`** — the actual two-opt pass. Between two consecutive anchors, it
   repeatedly tries **reversing every possible sub-segment** of the movable blocks and
   keeps the reversal only if it increases the total utility:

   ```
   utility = Σ [ recommendationScore(place) − costPenalty(place) ]
             − Σ [ travelTimePenalty(minutes between consecutive blocks) ]
   ```

   - `recommendationScoreOf` = `rating / 5`, clamped, 0.5 if unrated.
   - `costPenaltyOf` = price string parsed to a number ÷ 200, clamped to [0,1]; 0 if
     free, 0.2 if unparseable.
   - `travelTimePenaltyOf(minutes)` = `minutes / 60`, clamped to [0,1].
   - Per-place terms (recommendationScore, costPenalty) are identical no matter how the
     *same set* of places is ordered, so they mathematically cancel out of the
     *comparison* between two orderings — only the travel-time term (which genuinely
     depends on sequence) decides which ordering wins. This is intentional, not a
     shortcut: it keeps the formula matching the documentation's exact shape while the
     actual decision variable is still correct.
   - The search repeats until no reversal improves utility or 200 iterations pass
     (`guard`), classic 2-opt termination.
5. Each day's final slot assignment (`scheduleDay`) places fixed items first, then flex
   items by slot preference, inserting 15/30-minute travel gaps between different
   districts, nudging anything that collides with another booked slot forward in
   15-minute steps, and keeping a sight from running more than 30 minutes into a
   meal window.
6. Every change returned carries a human-readable `reason` string (e.g. "moved to Day
   2 — shares a district with 3 other places"). Anything still unfixable comes back in
   `notes` (in single-day mode, suggesting "try Optimise Whole Trip" instead).

**This activated previously-dead code:** `optimise_engine.js` already had the
proximity/district-grouping logic and `functions/itinerary.js` already *read*
`lat`/`lng` off catalog docs — but nothing on the Flutter side ever *wrote* those
fields, so the real-distance path never actually ran until `catalog_repository.dart`'s
OSM refresh was extended to also persist `lat`/`lng` (and `distanceKm`).

### 5. AI-Summarised Itinerary ("AI Summarise" button)

**Files:** `functions/itinerary.js` (`generateItinerary`, the Cloud Function),
`functions/itinerary_engine.js` (`buildItinerary`), `functions/itinerary_prompt.js`
(parsing/resolving), `functions/planner/` (`places.js`, `decide.js`, `needs.js`,
`schedule.js`, `logistics_plan.js`, `osm_places.js`, `vote_days.js`),
`functions/discussion_summary/` (the trained decision/classification model),
`lib/services/itinerary_ai_service.dart`, `lib/views/group/ai_itinerary_sheet.dart`

**Important framing for viva:** the FYP doc's "AI service" dependency is **Voya's own
locally-trained model** (TF-IDF + Linear SVM classifier, trained on your own labelled
chat data — see Part 2), *not* a live call to Gemini/OpenAI/ChatGPT. The 2026-10-13
session explicitly removed Gemini from this feature for exactly this reason (free-tier
rate limits were causing real production errors, and the doc never actually required
a 3rd-party LLM — it required "an AI service", which your own trained model satisfies).
A tiny bounded OpenAI call (capped at 1,000,000 tokens total, tracked in
`functions/openai_budget.js`) is used only as a narrow fallback for naming/day
disambiguation the rule engine can't resolve on its own — this is optional and the
feature works without it.

`generateItinerary` is restructured into the documented 12-step pipeline, explicitly
numbered in the code:

1. **Consent gate** — the Cloud Function rejects any call where
   `request.data.consent !== true`. The Flutter sheet shows a real "Let AI Summarise
   read this chat?" dialog before the *first* read for a job; re-opening an
   already-running/ready job skips it (not a new read each time).
2. **Retrieve** — pulls the last `MAX_MESSAGES` chat messages, saved places, the
   destination's catalog places, saved hotels, and votes, all in parallel
   (`Promise.all`).
3. **Filter** — drops empty/non-text messages; keeps only messages with real content.
4. **Extract** — inside `planner/places.js`: a chat line becomes a candidate place only
   if it names a *real* place, matched in priority order against (a) the trip's saved
   list, (b) the destination's Firestore catalog, (c) a 235-place/15-city gazetteer
   built from a hand-curated knowledge base (`ml/discussion_summary/kb.py` →
   `gazetteer.json`) with Chinese aliases, districts and visit-hour data, (d) a
   name-pattern matcher for Chinese place-suffix words (…路/…寺/…园 etc.) with a strict
   exclude-list so chit-chat ("走路", "逛街") isn't mistaken for a place name.
5. **Decide** — `planner/decide.js` attaches every message's *stance* (agree / object /
   doubt / hesitate) to the place it's replying about, using a thread model (a
   discussion about one place stays "open" across up to 10 replies / 5 messages).
   Objection detection is a strict explicit-phrase match (not "any negative word") —
   e.g. "不要每一句都讲食物" (banter) is correctly *not* an objection, but "不要去"/"skip"
   is. The **decision rule is silence-is-consent**: a place is "agreed" if someone
   proposed it and nobody explicitly objected, not simple majority vote. Short replies
   (≤12 characters, e.g. "ok", "好") use the trained classifier's lexicon score; longer
   replies use rule-based phrase matching.
6. **Build prompt** — `buildPrompt()` assembles one structured object (messages,
   members, days, current plan, saved/catalog places, the loaded model, destination,
   logistics window, flights/hotels, votes, declared interests) — this *is* the input
   handed to "the AI service" (your own model), replacing what would otherwise be a
   literal text prompt to a 3rd-party LLM.
7. **Submit & parse** — `submitAndParse()` calls `buildItinerary(prompt)` (runs the
   local model/rules) and parses its JSON answer; returns `null` cleanly on a bad
   parse rather than throwing, so step 9 can retry.
8. **Validate** — `resolveItineraryAnswer` + a logistics-window filter drop any
   suggestion that falls outside the trip's actual flight/hotel-constrained time
   window (e.g. an activity before the flight lands).
9. **Regenerate on failure** — a bounded retry loop (max 2 attempts): a genuine parse
   failure (not "nothing to suggest", which is a valid, different answer) retries once
   using only the most recent half of the discussion, so the retry is a meaningfully
   different input, not a repeat of the same deterministic one.
10-12. **Display / review / confirm-to-save** — the Flutter sheet (`ai_itinerary_sheet.dart`)
    shows every suggested add/update/remove as a **tick-list**; nothing is written to
    the trip plan until the user explicitly ticks items and presses Apply.

**Logistics layer** (shared with Optimise): `planner/logistics_plan.js`'s
`tripLogistics()` turns booked/typed flights and hotel stays into fixed "busy slots" —
arrival day starts 90 minutes after landing, the last day ends 3 hours before the
return flight, a booked hotel occupies 15:00 check-in / 11:00 check-out.

---

## Part 2 — The ML layer underneath AI-Summarise: TF-IDF + Linear SVM

**Files:** `ml/discussion_summary/train_classifier.py` (training),
`ml/discussion_summary/features.py` (feature extraction),
`functions/discussion_summary/` (the runtime that loads and uses the trained model
inside the Cloud Functions).

- **Task**: classify each chat message into a topic label (`ATTRACTION`,
  `ACCOMMODATION`, `TRANSPORT`, `OTHER`, plus more granular labels for your own
  hand-labelled data) so the planner knows which messages are "about a place" at all.
- **Experiment A** (`train_classifier.py`) compares four models under identical
  5-fold **GroupKFold** cross-validation (grouped by chat, so messages from the same
  conversation never leak across the train/validation split):
  - Majority-class baseline (`DummyClassifier`)
  - Multinomial Naive Bayes
  - Logistic Regression
  - **Linear SVM** (`LinearSVC`) — this is the one actually shipped
  - Compared on word n-grams vs character n-grams, with/without money·date·question
    tag features.
- Features: `TfidfVectorizer` (TF-IDF weighting) over the chosen n-gram representation,
  in an sklearn `Pipeline` with the classifier.
- The selected configuration is refit on **all** training data, then scored once (never
  tuned again) on held-out splits: `test_seen`, `test_unseen` (destinations never in
  training — proves it generalises, not memorises places), `test_challenge`,
  `test_smalltalk`, `test_real` (genuine scraped/collected chat text), `test_public`,
  `test_offtopic`.
- Output: `models/classifier.joblib` (the fitted pipeline), loaded at runtime by
  `functions/discussion_summary/load_model.js` → `model.json` / `runtime.js`, and used
  by both `generateItinerary` (step 5 above) and the separate Discussion Summary
  feature (`functions/discussion_summary/summariser.js` — importance scoring +
  TextRank/cosine-similarity sentence extraction, rule-based decision resolution).

**One-line answer if asked "is AI Summarise powered by a neural network / LLM":** no —
message topic classification is a **TF-IDF + Linear SVM** classifier you trained and
evaluated yourself (with a documented GroupKFold cross-validation methodology and
seen/unseen test splits), and the actual plan-building logic on top of it is
rule-based (stance detection, place extraction, consent-based decisions), not a
generative model. A tiny bounded OpenAI call is an optional fallback for edge cases
only.

---

## Part 3 — File-by-file map

### `lib/controllers/` — one controller per screen/feature (state + business logic, no UI)

| File | What it's for |
|---|---|
| `attraction_chat_controller.dart` | State for the "ask about this attraction" AI chat sheet |
| `auth_controller.dart` | Login/signup/forgot-password/OTP flow state |
| `booking_details_controller.dart` | Flight/hotel detail-page booking state |
| `booking_payment_controller.dart` | Payment step for a flight/hotel/insurance booking |
| `bottom_nav_controller.dart` | Which bottom-nav tab is selected |
| `community_controller.dart` | Community feed: create/edit posts, moderation flag handling (`lastPublishWasFlagged`) |
| `create_plan_wizard_controller.dart` | The multi-step "create a new trip" wizard |
| `detail_page_controller.dart` | Shared state for attraction/restaurant/hotel/place detail pages |
| `expenses_controller.dart` | Expense tab: list, filters, settle-up state |
| `explore_controller.dart` | Explore tab: loads attractions/restaurants/hotels, owns affinity subscriptions (Part 1 §3) |
| `filter_controller.dart` | Filter-sheet state (price/category/cuisine/open-now/accessible toggles) |
| `group_settings_controller.dart` | Group info/settings page state |
| `group_trip_controller.dart` | The main Group Trip page: day tabs, chat, votes, AI Summarise/Optimise triggers |
| `insurance_controller.dart` | Insurance plan browsing/quote/purchase state |
| `near_by_controller.dart` | "Near By" tab: nearby places by category |
| `notifications_controller.dart` | In-app notification list state |
| `onboarding_controller.dart` | First-run onboarding wizard |
| `plan_page_controller.dart` | The "Plan" tab (list of the user's trips) |
| `profile_controller.dart` | Profile tab state |
| `saved_items_controller.dart` | "Saved" list (favorited places) state |
| `vote_controller.dart` | Vote/poll creation and `castVote` call site (Part 1 §2) |

### `lib/repositories/` — Firestore read/write layer (no UI, no widget state)

| File | What it's for |
|---|---|
| `booking_repository.dart` | Flight/hotel booking documents |
| `catalog_repository.dart` | Shared catalog (attractions/restaurants/hotels from OSM/RollingGo/Duffel) + affinity counters (Part 1 §3) |
| `community_repository.dart` | Community posts: create/report/moderation flags (`autoFlagged`) |
| `country_emergency_repository.dart` | Per-country emergency contact numbers |
| `discussion_decisions.dart` | Reads/writes a trip's resolved discussion decisions |
| `friends_repository.dart` | Friends list |
| `insurance_chat_repository.dart` | Insurance partner ↔ traveller messaging |
| `insurance_repository.dart` | Insurance plans/purchases/claims |
| `notifications_repository.dart` | In-app notification documents |
| `review_helpers.dart` | Shared review-reporting/moderation logic reused by multiple review types |
| `trip_plan_edits.dart` | Low-level plan-item mutations (add/move/remove/setTime) used by AI Summarise & Optimise appliers |
| `trip_repository.dart` | The big one: trips, days, expenses (Part 1 §1), votes (Part 1 §2), chat |
| `user_repository.dart` | User profile documents |

### `lib/services/` — everything that isn't a direct Firestore CRUD op

| File | What it's for |
|---|---|
| `attraction_chat_service.dart` / `attraction_report_service.dart` | AI Q&A about an attraction; "report this place" |
| `auth_service.dart` | Firebase Auth wrapper (sign-in/up, MFA/step-up email code) |
| `avatar_service.dart` | Avatar upload/URL handling |
| `booking_document_service.dart` / `flight_document_service.dart` / `hotel_document_service.dart` / `claim_document_service.dart` | PDF/file upload for bookings & insurance claims |
| `chat_attachment_service.dart` / `community_media_service.dart` | Media upload for chat/community posts |
| `content_moderation_service.dart` | Local profanity check + `moderateText` Cloud Function call (see the content-moderation test you ran earlier) |
| `currency_service.dart` | Live FX rates |
| `discussion_summary_service.dart` | Client call to the Discussion Summary Cloud Function |
| `duffel_api_service.dart` / `rollinggo_api_service.dart` / `places_api_service.dart` | 3rd-party API wrappers (flights/hotels, hotel aggregator, places) |
| `format_utils.dart` | Shared text/date formatting helpers |
| `interest_mapping.dart` | Blends a trip's declared interests into affinity scores (Part 1 §3) |
| `itinerary_ai_service.dart` | Client call to `generateItinerary` (AI Summarise, Part 1 §5) |
| `itinerary_export_service.dart` | PDF/image export of an itinerary |
| `itinerary_optimise_service.dart` | Client call to Optimise (Part 1 §4) |
| `itinerary_summary_service.dart` | Client call to Discussion Summary |
| `location_service.dart` / `traffic_service.dart` / `weather_service.dart` | Device location, live traffic, live weather widgets |
| `maps_service.dart` | Client-side `LatLng` + map-launch helpers (distinct from `functions/maps_service.js`, which is server-side distance estimation) |
| `name_translation_service.dart` | Place-name translation (Gemini-based) |
| `opening_hours.dart` | "Is this open now" parser (Part 1 §3) |
| `paypal_service.dart` / `stripe_service.dart` | Payment processing |
| `pdf_report_service.dart` | Admin-side report PDF generation helper shared with Flutter where applicable |
| `receipt_ocr_service.dart` / `receipt_service.dart` | Expense receipt photo → OCR → pre-filled expense form |
| `recommendation_service.dart` | **The Explore ranking algorithm** (Part 1 §3) |
| `trip_cover_service.dart` | Trip cover photo selection |
| `verification_service.dart` | Partner/account verification flows |
| `vote_resolution_service.dart` | Resolves a closed vote's winning option |

### `lib/views/` — grouped by feature folder

- **`auth/`** — login, signup, forgot-password, OTP/step-up verification, splash screen.
- **`community/`** — social feed: post list, create/edit post, post detail, author profile, "my posts", picking an itinerary to attach to a post.
- **`create_plan/`** — the new-trip wizard screen.
- **`detail/`** — attraction/restaurant/hotel/flight/place detail pages, reviews, booking payment, passenger/guest detail entry, shared detail widgets (incl. `person_info_sheet.dart`'s sibling for reviews).
- **`expenses/`** — expense tab, add-expense flow (choice → form/itemized/custom-split), friend picker, transaction detail.
- **`explore/`** — **the Explore tab** (`explore_page.dart` — ranking call site), saved items, attraction AI-chat page.
- **`filter/`** — the shared filter bottom sheet for attractions/restaurants/hotels.
- **`group/`** — the Group Trip page itself plus everything inside it: day timeline, AI Summarise sheet, Optimise sheet, decide-now sheet, flight/hotel add & detail pages, group info/settings, embassy/emergency pages, live conditions card, member location, invite/scan QR, join trip.
- **`home/`** — the Home tab.
- **`insurance/`** — insurance browsing, plan compare/detail, quote, payment method, traveller details, claim/refund, partner chat/messages.
- **`near_by/`** — the Near By tab.
- **`notifications/`** — in-app notification list.
- **`onboarding/`** — first-run wizard.
- **`payment/`** — payment method picker, PayPal checkout.
- **`plan/`** — the Plan tab (trip list).
- **`profile/`** — profile, account settings, friends, history, privacy/security, help/support, blocked users, report-attraction.
- **`shared/`** — reusable widgets: bottom nav, budget picker, dialogs/pickers, interest grid, maps launcher, member-select, `person_info_sheet.dart` (tap a passenger/guest row to see their details), phone input.
- **`vote/`** — create a vote, pick a saved item to vote on, the vote tab itself.

### `lib/models/`, `lib/data/`, `lib/config/`

- **`models/`** — plain data classes mirroring Firestore docs (one per feature: booking, community, day-plan, duffel/flight, explore, filter, group, insurance, itinerary-detail, nearby, plan-page, profile, review).
- **`data/`** — static reference data: airlines, countries, country codes/areas/gateways, emergency info defaults, Malaysia airports, popular destinations.
- **`config/secrets.dart`** — API keys (Gemini, etc.) — not committed with real values in a shared repo context.

### `functions/` (Firebase Cloud Functions, Node.js)

| File | What it's for |
|---|---|
| `index.js` | Registers/exports every Cloud Function |
| `itinerary.js` / `itinerary_engine.js` / `itinerary_prompt.js` | **AI Summarise** (Part 1 §5) |
| `optimise.js` / `optimise_engine.js` / `optimise_prompt.js` (prompt file now dead/removed) | **Optimise** (Part 1 §4) |
| `maps_service.js` | Distance/time estimator shared by Optimise & AI Summarise logistics |
| `logistics.js` | Flight/hotel-aware day-window computation |
| `content_moderation.js` | `moderateText` — the OpenAI Moderation API call-through for community posts/reviews |
| `email_code.js` | MFA/step-up email verification code send+check |
| `expense_reminders.js` | Scheduled reminders for unpaid expenses |
| `mailer.js` / `policy_email.js` / `post_rejected_email.js` | Transactional emails (policy documents, moderation rejection notices) |
| `notification_cleanup.js` | Scheduled stale-notification pruning |
| `paypal.js` | PayPal server-side order/capture |

### `functions/planner/` — supports both AI Summarise and Optimise

| File | What it's for |
|---|---|
| `places.js` | Place-name extraction from chat text (Part 1 §5 step 4) |
| `decide.js` | Stance/decision resolution — silence-is-consent (Part 1 §5 step 5) |
| `needs.js` | Matches candidate places against the trip's declared interests |
| `schedule.js` | Low-level day-schedule slot placement (shared by Optimise) |
| `osm_places.js` | OpenStreetMap place lookups for the planner |
| `vote_days.js` | Resolves which calendar days a trip actually covers from votes/dates |
| `logistics_plan.js` | `tripLogistics()` — flight/hotel-aware busy-slot builder (Part 1 §5) |
| `gazetteer.json` | The 235-place/15-city knowledge base used by `places.js` |

### `functions/discussion_summary/` — the trained-model runtime (Part 2)

| File | What it's for |
|---|---|
| `load_model.js` / `model.json` | Loads the trained classifier at Cloud Function cold-start |
| `runtime.js` | Runs the loaded model against a message/batch of messages |
| `decisions.js` | Decision-resolution helpers shared with AI Summarise |
| `summariser.js` | Discussion Summary feature: importance scoring, TextRank/cosine sentence extraction |
| `textproc.js` | Shared text cleaning/tokenising |
| `lexicons.json` | Hand-built stance/sentiment word lists (agree/object/hesitate phrases, EN+ZH+BM) |

### `ml/discussion_summary/` — training & evaluation (Python, not deployed — produces the model files above)

Key files: `train_classifier.py` (Part 2), `features.py` (TF-IDF/n-gram feature
building), `build_dataset.py` / `manual_data*.py` / `generate_template_data.py` /
`import_public_datasets.py` (dataset construction — your own hand-labelled chats +
templated synthetic chats + public dialogue datasets), `kb.py` / `kb_pois.py` /
`export_gazetteer.py` (the 235-place knowledge base feeding `gazetteer.json`),
`evaluate_summary.py` / `results/` (evaluation reports — the seen/unseen F1 tables you
can quote if asked for numbers), `test_optimise.js` / `test_planner.js` /
`test_functions_mock.js` (regression tests for the planner/optimiser logic).

### `admin_web/` — the admin + partner web console (plain HTML/JS, no framework)

- **`admin/`** — admin-only pages: dashboard (`overview.html`), user management
  (`users.html`), content moderation (`content-moderation.html`), places management
  (`attractions.html` + restaurant/attraction form + bulk-import/geocoding tools),
  country emergency info, insurance management (partners/plans/transactions tabs,
  `insurance.html`), transactions, reports, admin profile, login.
- **`partner/`** — insurance-partner-only pages: dashboard, plans, transactions,
  refund/claim handling, messages (traveller chat), organization profile, reports,
  register/verify-email/login.
- **`js/`** — shared logic: `data.js` (every Firestore read/write call used across
  admin+partner pages), `ui.js` (shared render helpers — stat cards, status badges,
  `reporterLabel`), `sidebar.js` (nav + notification-badge wiring, see the Insurance
  red-dot fix from earlier), `auth-guard.js` (role-gated page access), `icons.js`,
  `firebase-config.js`, `countries.js`/`dial_codes.js` (reference data),
  `places-config.js`/`places-import.js` (catalog seeding tools), `report-export.js`
  (CSV/PDF export), `voya-logo-base64.js`.

---

*This document was written before the "delete all long explanatory comments"
clean-up pass, specifically so the reasoning behind any comment that gets deleted is
still captured somewhere. If you want the exact wording of a removed comment for a
specific file before your viva, ask and I'll pull it from this project's session
history rather than guessing — git history on your machine is possible too, but I
didn't confirm your working tree is clean before this pass, so don't rely on
`git diff`/`git stash` alone without checking yourself first.*
