// Port of ml/discussion_summary/summariser.py - line by line, keep the two identical.
// See the Python file for the explanation of every step; test_parity.py checks
// that both produce the same summary for every test chat.

const { normalize, MONEY_RE, DATE_RE, QUESTION_RE } = require("./textproc");
const { cosine, softmaxTop } = require("./runtime");
const LEX = require("./lexicons.json");

const DEFAULT_WEIGHTS = { R: 0.25, D: 0.45, N: 0.1, C: 0.2 };
const TOPIC_CATS = ["DESTINATION", "BUDGET", "DATE", "ATTRACTION", "TRANSPORT", "ACCOMMODATION"];
const SINGLE_VALUE = new Set(["DESTINATION", "BUDGET", "DATE", "ACCOMMODATION"]);
const TITLES = { DESTINATION: "Destination", DATE: "Dates", BUDGET: "Budget", ACCOMMODATION: "Accommodation",
  ATTRACTION: "Places to visit", TRANSPORT: "Transport" };
const REF_SIM = 0.22;
const SAME_TOPIC_SIM = 0.55;
const WINDOW = 25;

const STOP_WORDS = new Set(LEX.STOP_WORDS);
const ZH_STOP = new Set(Array.from(LEX.ZH_STOP));
const SMALL_TALK = new Set(LEX.SMALL_TALK);
const SMALL_TALK_ZH = [...LEX.SMALL_TALK_ZH].sort((a, b) => (Array.from(b).length - Array.from(a).length) || (a < b ? -1 : a > b ? 1 : 0));
const LAUGH = /^((h[aeiu]){2,}h?|(wk){2,}w?|l+o+l+|lmf?a+o+|x+d+)$/u;
const REPEAT = /(.)\1+/gu;
const WORD_SPLIT = /[^a-z0-9+'À-ɏ]+/u;
const LATIN = /[a-z+]/u;

const len = (s) => Array.from(s).length;

function words(norm) {
  return " " + norm.split(WORD_SPLIT).filter((w) => w).join(" ") + " ";
}

function hasCue(norm, ws, cues) {
  for (const c of cues) {
    if (LATIN.test(c)) {
      if (ws.includes(" " + c + " ")) return true;
    } else if (norm.includes(c)) return true;
  }
  return false;
}

const byLenThenText = (a, b) => (len(b) - len(a)) || (a < b ? -1 : a > b ? 1 : 0);
const ALL_CUES = [].concat(LEX.SPECIAL_AGREE, LEX.SPECIAL_DEFER, LEX.FINALIZE, LEX.REJECT, LEX.DEFER, LEX.AGREE);
const ZH_CUES = [...new Set(ALL_CUES.filter((c) => !LATIN.test(c)))].sort(byLenThenText);
const LATIN_CUES = [...new Set(ALL_CUES.filter((c) => LATIN.test(c)))].sort(byLenThenText);

function contentSize(norm) {
  let rest = norm;
  for (const c of ZH_CUES) rest = rest.split(c).join(" ");
  let ws = words(rest);
  for (const c of LATIN_CUES) ws = ws.split(" " + c + " ").join(" ");
  let n = ws.split(/\s+/u).filter((w) => w && !STOP_WORDS.has(w) && !/^[0-9]+$/u.test(w)).length;
  for (const ch of rest) if (ch >= "一" && ch <= "鿿" && !ZH_STOP.has(ch)) n++;
  return n;
}

const CAP_WORD = /[A-Z][A-Za-z']{3,}/g;
const REACTION_CUES = [].concat(LEX.AGREE, LEX.REJECT, LEX.DEFER, LEX.FINALIZE);

// False when a reply names a place (a Capitalised word that is not the first word)
// that never appears in the topic's own messages.
function namesFit(rawText, topicTexts) {
  const all = rawText.match(CAP_WORD) || [];
  const skipFirst = /^[A-Z][A-Za-z']{3,}/.test(rawText.trim()) ? 1 : 0;
  const ws = all.slice(skipFirst).map((w) => w.toLowerCase())
    .filter((w) => !STOP_WORDS.has(w) && !hasCue(w, " " + w + " ", REACTION_CUES));
  if (!ws.length) return true;
  const joined = topicTexts.map((t) => normalize(t)).join(" ");
  return ws.some((w) => joined.includes(w));
}

// Rules in front of the classifier - see gate() in summariser.py.
function gate(label, text, topProb = 1, minProb = 0) {
  const norm = normalize(text);
  let rest = norm;
  for (const c of SMALL_TALK_ZH) rest = rest.split(c).join(" ");
  const latin = [];
  for (const w of rest.split(WORD_SPLIT)) {
    if (!w || /^[0-9]+$/u.test(w)) continue;
    const w1 = w.replace(REPEAT, "$1");
    if (SMALL_TALK.has(w) || SMALL_TALK.has(w1) || LAUGH.test(w)) continue;
    latin.push(w);
  }
  const cjk = Array.from(rest).filter((ch) => ch >= "\u4e00" && ch <= "\u9fff");
  if (!latin.length && !cjk.length) return "OTHER";
  if (rest !== norm && latin.every((w) => STOP_WORDS.has(w)) && cjk.every((ch) => ZH_STOP.has(ch))) return "OTHER";
  if (["DESTINATION", "ATTRACTION", "TRANSPORT", "ACCOMMODATION"].includes(label)) {
    if (topProb < minProb) return "OTHER";
    const content = latin.filter((w) => Array.from(w).length >= 3 && !STOP_WORDS.has(w));
    if (!content.length && cjk.filter((ch) => !ZH_STOP.has(ch)).length < 2) return "OTHER";
  }
  return label;
}

function detectStance(text) {
  const norm = normalize(text);
  const ws = words(norm);
  if (hasCue(norm, ws, LEX.SPECIAL_AGREE)) return "agree";
  if (hasCue(norm, ws, LEX.SPECIAL_DEFER)) return "defer";
  if (hasCue(norm, ws, LEX.FINALIZE)) return "finalize";
  if (hasCue(norm, ws, LEX.REJECT)) return "reject";
  if (hasCue(norm, ws, LEX.DEFER)) return "defer";
  if (hasCue(norm, ws, LEX.AGREE)) return "agree";
  return "none";
}

// ---------------------------------------------------------------- values
const ZH_DIGIT = { "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10 };
const MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
const MONTH_ALIASES = { sept: "sep", januari: "jan", februari: "feb", mac: "mar", april: "apr", mei: "may",
  julai: "jul", ogos: "aug", oktober: "oct", disember: "dec", september: "sep", november: "nov", june: "jun",
  july: "jul", march: "mar", august: "aug", october: "oct", december: "dec", january: "jan", february: "feb" };
const NUM_RE = /([0-9][0-9,]*(\.[0-9]+)?)[ ]?(k)?(?![a-z])/gu;
const ZH_AMOUNT_RE = /([一二两三四五六七八九十])([千万])([一二两三四五六七八九])?/gu;

function parseMoney(text, last = false) {
  const norm = normalize(text);
  if (!MONEY_RE.test(norm)) return null;
  let vals = [];
  for (const m of norm.matchAll(NUM_RE)) {
    let v = parseFloat(m[1].replace(/,/g, ""));
    if (m[3]) v *= 1000;
    vals.push([m.index, v]);
  }
  for (const m of norm.matchAll(ZH_AMOUNT_RE)) {
    const unit = m[2] === "千" ? 1000 : 10000;
    let v = ZH_DIGIT[m[1]] * unit;
    if (m[3]) v += Math.floor(ZH_DIGIT[m[3]] * unit / 10);
    vals.push([m.index, v]);
  }
  vals = vals.filter((pv) => pv[1] >= 50);
  if (!vals.length) return null;
  if (last) {
    let best = vals[0];
    for (const pv of vals) if (pv[0] > best[0] || (pv[0] === best[0] && pv[1] > best[1])) best = pv;
    return Math.trunc(best[1]);
  }
  return Math.trunc(Math.max(...vals.map((pv) => pv[1])));
}

function moneyBasis(text) {
  const norm = normalize(text);
  const ws = words(norm);
  if (hasCue(norm, ws, LEX.TOTAL)) return "total";
  if (hasCue(norm, ws, LEX.PER_PERSON)) return "per_person";
  return null;
}

function monthKey(tok) {
  tok = tok.toLowerCase();
  tok = MONTH_ALIASES[tok] || tok;
  return MONTHS.includes(tok.slice(0, 3)) ? tok.slice(0, 3) : null;
}
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();

const DATE_PATTERNS = [
  [/([0-9]{1,2})[ ]?([a-z]+)[ ]?(?:-|to|到|至|until|till|hingga)[ ]?([0-9]{1,2})[ ]?([a-z]+)/gu, "d m-d m"],
  [/([0-9]{1,2})[ ]?(?:-|to|到|至|hingga|until|till)[ ]?([0-9]{1,2})[ ]?([a-z]+)/gu, "d-d m"],
  [/([a-z]+)[ ]([0-9]{1,2})[ ]?(?:-|to|until|till)[ ]?([0-9]{1,2})/gu, "m d-d"],
  [/([0-9]{1,2})月([0-9]{1,2})[号日]?[ ]?(?:到|至|-)[ ]?([0-9]{1,2})/gu, "zh d-d"],
  [/(early|mid|end|awal|pertengahan|hujung)[ ](?:of[ ])?([a-z]+)/gu, "part m"],
  [/([0-9]{1,2})月([初中底])/gu, "zh part"],
];

function readDate(kind, g) {
  const i = (x) => parseInt(x, 10);
  if (kind === "d m-d m" && monthKey(g[1]) && monthKey(g[3])) {
    return monthKey(g[1]) === monthKey(g[3]) ? `${i(g[0])}-${i(g[2])} ${cap(monthKey(g[1]))}`
      : `${i(g[0])} ${cap(monthKey(g[1]))} - ${i(g[2])} ${cap(monthKey(g[3]))}`;
  }
  if (kind === "d-d m" && monthKey(g[2])) return `${i(g[0])}-${i(g[1])} ${cap(monthKey(g[2]))}`;
  if (kind === "m d-d" && monthKey(g[0])) return `${i(g[1])}-${i(g[2])} ${cap(monthKey(g[0]))}`;
  if (kind === "zh d-d" && i(g[0]) >= 1 && i(g[0]) <= 12) return `${i(g[1])}-${i(g[2])} ${cap(MONTHS[i(g[0]) - 1])}`;
  if (kind === "part m" && monthKey(g[1])) {
    const which = { awal: "early", pertengahan: "mid", hujung: "end" }[g[0]] || g[0];
    return `${which} ${cap(monthKey(g[1]))}`;
  }
  if (kind === "zh part" && i(g[0]) >= 1 && i(g[0]) <= 12) {
    return `${{ "初": "early", "中": "mid", "底": "end" }[g[1]]} ${cap(MONTHS[i(g[0]) - 1])}`;
  }
  return null;
}

function parseDates(text) {
  const norm = normalize(text);
  let bestPos = -1;
  let best = null;
  for (const [rx, kind] of DATE_PATTERNS) {
    for (const m of norm.matchAll(rx)) {
      const val = readDate(kind, m.slice(1));
      if (val !== null && m.index > bestPos) { bestPos = m.index; best = val; }
    }
  }
  if (best !== null) return best;
  const m = norm.match(DATE_RE);
  return m ? m[0] : null;
}

// ---------------------------------------------------------------- decision rule
function latestStances(stances) {
  const latest = new Map();
  for (const [who, st] of stances) {
    if (st === "agree" || st === "finalize" || st === "propose") latest.set(who, "agree");
    else if (st === "reject") latest.set(who, "reject");
    else if (st === "defer") latest.set(who, "defer");
  }
  return latest;
}

// "Silence is consent": a proposal nobody argues against is agreed.
function decisionStatus(stances, nMembers, superseded) {
  const latest = latestStances(stances);
  const finalized = stances.some(([, st]) => st === "finalize");
  let support = 0;
  let oppose = 0;
  let hesitant = 0;
  for (const v of latest.values()) {
    if (v === "agree") support++;
    else if (v === "reject") oppose++;
    else if (v === "defer") hesitant++;
  }
  if (superseded) return "rejected";
  if (oppose && oppose >= support + hesitant) return "rejected";
  if (oppose) return "pending";
  if (finalized) return "confirmed";
  if (hesitant && support <= 1) return "pending";
  return "confirmed";
}

// ---------------------------------------------------------------- main
const sigmoid = (x) => 1 / (1 + Math.exp(-Math.max(-30, Math.min(30, x))));

function textrank(vecs, nodes, d = 0.85, iters = 40) {
  const n = nodes.length;
  if (n === 0) return new Map();
  const W = nodes.map(() => new Array(n).fill(0));
  for (let a = 0; a < n; a++) {
    for (let b = a + 1; b < n; b++) {
      const s = cosine(vecs.get(nodes[a]), vecs.get(nodes[b]));
      if (s > 0.05) { W[a][b] = s; W[b][a] = s; }
    }
  }
  const outSum = W.map((row) => { let t = 0; for (const x of row) t += x; return t; });
  let pr = new Array(n).fill(1 / n);
  for (let it = 0; it < iters; it++) {
    const next = [];
    for (let b = 0; b < n; b++) {
      let acc = 0;
      for (let a = 0; a < n; a++) if (W[a][b] > 0 && outSum[a] > 0) acc += pr[a] * W[a][b] / outSum[a];
      next.push((1 - d) / n + d * acc);
    }
    pr = next;
  }
  const top = Math.max(...pr) || 1;
  return new Map(nodes.map((id, i) => [id, pr[i] / top]));
}

function isProposal(label, text, stance) {
  const norm = normalize(text);
  const ws = words(norm);
  if (label === "BUDGET") {
    if (!MONEY_RE.test(norm)) return false;
    if (stance === "reject" || hasCue(norm, ws, ["budget", "预算", "bajet"])) return true;
    if (hasCue(norm, ws, LEX.COST_ITEM_CUES)) return false;
    return hasCue(norm, ws, LEX.BUDGET_CUES);
  }
  if (label === "DATE") return DATE_RE.test(norm) && parseDates(text) !== null;
  if (stance === "reject") return true;
  if (hasCue(norm, ws, LEX.INFO_CUES) && !hasCue(norm, ws, ["let's", "lets", "how about", "jom", "去", "吧"])) return false;
  if (QUESTION_RE.test(norm) && hasCue(norm, ws, LEX.INFO_QUESTION_CUES) && !hasCue(norm, ws, LEX.PROPOSE_CUES)) return false;
  return true;
}

const round4 = (x) => Math.round(x * 1e4) / 1e4;

function short(text, n = 45) {
  const t = String(text).split(/\s+/u).filter((x) => x).join(" ");
  const cps = Array.from(t);
  return cps.length <= n ? t : cps.slice(0, n - 1).join("") + "…";
}

function renderText(summary) {
  const wordsFor = [["confirmed", "agreed"], ["pending", "still undecided"], ["rejected", "turned down"]];
  const lines = [];
  for (const sec of summary.sections) {
    const parts = [];
    for (const [status, word] of wordsFor) {
      const vals = sec.items.filter((it) => it.status === status).map((it) => it.value || short(it.text));
      if (vals.length) parts.push(`${word}: ${vals.join(", ")}`);
    }
    lines.push(`${sec.title} - ` + parts.join("; ") + ".");
  }
  if (summary.preferences.length) {
    lines.push("Preferences - " + summary.preferences.map((p) => `${p.speaker}: ${short(p.text, 45)}`).join("; ") + ".");
  }
  if (summary.pending.length) {
    lines.push("Still to decide - " + summary.pending.map((it) => it.value || short(it.text, 35)).join(", ") + ".");
  }
  return lines.join("\n");
}

/**
 * messages: [{id, speaker, text}] in chat order; members: array (only its length is used).
 * Returns the same structure as summariser.py's summarise().
 */
function summarise(messages, model, members = null, weights = null, highlightRatio = 0.2) {
  const w = Object.assign({}, DEFAULT_WEIGHTS, weights || {});
  const speakers = [];
  for (const m of messages) if (!speakers.includes(m.speaker)) speakers.push(m.speaker);
  const nMembers = Math.max((members || []).length, speakers.length, 1);

  const labels = new Map();
  const vecs = new Map();
  const rel = new Map();
  const kOther = model.labels.indexOf("OTHER");
  for (const m of messages) {
    const [rawLab, s, vec] = model.predict(m.text);
    const lab = gate(rawLab, m.text, softmaxTop(s), model.topicMinProb);
    labels.set(m.id, lab);
    vecs.set(m.id, vec);
    let bestOther = -Infinity;
    for (let k = 0; k < s.length; k++) if (k !== kOther && s[k] > bestOther) bestOther = s[k];
    rel.set(m.id, lab === rawLab ? sigmoid(2.0 * (bestOther - s[kOther])) : 0.0);
  }

  const topics = [];
  const stanceOf = new Map();
  const attach = new Map();
  const pos = new Map(messages.map((m, i) => [m.id, i]));
  const textOfMsg = new Map(messages.map((m) => [m.id, m.text]));
  const openTopics = (i, category = null) =>
    topics.filter((t) => i - t.last <= WINDOW && (category === null || t.category === category));

  messages.forEach((m, i) => {
    const mid = m.id;
    const lab = labels.get(mid);
    let st = detectStance(m.text);
    if (TOPIC_CATS.includes(lab)) {
      const same = openTopics(i, lab);
      let best = null;
      let bestSim = 0;
      for (const t of same) {
        const sim = cosine(vecs.get(mid), vecs.get(t.proposal));
        if (sim > bestSim) { best = t; bestSim = sim; }
      }
      if (!isProposal(lab, m.text, st)) {
        if (same.length) {
          const tgt = bestSim >= REF_SIM ? best : same[same.length - 1];
          tgt.messages.push(mid);
          tgt.refs.push(mid);
          attach.set(mid, tgt.id);
        }
        stanceOf.set(mid, "info");
        return;
      }
      if (best !== null && (bestSim >= SAME_TOPIC_SIM || ((st === "agree" || st === "finalize") && bestSim >= REF_SIM))) {
        const st2 = st === "finalize" ? "finalize" : "agree";
        best.stances.push([m.speaker, st2]);
        best.messages.push(mid);
        best.last = i;
        attach.set(mid, best.id);
        stanceOf.set(mid, st2);
        return;
      }
      if (st === "reject" && same.length) same[same.length - 1].stances.push([m.speaker, "reject"]);
      const t = { id: `t${topics.length + 1}`, category: lab, proposal: mid, index: i, counter: st === "reject",
        stances: [[m.speaker, "propose"]], messages: [mid], refs: [mid], last: i };
      topics.push(t);
      attach.set(mid, t.id);
      stanceOf.set(mid, "propose");
    } else if (lab === "DECISION") {
      if (st === "none") st = contentSize(normalize(m.text)) <= 1 ? "agree" : "none";
      const cands = openTopics(i);
      if (!cands.length) { stanceOf.set(mid, st); return; }
      let best = null;
      let bestSim = 0;
      for (const t of cands) {
        let sim = -Infinity;
        for (const x of t.refs) sim = Math.max(sim, cosine(vecs.get(mid), vecs.get(x)));
        if (sim > bestSim) { best = t; bestSim = sim; }
      }
      let tgt;
      if (bestSim >= REF_SIM) {
        tgt = best;
      } else {
        let latest = cands[0];
        for (const t of cands) if (t.index > latest.index) latest = t;
        if (contentSize(normalize(m.text)) === 0 ||
            (i - latest.last <= 2 && namesFit(m.text, latest.refs.map((x) => textOfMsg.get(x))))) tgt = latest;
        else { stanceOf.set(mid, st); return; }
      }
      tgt.stances.push([m.speaker, st]);
      tgt.messages.push(mid);
      tgt.last = i;
      attach.set(mid, tgt.id);
      stanceOf.set(mid, st);
    } else {
      stanceOf.set(mid, "none");
    }
  });

  const raw = new Map(topics.map((t) => [t.id, decisionStatus(t.stances, nMembers, false)]));
  for (const t of topics) {
    const superseded = SINGLE_VALUE.has(t.category) && topics.some(
      (u) => u.category === t.category && u.index > t.index && raw.get(u.id) === "confirmed");
    t.status = decisionStatus(t.stances, nMembers, superseded);
    const latest = latestStances(t.stances);
    t.support = [...latest].filter(([, v]) => v === "agree").map(([p]) => p);
    t.against = [...latest].filter(([, v]) => v === "reject").map(([p]) => p);
  }

  const byId = new Map(topics.map((t) => [t.id, t]));
  const D = new Map();
  for (const m of messages) {
    const mid = m.id;
    const st = stanceOf.get(mid) || "none";
    const t = byId.get(attach.get(mid));
    let d = 0;
    if (st === "propose" && t) d = { confirmed: 1.0, pending: 0.7, rejected: 0.5 }[t.status];
    else if (st === "finalize") d = 0.8;
    else if (labels.get(mid) === "PREFERENCE") d = 0.6;
    else if ((st === "agree" || st === "reject" || st === "defer") && t) d = 0.25;
    else if (st === "info" && t) d = 0.3;
    D.set(mid, d);
  }
  const N = new Map();
  messages.forEach((m, i) => {
    let mx = null;
    for (let j = 0; j < i; j++) {
      const c = cosine(vecs.get(m.id), vecs.get(messages[j].id));
      if (mx === null || c > mx) mx = c;
    }
    N.set(m.id, 1.0 - (mx === null ? 0 : mx));
  });
  const relevant = messages.filter((m) => labels.get(m.id) !== "OTHER").map((m) => m.id);
  const C = textrank(vecs, relevant);
  const S = new Map();
  for (const m of messages) {
    S.set(m.id, w.R * rel.get(m.id) + w.D * D.get(m.id) + w.N * N.get(m.id) + w.C * (C.get(m.id) || 0));
  }

  const textOf = new Map(messages.map((m) => [m.id, m.text]));
  const speakerOf = new Map(messages.map((m) => [m.id, m.speaker]));
  const item = (t) => {
    let value = null;
    if (t.category === "BUDGET") {
      const amt = parseMoney(textOf.get(t.proposal), t.counter);
      if (amt) {
        const basis = moneyBasis(textOf.get(t.proposal));
        value = `RM${amt}` + ({ per_person: " per person", total: " in total" }[basis] || "");
      }
    } else if (t.category === "DATE") {
      value = parseDates(textOf.get(t.proposal));
    }
    return { topic: t.id, category: t.category, status: t.status, messageId: t.proposal, text: textOf.get(t.proposal),
      value, proposer: speakerOf.get(t.proposal), support: t.support, against: t.against, score: round4(S.get(t.proposal)) };
  };

  const order = { confirmed: 0, pending: 1, rejected: 2 };
  const sections = [];
  for (const cat of TOPIC_CATS) {
    const ts = topics.filter((t) => t.category === cat);
    if (!ts.length) continue;
    ts.sort((a, b) => (order[a.status] - order[b.status]) || (S.get(b.proposal) - S.get(a.proposal)) || (a.index - b.index));
    sections.push({ category: cat, title: TITLES[cat], items: ts.map(item) });
  }

  const facts = { destination: null, budget: null, budget_basis: null, dates: null };
  for (const cat of ["DESTINATION", "BUDGET", "DATE"]) {
    const conf = topics.filter((t) => t.category === cat && t.status === "confirmed");
    if (!conf.length) continue;
    const t = conf[conf.length - 1];
    if (cat === "DESTINATION") facts.destination = textOf.get(t.proposal);
    else if (cat === "BUDGET") {
      facts.budget = parseMoney(textOf.get(t.proposal), t.counter);
      facts.budget_basis = moneyBasis(textOf.get(t.proposal));
    } else facts.dates = parseDates(textOf.get(t.proposal));
  }

  const prefs = [];
  const seenPref = [];
  for (const m of messages) {
    if (labels.get(m.id) !== "PREFERENCE") continue;
    if (seenPref.some((p) => cosine(vecs.get(m.id), vecs.get(p)) > 0.6)) continue;
    seenPref.push(m.id);
    prefs.push({ speaker: m.speaker, text: m.text, messageId: m.id });
  }

  const pending = [...topics].sort((a, b) => a.index - b.index).filter((t) => t.status === "pending").map(item);

  const k = Math.max(1, pyRound(messages.length * highlightRatio));
  const ranked = [...messages].sort((a, b) => (S.get(b.id) - S.get(a.id)) || (pos.get(a.id) - pos.get(b.id)));
  const hlIds = ranked.slice(0, k).filter((m) => labels.get(m.id) !== "OTHER").map((m) => m.id)
    .sort((a, b) => pos.get(a) - pos.get(b));
  const highlights = hlIds.map((x) => ({ messageId: x, speaker: speakerOf.get(x), text: textOf.get(x), score: round4(S.get(x)) }));

  const summary = {
    facts,
    sections,
    preferences: prefs,
    pending,
    highlights,
    messages: messages.map((m) => ({ id: m.id, label: labels.get(m.id), stance: stanceOf.get(m.id) || "none",
      topic: attach.get(m.id) || null, score: round4(S.get(m.id)), R: round4(rel.get(m.id)), D: D.get(m.id),
      N: round4(N.get(m.id)), C: round4(C.get(m.id) || 0) })),
    topics: topics.map((t) => ({ id: t.id, category: t.category, proposal: t.proposal, status: t.status })),
    stats: { messages: messages.length, relevant: relevant.length, topics: topics.length,
      confirmed: topics.filter((t) => t.status === "confirmed").length, pending: pending.length,
      highlights: highlights.length },
  };
  summary.text = renderText(summary);
  let chatLen = 0;
  for (const m of messages) chatLen += len(m.text);
  summary.stats.compression = round4(len(summary.text) / Math.max(1, chatLen));
  return summary;
}

/** Python's round() for x.5 cases (banker's rounding) - used for the highlight count. */
function pyRound(x) {
  const f = Math.floor(x);
  const diff = x - f;
  if (diff > 0.5) return f + 1;
  if (diff < 0.5) return f;
  return f % 2 === 0 ? f : f + 1;
}

module.exports = { summarise, detectStance, parseMoney, parseDates, decisionStatus, DEFAULT_WEIGHTS };
