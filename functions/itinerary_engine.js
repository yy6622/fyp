
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
const FILLER = [
  /^(ok+|okay|so|guys|eh|wah|hmm+|btw)[, ]+/i,
  /\b(let'?s|lets|we should|should we|can we|how about|what about|i (really )?want to|i wanna|want to|must|wajib|jom|apa kata kita|kita kena)\b/gi,
  /\b(go to|go|visit|try|eat at|makan (kat|di)|pergi( ke)?|add|put|in the plan|on day \d+|day \d+|anyone|pls|please|lah|la|leh|ah|ya)\b/gi,
  /(我们|我想|要不要|一定要|去|吃|吧|好不好|怎么样|呢|啊|嘛|欸)/g,
  /[?!？！.,，。~😊😅🤔👍🙏😍🥰]+/g,
];

const tokens = (s) => normalize(s).replace(/[^a-z0-9一-鿿 ]+/g, " ").split(" ").filter(Boolean);

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
  let s = String(text).split(/[，,。;；\n]/)[0] || String(text);
  for (const rx of TIME_WORDS) s = s.replace(rx, " ");
  for (const rx of FILLER) s = s.replace(rx, " ");
  s = s.split(/\s+/).filter(Boolean).join(" ").trim();
  const cps = Array.from(s);
  return (cps.length > 40 ? cps.slice(0, 40).join("") : s) || Array.from(String(text)).slice(0, 40).join("");
}

const toMin = (t) => { const [h, m] = t.split(":").map(Number); return h * 60 + m; };
const toHHMM = (n) => `${String(Math.floor(n / 60) % 24).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;

function freeTime(day, time, taken) {
  let t = toMin(time);
  const set = taken.get(day) || new Set();
  while (set.has(t) && t < 22 * 60) t += 30;
  set.add(t);
  taken.set(day, set);
  return toHHMM(t);
}

const PACE_PREF = /(不想赶|不要太赶|不用赶|别太赶|慢慢|悠闲|放松|chill|relax|slow pace|not rushed|no rush|don'?t want to rush|santai)/i;

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

function whyAgreed(p) {
  const others = p.support.filter((w) => w !== p.proposer);
  const names = others.length > 2 ? `${others.slice(0, 2).join(", ")} +${others.length - 2}` : others.join(", ");
  return `${p.proposer} suggested${names ? ` · ${names} agreed` : " · nobody objected"}`;
}

function freeSlot(planItems, day, time, self = null) {
  const toM = (t) => { const [h, m] = String(t).split(":").map(Number); return h * 60 + (m || 0); };
  const busy = planItems.filter((it) => it.day === day && it !== self && /^\d{2}:\d{2}$/.test(it.time || ""))
    .map((it) => ({ label: it.label, at: toM(it.time) }));
  let t = toM(time);
  const firstClash = busy.find((b) => Math.abs(b.at - t) < 60);
  while (busy.some((b) => Math.abs(b.at - t) < 60) && t < 22 * 60) t += 30;
  return { time: `${String(Math.floor(t / 60)).padStart(2, "0")}:${String(t % 60).padStart(2, "0")}`,
    bumpedBy: firstClash ? firstClash.label : null };
}

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

// Meal gaps: when a day has sights planned but nothing to eat around lunch or
// dinner time, suggest a restaurant close to the stop the group will be at.
const MEALS = [
  { name: "Lunch", from: 11 * 60 + 30, to: 14 * 60, at: 12 * 60 + 30 },
  { name: "Dinner", from: 17 * 60 + 30, to: 21 * 60, at: 19 * 60 },
];
const MEAL_LABEL = /(breakfast|brunch|lunch|dinner|supper|meal|restaurant|food court|hawker|早餐|午餐|午饭|晚餐|晚饭|宵夜|吃饭|餐厅|makan)/i;

const NIGHT_MARKET = /(night market|夜市|pasar malam)/i;
const hasGeo = (p) => p && Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lng));
function kmApart(a, b) {
  const rad = (x) => (Number(x) * Math.PI) / 180;
  const dLat = rad(b.lat) - rad(a.lat);
  const dLng = rad(b.lng) - rad(a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

function suggestMeals({ answer, planItems, fixed = [], days, known, window, foodPreference = "", taken = new Set() }) {
  const { withinWindow } = require("./logistics");
  const { aliasHits, norm } = require("./planner/places");
  const { matchesFoodPreference } = require("./planner/needs");
  const toM = (t) => { const [h, m] = String(t).split(":").map(Number); return h * 60 + (m || 0); };
  const isTime = (t) => /^\d{2}:\d{2}$/.test(t || "");

  // The day plan as it will look after the user applies everything above.
  const removed = new Set(answer.remove.map((r) => `${r.day}|${normalize(r.label)}`));
  const moved = new Map(answer.update.map((u) => [`${u.from_day}|${normalize(u.label)}`, u]));
  const items = [];
  for (const it of planItems) {
    const k = `${it.day}|${normalize(it.label)}`;
    if (removed.has(k)) continue;
    const u = moved.get(k);
    items.push(u ? { ...it, day: u.day, time: u.time } : it);
  }
  for (const a of answer.add) items.push({ day: a.day, time: a.time, label: a.label, location: a.location, icon: a.icon });
  for (const f of fixed) items.push({ day: f.day, time: f.time, label: f.label, icon: f.kind });

  const placeOf = (it) => {
    const n = norm(it.label || "");
    return known.places.find((p) => norm(p.name) === n || (p.saved && norm(p.saved.name) === n) || (p.catalogName && norm(p.catalogName) === n))
      || ((aliasHits(it.label || "", known.places)[0] || {}).place) || null;
  };
  const isMeal = (it) => it.icon === "food" || MEAL_LABEL.test(it.label || "") || (placeOf(it) || {}).icon === "food";

  const used = new Set(taken);
  for (const it of items) used.add(`place:${normalize(it.label || "")}`);
  const nameOf = (p) => (p.saved && p.saved.name) || p.catalogName || p.name;
  const restaurants = known.places.filter((p) => p.icon === "food");
  const hasNightMarket = items.some((it) => NIGHT_MARKET.test(it.label || ""));
  const out = { add: [], ideas: [] };

  for (const d of days) {
    const dayItems = items.filter((it) => it.day === d.day && isTime(it.time));
    const sights = dayItems.filter((it) => it.icon !== "hotel" && it.icon !== "flight" && !isMeal(it));
    if (!sights.length) continue;
    if (sights.some((it) => ((placeOf(it) || {}).hours || 0) >= 6)) continue; // full-day park: meals are eaten inside
    const first = Math.min(...sights.map((it) => toM(it.time)));
    const last = Math.max(...sights.map((it) => toM(it.time)));
    for (const meal of MEALS) {
      if (dayItems.some((it) => isMeal(it) && toM(it.time) >= meal.from - 30 && toM(it.time) <= meal.to)) continue;
      if (first > meal.to || last < meal.from - 180) continue; // the group is not out around this meal
      const busy = [...dayItems, ...out.add.filter((a) => a.day === d.day)].map((it) => toM(it.time));
      let at = null;
      for (const off of [0, 30, -30, 60, -60, 90]) {
        const t = meal.at + off;
        if (t < meal.from || t > meal.to) continue;
        if (busy.some((b) => Math.abs(b - t) < 45)) continue;
        if (!withinWindow(window || {}, d.day, toHHMM(t))) continue;
        at = t;
        break;
      }
      if (at === null) continue;

      const anchors = sights.map((it) => ({ it, p: placeOf(it), gap: Math.abs(toM(it.time) - at) })).sort((a, b) => a.gap - b.gap);
      const anchor = anchors.find((x) => hasGeo(x.p)) || anchors.find((x) => x.p && x.p.district) || anchors[0];
      const ap = anchor && anchor.p;
      const score = (p) => {
        let s = 0;
        if (p.saved) s += 3;
        if (foodPreference && matchesFoodPreference(p, foodPreference)) s += 2;
        if (hasGeo(ap) && hasGeo(p)) s += 3 / (1 + kmApart(ap, p));
        else if (ap && ap.district && p.district === ap.district) s += 1.5;
        if (p.source === "catalog") s += 0.3;
        return s;
      };
      const slotOk = (p) => { const sl = p.slots || ""; return !/[BLAD]/.test(sl) || (meal.name === "Lunch" ? /L/.test(sl) : /D/.test(sl)); };
      const pick = restaurants
        .filter((p) => slotOk(p) && !(hasNightMarket && NIGHT_MARKET.test(`${p.name} ${(p.tags || []).join(" ")}`)))
        .filter((p) => !used.has(`place:${normalize(nameOf(p))}`) && !used.has(`place:${normalize(p.name)}`))
        .sort((a, b) => score(b) - score(a))[0];
      if (!pick) {
        out.ideas.push({ label: `${meal.name} on day ${d.day}`, saved: "",
          hint: "Suggested for you · no meal is planned at this time · save a restaurant in Explore" });
        continue;
      }
      used.add(`place:${normalize(nameOf(pick))}`);
      used.add(`place:${normalize(pick.name)}`);
      const km = hasGeo(ap) && hasGeo(pick) ? kmApart(ap, pick) : null;
      const near = !anchor ? ""
        : km !== null && km <= 15 ? ` · ${km < 1 ? `${Math.round(km * 1000)} m` : `${km.toFixed(1)} km`} from ${anchor.it.label}`
          : ap && ap.district && pick.district === ap.district ? ` · near ${anchor.it.label}` : "";
      out.add.push({ day: d.day, time: toHHMM(at), label: nameOf(pick),
        location: (pick.saved && pick.saved.location) || pick.area || "", icon: "food", known: true, source: "suggested",
        reason: `Suggested for you · ${meal.name.toLowerCase()} time, no meal planned${near}${pick.saved ? " · saved" : ""}` });
    }
  }
  return out;
}

async function buildItinerary({ messages, members, days, plan, saved, catalog = [], destination = "", model,
  decisions = null, window = null, hasHotel = false, flights = [], hotelStays = [], savedHotels = [], lookupNeed = null,
  foodPreference = "", accommodation = "", votes = [], interests = [] }) {
  const { knownPlaces, norm, findPlaces } = require("./planner/places");
  const { tripLogistics } = require("./planner/logistics_plan");
  const { decide, stanceOf } = require("./planner/decide");
  const { schedule } = require("./planner/schedule");
  const { placeFits, genericPlace, matchesFoodPreference, matchesInterests } = require("./planner/needs");
  const s = summarise(messages, model, members);
  const planItems = Object.keys(plan).flatMap((k) => (plan[k] || []).map((it) => ({ ...it, day: Number(k) })));
  const known = knownPlaces({ destination: destinationOf(destination, messages), saved, catalog,
    planned: planItems.map((it) => ({ name: it.label, location: it.location, icon: it.icon })) });
  // A vote like "第几天去极乐寺" -> "Day 3" is never linked to any chat
  // DiscussionItem, so it never reaches trip.discussionDecisions -- this is
  // the only way the model sees it. See planner/vote_days.js for why.
  const { voteDayAssignments, leadingOptionOf, voteTie } = require("./planner/vote_days");
  const voteDayByPlace = voteDayAssignments({ votes, known, days });
  // Generalised version of the comment above: ANY poll (hotel, restaurant,
  // attraction, "which day", activity -- anything) whose title + winning
  // option names a place or hotel this trip already knows about counts as
  // the group having agreed on it, same as a clear chat consensus would --
  // and a poll result carries MORE weight than chat sentiment: it overrides
  // even an explicit chat rejection ("不要去"), since an actual vote is a
  // more deliberate signal of what the group decided than passive chat
  // discussion. A poll with zero votes yet resolves nothing (same as
  // before). A genuine TIE is different from "no votes" -- instead of
  // silently resolving nothing the same way, it's surfaced in `unresolved`
  // so the group is told to break the tie rather than have the app guess.
  const HOTEL_VOTE_RE = /hotel|accommodation|住宿|酒店|住哪/i;
  // A standalone "Yes/No: visit X?" poll names the place in its TITLE no
  // matter which option wins -- so a "No" win must not be read as "the
  // group agreed to X" just because X happens to be in the title. Mirrors
  // the yes/no convention VoteResolutionService.pollVerdict already uses
  // elsewhere in the app for discussion-linked polls.
  const NEGATIVE_OPTION_RE = /^(no|skip|cancel|不要|不去|算了|跳过)\b/i;
  const votePlaceWinners = new Map(); // norm(place name) -> { place, voteTitle }
  let hotelVoteWinner = null; // { name, voteTitle } | null
  // Structured (not just text) so the sheet can let the group resolve the
  // tie right there -- tap an option, cast the vote, done -- instead of
  // just being told a tie exists and having to go find the poll themselves.
  const tiedVotes = []; // { voteId, title, options: [{ id, label, votes }] }
  for (const vote of votes || []) {
    const voteTitle = String((vote && vote.title) || "").trim();
    const isHotelPoll = HOTEL_VOTE_RE.test(voteTitle);
    const leader = leadingOptionOf(vote);
    if (leader && !NEGATIVE_OPTION_RE.test(String(leader.label || "").trim())) {
      const label = String(leader.label || "").trim();
      if (isHotelPoll && label && !hotelVoteWinner) hotelVoteWinner = { name: label, voteTitle: voteTitle || "a poll" };
      const text = `${voteTitle} ${label}`.trim();
      if (text) {
        for (const hit of findPlaces(text, known, members)) {
          if (hit.negated || hit.compare) continue;
          votePlaceWinners.set(norm(hit.place.name), { place: hit.place, voteTitle: voteTitle || "a poll" });
        }
      }
    } else if (!leader && voteTie(vote)) {
      const optionEntries = Object.entries(vote.options || {});
      const relevant = isHotelPoll ||
        optionEntries.some(([, o]) => findPlaces(`${voteTitle} ${(o && o.label) || ""}`, known, members)
          .some((h) => !h.negated && !h.compare));
      if (relevant && vote.id) {
        tiedVotes.push({
          voteId: vote.id,
          title: voteTitle || "This vote",
          options: optionEntries.map(([id, o]) => ({
            id,
            label: String((o && o.label) || ""),
            votes: Array.isArray(o && o.votedBy) ? o.votedBy.length : 0,
          })),
        });
      }
    }
  }
  const d = decide({ messages, s, known, members, decisions });
  const lp = tripLogistics({ flights, hotelStays, days, window, messages });
  window = lp.window;
  const planWithFixed = {};
  for (const k of Object.keys(plan)) planWithFixed[k] = [...(plan[k] || [])];
  for (const f of lp.fixed) (planWithFixed[f.day] = planWithFixed[f.day] || []).push({ time: f.time, label: f.label, icon: f.kind });
  const answer = { add: [], update: [], remove: [], unresolved: [] };
  const mentionText = new Map(messages.map((m) => [m.id, m.text]));

  const toPlan = [];
  const voteHandledKeys = new Set();
  for (const p of d.places) {
    const inPlan = planItemFor(p.place, planItems);
    const mentions = p.mentions.map((id) => mentionText.get(id));
    const voteWin = votePlaceWinners.get(norm(p.place.name));
    if (voteWin) voteHandledKeys.add(norm(p.place.name));
    // A poll result overrides chat status either way -- "still pending in
    // chat" (nobody reached a clear yes) and even an explicit chat
    // rejection ("不要去") both get promoted to agreed when a vote settled
    // it, since a vote is a more deliberate, harder signal than chat
    // sentiment.
    const status = voteWin ? "agreed" : p.status;
    const reason = voteWin ? `Voted for in "${voteWin.voteTitle}"` : whyAgreed(p);
    const votedDay = voteDayByPlace.get(norm(p.place.name));
    let day = votedDay || dayFrom(mentions, days);
    const replyDay = day ? null : dayFrom(p.dayText.filter((t) => !/(不想|不要|别|怕|not|don'?t|won'?t)/i.test(t)), days);
    const fullDay = (p.place.hours || 0) >= 6;
    if (!day && replyDay && !(fullDay && days.length > 2 && (replyDay === 1 || replyDay === days.length))) day = replyDay;
    let time = null;
    // Prefer the LATEST chat mention that actually states a time, not the
    // first one -- otherwise a later correction ("let's move it to 8am
    // instead") is silently ignored once an earlier, vaguer mention (e.g.
    // "day 2 morning") has already matched. Mirrors the fallback loop below,
    // which already keeps overwriting instead of breaking on first hit.
    for (const t of mentions) { const tt = readTime(clauseFor(t, p.place)); if (tt) time = tt; }
    if (!time) {
      const own = new Set(mentions);
      for (const t of p.dayText) {
        if (own.has(t) || /(不要|别|不想|not|don'?t)[^，,。]*点/.test(t)) continue;
        const tt = readTime(t);
        if (tt && (stanceOf(t) === "agree" || !/\d|点/.test(normalize(t)))) time = tt;
      }
    }
    if (fullDay) time = null;
    if (status === "pending") {
      answer.unresolved.push(p.name);
    } else if (status === "rejected") {
      if (inPlan) answer.remove.push({ day: inPlan.day, label: inPlan.label });
    } else if (inPlan) {
      const newDay = day || inPlan.day;
      const newTime = time || inPlan.time;
      if (newDay !== inPlan.day || newTime !== inPlan.time) {
        // Same reason text the add-path uses (whyAgreed) -- an existing
        // item's day/time moving because of chat discussion (or a poll)
        // deserves the same "who suggested / who agreed" explanation a
        // brand-new item gets, instead of a bare "New time (was ...)".
        const slot = freeSlot(planItems, newDay, newTime, inPlan);
        // If the group's chosen time collided with something already on the
        // day, say so explicitly -- otherwise a time that doesn't match what
        // was literally typed in chat reads as Summarise mishearing them,
        // when it's actually deliberately avoiding a double-booking.
        const conflictNote = slot.bumpedBy
          ? `Set for ${slot.time} instead of ${newTime} because ${slot.bumpedBy} is already there then. `
          : "";
        answer.update.push({ label: inPlan.label, from_day: inPlan.day, day: newDay,
          time: slot.time, reason: `${conflictNote}${reason}` });
      }
    } else {
      toPlan.push({ key: p.key, name: p.name, place: p.place, day, time, partners: p.partners, reason });
    }
  }

  // Polls that named a known place but that decide() never surfaced at all
  // (nobody discussed it in chat -- it was purely voted on) still deserve
  // to make it into the plan, same as any other agreed place would.
  for (const [key, voteWin] of votePlaceWinners) {
    if (voteHandledKeys.has(key)) continue;
    const already = planItemFor(voteWin.place, planItems);
    if (already || toPlan.some((tp) => norm(tp.name) === key)) continue;
    toPlan.push({ key: voteWin.place.name, name: voteWin.place.name, place: voteWin.place, day: null, time: null,
      partners: [], reason: `Voted for in "${voteWin.voteTitle}"` });
  }

  const ideas = [];
  const taken = new Set(toPlan.map((p) => p.key));
  for (const n of d.needs) {
    if (n.status === "rejected") continue;
    const city = known.city || destination || "";
    const coveredBy = d.places.find((p) => p.status !== "rejected" && placeFits(p.place, n.need, city));
    if (coveredBy) {
      const cp = toPlan.find((x) => x.key === coveredBy.key);
      if (cp) cp.reason = whyAgreed({ ...coveredBy, support: [...new Set([...coveredBy.support, ...n.support])] });
      continue;
    }
    if (planItems.some((it) => n.need.fits.test(it.label) || normalize(it.label) === normalize(n.name))) continue;
    const free = (pl) => !taken.has(`place:${normalize(pl.name)}`) && !planItemFor(pl, planItems);
    const savedFits = known.places.filter((pl) => pl.saved && placeFits(pl, n.need, city) && free(pl));
    const fit = n.need.food && foodPreference
      ? savedFits.find((pl) => matchesFoodPreference(pl, foodPreference)) || savedFits.find((pl) => matchesInterests(pl, interests)) || savedFits[0]
      : savedFits.find((pl) => matchesInterests(pl, interests)) || savedFits[0];
    const districts = new Set(toPlan.map((p) => p.place.district).filter(Boolean));
    const voyaPick = fit ? null : known.places
      .filter((pl) => !pl.saved && placeFits(pl, n.need, city) && free(pl))
      .sort((a, b) =>
        (n.need.food && foodPreference ? Number(matchesFoodPreference(b, foodPreference)) - Number(matchesFoodPreference(a, foodPreference)) : 0) ||
        (Number(matchesInterests(b, interests)) - Number(matchesInterests(a, interests))) ||
        Number(districts.has(b.district)) - Number(districts.has(a.district)) ||
        Number(b.source === "catalog") - Number(a.source === "catalog"))[0];
    const who = n.proposer;
    const looseFoodPick = (!fit && !voyaPick && n.need.food) ? known.places
      .filter((pl) => pl.icon === "food" && free(pl))
      .sort((a, b) =>
        Number(districts.has(b.district)) - Number(districts.has(a.district)) ||
        Number(b.source === "catalog") - Number(a.source === "catalog"))[0] || null : null;
    let osmPick = null;
    if (!fit && !voyaPick && !looseFoodPick && n.status === "confirmed" && !n.conditional && lookupNeed) {
      const { fromCatalog } = require("./planner/places");
      const found = fromCatalog(await lookupNeed(n.need, city), "osm").filter(free);
      osmPick = found.find((pl) => placeFits(pl, n.need, city)) || found[0] || null;
      if (osmPick && n.need.slots) osmPick = { ...osmPick, slots: n.need.slots, hours: n.need.hours || osmPick.hours,
        icon: n.need.icon || osmPick.icon };
    }
    if (n.status === "confirmed" && !n.conditional) {
      const pick = fit || voyaPick || looseFoodPick || osmPick || genericPlace(n.need);
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
            : looseFoodPick ? `${wanted} · a restaurant in ${String(city).split(",")[0] || "this city"} you might like (not saved yet)`
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

  if (interests.length) {
    const alreadySuggested = new Set(ideas.map((i) => normalize(i.label)));
    const interestPicks = known.places
      .filter((pl) =>
        pl.icon !== "food" && // restaurants are a separate recommendation list (cuisine tags, not category tags) -- see interest_mapping.dart's own doc comment for why Food/Nightlife aren't in INTEREST_WORDS either
        !planItemFor(pl, planItems) &&
        !taken.has(`place:${normalize(pl.name)}`) &&
        !alreadySuggested.has(normalize(pl.name)) &&
        matchesInterests(pl, interests))
      .sort((a, b) => Number(!!b.saved) - Number(!!a.saved) || Number(b.source === "catalog") - Number(a.source === "catalog"))
      .slice(0, 2);
    // A real saved/catalog place matching the trip's own interests is data
    // we actually have, not a guess -- schedule it into the day with a real
    // time like any other suggestion, and let the traveller decide whether
    // to keep it, instead of leaving it as a text-only "idea" card they'd
    // have to go add by hand.
    for (const pick of interestPicks) {
      const key = `place:${normalize(pick.name)}`;
      taken.add(key);
      toPlan.push({ key, name: pick.name, place: pick, day: null, time: null, partners: [],
        reason: `Matches your trip's interests${pick.saved ? " · saved" : ""} · nobody asked for this in chat, just a suggestion` });
    }
  }

  let checkIn = lp.checkIn;
  let hotel = d.hotels.find((h) => h.status === "confirmed");
  let hotelReasonBase = hotel ? `Agreed to stay near ${hotel.name}` : null;
  // hotelVoteWinner was already resolved in the single pass over `votes`
  // above (hotels live in `savedHotels`, not `known.places`, so they can't
  // go through the generic votePlaceWinners matching).
  if (!hotel && hotelVoteWinner) {
    hotel = { name: hotelVoteWinner.name };
    hotelReasonBase = `Voted for in "${hotelVoteWinner.voteTitle}"`;
  }
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
        known: true, source: "saved", reason: `${hotelReasonBase} · picked from your saved hotels · not booked yet` });
    } else {
      answer.add.push({ day: 1, time: checkIn.time, label: `Hotel check-in (near ${hotel.name})`, location: hotel.name, icon: "hotel",
        known: true, reason: hotelReasonBase });
      ideas.unshift({ label: `Hotel near ${hotel.name}`, saved: "", hint: "Not booked yet · save or book one in Explore" });
    }
  } else if (!hasHotel && !planItems.some((it) => it.icon === "hotel")) {
    const ACCOM_WORDS = { Resort: /resort/i, Hostel: /hostel/i, Homestay: /home.?stay/i,
      Apartment: /apartment|service[d]? apartment|condo/i, Hotel: /\bhotel\b/i };
    const accomRe = ACCOM_WORDS[String(accommodation || "").trim()];
    const hotelPick = (accomRe && savedHotels.find((h) => accomRe.test(h.name))) || savedHotels[0];
    ideas.unshift({ label: "Hotel", saved: (hotelPick && hotelPick.name) || "",
      hint: savedHotels.length ? `Not booked yet · ${savedHotels.length} saved, none agreed in the chat` : "Not booked yet · the group has not picked one" });
  }
  if (!lp.flightsBooked) {
    ideas.unshift({ label: "Flights", saved: "", hint: lp.fixed.some((f) => f.kind === "flight")
      ? "Not booked yet · planned around the times mentioned in the chat" : "Not booked yet · day 1 and the last day are kept light" });
  }
  for (const h of d.hotels) if (h.status === "pending") answer.unresolved.push(`Hotel near ${h.name}`);

  const relaxed = messages.some((m) => PACE_PREF.test(m.text || ""));
  const { aliasHits } = require("./planner/places");
  const planAreas = {};
  for (const it of planItems) {
    const hit = aliasHits(it.label, known.places).sort((a, b) => (b.end - b.start) - (a.end - a.start))[0];
    const area = hit && String(hit.place.district || "").normalize("NFKC").toLowerCase().replace(/\s+/g, " ").trim();
    if (area) (planAreas[it.day] = planAreas[it.day] || []).push(area);
  }
  const times = schedule(toPlan, days, planWithFixed, window, { relaxed, checkIn, planAreas });
  const byKey = new Map(toPlan.map((p) => [p.key, p]));
  const toM = (x) => { const [h, m] = String(x).split(":").map(Number); return h * 60 + (m || 0); };
  for (const t of times) {
    const p = byKey.get(t.key);
    const savedName = p.place.saved && p.place.saved.name;
    // Same reasoning as the update-path's freeSlot note: if the chat gave an
    // explicit time on this same day but the scheduler put it somewhere
    // else, that's almost always because the stated time was already taken
    // -- say so, instead of leaving it looking like the time got misread.
    let conflictNote = "";
    if (p.time && p.day === t.day && p.time !== t.time) {
      const clash = (planWithFixed[t.day] || [])
        .find((it) => /^\d{2}:\d{2}$/.test(it.time || "") && Math.abs(toM(it.time) - toM(p.time)) < 60);
      conflictNote = clash
        ? `Set for ${t.time} instead of ${p.time} because ${clash.label} is already there then. `
        : `Set for ${t.time} instead of ${p.time} to fit around the rest of your day. `;
    }
    answer.add.push({ day: t.day, time: t.time,
      label: savedName || p.place.catalogName || p.name,
      location: (p.place.saved && p.place.saved.location) || p.place.area || "",
      icon: p.place.icon === "activity" ? "activity" : p.place.icon || "place",
      known: p.place.source !== "pattern",
      source: p.place.saved ? "saved" : p.place.generic ? "generic" : p.place.source === "osm" ? "voya" : p.place.source || "voya",
      reason: `${conflictNote}${p.reason || ""}` });
  }
  const meals = suggestMeals({ answer, planItems, fixed: lp.fixed, days, known, window, foodPreference, taken });
  answer.add.push(...meals.add);
  ideas.push(...meals.ideas);
  answer.add.sort((a, b) => a.day - b.day || a.time.localeCompare(b.time));

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
    tiedVotes,
  };
}

module.exports = { buildItinerary, destinationOf, readDay, readTime, findNamed, cleanName, dayMonth };
