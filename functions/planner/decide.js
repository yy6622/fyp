// What did the group decide about each PLACE (and the hotel area)?
//
// The trained model (discussion_summary/) labels every message and reads its stance
// (agree / reject / defer ...). This file anchors those stances on the real places the
// chat names (places.js), instead of on whole messages:
//
//   a message that names a place        -> a proposal of / vote for that place by its sender
//                                           ("不去上海中心" -> against; "跟东方明珠差不多" -> neither)
//   a short reply without a place        -> a reaction to the place(s) named just before it
//   "agree" right after an objection      -> agrees with the objection
//   complaints about the pace in general  ("我也不想赶行程", "太早了") are preferences, not votes
//
// Then the group's rule ("if someone proposes it and nobody objects, it is agreed"):
//   objection still standing  -> rejected when objectors >= supporters, otherwise undecided
//   doubt still standing ("我不确定", "看情况") and at most one supporter -> undecided
//   otherwise                 -> agreed
// A choice made in the app ("Decide now", stored per proposal message) always wins.

const { findPlaces, findAreas, findCity, norm } = require("./places");
const { detectStance } = require("../discussion_summary/summariser");
const { effectiveStatus } = require("../discussion_summary/decisions");
const { findNeeds } = require("./needs");

const REACT_WINDOW = 5;          // a reply counts for the places named in the last 5 messages
const QUESTION = /[?？]\s*$|吗\s*[?？]?\s*$|(^|\s)(anyone|who|what|when|where|how)\b/i;
const HOTEL_WORDS = /(酒店|饭店|宾馆|旅馆|民宿|住宿|住在|住哪|hotel|hostel|airbnb|homestay|resort|guesthouse|check[ -]?in|stay)/i;
const HOTEL_ONLY_ZH = /住/;
const PACE = /(赶|行程|累|早起|太早|起不来|睡|休息|rush|tired|wake up|early|sleep|pace|chill)/i;
const CONCERN = /(贵|expensive|pricey|人多|人潮|很多人|好多人|crowded|远|far|排队|queue|太热|好热|晒)/i;
const DOUBT = /(不确定|不知道要不要|看情况|再看看|再说|再想想|再决定|再确认|考虑一下|maybe|not sure|dunno|idk|depends|we'll see|tengok dulu|decide later)/i;
// A real objection to GOING somewhere. A plain "不要" / "cannot" is not enough: in a group chat it is
// mostly banter ("你可不可以不要每一句都讲食物", "Cannot lah，这是我的 personality") or advice
// ("不要每一餐都吃很贵"). "要不要" is a question, and "进不去" is not "不去".
const OBJECT = /(不要去|不想去|不用去|没必要去|别去|不去了|不去吧|不如不去|算了吧|跳过|去一个就够|skip|no need to go|not going|rather not|pass on|not worth|tak nak pergi|tak payah pergi)/i;
const OBJECT_ALONE = /^(不要|不要吧|不好|不行|不了|算了|no|nah|nope|no la|no lah|tak nak|taknak|不想|不去)[!！.。~ 😂😅🙃]*$/i;
const SUPPORT = /(^|[^不])(好啊|好呀|好的|好|可以|行|要啊|我要|去吧|想去|必去|一定要|没问题|没意见|无所谓|都可以|赞成|同意|支持|可以考虑|值得|不错|agree|ok|okay|sure|yes|yeah|yup|can|fine|deal|let'?s go|i'?m in|jom|boleh|setuju|👍|👌|浪漫|romantic|期待|nice|love|good idea|perfect)/i;

/** Firestore-safe id for one place / hotel / wish: "place:shanghai tower" -> "d_place_shanghai_tower". */
function decisionIdFor(key) {
  return "d_" + String(key).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "_").replace(/^_+|_+$/g, "").slice(0, 80);
}

function stanceOf(text, modelStance) {
  const t = norm(text).replace(/要不要/g, " ").replace(/[进出回过上下]不去/g, " ");
  const bare = t.replace(/[\s,，.。!！?？~]+/g, " ").trim();
  if (OBJECT.test(t) || OBJECT_ALONE.test(bare)) return "reject";
  if (DOUBT.test(t)) return "defer";
  if (SUPPORT.test(t)) return CONCERN.test(t) && /[?？]|吗/.test(t) ? "defer" : "agree";
  if (CONCERN.test(t)) return "defer";
  if (PACE.test(t)) return "none";
  // the model's own stance only counts for short replies; in a long message it is mostly about something else
  const lex = Array.from(bare).length <= 12 ? detectStance(text) : "none";
  if (lex === "agree" || lex === "finalize") return "agree";
  if (lex === "defer") return "defer";
  if (lex === "reject" && OBJECT_ALONE.test(bare)) return "reject";
  return modelStance === "agree" || modelStance === "finalize" ? (Array.from(bare).length <= 12 ? "agree" : "none") : "none";
}

/**
 * messages: [{id, speaker, text}]   s: summarise() result (per-message label / stance)
 * known: places.knownPlaces(...)    decisions: trips/{id}.discussionDecisions (or null)
 * Returns { places: [...], hotels: [...], destination }
 *   each: { key, kind, name, place, status, proposer, support, against, hesitant, mentions, messageId,
 *           dayText: [texts that may name the day], timeText: [texts that may name the time], partners }
 */
function decide({ messages, s, known, members = [], decisions = null }) {
  const modelOf = new Map((s.messages || []).map((m) => [m.id, m]));
  const items = new Map();          // key -> item
  const recent = [];                // [{idx, keys}] messages that named something
  const namedIn = new Map();        // message id -> how many places / wishes it names
  let destination = null;

  const item = (key, kind, name, place, msg) => {
    if (!items.has(key)) {
      items.set(key, { key, kind, name, place, proposer: msg.speaker, messageId: msg.id, events: [], mentions: [],
        dayText: [], timeText: [], partners: new Set() });
    }
    return items.get(key);
  };

  messages.forEach((msg, idx) => {
    const text = msg.text || "";
    const model = modelOf.get(msg.id) || {};
    if (!destination) destination = findCity(text, known);
    const hotelTalk = HOTEL_WORDS.test(text) || (HOTEL_ONLY_ZH.test(text) && /附近|旁边|那边|一带/.test(text));
    const named = [];

    if (hotelTalk) {
      for (const area of findAreas(text, known)) {
        const it = item(`hotel:${norm(area)}`, "hotel", area, null, msg);
        named.push({ it, negated: false });
      }
    } else {
      const hits = findPlaces(text, known, members);
      for (const h of hits) {
        if (h.compare) continue;
        const it = item(`place:${norm(h.place.name)}`, "place", h.place.name, h.place, msg);
        named.push({ it, negated: h.negated });
      }
      // "a museum", "café with a city view", "本帮菜": a kind of place, not a named one
      const prev = recent[recent.length - 1];
      const thread = prev && idx - prev.idx <= REACT_WINDOW ? prev.keys.filter((k) => k.startsWith("place:")) : [];
      for (const need of findNeeds(text, hits.map((h) => [h.start, h.end]))) {
        const it = item(`need:${need.kind}`, "need", need.label, null, msg);
        it.need = need;
        it.conditional = it.mentions.length ? it.conditional && need.conditional : need.conditional;
        for (const k of thread) it.partners.add(k);       // "附近的 brunch place" -> near the place just discussed
        named.push({ it, negated: false });
      }
    }

    if (named.length) {
      namedIn.set(msg.id, named.length);
      const stance = stanceOf(text, model.stance);
      for (const { it, negated } of named) {
        it.mentions.push(msg.id);
        it.dayText.push(text);
        it.timeText.push(text);
        // naming a place = proposing / supporting it, unless it is turned down in the same breath
        const type = negated || stance === "reject" && it.mentions.length > 1 ? "reject"
          : stance === "defer" && it.mentions.length > 1 ? "defer" : "support";
        it.events.push({ type, who: msg.speaker, idx });
        for (const o of named) if (o.it !== it) it.partners.add(o.it.key);
      }
      recent.push({ idx, keys: named.map((n) => n.it.key) });
      return;
    }

    // a reply without a place: reacts to whatever was named just before
    const last = recent[recent.length - 1];
    if (!last || idx - last.idx > REACT_WINDOW) return;
    // a new question without a place ("我退出这个 group 还来得及吗") starts another thread:
    // the replies after it answer that question, not the place
    if (QUESTION.test(text.trim()) && !/(第.天|day ?\d|几点|what time)/i.test(text) && !CONCERN.test(text)) {
      recent.push({ idx, keys: [] });
      return;
    }
    if (!last.keys.length) return;
    // the thread goes on as long as people keep replying to it (at most 10 replies)
    last.replies = (last.replies || 0) + 1;
    if (last.replies <= 10) last.idx = idx;
    let stance = stanceOf(text, model.stance);
    if (stance === "none" || stance === "info" || stance === "ask" || stance === "propose") {
      // still useful: "那排第二天吧" names the day for the place just discussed
      for (const k of last.keys) items.get(k).dayText.push(text);
      return;
    }
    for (const k of last.keys) {
      const it = items.get(k);
      const prev = it.events[it.events.length - 1];
      // "agree" straight after an objection agrees with the objection
      if (stance === "agree" && prev && prev.type === "reject" && prev.idx >= idx - 2 && prev.who !== msg.speaker &&
          it.proposer !== msg.speaker && Array.from(text).length <= 15) {
        stance = "reject";
      }
      it.events.push({ type: stance === "agree" ? "support" : stance, who: msg.speaker, idx });
      it.dayText.push(text);
    }
  });

  const out = [];
  for (const it of items.values()) {
    const latest = new Map();         // each person's last word counts
    for (const e of it.events) latest.set(e.who, e.type);
    const support = [...latest].filter(([, t]) => t === "support").map(([w]) => w);
    const against = [...latest].filter(([, t]) => t === "reject").map(([w]) => w);
    const hesitant = [...latest].filter(([, t]) => t === "defer").map(([w]) => w);
    let status = "confirmed";
    if (against.length) status = against.length >= support.length ? "rejected" : "pending";
    else if (hesitant.length && (support.length <= 1 || it.kind === "need")) status = "pending";   // a vague wish + doubt = not decided
    // "Decide now" choices are stored per ITEM (decisionIdFor), so one message that names two
    // places ("上海中心大厦、东方明珠") gives two separate choices. Older choices were stored per
    // message: still honoured, but only when that message named this item alone.
    const ownId = decisionIdFor(it.key);
    const legacyId = decisions && it.mentions.find((id) => decisions[id] && (namedIn.get(id) || 0) === 1);
    const decision = decisions && (decisions[ownId] || (legacyId && decisions[legacyId])) || null;
    out.push({
      key: it.key, kind: it.kind, name: it.name, place: it.place,
      status: effectiveStatus(decision, status),
      decided: decision ? { status: decision.status, byName: decision.byName || "", memberNames: decision.memberNames || [],
        voteTitle: decision.voteTitle || "" } : null,
      proposer: it.proposer, support, against, hesitant,
      // the id the app records a "Decide now" choice under (kept in the messageId field for the app)
      messageId: ownId, sourceMessageId: it.messageId, mentions: it.mentions,
      dayText: it.dayText, timeText: it.timeText, partners: [...it.partners],
      need: it.need || null, conditional: Boolean(it.conditional),
    });
  }
  return {
    places: out.filter((x) => x.kind === "place"),
    hotels: out.filter((x) => x.kind === "hotel"),
    needs: out.filter((x) => x.kind === "need"),
    destination,
  };
}

module.exports = { decide, stanceOf, decisionIdFor };
