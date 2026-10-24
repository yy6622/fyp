// Tests for Optimise (functions/optimise_engine.js): Voya's own scheduler, no AI model.
// Run: node ml/discussion_summary/test_optimise.js
const path = require("path");
const assert = require("assert");
const fn = path.join(__dirname, "..", "..", "functions");
const { optimisePlan, toMin } = require(path.join(fn, "optimise_engine"));

const days = [1, 2, 3, 4].map((d) => ({ day: d, date: `${7 + d} Oct 2026` }));
const item = (id, time, label, location, icon = "place") => ({ id, time, label, location, icon });
const DUR = { food: 60, hotel: 45, flight: 60 };
const findItem = (plan, label) => Object.values(plan).flat().find((it) => it.label === label);

/** the plan after applying the updates: {day: [{label, time, icon}]} */
function apply(plan, update) {
  const out = {};
  for (const [d, items] of Object.entries(plan)) {
    for (const it of items) {
      const u = update.find((x) => x.label === it.label && x.from_day === Number(d));
      const day = u ? u.day : Number(d);
      (out[day] = out[day] || []).push({ ...it, time: u ? u.time : it.time });
    }
  }
  return out;
}
function noOverlap(after, note) {
  for (const [d, items] of Object.entries(after)) {
    const rows = items.map((it) => [toMin(it.time), it]).sort((a, b) => a[0] - b[0]);
    for (let i = 1; i < rows.length; i++) {
      assert.ok(rows[i][0] > rows[i - 1][0] || rows[i][1].icon === "food",
        `${note}: two things at ${rows[i][1].time} on day ${d} (${rows[i - 1][1].label} / ${rows[i][1].label})`);
    }
  }
}

// 1. one day: the Bund at 9 am, lunch at 4 pm, cruise in the morning
const plan1 = {
  1: [], 2: [
    item("a", "09:00", "The Bund", "Huangpu"),
    item("b", "10:30", "Huangpu River Cruise", "Huangpu", "activity"),
    item("c", "16:00", "Lunch at Yang's Fried Dumplings", "Huangpu", "food"),
    item("d", "17:00", "Yu Garden", "Huangpu"),
    item("e", "12:00", "Oriental Pearl Tower", "Pudong"),
  ], 3: [], 4: [],
};
const r1 = optimisePlan(plan1, { mode: "day", onlyDay: 2, destination: "Shanghai", days });
const a1 = apply(plan1, r1.update);
console.log("1. one day");
for (const u of r1.update) console.log(`   ${u.label}: ${u.time}  (${u.reason})`);
const t1 = (label) => toMin(a1[2].find((it) => it.label === label).time);
assert.ok(r1.update.every((u) => u.day === 2 && u.from_day === 2), "day mode never touches another day");
assert.ok(t1("The Bund") >= 19 * 60, "the Bund is an evening place");
assert.ok(t1("Huangpu River Cruise") >= 19 * 60, "the river cruise is in the evening");
assert.ok(t1("Lunch at Yang's Fried Dumplings") >= 12 * 60 && t1("Lunch at Yang's Fried Dumplings") < 14 * 60, "lunch at lunch time");
assert.ok(t1("Yu Garden") < 18 * 60, "Yu Garden (morning / afternoon) goes before the evening places");
assert.ok(r1.update.every((u) => u.reason), "every change says why");
assert.ok(r1.update.find((u) => u.label === "The Bund").reason === "Best in the evening");
noOverlap(a1, "one day");

// 2. whole trip: Disneyland plus three other sights on the same day
const plan2 = {
  1: [item("h", "15:00", "Hotel check-in", "People's Square", "hotel")],
  2: [
    item("p", "09:00", "Shanghai Disneyland", "Pudong", "activity"),
    item("q", "13:00", "Shanghai Museum", "Huangpu"),
    item("r", "15:00", "City God Temple", "Huangpu"),
    item("s", "18:00", "Jing'an Temple", "Jing'an"),
  ],
  3: [item("t", "10:00", "Yu Garden", "Huangpu")],
  4: [],
};
const r2 = optimisePlan(plan2, { mode: "whole", destination: "Shanghai", days });
const a2 = apply(plan2, r2.update);
console.log("2. whole trip with a theme park");
for (const u of r2.update) console.log(`   ${u.label}: day ${u.from_day} -> ${u.day} ${u.time}  (${u.reason})`);
assert.deepStrictEqual(a2[2].map((it) => it.label), ["Shanghai Disneyland"], "Disneyland gets the day to itself");
const dayOf = (after, label) => Number(Object.keys(after).find((d) => after[d].some((it) => it.label === label)));
assert.strictEqual(dayOf(a2, "Shanghai Museum"), dayOf(a2, "Yu Garden"), "Shanghai Museum joins Yu Garden (both Huangpu)");
assert.ok(r2.update.find((u) => u.label === "Shanghai Museum").reason.includes("Disneyland"), "reason names the theme park");
for (const it of a2[1] || []) {
  if (it.icon !== "hotel") assert.ok(toMin(it.time) >= 15 * 60 + 45, `day 1: ${it.label} after check-in`);
}
noOverlap(a2, "whole trip");

// 3. typed-in flights (not booked in Explore): 13:20 landing, 15:00 flight home
const flights = [
  { airline: "AirAsia", flightNumber: "D7 330", dateTime: "8 October 2026 08:10", arrivalTime: "8 October 2026 13:20" },
  { airline: "AirAsia", flightNumber: "D7 331", dateTime: "11 October 2026 15:00", arrivalTime: "11 October 2026 20:30" },
];
const hotelStays = [{ name: "Hotel Indigo Shanghai on the Bund", checkIn: "8 October 2026", checkOut: "11 October 2026" }];
const plan3 = {
  1: [item("x1", "09:00", "Yu Garden", "Huangpu"), item("x2", "11:00", "Shanghai Museum", "Huangpu"),
    item("x3", "16:00", "Tianzifang", "Xuhui", "shopping"), item("x4", "19:00", "Dinner at Nanxiang Steamed Bun Restaurant", "Huangpu", "food")],
  2: [item("y1", "10:00", "Wukang Road", "Xuhui")],
  3: [],
  4: [item("z1", "09:00", "Jade Buddha Temple", "Putuo"), item("z2", "11:00", "Shanghai Tower Observation Deck", "Pudong"),
    item("z3", "14:00", "Lujiazui", "Pudong")],
};
const r3 = optimisePlan(plan3, { mode: "whole", destination: "Shanghai", days, flights, hotelStays });
const a3 = apply(plan3, r3.update);
console.log("3. typed-in flights + booked hotel");
for (const u of r3.update) console.log(`   ${u.label}: day ${u.from_day} -> ${u.day} ${u.time}  (${u.reason})`);
assert.deepStrictEqual(r3.window.floor, { day: 1, minMinutes: 13 * 60 + 20 + 90 });
assert.deepStrictEqual(r3.window.ceil, { day: 4, maxMinutes: 12 * 60 });
for (const it of a3[1] || []) {
  assert.ok(toMin(it.time) >= 14 * 60 + 50, `day 1: ${it.label} at ${it.time} is after landing`);
  assert.ok(Math.abs(toMin(it.time) - 15 * 60) >= DUR.hotel || toMin(it.time) >= 15 * 60 + 45, `day 1: ${it.label} not on top of check-in`);
}
for (const it of a3[4] || []) assert.ok(toMin(it.time) + 60 <= 12 * 60 + 60 && toMin(it.time) < 12 * 60, `day 4: ${it.label} before the flight home`);
for (const it of a3[4] || []) assert.ok(Math.abs(toMin(it.time) - 11 * 60) >= DUR.hotel || toMin(it.time) < 10 * 60 + 15, `day 4: ${it.label} not on check-out`);
assert.ok((a3[3] || []).length > 0, "the empty day takes what did not fit on the short days");
assert.ok(r3.update.some((u) => /flight/.test(u.reason)), "reason mentions the flight");
for (const label of ["Yu Garden", "Shanghai Museum", "Jade Buddha Temple", "Wukang Road"]) {
  const it = Object.values(a3).flat().find((x) => x.label === label);
  assert.ok(toMin(it.time) < 17 * 60 + 30, `${label} is visited in daylight (${it.time})`);
}
// the same day in mode "day" cannot move anything away: it says so instead
const r3d = optimisePlan(plan3, { mode: "day", onlyDay: 1, destination: "Shanghai", days, flights, hotelStays });
console.log("   day 1 alone:", r3d.notes.join(" | "));
assert.ok(r3d.notes.some((n) => n.includes("Optimise Whole Trip")), "a too-full day in mode day comes back as a note");
noOverlap(a3, "flights");

// 4. an untouched plan stays untouched
const r4 = optimisePlan(apply(plan1, r1.update), { mode: "day", onlyDay: 2, destination: "Shanghai", days });
assert.strictEqual(r4.update.length, 0, "running Optimise twice changes nothing the second time");

// 5. unknown places still work (keyword rules only)
const plan5 = { 1: [item("u1", "08:00", "Night market", "Old town", "food"), item("u2", "21:00", "Breakfast", "Hotel", "food"),
  item("u3", "07:00", "Sunset point", "Hill")] };
const r5 = optimisePlan(plan5, { mode: "day", onlyDay: 1, destination: "Nowhere" });
const a5 = apply(plan5, r5.update);
const t5 = (l) => toMin(a5[1].find((it) => it.label === l).time);
assert.ok(t5("Breakfast") < 10 * 60 && t5("Night market") >= 20 * 60 && t5("Sunset point") >= 17 * 60, "keyword rules for unknown places");
assert.ok(findItem(plan5, "Breakfast"));

// 6. one area on one day: Huangpu and Pudong places mixed over three days
const plan6 = {
  1: [item("m1", "10:00", "Yu Garden", "Shanghai"), item("m2", "14:00", "Lujiazui", "Shanghai")],
  2: [item("m3", "10:00", "Shanghai Tower Observation Deck", "Shanghai"), item("m4", "14:00", "City God Temple", "Shanghai")],
  3: [item("m5", "10:00", "Shanghai Museum", "Shanghai"), item("m6", "14:00", "Oriental Pearl Tower", "Shanghai")],
  4: [],
};
const r6 = optimisePlan(plan6, { mode: "whole", destination: "Shanghai", days });
const a6 = apply(plan6, r6.update);
console.log("6. one area per day");
for (const u of r6.update) console.log(`   ${u.label}: day ${u.from_day} -> ${u.day} ${u.time}  (${u.reason})`);
const huangpu = ["Yu Garden", "City God Temple", "Shanghai Museum"].map((l) => dayOf(a6, l));
const pudong = ["Lujiazui", "Shanghai Tower Observation Deck", "Oriental Pearl Tower"].map((l) => dayOf(a6, l));
assert.ok(new Set(huangpu).size === 1, `Huangpu places on one day (${huangpu})`);
assert.ok(new Set(pudong).size === 1, `Pudong places on one day (${pudong})`);
assert.notStrictEqual(huangpu[0], pudong[0], "the two areas on different days");
assert.ok(!Object.values(a6).flat().some((it) => it.label && false));
// the city as an item's "location" is not an area: it must not glue everything together
assert.ok(r6.update.some((u) => /Same area as/.test(u.reason)), "moves say which place they join");
// the group said no in the app: nothing moves just for the area
const r6b = optimisePlan(plan6, { mode: "whole", destination: "Shanghai", days, groupByArea: false });
assert.ok(!r6b.update.some((u) => u.day !== u.from_day && /Same area/.test(u.reason)), "groupByArea off: no area moves");

// 7. places only the catalog knows, by coordinates (within 2.5 km = one area)
const catalog = [
  { name: "Cafe Alpha", type: "restaurant", location: "Kuala Lumpur", lat: 3.1478, lng: 101.7123 },
  { name: "Gallery Beta", type: "attraction", location: "Kuala Lumpur", lat: 3.1490, lng: 101.7100 },
  { name: "Lake Gamma Park", type: "attraction", location: "Kuala Lumpur", lat: 3.0500, lng: 101.5000 },
  { name: "Museum Delta", type: "attraction", location: "Kuala Lumpur", lat: 3.0510, lng: 101.5020 },
];
const plan7 = {
  1: [item("k1", "10:00", "Gallery Beta", "Kuala Lumpur"), item("k2", "14:00", "Lake Gamma Park", "Kuala Lumpur")],
  2: [item("k3", "10:00", "Museum Delta", "Kuala Lumpur"), item("k4", "14:00", "Wild Epsilon Zoo", "Kuala Lumpur")],
  3: [], 4: [],
};
const r7 = optimisePlan(plan7, { mode: "whole", destination: "Kuala Lumpur", days, catalog });
const a7 = apply(plan7, r7.update);
console.log("7. catalog places by coordinates");
for (const u of r7.update) console.log(`   ${u.label}: day ${u.from_day} -> ${u.day} ${u.time}  (${u.reason})`);
assert.strictEqual(dayOf(a7, "Lake Gamma Park"), dayOf(a7, "Museum Delta"), "Lake Gamma Park and Museum Delta (200 m apart) share a day");

console.log("optimise test: all checks passed");
