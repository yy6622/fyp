// Checks that AI Summarise builds an ORGANISED plan from a messy chat (plan_test_chat.json,
// written in the style of the real Shanghai group): only real places, one entry per place,
// sensible days and times, nothing copied from small talk.
// Run from functions/:   cd functions && node ../ml/discussion_summary/test_planner.js
const path = require("path");
const assert = require("assert");
const fn = path.join(__dirname, "..", "..", "functions");
const chat = require("./plan_test_chat.json");
const { buildItinerary } = require(path.join(fn, "itinerary_engine"));
const { buildResponse } = require(path.join(fn, "discussion_summary"));
const { loadModel } = require(path.join(fn, "discussion_summary", "load_model"));

(async () => {
  const messages = chat.messages.map(([speaker, text], i) => ({ id: "m" + String(i).padStart(3, "0"), speaker, text }));
  const members = [...new Set(chat.messages.map((m) => m[0]))];
  const plan = {};
  for (const d of chat.days) plan[d.day] = [];
  const r = await buildItinerary({ messages, members, days: chat.days, plan, saved: [], destination: chat.destination,
    model: loadModel().model });
  const add = r.answer.add;
  for (const a of add) console.log(`  Day ${a.day} ${a.time}  ${a.label}${a.location ? "  (" + a.location + ")" : ""}`);
  console.log("  undecided:", r.answer.unresolved.join(", "));

  const labels = add.map((a) => a.label);
  for (const p of chat.expect.places) assert.ok(labels.includes(p), `agreed place in the plan: ${p}`);
  for (const p of chat.expect.rejected) assert.ok(!labels.includes(p), `turned-down place not in the plan: ${p}`);
  for (const p of chat.expect.pending) assert.ok(r.answer.unresolved.includes(p), `undecided: ${p}`);
  for (const t of chat.expect.never) assert.ok(!labels.some((l) => l.includes(t)), `small talk never becomes a plan item: ${t}`);
  assert.strictEqual(new Set(labels).size, labels.length, "each place once");
  const at = (l) => add.find((a) => a.label === l);
  assert.strictEqual(at("Shanghai Disneyland").day, 2, "Disneyland on day 2 (那排第二天吧)");
  assert.ok(!add.some((a) => a.day === 2 && a.label !== "Shanghai Disneyland"), "Disneyland day has nothing else");
  assert.ok(at("The Bund").day === 1 && at("The Bund").time >= "18:00", "the Bund on the first evening (第一天晚上)");
  assert.strictEqual(at("Yu Garden").day, at("Nanxiang Steamed Bun Restaurant").day, "豫园 + 南翔小笼 on the same day");
  assert.ok(add.some((a) => a.icon === "hotel" && a.day === 1 && a.time === "15:00"), "check-in near People's Square, day 1 15:00");
  assert.ok(add.every((a) => a.time >= "08:00"), "nothing at night-time hours like 02:30");
  const perDay = {};
  for (const a of add) if (!["food", "hotel"].includes(a.icon)) perDay[a.day] = (perDay[a.day] || 0) + 1;
  assert.ok(Object.values(perDay).every((n) => n <= 3), "at most 3 sights a day (the chat asked for a relaxed trip)");

  const sum = buildResponse(messages, members, null, { destination: chat.destination, memberNames: members });
  console.log(sum.text.split("\n").map((l) => "  " + l).join("\n"));
  const items = sum.sections.flatMap((s) => s.items);
  assert.ok(items.every((it) => it.value), "every summary item has a clean value (no raw chat lines)");
  assert.ok(sum.facts.destination === "Shanghai" && /8-15 Oct/.test(sum.text), "destination + dates");
  assert.ok(items.some((it) => it.value === "Shanghai Tower Observation Deck" && it.status === "rejected"), "turned down shown");

  // 2. the group's own Shanghai chat (real_chats/shanghai_group.json, 182 messages of mostly banter)
  const real = require("./real_chats/shanghai_group.json");
  const rm = real.messages.map(([speaker, text], i) => ({ id: "r" + String(i).padStart(3, "0"), speaker, text }));
  const rmembers = [...new Set(real.messages.map((m) => m[0]))];
  const rplan = {};
  for (const d of real.days) rplan[d.day] = [];
  const rr = await buildItinerary({ messages: rm, members: rmembers, days: real.days, plan: rplan, saved: [],
    destination: real.destination, model: loadModel().model });
  console.log("  -- real group chat --");
  for (const a of rr.answer.add) console.log(`  Day ${a.day} ${a.time}  ${a.label}`);
  console.log("  undecided:", rr.answer.unresolved.join(", "));
  const rl = rr.answer.add.map((a) => a.label);
  for (const p of ["The Bund", "Nanjing Road", "Yu Garden", "Huangpu River Cruise", "Wukang Road", "Shanghai Museum", "Lujiazui"]) {
    assert.ok(rl.includes(p), `real chat: agreed place in the plan: ${p}`);
  }
  assert.ok(rr.answer.add.every((a) => a.known), "real chat: only real places (no 例如博物馆 / 一条小巷 / 提前弄)");
  const ra = (l) => rr.answer.add.find((a) => a.label === l);
  assert.ok(ra("Nanjing Road").day === ra("The Bund").day && ra("Nanjing Road").time < ra("The Bund").time,
    "real chat: 先去南京路走走，晚上再去外滩");
  assert.ok(ra("The Bund").time >= "18:00", "real chat: the Bund at night");
  assert.ok(rr.answer.add.every((a) => a.time >= "08:00"), "real chat: no 01:00 / 06:00 times");
  assert.ok(rr.answer.unresolved.includes("Oriental Pearl Tower"), "real chat: observation decks undecided (先看天气再决定)");

  // 3. same chat + a saved list + things already in the plan
  const saved = [
    { name: "Yuyuan Garden", location: "Huangpu", type: "attraction", category: "Garden" },
    { name: "Shanghai Museum", location: "People's Square", type: "attraction", category: "Museum" },
    { name: "Shanghai Natural History Museum", location: "Jing'an", type: "attraction", category: "Museum" },
    { name: "Jia Jia Tang Bao", location: "Huanghe Road", type: "restaurant", cuisineTags: ["Chinese", "Dumplings"] },
    { name: "Seesaw Coffee", location: "Jing'an", type: "restaurant", cuisineTags: ["Cafe"] },
    { name: "Sproutworks", location: "Xuhui", type: "restaurant", cuisineTags: ["Brunch", "Cafe"] },
    { name: "Old Jesse", location: "Xuhui", type: "restaurant", cuisineTags: ["Shanghainese"] },
  ];
  const splan = {};
  for (const d of real.days) splan[d.day] = [];
  splan[2] = [{ id: "x1", time: "09:30", label: "Meet tour guide", icon: "activity" }];
  splan[3] = [{ id: "x2", time: "10:00", label: "Cooking class", icon: "activity" }, { id: "x3", time: "19:30", label: "Acrobatics show", icon: "activity" }];
  const sr = await buildItinerary({ messages: rm, members: rmembers, days: real.days, plan: splan, saved,
    destination: real.destination, model: loadModel().model });
  console.log("  -- with saved list + existing plan --");
  for (const a of sr.answer.add) console.log(`  Day ${a.day} ${a.time}  ${a.label}  [${a.source}]  ${a.reason}`);
  for (const i of sr.ideas) console.log(`  idea: ${i.label} - ${i.hint}`);
  const sl = sr.answer.add.map((a) => a.label);
  assert.ok(sl.includes("Yuyuan Garden") && !sl.includes("Yu Garden"), "saved place uses its exact saved name (rich activity card)");
  assert.ok(sr.answer.add.find((a) => a.label === "Yuyuan Garden").source === "saved", "marked as from the saved list");
  for (const n of ["Jia Jia Tang Bao", "Seesaw Coffee", "Sproutworks", "Old Jesse"]) {
    assert.ok(sl.includes(n), `generic wish filled from the saved list: ${n}`);
  }
  assert.ok(!sl.includes("Shanghai Natural History Museum"), "\"博物馆\" is already covered by 上海博物馆: no second museum");
  // dessert wanted, nothing saved or known fits -> the wish itself goes into the plan as a time block
  // dessert wanted, nothing saved fits -> a dessert place Voya knows in Shanghai, in the afternoon
  const dessert = sr.answer.add.find((a) => /Dessert/.test(a.reason));
  assert.ok(dessert && dessert.source === "voya" && dessert.time >= "13:00", "dessert wanted -> Voya's pick in the afternoon");
  const foodByDay = {};
  for (const a of sr.answer.add) if (a.icon === "food") foodByDay[a.day] = (foodByDay[a.day] || 0) + 1;
  assert.ok(Object.values(foodByDay).every((c) => c <= 3), "at most 3 food stops a day");
  const toM = (t) => +t.slice(0, 2) * 60 + +t.slice(3);
  for (const a of sr.answer.add) {
    for (const it of splan[a.day]) {
      assert.ok(Math.abs(toM(it.time) - toM(a.time)) >= 60, `no clash with the plan: ${a.label} vs ${it.label} on day ${a.day}`);
    }
  }
  const meals = {};
  for (const a of sr.answer.add) if (a.icon === "food") (meals[a.day] = meals[a.day] || []).push(a.time);
  for (const ts of Object.values(meals)) {
    const lunches = ts.filter((t) => t >= "10:00" && t < "14:00");
    assert.ok(lunches.length <= 1, "at most one brunch / lunch a day");
  }

  // 4. "Decide now" on one of two places named in the SAME message only changes that one
  const { buildResponse: br } = require(path.join(fn, "discussion_summary"));
  const rs = br(rm, rmembers, null, { destination: real.destination, memberNames: rmembers });
  const tower = rs.pending.find((p) => p.value === "Shanghai Tower Observation Deck");
  const pearl = rs.pending.find((p) => p.value === "Oriental Pearl Tower");
  assert.ok(tower && pearl && tower.messageId !== pearl.messageId, "two places from one message get two decision ids");
  const dec = { [tower.messageId]: { status: "split", byName: "Emily", memberNames: ["Emily"] } };
  const rs2 = br(rm, rmembers, dec, { destination: real.destination, memberNames: rmembers });
  const all2 = rs2.sections.flatMap((x) => x.items);
  assert.ok(all2.find((i) => i.value === "Shanghai Tower Observation Deck").decided.status === "split", "split applied to the tapped place");
  assert.ok(!all2.find((i) => i.value === "Oriental Pearl Tower").decided, "the other place is untouched");
  // 5. booked flights and hotel: the plan is built around them
  const flights = [
    { airline: "AirAsia", flightNumber: "D7 330", routeCode: "KUL-PVG", dateTime: "8 October 2026 08:10", arrivalTime: "8 October 2026 13:20" },
    { airline: "AirAsia", flightNumber: "D7 331", routeCode: "PVG-KUL", dateTime: "15 October 2026 15:00", arrivalTime: "15 October 2026 20:30" },
  ];
  const hotelStays = [{ name: "Hotel Indigo Shanghai on the Bund", location: "Huangpu, Shanghai", checkIn: "8 October 2026", checkOut: "15 October 2026" }];
  const fr = await buildItinerary({ messages: rm, members: rmembers, days: real.days, plan: rplan, saved: [],
    destination: real.destination, model: loadModel().model, flights, hotelStays, hasHotel: true });
  console.log("  -- real chat + booked flights and hotel --");
  for (const a of fr.answer.add.filter((x) => x.source !== "voya" && x.icon !== "hotel")) console.log(`  why: ${a.label} - ${a.reason}`);
  for (const f of fr.logistics.fixed) console.log(`  [fixed] Day ${f.day} ${f.time}  ${f.label}`);
  for (const a of fr.answer.add) console.log(`  Day ${a.day} ${a.time}  ${a.label}`);
  const last = real.days.length;
  assert.deepStrictEqual(fr.window.floor, { day: 1, minMinutes: 13 * 60 + 20 + 90 }, "typed-in arrival time sets the floor");
  assert.deepStrictEqual(fr.window.ceil, { day: last, maxMinutes: 12 * 60 }, "flight home sets the ceiling");
  assert.ok(fr.answer.add.some((a) => a.day === 1 && a.label === hotelStays[0].name && a.icon === "hotel" && a.time === "15:00"),
    "check-in on day 1 under the exact hotel name");
  assert.ok(fr.answer.add.some((a) => a.day === last && a.label.startsWith("Check out") && a.time === "11:00"), "check-out on the last day");
  assert.ok(!fr.answer.add.some((a) => a.label.startsWith("Hotel check-in (near")), "no 'find a hotel' item when one is booked");
  for (const a of fr.answer.add) {
    if (a.icon === "hotel") continue;
    if (a.day === 1) assert.ok(toM(a.time) >= 16 * 60, `nothing before landing + check-in: ${a.label} ${a.time}`);
    if (a.day === last) assert.ok(toM(a.time) < 12 * 60, `nothing too close to the flight home: ${a.label} ${a.time}`);
  }
  assert.ok(!fr.ideas.some((i) => i.label === "Flights"), "flights booked: no 'book flights' idea");
  const nf = await buildItinerary({ messages: rm, members: rmembers, days: real.days, plan: rplan, saved: [],
    destination: real.destination, model: loadModel().model,
    savedHotels: [{ name: "The Bund Riverside Hotel", location: "The Bund, Huangpu" }] });
  assert.ok(nf.ideas.some((i) => i.label === "Flights"), "nothing booked: flights idea");
  console.log("  nothing booked ->", nf.answer.add.filter((a) => a.icon === "hotel").map((a) => a.label).join(", "), "|",
    nf.ideas.map((i) => i.label).join(", "));

  // 6. wishes without a place name, in Bangkok: "夜市" / "按摩" / "泰国菜" with nothing saved
  const bk = [["Alex", "去泰国一定要逛夜市！"], ["Emily", "对啊夜市必去"], ["Mia", "好啊 night market"], ["Ryan", "我想去按摩"],
    ["Alex", "ok泰式按摩可以"], ["Emily", "还有大皇宫"], ["Mia", "好"], ["Ryan", "也想吃好吃的泰国菜 local food"], ["Alex", "同意"]]
    .map(([speaker, text], i) => ({ id: "b" + i, speaker, text }));
  const bdays = [1, 2, 3, 4].map((d) => ({ day: d, date: `${7 + d} Nov 2026` }));
  const bplan = {};
  for (const x of bdays) bplan[x.day] = [];
  const bkr = await buildItinerary({ messages: bk, members: ["Alex", "Emily", "Mia", "Ryan"], days: bdays, plan: bplan, saved: [],
    destination: "Bangkok", model: loadModel().model });
  console.log("  -- Bangkok, wishes without a place name --");
  for (const a of bkr.answer.add) console.log(`  Day ${a.day} ${a.time}  ${a.label}  [${a.source}]  ${a.reason}`);
  const nm = bkr.answer.add.find((a) => /night market/i.test(a.label));
  assert.ok(nm && nm.source === "voya" && nm.time >= "18:00", "夜市 -> a real Bangkok night market, in the evening");
  assert.ok(bkr.answer.add.some((a) => a.source === "voya" && /thai/i.test(a.label)), "泰国菜 -> a Thai restaurant Voya knows");
  assert.ok(bkr.answer.add.some((a) => /massage/i.test(a.label) && a.source === "voya"), "按摩 -> a massage place Voya knows");
  const kl = await buildItinerary({ messages: bk, members: ["Alex", "Emily", "Mia", "Ryan"], days: bdays, plan: bplan, saved: [],
    destination: "Kuala Lumpur", model: loadModel().model });
  assert.ok(kl.answer.add.some((a) => a.label === "Massage / spa" && a.source === "generic"), "no massage place known in KL -> a time block");
  // a saved night market wins over Voya's pick
  const bkr2 = await buildItinerary({ messages: bk, members: ["Alex", "Emily", "Mia", "Ryan"], days: bdays, plan: bplan,
    saved: [{ name: "Rot Fai Night Market Srinakarin", location: "Srinakarin", type: "attraction", category: "Night Market" }],
    destination: "Bangkok", model: loadModel().model });
  assert.ok(bkr2.answer.add.some((a) => a.label === "Rot Fai Night Market Srinakarin" && a.source === "saved"), "saved night market is used");
  assert.ok(!bkr2.answer.add.some((a) => a.label === "Jodd Fairs Night Market"), "and not a second one");
  console.log("planner test: all checks passed");
})().catch((e) => { console.error(e); process.exit(1); });
