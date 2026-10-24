// AI Summarise (itinerary suggestions) - no Gemini, no OpenAI.
//
//  1. Voya's own trained model (discussion_summary/) reads every message and its stance
//     (agree / object / unsure ...).
//  2. The planner (planner/) anchors those stances on REAL places named in the chat (saved list,
//     the app's catalog, Voya's place database), applies the group rule "proposed and nobody
//     objected = agreed", fills wishes like "a museum" from the saved list, and organises the
//     agreed places into days without clashing with the current plan.
//
// Output: {add, update, remove, unresolved} + ideas, parsed / resolved by itinerary_prompt.js.

const { summarise } = require("./discussion_summary/summariser");
const { normalize } = require("./discussion_summary/textproc");

const SLOTS = [
  [/(brunch|早午餐)/, "10:30"],
  [/(breakfast|早餐|sarapan)/, "08:00"],
  [/(sunrise|日出|matahari terbit)/, "06:00"],
  [/(lunch|午餐|午饭|中午|tengah hari|makan tengahari)/, "12:30"],
  [/(sunset|日落|matahari terbenam)/, "17:30"],
  [/(dinner|晚餐|晚饭|makan malam)/, "19:00"],
  [/(supper|宵夜|night market|夜市|pasar malam|night|晚上|malam)/, "20:30"],
  [/(evening|傍晚|petang)/, "17:00"],
  [/(afternoon|下午)/, "14:30"],
  [/(morning|早上|上午|pagi)/, "10:00"],
];
const ZH_NUM = { "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10 };
const WEEKDAYS = [
  ["sun", "sunday", "星期日", "星期天", "周日", "礼拜天", "ahad"],
  ["mon", "monday", "星期一", "周一", "礼拜一", "isnin"],
  ["tue", "tuesday", "星期二", "周二", "礼拜二", "selasa"],
  ["wed", "wednesday", "星期三", "周三", "礼拜三", "rabu"],
  ["thu", "thursday", "星期四", "周四", "礼拜四", "khamis"],
  ["fri", "friday", "星期五", "周五", "礼拜五", "jumaat"],
  ["sat", "saturday", "星期六", "周六", "礼拜六", "sabtu"],
];
const MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
const FOOD_WORDS = /(eat|makan|吃|food|restaurant|cafe|café|kopitiam|hawker|dim sum|laksa|nasi|mee|ramen|sushi|bbq|steamboat|火锅|餐|饭|面|茶|coffee|breakfast|lunch|dinner|supper)/;
const SHOP_WORDS = /(shop|shopping|mall|market|bazaar|outlet|购物|商场|市场|beli|pasar)/;
// Proposal wording to strip when we have to build a name from the message itself.
const FILLER = [
  /^(ok+|okay|so|guys|eh|wah|hmm+|btw)[, ]+/i,
  /\b(let'?s|lets|we should|should we|can we|how about|what about|i (really )?want to|i wanna|want to|must|wajib|jom|apa kata kita|kita kena)\b/gi,
  /\b(go to|go|visit|try|eat at|makan (kat|di)|pergi( ke)?|add|put|in the plan|on day \d+|day \d+|anyone|pls|please|lah|la|leh|ah|ya)\b/gi,
  /(我们|我想|要不要|一定要|去|吃|吧|好不好|怎么样|呢|啊|嘛|欸)/g,
  /[?!？！.,，。~😊😅🤔👍🙏😍🥰]+/g,
];

const tokens = (s) => normalize(s).replace(/[^a-z0-9一-鿿 ]+/g, " ").split(" ").filter(Boolean);

/** A saved place / plan item named in the text (all words of its name, or its Chinese name, appear). */
function findNamed(text, candidates, nameOf) {
  const norm = normalize(text);
  const words = new Set(tokens(text));
  let best = null;
  for (const c of candidates) {
    const name = nameOf(c);
    const tk = tokens(name).filter((t) => t.length >= 3 || /[一-鿿]/.test(t));
    if (!tk.length) continue;
    const hit = normalize(name).length >= 2 && norm.includes(normalize(name))
      ? tk.length + 10
      : tk.every((t) => (/[一-鿿]/.test(t) ? norm.includes(t) : words.has(t))) ? tk.length : 0;
    if (hit && (!best || hit > best.hit)) best = { c, hit };
  }
  return best ? best.c : null;
}

function dayMonth(str) {
  const s = normalize(str);
  let m = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(s);
  if (m) return { d: +m[3], m: +m[2] };
  m = /(\d{1,2})\s*([a-z]{3})[a-z]*/.exec(s);
  if (m && MONTHS.includes(m[2])) return { d: +m[1], m: MONTHS.indexOf(m[2]) + 1 };
  m = /([a-z]{3})[a-z]*\s*(\d{1,2})(?![0-9])/.exec(s);
  if (m && MONTHS.includes(m[1])) return { d: +m[2], m: MONTHS.indexOf(m[1]) + 1 };
  m = /(\d{1,2})月(\d{1,2})/.exec(s);
  if (m) return { d: +m[2], m: +m[1] };
  m = /(\d{1,2})\/(\d{1,2})/.exec(s);
  if (m) return { d: +m[1], m: +m[2] };
  return null;
}

/** 1-based trip day the text points at, or null. */
function readDay(text, days) {
  const s = normalize(text);
  let m = /(?:day|hari)\s*(\d{1,2})/.exec(s);
  if (m && +m[1] >= 1 && +m[1] <= days.length) return +m[1];
  m = /第\s*([0-9]{1,2}|[一二两三四五六七八九十])\s*天/.exec(s);
  if (m) {
    const n = ZH_NUM[m[1]] || +m[1];
    if (n >= 1 && n <= days.length) return n;
  }
  if (/(first day|第一天|hari pertama)/.test(s)) return 1;
  if (/(last day|最后一天|hari terakhir)/.test(s)) return days.length;
  const words = new Set(tokens(text));
  for (let w = 0; w < 7; w++) {
    if (!WEEKDAYS[w].some((x) => (/[一-鿿]/.test(x) ? s.includes(x) : words.has(x)))) continue;
    const hit = days.find((d) => WEEKDAYS[w].includes(normalize(d.weekday).slice(0, 3)) || normalize(d.weekday) === WEEKDAYS[w][1]);
    if (hit) return hit.day;
  }
  const dm = dayMonth(text);
  if (dm) {
    const hit = days.find((d) => {
      const x = dayMonth(d.date || "");
      return x && x.d === dm.d && x.m === dm.m;
    });
    if (hit) return hit.day;
  }
  return null;
}

function readTime(text) {
  const s = normalize(text);
  const m = /(\d{1,2})(?::(\d{2}))?\s*(am|pm)/.exec(s) || /(\d{1,2}):(\d{2})/.exec(s);
  if (m) {
    let h = +m[1];
    if (m[3] === "pm" && h < 12) h += 12;
    if (m[3] === "am" && h === 12) h = 0;
    if (h <= 23) return `${String(h).padStart(2, "0")}:${m[2] || "00"}`;
  }
  // Chinese clock: "九点", "下午三点半", "晚上8点"
  // not "一点点" / "早一点" / "多一点" (= a little), and a bare hour must be a daytime hour
  const zh = /(早上|上午|中午|下午|傍晚|晚上)?\s*(?<![早晚多少快慢好大小有差])([0-9]{1,2}|[一二两三四五六七八九十]{1,3})\s*点(?!点|儿)(半)?/.exec(s);
  if (zh && (zh[1] || !/^(一|两|1|2)$/.test(zh[2]))) {
    const n = zh[2];
    let h = /^[0-9]+$/.test(n) ? +n : n === "十" ? 10 : n.startsWith("十") ? 10 + (ZH_NUM[n[1]] || 0)
      : n.endsWith("十") ? (ZH_NUM[n[0]] || 0) * 10 : n.length === 1 ? ZH_NUM[n] : 0;
    if (/下午|傍晚|晚上/.test(zh[1] || "") && h < 12) h += 12;
    if (!zh[1] && h < 6) h += 12;      // "三点" without 上午 = 3 pm
    if (h >= 6 && h <= 23) return `${String(h).padStart(2, "0")}:${zh[3] ? "30" : "00"}`;
  }
  for (const [rx, t] of SLOTS) if (rx.test(s)) return t;
  return null;
}

/** The part of a message about one place: "先去南京路走走，晚上再去外滩" -> "先去南京路走走" for Nanjing Road. */
function clauseFor(text, place) {
  const names = [place.name, ...(place.aliases || [])].map((a) => normalize(a)).filter((a) => a.length >= 2);
  const parts = normalize(text).split(/[，,。.;；!！?？\n]|然后|之后|then|after that/);
  const hit = parts.filter((c) => names.some((a) => c.includes(a)));
  return hit.length ? hit.join(" ") : normalize(text);
}

function iconFor(text, savedType) {
  if (savedType === "restaurant") return "food";
  const s = normalize(text);
  if (FOOD_WORDS.test(s)) return "food";
  if (SHOP_WORDS.test(s)) return "shopping";
  return "place";
}

const TIME_WORDS = [
  /第\s*([0-9]{1,2}|[一二两三四五六七八九十])\s*天/g, /(今天|明天|后天|今晚|明晚|晚上|早上|上午|下午|中午|傍晚)/g,
  /\b(day|hari)\s*\d+\b/gi, /\b(today|tomorrow|tonight|morning|afternoon|evening|night|pagi|petang|malam)\b/gi,
  /\b(on )?(mon|tues|wednes|thurs|fri|satur|sun)day\b/gi,
];

function cleanName(text) {
  // the name is usually before the first comma ("外滩一定要去，晚上很漂亮")
  let s = String(text).split(/[，,。;；\n]/)[0] || String(text);
  for (const rx of TIME_WORDS) s = s.replace(rx, " ");
  for (const rx of FILLER) s = s.replace(rx, " ");
  s = s.split(/\s+/).filter(Boolean).join(" ").trim();
  const cps = Array.from(s);
  return (cps.length > 40 ? cps.slice(0, 40).join("") : s) || Array.from(String(text)).slice(0, 40).join("");
}

const toMin = (t) => { const [h, m] = t.split(":").map(Number); return h * 60 + m; };
const toHHMM = (n) => `${String(Math.floor(n / 60) % 24).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;

/** Moves a time later in 30-minute steps until it is free on that day. */
function freeTime(day, time, taken) {
  let t = toMin(time);
  const set = taken.get(day) || new Set();
  while (set.has(t) && t < 22 * 60) t += 30;
  set.add(t);
  taken.set(day, set);
  return toHHMM(t);
}

const PACE_PREF = /(不想赶|不要太赶|不用赶|别太赶|慢慢|悠闲|放松|chill|relax|slow pace|not rushed|no rush|don'?t want to rush|santai)/i;

/** The trip's destination, or the city the chat talks about most when the trip has none / an unknown one. */
function destinationOf(destination, messages) {
  const { placesFor, findCity } = require("./planner/places");
  if (placesFor(destination).city) return destination;
  const all = placesFor("");
  const count = new Map();
  for (const m of messages) {
    const c = findCity(m.text || "", all);
    if (c) count.set(c, (count.get(c) || 0) + 1);
  }
  const best = [...count].sort((a, b) => b[1] - a[1])[0];
  return best ? best[0] : destination;
}

/** "Emily suggested · Alex, Mia +2 agreed" */
function whyAgreed(p) {
  const others = p.support.filter((w) => w !== p.proposer);
  const names = others.length > 2 ? `${others.slice(0, 2).join(", ")} +${others.length - 2}` : others.join(", ");
  return `${p.proposer} suggested${names ? ` · ${names} agreed` : " · nobody objected"}`;
}

/** The time itself if nothing else in the plan is on that day at that time, otherwise the next free half hour. */
function freeSlot(planItems, day, time, self = null) {
  const toM = (t) => { const [h, m] = String(t).split(":").map(Number); return h * 60 + (m || 0); };
  const busy = planItems.filter((it) => it.day === day && it !== self && /^\d{2}:\d{2}$/.test(it.time || "")).map((it) => toM(it.time));
  let t = toM(time);
  while (busy.some((b) => Math.abs(b - t) < 60) && t < 22 * 60) t += 30;
  return `${String(Math.floor(t / 60)).padStart(2, "0")}:${String(t % 60).padStart(2, "0")}`;
}

/** Plan item that is this place (any of its names appears in the item's label, or the other way round). */
function planItemFor(place, planItems) {
  const names = [place.name, ...(place.aliases || [])].map((a) => normalize(a)).filter((a) => a.length >= 2);
  return planItems.find((it) => {
    const l = normalize(it.label);
    return names.some((a) => l.includes(a) || (l.length >= 3 && a.includes(l)));
  }) || null;
}

function dayFrom(texts, days) {
  for (const t of texts) {
    const d = readDay(t, days);
    if (d) return d;
  }
  return null;
}

/**
 * messages: [{id, speaker, text}], days: [{day, weekday, date}], destination: trip destination,
 * plan: {day: [{id, time, label, location, icon}]}, saved / catalog: [{name, location, type}],
 * window: logistics window (logistics.js) or null, hasHotel: a hotel stay is already booked.
 * Returns { answer: {add, update, remove, unresolved}, stats, decided }
 */
async function buildItinerary({ messages, members, days, plan, saved, catalog = [], destination = "", model,
  decisions = null, window = null, hasHotel = false, flights = [], hotelStays = [], savedHotels = [], lookupNeed = null }) {
  const { knownPlaces } = require("./planner/places");
  const { tripLogistics } = require("./planner/logistics_plan");
  const { decide, stanceOf } = require("./planner/decide");
  const { schedule } = require("./planner/schedule");
  const { placeFits, genericPlace } = require("./planner/needs");
  const s = summarise(messages, model, members);
  const known = knownPlaces({ destination: destinationOf(destination, messages), saved, catalog });
  const d = decide({ messages, s, known, members, decisions });
  const planItems = Object.keys(plan).flatMap((k) => (plan[k] || []).map((it) => ({ ...it, day: Number(k) })));
  // booked flights / hotel stays (or the times the chat gave): the plan is built around them
  const lp = tripLogistics({ flights, hotelStays, days, window, messages });
  window = lp.window;
  // the schedule sees them as busy slots, so nothing lands on a flight or a check-in
  const planWithFixed = {};
  for (const k of Object.keys(plan)) planWithFixed[k] = [...(plan[k] || [])];
  for (const f of lp.fixed) (planWithFixed[f.day] = planWithFixed[f.day] || []).push({ time: f.time, label: f.label, icon: f.kind });
  const answer = { add: [], update: [], remove: [], unresolved: [] };
  const mentionText = new Map(messages.map((m) => [m.id, m.text]));

  const toPlan = [];
  for (const p of d.places) {
    const inPlan = planItemFor(p.place, planItems);
    const mentions = p.mentions.map((id) => mentionText.get(id));
    let day = dayFrom(mentions, days);
    // a day from a reply in the thread ("那排第二天吧"), but not from "我也不想最后一天…才发现…"
    const replyDay = day ? null : dayFrom(p.dayText.filter((t) => !/(不想|不要|别|怕|not|don'?t|won'?t)/i.test(t)), days);
    const fullDay = (p.place.hours || 0) >= 6;
    // a whole-day place (theme park) is never squeezed into the arrival / last day because of a reply
    if (!day && replyDay && !(fullDay && days.length > 2 && (replyDay === 1 || replyDay === days.length))) day = replyDay;
    // a clock time only from the messages that name the place; "evening" / "lunch" also from the replies
    let time = null;
    for (const t of mentions) { time = readTime(clauseFor(t, p.place)); if (time) break; }
    if (!time) {
      // the replies in the same thread ("九点左右应该可以吧", "晚上走走就好")
      // the last time someone settled on wins; "不要告诉我六点" is not a time anyone wants
      const own = new Set(mentions);
      for (const t of p.dayText) {
        if (own.has(t) || /(不要|别|不想|not|don'?t)[^，,。]*点/.test(t)) continue;
        // a clock time only from a reply that agrees to it ("九点左右应该可以吧"), not from banter about it
        const tt = readTime(t);
        if (tt && (stanceOf(t) === "agree" || !/\d|点/.test(normalize(t)))) time = tt;
      }
    }
    if (fullDay) time = null;          // a whole day: starts in the morning, whatever was said about "tonight"
    if (p.status === "pending") {
      answer.unresolved.push(p.name);
    } else if (p.status === "rejected") {
      if (inPlan) answer.remove.push({ day: inPlan.day, label: inPlan.label });
    } else if (inPlan) {
      const newDay = day || inPlan.day;
      const newTime = time || inPlan.time;
      if (newDay !== inPlan.day || newTime !== inPlan.time) {
        answer.update.push({ label: inPlan.label, from_day: inPlan.day, day: newDay,
          time: freeSlot(planItems, newDay, newTime, inPlan) });
      }
    } else {
      toPlan.push({ key: p.key, name: p.name, place: p.place, day, time, partners: p.partners, reason: whyAgreed(p) });
    }
  }

  // "a museum" / "夜市" / "本帮菜": unless a place the group already named covers it (上海博物馆 is a
  // museum), plan a SAVED place of that kind, else one Voya knows in the city, else the wish itself as a
  // time block (planner/needs.js). Undecided or "if it rains" wishes are shown as ideas.
  const ideas = [];
  const taken = new Set(toPlan.map((p) => p.key));
  for (const n of d.needs) {
    if (n.status === "rejected") continue;
    const city = known.city || destination || "";
    const coveredBy = d.places.find((p) => p.status !== "rejected" && placeFits(p.place, n.need, city));
    if (coveredBy) {
      // "博物馆不错" was a vote for 上海博物馆: count it in that place's reason
      const cp = toPlan.find((x) => x.key === coveredBy.key);
      if (cp) cp.reason = whyAgreed({ ...coveredBy, support: [...new Set([...coveredBy.support, ...n.support])] });
      continue;
    }
    if (planItems.some((it) => n.need.fits.test(it.label) || normalize(it.label) === normalize(n.name))) continue;
    const free = (pl) => !taken.has(`place:${normalize(pl.name)}`) && !planItemFor(pl, planItems);
    const fit = known.places.find((pl) => pl.saved && placeFits(pl, n.need, city) && free(pl));
    // nobody saved one: a place of that kind Voya knows in this city (the app's catalog first, then the
    // gazetteer), preferring one in a district the plan already goes to
    const districts = new Set(toPlan.map((p) => p.place.district).filter(Boolean));
    const voyaPick = fit ? null : known.places
      .filter((pl) => !pl.saved && placeFits(pl, n.need, city) && free(pl))
      .sort((a, b) => Number(districts.has(b.district)) - Number(districts.has(a.district)) ||
        Number(b.source === "catalog") - Number(a.source === "catalog"))[0];
    const who = n.proposer;
    // still nothing: catalog_places in Firestore, then OpenStreetMap (planner/osm_places.js)
    let osmPick = null;
    if (!fit && !voyaPick && n.status === "confirmed" && !n.conditional && lookupNeed) {
      const { fromCatalog } = require("./planner/places");
      const found = fromCatalog(await lookupNeed(n.need, city), "osm").filter(free);
      osmPick = found.find((pl) => placeFits(pl, n.need, city)) || found[0] || null;
      if (osmPick && n.need.slots) osmPick = { ...osmPick, slots: n.need.slots, hours: n.need.hours || osmPick.hours,
        icon: n.need.icon || osmPick.icon };
    }
    if (n.status === "confirmed" && !n.conditional) {
      const pick = fit || voyaPick || osmPick || genericPlace(n.need);
      const key = `place:${normalize(pick.name)}`;
      taken.add(key);
      const mentions = n.mentions.map((id) => mentionText.get(id));
      let time = null;
      for (const t of mentions) { time = readTime(t); if (time) break; }
      const wanted = `${who} wanted: ${n.name}`;
      toPlan.push({ key, name: pick.name, place: pick, day: dayFrom(mentions, days), time,
        partners: n.partners.filter((k) => k.startsWith("place:")),
        reason: fit ? `${wanted} · picked from your saved list`
          : voyaPick ? `${wanted} · Voya's pick in ${String(city).split(",")[0] || "this city"} (not saved yet)`
            : osmPick ? `${wanted} · found nearby on OpenStreetMap (not saved yet)`
            : `${wanted} · no place picked yet, swap in one you like` });
      continue;
    }
    ideas.push({
      label: n.name,
      hint: n.conditional ? (fit ? `Backup if it rains: ${fit.saved.name} (saved)` : "Backup idea if it rains")
        : n.status === "pending" ? `Not decided yet${n.hesitant.length ? ` · ${n.hesitant.join(", ")} unsure` : ""}`
          : `${who} wants this · save one in Explore and run AI Summarise again`,
      saved: fit ? fit.saved.name : "",
    });
  }

  // hotels. Booked stay: check in / check out on its days (the exact hotel name, so the plan shows its
  // card), and a warning when it is not where the group agreed to stay. Nothing booked: the agreed
  // area, using a hotel someone saved there when there is one.
  let checkIn = lp.checkIn;
  const hotel = d.hotels.find((h) => h.status === "confirmed");
  const hasIcon = (day, icon, label) => planItems.some((it) => it.day === day && it.icon === icon &&
    (!label || normalize(it.label).includes(normalize(label)) || normalize(label).includes(normalize(it.label))));
  const near = (text, area) => normalize(text).includes(normalize(area)) || normalize(area).includes(normalize(text));
  if (lp.stays.length) {
    for (const st of lp.stays) {
      const inT = lp.fixed.find((f) => f.kind === "hotel" && f.day === st.fromDay && f.label.startsWith("Check in"));
      if (inT && !hasIcon(st.fromDay, "hotel", st.name)) {
        answer.add.push({ day: st.fromDay, time: inT.time, label: st.name, location: st.location, icon: "hotel", known: true,
          source: "booked", reason: `Check in · booked for day ${st.fromDay}-${st.toDay}` });
      }
      if (st.toDay !== st.fromDay && !hasIcon(st.toDay, "hotel", st.name)) {
        answer.add.push({ day: st.toDay, time: "11:00", label: `Check out · ${st.name}`, location: st.location, icon: "hotel",
          known: true, source: "booked", reason: "Check out of the booked hotel" });
      }
    }
    if (hotel && !lp.stays.some((st) => near(`${st.name} ${st.location}`, hotel.name))) {
      ideas.unshift({ label: `Hotel area: ${hotel.name}`, saved: "",
        hint: `The group agreed to stay near ${hotel.name}, but ${lp.stays[0].name} is booked · check the booking` });
    }
  } else if (hotel && !hasIcon(1, "hotel")) {
    let t = 15 * 60;
    if (window && window.floor && window.floor.day === 1) t = Math.max(t, Math.ceil(window.floor.minMinutes / 15) * 15);
    checkIn = { day: 1, time: `${String(Math.floor(t / 60)).padStart(2, "0")}:${String(t % 60).padStart(2, "0")}` };
    const pick = (savedHotels || []).find((h) => near(`${h.name} ${h.location}`, hotel.name));
    if (pick) {
      answer.add.push({ day: 1, time: checkIn.time, label: pick.name, location: pick.location || hotel.name, icon: "hotel",
        known: true, source: "saved", reason: `Agreed to stay near ${hotel.name} · picked from your saved hotels · not booked yet` });
    } else {
      answer.add.push({ day: 1, time: checkIn.time, label: `Hotel check-in (near ${hotel.name})`, location: hotel.name, icon: "hotel",
        known: true, reason: `Agreed to stay near ${hotel.name}` });
      ideas.unshift({ label: `Hotel near ${hotel.name}`, saved: "", hint: "Not booked yet · save or book one in Explore" });
    }
  } else if (!hasHotel && !planItems.some((it) => it.icon === "hotel")) {
    ideas.unshift({ label: "Hotel", saved: (savedHotels[0] && savedHotels[0].name) || "",
      hint: savedHotels.length ? `Not booked yet · ${savedHotels.length} saved, none agreed in the chat` : "Not booked yet · the group has not picked one" });
  }
  if (!lp.flightsBooked) {
    ideas.unshift({ label: "Flights", saved: "", hint: lp.fixed.some((f) => f.kind === "flight")
      ? "Not booked yet · planned around the times mentioned in the chat" : "Not booked yet · day 1 and the last day are kept light" });
  }
  for (const h of d.hotels) if (h.status === "pending") answer.unresolved.push(`Hotel near ${h.name}`);

  const relaxed = messages.some((m) => PACE_PREF.test(m.text || ""));
  // the areas each day of the plan already goes to (a place already planned that Voya knows)
  const { aliasHits } = require("./planner/places");
  const planAreas = {};
  for (const it of planItems) {
    const hit = aliasHits(it.label, known.places).sort((a, b) => (b.end - b.start) - (a.end - a.start))[0];
    const area = hit && String(hit.place.district || "").normalize("NFKC").toLowerCase().replace(/\s+/g, " ").trim();
    if (area) (planAreas[it.day] = planAreas[it.day] || []).push(area);
  }
  const times = schedule(toPlan, days, planWithFixed, window, { relaxed, checkIn, planAreas });
  const byKey = new Map(toPlan.map((p) => [p.key, p]));
  for (const t of times) {
    const p = byKey.get(t.key);
    const savedName = p.place.saved && p.place.saved.name;
    answer.add.push({ day: t.day, time: t.time,
      // the exact saved name: that is what makes the plan show it as a rich activity card
      label: savedName || p.place.catalogName || p.name,
      location: (p.place.saved && p.place.saved.location) || p.place.area || "",
      icon: p.place.icon === "activity" ? "activity" : p.place.icon || "place",
      known: p.place.source !== "pattern",
      source: p.place.saved ? "saved" : p.place.generic ? "generic" : p.place.source === "osm" ? "voya" : p.place.source || "voya",
      reason: p.reason || "" });
  }
  answer.add.sort((a, b) => a.day - b.day || a.time.localeCompare(b.time));

  // undecided budget / dates keep the summary's cleaned value; nothing raw from the chat
  for (const it of s.pending) if (it.value && ["BUDGET", "DATE"].includes(it.category)) answer.unresolved.push(it.value);
  answer.unresolved = [...new Set(answer.unresolved.filter(Boolean))].slice(0, 12);
  return {
    answer,
    ideas,
    decided: d,
    window,
    logistics: { fixed: lp.fixed, stays: lp.stays, flightsBooked: lp.flightsBooked },
    stats: { topics: s.topics.length, places: d.places.length, confirmed: d.places.filter((p) => p.status === "confirmed").length,
      relaxed, openai: "not-needed", openaiTokens: 0 },
  };
}

module.exports = { buildItinerary, destinationOf, readDay, readTime, findNamed, cleanName, dayMonth };
