// Executable test cases for Voya's four Cloud Functions.
// Runs the REAL function code (functions/*.js) with an in-memory Firestore
// (fake_firestore.js), a stubbed Stripe client and the network switched off,
// so the results do not depend on a Firebase project or API keys.
//
// Run:  node --test tests/functions/        (needs `npm ci` inside functions/ first)
//
// Every test name starts with the test case ID from Chapter 5 (TCxx) so
// tools/collect_results.js can map results back to the test case table.

const { test, before } = require("node:test");
const assert = require("node:assert/strict");
const path = require("path");
const Module = require("module");
const { createFakeDb } = require("./fake_firestore");

const fnDir = path.join(__dirname, "..", "..", "functions");
const fnRequire = Module.createRequire(path.join(fnDir, "index.js"));

// ---------------------------------------------------------------------------
// Environment: no network, fake Firestore, stub Stripe.
// ---------------------------------------------------------------------------
globalThis.fetch = async () => { throw new Error("network disabled in tests"); };
process.env.STRIPE_SECRET_KEY = "sk_test_dummy_for_tests";
process.env.OPENAI_API_KEY = "";

let currentDb = createFakeDb();
const FieldValue = {
  serverTimestamp: () => Date.now(),
  increment: (n) => n,
  arrayUnion: (...v) => v,
  arrayRemove: () => [],
  delete: () => undefined,
};
const fsPath = fnRequire.resolve("firebase-admin/firestore");
require.cache[fsPath] = {
  id: fsPath, filename: fsPath, loaded: true,
  exports: { getFirestore: () => currentDb, FieldValue, Timestamp: { now: () => Date.now() } },
};

const stripeCalls = [];
let stripeBehaviour = "ok";
const stripePath = fnRequire.resolve("stripe");
require.cache[stripePath] = {
  id: stripePath, filename: stripePath, loaded: true,
  exports: function FakeStripe(key) {
    return {
      key,
      paymentIntents: {
        create: async (params) => {
          stripeCalls.push({ key, params });
          if (stripeBehaviour === "error") throw new Error("Your card was declined.");
          return { id: "pi_test_123", client_secret: "pi_test_123_secret_abc", status: "requires_payment_method" };
        },
      },
    };
  },
};

let fns;
before(() => {
  fns = {
    ...fnRequire(path.join(fnDir, "index.js")),
  };
});

const call = (fn, data, uid = "u1") => fn.run({ auth: uid ? { uid } : null, data });
const codeOf = async (promise) => {
  try { await promise; return "ok"; } catch (e) { return e.code || e.message; }
};

// ---------------------------------------------------------------------------
// Test data: a 3-day Kuala Lumpur trip for 3 members.
// ---------------------------------------------------------------------------
function klTrip({ chat, day2Items = {}, extra = {} }) {
  const seed = {
    "trips/t1": {
      name: "KL Getaway",
      destination: "Kuala Lumpur",
      ownerId: "u1",
      memberIds: ["u1", "u2", "u3"],
      memberNames: { u1: "Ali", u2: "Bella", u3: "Chong" },
      flights: [], hotelStays: [],
      days: {
        0: { weekday: "Thu", date: "10 Dec", items: {} },
        1: { weekday: "Fri", date: "11 Dec", items: day2Items },
        2: { weekday: "Sat", date: "12 Dec", items: {} },
      },
      ...extra,
    },
    "catalog_attractions/petronas": {
      name: "Petronas Twin Towers", location: "KLCC, Kuala Lumpur", destinationQuery: "kuala lumpur",
      category: "Landmark", lat: 3.1579, lng: 101.7116, rating: "4.7",
    },
    "catalog_attractions/batu": {
      name: "Batu Caves", location: "Gombak", destinationQuery: "kuala lumpur",
      category: "Temple", lat: 3.2379, lng: 101.6840, rating: "4.6",
    },
    "catalog_attractions/titiwangsa": {
      name: "Titiwangsa Lake Gardens", location: "Titiwangsa", destinationQuery: "kuala lumpur",
      category: "Park", lat: 3.1793, lng: 101.7064, rating: "4.4",
    },
    "catalog_attractions/central": {
      name: "Central Market", location: "Chinatown", destinationQuery: "kuala lumpur",
      category: "Market", lat: 3.1456, lng: 101.6953, rating: "4.3",
    },
  };
  chat.forEach(([speaker, text], i) => {
    seed[`trips/t1/messages/m${String(i).padStart(3, "0")}`] = {
      senderName: speaker, senderId: speaker, text, type: "text", createdAt: 1_000 + i,
    };
  });
  return seed;
}

// ---------------------------------------------------------------------------
// TC25 - AI Summarise must not read the chat without consent
// ---------------------------------------------------------------------------
test("TC25 AI Summarise refuses to read the chat without consent", async () => {
  currentDb = createFakeDb(klTrip({ chat: [["Ali", "Petronas Twin Towers on day 2?"], ["Bella", "ok"]] }));
  assert.equal(await codeOf(call(fns.generateItinerary, { tripId: "t1" })), "failed-precondition");
  assert.equal(await codeOf(call(fns.generateItinerary, { tripId: "t1", consent: false })), "failed-precondition");
  assert.equal(await codeOf(call(fns.generateItinerary, { tripId: "t1", consent: true }, null)), "unauthenticated");
  assert.equal(await codeOf(call(fns.generateItinerary, { tripId: "t1", consent: true }, "stranger")), "permission-denied");
});

// ---------------------------------------------------------------------------
// TC26 - an agreed place becomes an "add" suggestion on the right day
// ---------------------------------------------------------------------------
test("TC26 AI Summarise suggests adding an agreed place on the day the chat named", async () => {
  currentDb = createFakeDb(klTrip({
    chat: [
      ["Ali", "Let's go Petronas Twin Towers on day 2?"],
      ["Bella", "ok"],
      ["Chong", "sounds good to me"],
    ],
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const labels = res.add.map((a) => `${a.label} (day ${a.day} ${a.time})`);
  const petronas = res.add.find((a) => /Petronas/i.test(a.label));
  assert.ok(petronas, `expected Petronas in add suggestions, got ${JSON.stringify(labels)}`);
  assert.equal(petronas.day, 2, `Petronas should be on day 2, got ${JSON.stringify(labels)}`);
  assert.equal(res.engine, "voya-planner");
});

// ---------------------------------------------------------------------------
// TC27 - a place the group turned down becomes a "remove" suggestion
// ---------------------------------------------------------------------------
test("TC27 AI Summarise suggests removing a place the group rejected", async () => {
  currentDb = createFakeDb(klTrip({
    day2Items: { x1: { time: "10:00", label: "Sunway Lagoon", location: "Petaling Jaya", icon: "activity" } },
    chat: [
      ["Bella", "can we skip Sunway Lagoon? too expensive"],
      ["Ali", "agree, no Sunway Lagoon"],
    ],
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  assert.ok(res.remove.some((r) => r.label === "Sunway Lagoon"),
    `expected Sunway Lagoon in remove suggestions, got ${JSON.stringify(res.remove)}`);
});

// Found while executing TC27: a plan item whose name is not in Voya's place list
// (a custom activity, or a place from another city) is never removed, and the
// "no ..." reply is wrongly counted against the place discussed just before it.
test("TC27b Rejecting a custom plan item does not turn the previous place into rejected", async () => {
  currentDb = createFakeDb(klTrip({
    day2Items: { x1: { time: "10:00", label: "Disneyland", location: "Theme park", icon: "activity" } },
    chat: [
      ["Ali", "Let's go Petronas Twin Towers on day 2?"], ["Bella", "ok"],
      ["Bella", "can we skip Disneyland? too expensive"], ["Ali", "agree, no Disneyland"],
    ],
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  assert.ok(res.add.some((a) => /Petronas/.test(a.label)),
    `Petronas was agreed but is missing from add: ${JSON.stringify(res.add.map((a) => a.label))}`);
  assert.ok(res.remove.some((r) => r.label === "Disneyland"),
    `Disneyland is in the plan and was rejected, but remove = ${JSON.stringify(res.remove)}`);
});

// ---------------------------------------------------------------------------
// TC28 - AI Summarise only suggests; it never writes to the trip itself
// ---------------------------------------------------------------------------
test("TC28 AI Summarise saves nothing to the trip until the traveller applies it", async () => {
  currentDb = createFakeDb(klTrip({
    chat: [["Ali", "Let's go Petronas Twin Towers on day 2?"], ["Bella", "ok"]],
  }));
  const before = JSON.stringify(currentDb.store.get("trips/t1"));
  await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const tripWrites = currentDb.writes.filter((w) => w.path === "trips/t1" || w.path.startsWith("trips/t1/"));
  assert.deepEqual(tripWrites, [], `function wrote to the trip: ${JSON.stringify(tripWrites)}`);
  assert.equal(JSON.stringify(currentDb.store.get("trips/t1")), before);
});

// ---------------------------------------------------------------------------
// TC29 - Optimise reorders a day by real distance and keeps lunch at lunch time
// ---------------------------------------------------------------------------
const KM = (a, b) => {
  const r = (d) => (d * Math.PI) / 180;
  const h = Math.sin(r(b.lat - a.lat) / 2) ** 2 + Math.cos(r(a.lat)) * Math.cos(r(b.lat)) * Math.sin(r(b.lng - a.lng) / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(h));
};
const COORD = {
  "Batu Caves": { lat: 3.2379, lng: 101.6840 },
  "Central Market": { lat: 3.1456, lng: 101.6953 },
  "Titiwangsa Lake Gardens": { lat: 3.1793, lng: 101.7064 },
};
const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));

test("TC29 Optimise moves meals to meal time without adding travel, and explains each change", async () => {
  const start = {
    "Batu Caves": "09:00", "Central Market": "10:00", "Titiwangsa Lake Gardens": "11:00", "Lunch at Madam Kwan's": "09:30",
  };
  currentDb = createFakeDb(klTrip({
    chat: [],
    day2Items: {
      a1: { time: start["Batu Caves"], label: "Batu Caves", location: "Gombak", icon: "place" },
      a2: { time: start["Central Market"], label: "Central Market", location: "Chinatown", icon: "place" },
      a3: { time: start["Titiwangsa Lake Gardens"], label: "Titiwangsa Lake Gardens", location: "Titiwangsa", icon: "place" },
      a4: { time: start["Lunch at Madam Kwan's"], label: "Lunch at Madam Kwan's", location: "KLCC", icon: "food" },
    },
  }));
  const res = await call(fns.optimiseItinerary, { tripId: "t1", mode: "day", dayIndex: 1 });
  assert.equal(res.engine, "voya-optimiser");
  const after = { ...start };
  for (const u of res.update) after[u.label] = u.newTime;
  const route = (times) => Object.keys(COORD).sort((a, b) => toMin(times[a]) - toMin(times[b]));
  const dist = (order) => order.slice(1).reduce((km, p, i) => km + KM(COORD[order[i]], COORD[p]), 0);
  console.log(`TC29 measured: route ${route(start).join(" > ")} = ${dist(route(start)).toFixed(1)} km  ->  ${route(after).join(" > ")} = ${dist(route(after)).toFixed(1)} km; lunch ${after["Lunch at Madam Kwan's"]}`);
  const lunch = toMin(after["Lunch at Madam Kwan's"]);
  assert.ok(lunch >= 11 * 60 && lunch <= 14 * 60, `lunch should move to lunch time, got ${after["Lunch at Madam Kwan's"]}`);
  assert.ok(dist(route(after)) <= dist(route(start)) + 0.01, "the optimised day must not add travel distance");
  assert.ok(res.update.length > 0 && res.update.every((u) => u.reason), "every change explains why");
});

test("TC29b Optimise two-opt pass reorders freely movable places by real distance", () => {
  // Same rule as 4.8.2 step 8, called directly: three places on one line, listed out of order.
  const { optimisePlan, toMin: m } = fnRequire(path.join(fnDir, "optimise_engine.js"));
  const item = (id, time, label, location) => ({ id, time, label, location, icon: "place" });
  const catalog = [
    { name: "Place A", type: "attraction", location: "Area1", lat: 1.0, lng: 101.0 },
    { name: "Place B", type: "attraction", location: "Area2", lat: 1.0, lng: 101.2 },
    { name: "Place C", type: "attraction", location: "Area3", lat: 1.0, lng: 101.1 },
  ];
  const plan = { 1: [item("w1", "10:00", "Place A", "Area1"), item("w2", "10:05", "Place B", "Area2"), item("w3", "10:10", "Place C", "Area3")], 2: [] };
  const days = [{ day: 1, weekday: "Fri", date: "11 Dec" }, { day: 2, weekday: "Sat", date: "12 Dec" }];
  const r = optimisePlan(plan, { mode: "day", onlyDay: 1, destination: "City", days, catalog });
  const times = { "Place A": "10:00", "Place B": "10:05", "Place C": "10:10" };
  for (const u of r.update) times[u.label] = u.time;
  const order = Object.keys(times).sort((a, b) => m(times[a]) - m(times[b]));
  assert.deepEqual(order, ["Place A", "Place C", "Place B"]);
});

// ---------------------------------------------------------------------------
// TC32 / TC33 - payment Cloud Function
// ---------------------------------------------------------------------------
test("TC32 createPaymentIntent returns a client secret for a valid payment", async () => {
  stripeBehaviour = "ok";
  stripeCalls.length = 0;
  currentDb = createFakeDb({ "step_up/u1": { payment: Date.now() + 5 * 60 * 1000 } }); // email code confirmed
  const res = await call(fns.createPaymentIntent, { amount: 25000, currency: "MYR", receiptEmail: "test@voya.app" });
  assert.equal(res.clientSecret, "pi_test_123_secret_abc");
  assert.equal(stripeCalls.length, 1);
  assert.equal(stripeCalls[0].key, "sk_test_dummy_for_tests", "secret key comes from the server-side secret");
  assert.equal(stripeCalls[0].params.amount, 25000);
  assert.equal(stripeCalls[0].params.currency, "myr");
  assert.equal(stripeCalls[0].params.metadata.uid, "u1");
});

test("TC33 createPaymentIntent rejects invalid or failed payments", async () => {
  stripeBehaviour = "ok";
  currentDb = createFakeDb({ "step_up/u1": { payment: Date.now() + 5 * 60 * 1000 } });
  assert.equal(await codeOf(call(fns.createPaymentIntent, { amount: 25000, currency: "myr" }, null)), "unauthenticated");
  assert.equal(await codeOf(call(fns.createPaymentIntent, { amount: 0, currency: "myr" })), "invalid-argument");
  assert.equal(await codeOf(call(fns.createPaymentIntent, { amount: -500, currency: "myr" })), "invalid-argument");
  assert.equal(await codeOf(call(fns.createPaymentIntent, { amount: 500, currency: "ringgit" })), "invalid-argument");
  stripeBehaviour = "error";
  assert.equal(await codeOf(call(fns.createPaymentIntent, { amount: 500, currency: "myr" })), "internal");
  stripeBehaviour = "ok";
});

// ---------------------------------------------------------------------------
// TC05 - email verification codes (FR04): sign-up, new-device login, step-up
// ---------------------------------------------------------------------------
function codeHarness(seed = {}) {
  const { makeHandlers, constants } = fnRequire(path.join(fnDir, "email_code.js"));
  const db = createFakeDb(seed);
  const mails = [];
  const authUpdates = [];
  let clock = Date.now();
  const h = makeHandlers({
    db,
    auth: { updateUser: async (uid, data) => authUpdates.push({ uid, data }) },
    sendMail: async (m) => mails.push(m),
    now: () => clock,
  });
  const lastCode = () => mails[mails.length - 1].subject.match(/(\d{6})/)[1];
  return { h, db, mails, authUpdates, constants, lastCode, advance: (ms) => { clock += ms; }, now: () => clock };
}

test("TC05 Sign-up code is emailed, stored only as a hash, and verifies the account", async () => {
  const t = codeHarness();
  await t.h.send("u1", "ali@gmail.com", "signup");
  assert.equal(t.mails.length, 1);
  assert.equal(t.mails[0].to, "ali@gmail.com");
  const code = t.lastCode();
  const saved = t.db.store.get("verification_codes/u1_signup");
  assert.ok(saved.hash && !JSON.stringify(saved).includes(code), "the plain code is never stored");

  const res = await t.h.verify("u1", "signup", code, "device_abc12345", "Pixel 9");
  assert.equal(res.verified, true);
  assert.deepEqual(t.authUpdates, [{ uid: "u1", data: { emailVerified: true } }]);
  assert.equal(t.db.store.get("users/u1").emailVerified, true);
  assert.ok(t.db.store.get("users/u1/trusted_devices/device_abc12345").trustedUntil > t.now(), "this phone is trusted");
  assert.equal(t.db.store.has("verification_codes/u1_signup"), false, "a code works only once");
});

test("TC05 A wrong code is refused and five wrong codes lock it", async () => {
  const t = codeHarness();
  await t.h.send("u1", "ali@gmail.com", "login");
  const right = t.lastCode();
  const wrong = right === "000000" ? "111111" : "000000";
  assert.equal(await codeOf(t.h.verify("u1", "login", wrong, "device_abc12345")), "permission-denied");
  for (let i = 0; i < 4; i++) await codeOf(t.h.verify("u1", "login", wrong, "device_abc12345"));
  assert.equal(await codeOf(t.h.verify("u1", "login", right, "device_abc12345")), "resource-exhausted",
    "even the right code is refused after 5 wrong tries");
  assert.equal(t.db.store.has("users/u1/trusted_devices/device_abc12345"), false);
});

test("TC05 Codes expire after 10 minutes and can be re-sent only once a minute", async () => {
  const t = codeHarness();
  await t.h.send("u1", "ali@gmail.com", "login");
  assert.equal(await codeOf(t.h.send("u1", "ali@gmail.com", "login")), "resource-exhausted", "resend too soon");
  const code = t.lastCode();
  t.advance(t.constants.CODE_TTL_MS + 1000);
  assert.equal(await codeOf(t.h.verify("u1", "login", code, "device_abc12345")), "deadline-exceeded");
  await t.h.send("u1", "ali@gmail.com", "login");
  assert.equal(t.mails.length, 2, "a new code can be sent after a minute");
});

test("TC05 A new-device login code trusts the phone for 30 days", async () => {
  const t = codeHarness();
  await t.h.send("u1", "ali@gmail.com", "login");
  const res = await t.h.verify("u1", "login", t.lastCode(), "device_new99999", "Galaxy S24");
  const trusted = t.db.store.get("users/u1/trusted_devices/device_new99999");
  assert.equal(trusted.trustedUntil - t.now(), t.constants.TRUST_DEVICE_MS);
  assert.equal(res.trustedUntil, trusted.trustedUntil);
});

test("TC05 Payment needs a fresh email code (step-up) before Stripe is called", async () => {
  stripeBehaviour = "ok";
  stripeCalls.length = 0;
  currentDb = createFakeDb();
  assert.equal(await codeOf(call(fns.createPaymentIntent, { amount: 25000, currency: "myr" })), "failed-precondition");
  assert.equal(stripeCalls.length, 0, "no charge without the code");

  const t = codeHarness();
  currentDb = t.db;
  await t.h.send("u1", "ali@gmail.com", "payment");
  await t.h.verify("u1", "payment", t.lastCode());
  assert.equal(await t.h.hasStepUp("u1", "payment"), true);
  const res = await call(fns.createPaymentIntent, { amount: 25000, currency: "myr" });
  assert.ok(res.clientSecret);
  t.advance(t.constants.STEP_UP_MS + 1000);
  assert.equal(await t.h.hasStepUp("u1", "payment"), false, "the confirmation lasts 10 minutes");
});

test("TC05 Unknown purposes and malformed codes are refused", async () => {
  const t = codeHarness();
  assert.equal(await codeOf(t.h.send("u1", "ali@gmail.com", "anything")), "invalid-argument");
  assert.equal(await codeOf(t.h.verify("u1", "login", "12ab56")), "invalid-argument");
  assert.equal(await codeOf(t.h.verify("u1", "login", "123456")), "not-found");
});

// ---------------------------------------------------------------------------
// TC64 - AI itinerary generated within 30 s (3.4.2 A-ii), 50-message chat
// ---------------------------------------------------------------------------
test("TC64 AI Summarise finishes a 50-message chat within 30 seconds", async () => {
  const lines = [
    ["Ali", "Let's go Petronas Twin Towers on day 2?"], ["Bella", "ok"], ["Chong", "can we skip Disneyland? too expensive"],
    ["Ali", "agree, no Disneyland"], ["Bella", "Batu Caves in the morning on day 1"], ["Chong", "sure"],
    ["Ali", "Central Market for shopping on Saturday"], ["Bella", "hotel near KLCC ok"], ["Chong", "I prefer not to wake up too early"],
    ["Ali", "haha ok"],
  ];
  const chat = Array.from({ length: 50 }, (_, i) => lines[i % lines.length]);
  currentDb = createFakeDb(klTrip({ chat }));
  const t0 = process.hrtime.bigint();
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  console.log(`TC64 measured: ${ms.toFixed(0)} ms for ${res.messageCount} messages`);
  assert.equal(res.messageCount, 50);
  assert.ok(ms < 30_000, `took ${ms} ms`);
});

// ---------------------------------------------------------------------------
// Discussion summary (Chapter 1 "AI Summarizer") - agreed vs turned down
// ---------------------------------------------------------------------------
test("TC26b Discussion summary lists what the group agreed and turned down", async () => {
  currentDb = createFakeDb(klTrip({
    chat: [
      ["Ali", "Let's go Petronas Twin Towers on day 2?"], ["Bella", "ok"],
      ["Bella", "can we skip Sunway Lagoon? too expensive"], ["Ali", "agree, no Sunway Lagoon"],
    ],
  }));
  const sum = await call(fns.summariseDiscussion, { tripId: "t1" });
  const items = sum.sections.flatMap((s) => s.items);
  const status = (re) => (items.find((it) => re.test(it.value)) || {}).status;
  const seen = JSON.stringify(items.map((i) => [i.value, i.status]));
  assert.equal(status(/Petronas/i), "confirmed", seen);
  assert.equal(status(/Sunway Lagoon/i), "rejected", seen);
});
