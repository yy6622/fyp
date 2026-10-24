// Wishes without a place name ("夜市", "按摩") that neither the saved list nor Voya's place list can fill:
// AI Summarise looks in Firestore catalog_places, then OpenStreetMap, and writes what it found back to
// catalog_places. Offline: Nominatim / Overpass / Firestore are faked here.
// Run from functions/:   node ../ml/discussion_summary/test_osm_places.js
const path = require("path");
const assert = require("assert");
const Module = require("module");
const fn = path.join(__dirname, "..", "..", "functions");
const fnRequire = Module.createRequire(path.join(fn, "index.js"));

// fake firebase-admin/firestore (FieldValue only) and a fake db
const fsPath = fnRequire.resolve("firebase-admin/firestore");
require.cache[fsPath] = { id: fsPath, filename: fsPath, loaded: true,
  exports: { FieldValue: { arrayUnion: (...v) => ({ arrayUnion: v }) } } };
const store = new Map();               // catalog_places id -> data
const fakeDb = {
  collection: (name) => ({
    where: (field, op, value) => ({ limit: () => ({ get: async () => ({
      docs: [...store.entries()].filter(([, d]) => d._col === name && d[field] === value).map(([id, d]) => ({ id, data: () => d })) }) }) }),
    doc: (id) => ({ id, name }),
  }),
  batch: () => {
    const ops = [];
    return {
      set: (ref, data) => ops.push([ref.id, { ...data, _col: ref.name }]),
      commit: async () => {
        for (const [id, data] of ops) {
          const old = store.get(id) || {};
          const keys = new Set([...(old.needKeys || []), ...((data.needKeys && data.needKeys.arrayUnion) || [])]);
          store.set(id, { ...old, ...data, needKeys: [...keys] });
        }
      },
    };
  },
};

const calls = [];
async function fakeFetch(url, init) {
  calls.push(url.includes("nominatim") ? "nominatim" : "overpass");
  if (url.includes("nominatim")) return [{ lat: "3.1390", lon: "101.6869", address: { country_code: "my" } }];
  const q = decodeURIComponent(String(init.body).replace(/^data=/, ""));
  if (q.includes('"shop"="massage"')) {
    return { elements: [
      { type: "node", id: 11, lat: 3.146, lon: 101.711, tags: { name: "Urban Retreat Spa", shop: "massage", website: "https://example.com" } },
      { type: "node", id: 12, lat: 3.30, lon: 101.90, tags: { name: "Far Away Massage", shop: "massage" } },
    ] };
  }
  return { elements: [] };
}

const { buildItinerary } = require(path.join(fn, "itinerary_engine"));
const { loadModel } = require(path.join(fn, "discussion_summary", "load_model"));
const { makeNeedLookup, overpassQuery } = require(path.join(fn, "planner", "osm_places"));

(async () => {
  const chat = [["Alex", "去KL想去按摩放松一下"], ["Emily", "好啊按摩可以"], ["Mia", "同意"], ["Ryan", "还有双子塔"], ["Alex", "ok"]]
    .map(([speaker, text], i) => ({ id: "k" + i, speaker, text }));
  const days = [1, 2, 3].map((d) => ({ day: d, date: `${d} Dec 2026` }));
  const plan = { 1: [], 2: [], 3: [] };
  const run = () => buildItinerary({ messages: chat, members: ["Alex", "Emily", "Mia", "Ryan"], days, plan, saved: [],
    destination: "Kuala Lumpur", model: loadModel().model,
    lookupNeed: makeNeedLookup({ db: fakeDb, destination: "Kuala Lumpur", fetchJson: fakeFetch }) });

  const r1 = await run();
  for (const a of r1.answer.add) console.log(`  Day ${a.day} ${a.time}  ${a.label}  [${a.source}]  ${a.reason}`);
  const spa = r1.answer.add.find((a) => a.label === "Urban Retreat Spa");
  assert.ok(spa, "按摩 -> a massage place found on OpenStreetMap");
  assert.ok(/OpenStreetMap/.test(spa.reason), "the reason says where it came from");
  assert.ok(store.has("osm_n11"), "what OSM found is written to catalog_places");
  assert.deepStrictEqual(store.get("osm_n11").needKeys, ["MY:massage"]);
  assert.strictEqual(store.get("osm_n11").type, "attraction");
  assert.ok(calls.includes("overpass"), "OSM was asked");
  const card = store.get("place_osm_n11");
  assert.ok(card && card._col === "catalog_attractions" && card.destinationQuery === "kuala lumpur" && card.name === "Urban Retreat Spa",
    "and copied to catalog_attractions for the trip's destination, so the plan shows it as a card");

  calls.length = 0;
  const r2 = await run();
  assert.ok(r2.answer.add.some((a) => a.label === "Urban Retreat Spa"), "second trip to KL finds it again");
  assert.ok(!calls.includes("overpass"), "... from catalog_places, without asking OSM again");

  // OSM down: a time block, AI Summarise still works
  store.clear();
  const r3 = await buildItinerary({ messages: chat, members: ["Alex", "Emily", "Mia", "Ryan"], days, plan, saved: [],
    destination: "Kuala Lumpur", model: loadModel().model,
    lookupNeed: makeNeedLookup({ db: fakeDb, destination: "Kuala Lumpur", fetchJson: async () => null }) });
  assert.ok(r3.answer.add.some((a) => a.label === "Massage / spa" && a.source === "generic"), "OSM unreachable -> time block");

  assert.ok(/around:12000,1,2/.test(overpassQuery("night market", 1, 2, "TH")), "Overpass query around the city");
  assert.ok(/cuisine"~"thai/.test(overpassQuery("local food", 1, 2, "TH")), "local food = that country's cuisine");
  console.log("osm places test: all checks passed");
})().catch((e) => { console.error(e); process.exit(1); });
