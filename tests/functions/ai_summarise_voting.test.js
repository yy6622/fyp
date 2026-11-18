// Executable test cases for AI Summarise's vote-handling (generateItinerary).
// Runs the REAL function code (functions/*.js) with an in-memory Firestore
// (fake_firestore.js) and the network switched off, same harness as
// cloud_functions.test.js (kept in a separate file so it can be run and
// read on its own: `node --test tests/functions/ai_summarise_voting.test.js`).
//
// Covers the 2026-11-17 fix: Vote-tab polls (trips/{id}/votes) were
// previously invisible to generateItinerary except for "which day" polls.
// TC77-83 below exercise the generalised mechanism added in
// functions/itinerary_engine.js (votePlaceWinners / hotelVoteWinner /
// tiedPollNotes) plus the end-to-end `reason` field on update entries.

const { test, before } = require("node:test");
const assert = require("node:assert/strict");
const path = require("path");
const Module = require("module");
const { createFakeDb } = require("./fake_firestore");

const fnDir = path.join(__dirname, "..", "..", "functions");
const fnRequire = Module.createRequire(path.join(fnDir, "index.js"));

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

let fns;
before(() => {
  fns = { ...fnRequire(path.join(fnDir, "index.js")) };
});

const call = (fn, data, uid = "u1") => fn.run({ auth: uid ? { uid } : null, data });

// ---------------------------------------------------------------------------
// Test data: a 3-day Kuala Lumpur trip for 3 members, same shape as
// cloud_functions.test.js's klTrip() but with a `votes` option added.
// ---------------------------------------------------------------------------
function voteTrip({ chat = [], day2Items = {}, votes = {}, extra = {} }) {
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
    "catalog_attractions/petaling": {
      name: "Petaling Street", location: "Chinatown", destinationQuery: "kuala lumpur",
      category: "Market", lat: 3.1430, lng: 101.6968, rating: "4.1",
    },
  };
  chat.forEach(([speaker, text], i) => {
    seed[`trips/t1/messages/m${String(i).padStart(3, "0")}`] = {
      senderName: speaker, senderId: speaker, text, type: "text", createdAt: 1_000 + i,
    };
  });
  for (const [voteId, vote] of Object.entries(votes)) {
    seed[`trips/t1/votes/${voteId}`] = vote;
  }
  return seed;
}

// A poll document exactly as TripVote.fromFirestore reads it (lib/repositories
// /trip_repository.dart): { title, options: { optId: { label, votedBy } } }.
const poll = (title, optionVotes) => {
  const options = {};
  let i = 0;
  for (const [label, votedBy] of optionVotes) options[`opt${i++}`] = { label, votedBy };
  return { title, options };
};

// ---------------------------------------------------------------------------
// TC77 - a clear-winner hotel poll is reflected as a hotel check-in idea
// ---------------------------------------------------------------------------
test("TC77 AI Summarise picks up a hotel poll's clear winner", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [["Ali", "excited for this trip!"]],
    votes: {
      v1: poll("Which hotel should we book?", [["Grand Hyatt Kuala Lumpur", ["u1", "u2"]], ["Hotel Mulia", ["u3"]]]),
    },
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const hotelAdd = res.add.find((a) => a.icon === "hotel");
  assert.ok(hotelAdd, `expected a hotel add suggestion, got ${JSON.stringify(res.add)}`);
  assert.match(hotelAdd.label, /Grand Hyatt/i);
  assert.match(hotelAdd.reason || "", /Voted for in/i, `hotel reason should cite the poll: ${JSON.stringify(hotelAdd)}`);
});

// ---------------------------------------------------------------------------
// TC78 - a clear-winner poll for a place never mentioned in chat still gets
// added, with a reason citing the poll (the generic votePlaceWinners path)
// ---------------------------------------------------------------------------
test("TC78 AI Summarise adds a voted place that was never discussed in chat", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [["Ali", "can't wait for this trip"]],
    votes: {
      v1: poll("Where should we go on our free afternoon?", [["Batu Caves", ["u1", "u2"]], ["Titiwangsa Lake Gardens", ["u3"]]]),
    },
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const batu = res.add.find((a) => /Batu Caves/i.test(a.label));
  assert.ok(batu, `expected Batu Caves in add, got ${JSON.stringify(res.add.map((a) => a.label))}`);
  assert.match(batu.reason || "", /Voted for in "Where should we go on our free afternoon\?"/);
});

// ---------------------------------------------------------------------------
// TC79 - a poll result overrides an explicit chat rejection
// ---------------------------------------------------------------------------
test("TC79 A vote's clear winner overrides an explicit chat rejection", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [
      ["Bella", "can we skip Central Market? too crowded"],
      ["Ali", "agree, no Central Market"],
    ],
    votes: {
      v1: poll("Which market should we visit?", [["Central Market", ["u1", "u2"]], ["Petaling Street", ["u3"]]]),
    },
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  assert.ok(!res.remove.some((r) => r.label === "Central Market"),
    `Central Market should NOT be removed once the poll overrode the rejection: ${JSON.stringify(res.remove)}`);
  const added = res.add.find((a) => /Central Market/i.test(a.label));
  assert.ok(added, `expected Central Market in add despite the chat rejection, got ${JSON.stringify(res.add.map((a) => a.label))}`);
  assert.match(added.reason || "", /Voted for in "Which market should we visit\?"/);
});

// ---------------------------------------------------------------------------
// TC80 - a "No" win must not be read as agreement just because the poll's
// TITLE happens to name the place (negative-option guard)
// ---------------------------------------------------------------------------
test("TC80 A poll's 'No' winner does not force-add the place it names", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [["Ali", "can't wait for this trip, let's see what we end up doing"]],
    votes: {
      v1: poll("Should we visit Petaling Street?", [["No", ["u1", "u2"]], ["Yes", ["u3"]]]),
    },
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  assert.ok(!res.add.some((a) => /Petaling Street/i.test(a.label)),
    `"No" won this poll, Petaling Street must not be added: ${JSON.stringify(res.add.map((a) => a.label))}`);
});

// ---------------------------------------------------------------------------
// TC81 - a genuine tie is surfaced to the group instead of silently ignored
// ---------------------------------------------------------------------------
test("TC81 A tied poll is surfaced as something the group still needs to decide", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [["Ali", "let's decide on this one together"]],
    votes: {
      v1: poll("Which hotel should we book?", [["Grand Hyatt Kuala Lumpur", ["u1"]], ["Hotel Mulia", ["u2"]]]),
    },
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  // Structured, not just a text blurb -- this is what lets the sheet render
  // tappable options for the group to resolve the tie right there.
  const tied = (res.tiedVotes || []).find((v) => /Which hotel should we book/i.test(v.title));
  assert.ok(tied, `expected a structured tied vote, got ${JSON.stringify(res.tiedVotes)}`);
  assert.strictEqual(tied.voteId, "v1", `tied vote should carry the real Firestore doc id`);
  assert.strictEqual(tied.options.length, 2, `expected both options: ${JSON.stringify(tied.options)}`);
  assert.ok(tied.options.some((o) => /Grand Hyatt/i.test(o.label) && o.votes === 1), `Grand Hyatt option should show 1 vote: ${JSON.stringify(tied.options)}`);
  assert.ok(tied.options.some((o) => /Hotel Mulia/i.test(o.label) && o.votes === 1), `Hotel Mulia option should show 1 vote: ${JSON.stringify(tied.options)}`);
  assert.ok(!res.add.some((a) => a.icon === "hotel"), `a tie must not pick a winner: ${JSON.stringify(res.add)}`);
});

// ---------------------------------------------------------------------------
// TC82 - a poll nobody has voted on yet is NOT a tie -- it should resolve
// nothing and raise no tie notice (distinguishes "no votes" from "tied")
// ---------------------------------------------------------------------------
test("TC82 A poll with zero votes resolves nothing and is not flagged as tied", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [["Ali", "we'll vote on this later"]],
    votes: {
      v1: poll("Which hotel should we book?", [["Grand Hyatt Kuala Lumpur", []], ["Hotel Mulia", []]]),
    },
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  assert.strictEqual((res.tiedVotes || []).length, 0, `zero votes must not be reported as a tie: ${JSON.stringify(res.tiedVotes)}`);
  assert.ok(!res.add.some((a) => a.icon === "hotel"), `zero votes must not pick a winner: ${JSON.stringify(res.add)}`);
});

// ---------------------------------------------------------------------------
// TC83 - an existing plan item moved by chat discussion now explains why
// (the update[].reason end-to-end wiring fix)
// ---------------------------------------------------------------------------
test("TC83 Moving an existing plan item via chat discussion explains why", async () => {
  currentDb = createFakeDb(voteTrip({
    day2Items: { x1: { time: "10:00", label: "Petronas Twin Towers", location: "KLCC", icon: "activity" } },
    chat: [
      ["Ali", "let's move Petronas Twin Towers to 8am on day 2 to avoid crowds"],
      ["Bella", "yes agree"],
    ],
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const upd = res.update.find((u) => /Petronas/i.test(u.label));
  assert.ok(upd, `expected an update for Petronas, got ${JSON.stringify(res.update)}`);
  assert.equal(upd.newTime, "08:00");
  assert.ok(upd.reason && upd.reason.trim().length > 0,
    `the update should explain why the time changed, got reason=${JSON.stringify(upd.reason)}`);
});

// ---------------------------------------------------------------------------
// TC84 - a chat-driven time change that would collide with an existing plan
// item is nudged clear of it, not silently double-booked (freeSlot())
// ---------------------------------------------------------------------------
test("TC84 Moving an item to a time another item already occupies is nudged clear", async () => {
  currentDb = createFakeDb(voteTrip({
    day2Items: {
      x1: { time: "10:00", label: "Petronas Twin Towers", location: "KLCC", icon: "activity" },
      x2: { time: "14:00", label: "Batu Caves", location: "Gombak", icon: "activity" },
    },
    chat: [
      ["Ali", "let's move Batu Caves to 10am on day 2 instead"],
      ["Bella", "yes agree"],
    ],
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const upd = res.update.find((u) => /Batu Caves/i.test(u.label));
  assert.ok(upd, `expected an update for Batu Caves, got ${JSON.stringify(res.update)}`);
  assert.notEqual(upd.newTime, "10:00", "must not land exactly on Petronas's slot");
  const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
  assert.ok(Math.abs(toMin(upd.newTime) - toMin("10:00")) >= 60,
    `new time ${upd.newTime} is too close to the existing 10:00 item`);
  assert.match(upd.reason || "", /because Petronas Twin Towers is already there/,
    `the user should be told WHY it moved off 10:00, got reason=${JSON.stringify(upd.reason)}`);
});

// ---------------------------------------------------------------------------
// TC85 - a brand-new place the chat wants on a day that already has an
// activity at that time is scheduled around it, not on top of it
// (planner/schedule.js's busy-block logic for the add path)
// ---------------------------------------------------------------------------
test("TC85 A new place proposed for an already-busy time is scheduled around it", async () => {
  currentDb = createFakeDb(voteTrip({
    day2Items: {
      x1: { time: "10:00", label: "Petronas Twin Towers", location: "KLCC", icon: "activity" },
    },
    chat: [
      ["Ali", "let's also go Batu Caves on day 2 at 10am"],
      ["Bella", "sure"],
    ],
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const add = res.add.find((a) => /Batu Caves/i.test(a.label));
  assert.ok(add, `expected Batu Caves in add, got ${JSON.stringify(res.add.map((a) => a.label))}`);
  const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
  assert.ok(Math.abs(toMin(add.time) - toMin("10:00")) >= 60,
    `Batu Caves (${add.time}) was scheduled right on top of Petronas's 10:00 slot`);
  assert.match(add.reason || "", /instead of 10:00/,
    `the user should be told the 10am they asked for was already taken, got reason=${JSON.stringify(add.reason)}`);
});

// ---------------------------------------------------------------------------
// TC86 - a place matching the trip's own interests, that Voya already has
// real data for, is suggested as a concrete scheduled add (not a vague
// text-only idea the traveller has to go add by hand)
// ---------------------------------------------------------------------------
test("TC86 A data-backed interest match is suggested as a real scheduled item", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [["Ali", "can't wait, no idea what we're doing yet though"]],
    extra: { interests: ["Culture"] }, // Batu Caves' catalog category "Temple" matches Culture's INTEREST_WORDS
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const batu = res.add.find((a) => /Batu Caves/i.test(a.label));
  assert.ok(batu, `expected Batu Caves as a concrete add, got add=${JSON.stringify(res.add.map((a) => a.label))} ideas=${JSON.stringify(res.ideas)}`);
  assert.ok(batu.day && batu.time, `the suggestion should come with a real day/time, got ${JSON.stringify(batu)}`);
  assert.match(batu.reason || "", /Matches your trip's interests/);
  assert.ok(!res.ideas.some((i) => /Batu Caves/i.test(i.label)),
    `Batu Caves should not ALSO sit in ideas once it's a concrete suggestion: ${JSON.stringify(res.ideas)}`);
});

// ---------------------------------------------------------------------------
// TC87 - the group can settle a tied poll directly (decidedOptionId), as a
// decision rather than another ballot -- this is how the AI Summarise
// sheet's tie-break buttons resolve a tie (TripRepository.decideVote), since
// whoever taps almost always already voted in this exact poll and casting
// another ballot would just hit "you have already voted". A decided option
// must win outright regardless of the tied ballot counts, and must no
// longer show up in tiedVotes.
// ---------------------------------------------------------------------------
test("TC87 A poll settled directly (decidedOptionId) wins outright, not just another tied ballot", async () => {
  currentDb = createFakeDb(voteTrip({
    chat: [["Ali", "let's decide on this one together"]],
    votes: {
      v1: {
        ...poll("Which hotel should we book?", [["Grand Hyatt Kuala Lumpur", ["u1"]], ["Hotel Mulia", ["u2"]]]),
        decidedOptionId: "opt1", // Hotel Mulia, settled directly despite the 1-1 ballot tie
      },
    },
  }));
  const res = await call(fns.generateItinerary, { tripId: "t1", consent: true });
  const hotelAdd = res.add.find((a) => a.icon === "hotel");
  assert.ok(hotelAdd, `expected the decided hotel to be added, got ${JSON.stringify(res.add)}`);
  assert.match(hotelAdd.label, /Hotel Mulia/i, `the DECIDED option should win, not just the raw ballot leader`);
  assert.ok(!(res.tiedVotes || []).some((v) => /Which hotel should we book/i.test(v.title)),
    `a decided poll must not still show up as tied: ${JSON.stringify(res.tiedVotes)}`);
});
