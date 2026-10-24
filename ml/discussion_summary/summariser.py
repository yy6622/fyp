"""Travel group-discussion summariser (the algorithm around the trained classifier).

Pipeline for one chat:
  1. classify every message (trained TF-IDF + linear model, models/model.json)
  2. stance of each message: agree / reject / defer / finalize / propose / info (rules, 3 languages)
  3. topics: every proposal of a concrete option opens a topic; reactions are attached
     to the topic they answer (explicit reference by cosine similarity, else the latest proposal)
  4. group decision per topic: confirmed / rejected / pending (decision_status)
  5. importance score per message  S(m) = wR*R + wD*D + wN*N + wC*C
       R relevance   - classifier confidence that the message is about the trip (not OTHER)
       D decision    - role of the message in a decision (proposal of a settled topic, finalise, ...)
       N novelty     - 1 - max similarity to any earlier message
       C centrality  - TextRank score in the message-similarity graph
     used to pick highlights, order items and choose the best wording per topic
  6. structured summary: facts (budget, dates, destination), sections per category,
     preferences per person, still-to-decide list, highlights, plain-text rendering

Every step is ported line by line to functions/discussion_summary/summariser.js.
Keep both in sync; test_parity.py compares their output on the test chats.
"""

import json
import math
import re
from pathlib import Path

from features import DATE_RE, MONEY_RE, QUESTION_RE, normalize
from model_runtime import cosine, softmax_top

DEFAULT_WEIGHTS = {"R": 0.25, "D": 0.45, "N": 0.1, "C": 0.2}
TOPIC_CATS = ["DESTINATION", "BUDGET", "DATE", "ATTRACTION", "TRANSPORT", "ACCOMMODATION"]
SINGLE_VALUE = {"DESTINATION", "BUDGET", "DATE", "ACCOMMODATION"}
TITLES = {"DESTINATION": "Destination", "DATE": "Dates", "BUDGET": "Budget", "ACCOMMODATION": "Accommodation",
          "ATTRACTION": "Places to visit", "TRANSPORT": "Transport"}
REF_SIM = 0.22        # cosine above which a reply is taken to name a specific earlier topic
SAME_TOPIC_SIM = 0.55  # a new topical message this close to an open topic repeats it instead of proposing
WINDOW = 25           # how many messages back a bare "ok" can still answer

# ---------------------------------------------------------------------------
# Cue-word lists live in lexicons.json (shared with the JavaScript port).
# English/Malay cues match whole words; Chinese cues match substrings.
# ---------------------------------------------------------------------------
with open(Path(__file__).resolve().parent / "lexicons.json", encoding="utf-8") as _f:
    LEX = json.load(_f)
SPECIAL_AGREE, SPECIAL_DEFER = LEX["SPECIAL_AGREE"], LEX["SPECIAL_DEFER"]
FINALIZE, REJECT, DEFER, AGREE = LEX["FINALIZE"], LEX["REJECT"], LEX["DEFER"], LEX["AGREE"]
INFO_CUES, PROPOSE_CUES = LEX["INFO_CUES"], LEX["PROPOSE_CUES"]          # info vs. proposal
BUDGET_CUES, COST_ITEM_CUES = LEX["BUDGET_CUES"], LEX["COST_ITEM_CUES"]  # group budget vs. a cost item
INFO_QUESTION_CUES = LEX["INFO_QUESTION_CUES"]                           # questions asking for information
PER_PERSON, TOTAL = LEX["PER_PERSON"], LEX["TOTAL"]
STOP_WORDS = set(LEX["STOP_WORDS"])   # words that do not name an option ("ok lah" vs "ok for the hotel")
ZH_STOP = set(LEX["ZH_STOP"])
SMALL_TALK = set(LEX["SMALL_TALK"])            # greetings, thanks, bye, laughter, "test" ...
SMALL_TALK_ZH = sorted(LEX["SMALL_TALK_ZH"], key=lambda c: (-len(c), c))
_LAUGH = re.compile(r"^((h[aeiu]){2,}h?|(wk){2,}w?|l+o+l+|lmf?a+o+|x+d+)$")
_REPEAT = re.compile(r"(.)\1+")

_WORD_SPLIT = re.compile(r"[^a-z0-9+'\u00c0-\u024f]+")


def _words(norm):
    return " " + " ".join(w for w in _WORD_SPLIT.split(norm) if w) + " "


def has_cue(norm, words, cues):
    for c in cues:
        if re.search(r"[a-z+]", c):
            if " " + c + " " in words:
                return True
        elif c in norm:
            return True
    return False


def _content(norm):
    """(latin content words, Chinese text) left after removing reaction cues and filler."""
    cues = SPECIAL_AGREE + SPECIAL_DEFER + FINALIZE + REJECT + DEFER + AGREE
    rest = norm
    for c in sorted({c for c in cues if not re.search(r"[a-z+]", c)}, key=lambda c: (-len(c), c)):
        rest = rest.replace(c, " ")
    latin_cues = {c for c in cues if re.search(r"[a-z+]", c)}
    words = _words(rest)
    for c in sorted(latin_cues, key=lambda c: (-len(c), c)):
        words = words.replace(" " + c + " ", " ")
    latin = [w for w in words.split() if w not in STOP_WORDS and not w.isdigit()]
    return latin, rest


def content_size(norm):
    """How many words / Chinese characters are left after removing reaction cues
    and filler - 0 means a bare reaction like "ok lah" / "可以啊"."""
    latin, rest = _content(norm)
    return len(latin) + sum(1 for ch in rest if "\u4e00" <= ch <= "\u9fff" and ch not in ZH_STOP)


_CAP_WORD = re.compile(r"[A-Z][A-Za-z']{3,}")


def names_fit(raw_text, topic_texts):
    """False when a reply names a place (a Capitalised word that is not the first word)
    that never appears in the topic's own messages - e.g. "can we skip Disneyland?"
    right after a proposal about the Bund must not count as rejecting the Bund."""
    words = [w.lower() for w in _CAP_WORD.findall(raw_text)[(1 if _CAP_WORD.match(raw_text.strip()) else 0):]]
    words = [w for w in words if w not in STOP_WORDS and not has_cue(w, " " + w + " ", AGREE + REJECT + DEFER + FINALIZE)]
    if not words:
        return True
    joined = " ".join(normalize(t) for t in topic_texts)
    return any(w in joined for w in words)


def gate(label, text, top_prob=1.0, min_prob=0.0):
    """Rules in front of the classifier (2026-10-13: "hi" was labelled DESTINATION).
    1. Small talk only (greetings, thanks, bye, laughter, emoji, "test") -> OTHER.
    2. A place / transport / hotel / destination label needs some real content:
       a word of 3+ letters that is not a filler word, or 2+ Chinese characters."""
    norm = normalize(text)
    rest = norm
    for c in SMALL_TALK_ZH:
        rest = rest.replace(c, " ")
    latin = []
    for w in _WORD_SPLIT.split(rest):
        if not w or w.isdigit():
            continue
        w1 = _REPEAT.sub(r"\1", w)                   # hiii -> hi, hellooo -> helo, byeee -> bye
        if w in SMALL_TALK or w1 in SMALL_TALK or _LAUGH.match(w):
            continue
        latin.append(w)
    cjk = [ch for ch in rest if "\u4e00" <= ch <= "\u9fff"]
    if not latin and not cjk:
        return "OTHER"
    if rest != norm and all(w in STOP_WORDS for w in latin) and all(ch in ZH_STOP for ch in cjk):
        return "OTHER"      # small talk + filler only ("谢谢你", "thanks guys")
    if label in ("DESTINATION", "ATTRACTION", "TRANSPORT", "ACCOMMODATION"):
        if top_prob < min_prob:
            return "OTHER"      # the classifier is not sure this is about the trip
        content = [w for w in latin if len(w) >= 3 and w not in STOP_WORDS]
        if not content and len([ch for ch in cjk if ch not in ZH_STOP]) < 2:
            return "OTHER"
    return label


def detect_stance(text):
    norm = normalize(text)
    words = _words(norm)
    if has_cue(norm, words, SPECIAL_AGREE):
        return "agree"
    if has_cue(norm, words, SPECIAL_DEFER):
        return "defer"
    if has_cue(norm, words, FINALIZE):
        return "finalize"
    if has_cue(norm, words, REJECT):
        return "reject"
    if has_cue(norm, words, DEFER):
        return "defer"
    if has_cue(norm, words, AGREE):
        return "agree"
    return "none"


# ---------------------------------------------------------------------------
# Value extraction for the facts block
# ---------------------------------------------------------------------------
ZH_DIGIT = {"一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10}
MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
MONTH_ALIASES = {"sept": "sep", "januari": "jan", "februari": "feb", "mac": "mar", "april": "apr", "mei": "may",
                 "julai": "jul", "ogos": "aug", "oktober": "oct", "disember": "dec", "september": "sep",
                 "november": "nov", "june": "jun", "july": "jul", "march": "mar", "august": "aug",
                 "october": "oct", "december": "dec", "january": "jan", "february": "feb"}
NUM_RE = re.compile(r"([0-9][0-9,]*(\.[0-9]+)?)[ ]?(k)?(?![a-z])")
ZH_AMOUNT_RE = re.compile(r"([一二两三四五六七八九十])([千万])([一二两三四五六七八九])?")


def parse_money(text, last=False):
    """Amount mentioned (RM3,000 / 3k / 三千 / 两千五 / 一万二) or None.
    last=False -> the largest amount; last=True -> the last one (for
    "RM3000 too much, RM2000 can?" the new suggestion comes last)."""
    norm = normalize(text)
    if not MONEY_RE.search(norm):
        return None
    vals = []  # (position, value)
    for m in NUM_RE.finditer(norm):
        v = float(m.group(1).replace(",", ""))
        if m.group(3):
            v *= 1000
        vals.append((m.start(), v))
    for m in ZH_AMOUNT_RE.finditer(norm):
        unit = 1000 if m.group(2) == "千" else 10000
        v = ZH_DIGIT[m.group(1)] * unit
        if m.group(3):
            v += ZH_DIGIT[m.group(3)] * unit // 10
        vals.append((m.start(), float(v)))
    vals = [pv for pv in vals if pv[1] >= 50]
    if not vals:
        return None
    if last:
        return int(max(vals)[1])
    return int(max(v for _, v in vals))


def money_basis(text):
    norm = normalize(text)
    words = _words(norm)
    if has_cue(norm, words, TOTAL):
        return "total"
    if has_cue(norm, words, PER_PERSON):
        return "per_person"
    return None


def month_key(tok):
    tok = tok.lower()
    tok = MONTH_ALIASES.get(tok, tok)
    return tok[:3] if tok[:3] in MONTHS else None


DATE_PATTERNS = [
    # (regex, kind) - kind says how to read the groups
    (re.compile(r"([0-9]{1,2})[ ]?([a-z]+)[ ]?(?:-|to|到|至|until|till|hingga)[ ]?([0-9]{1,2})[ ]?([a-z]+)"), "d m-d m"),
    (re.compile(r"([0-9]{1,2})[ ]?(?:-|to|到|至|hingga|until|till)[ ]?([0-9]{1,2})[ ]?([a-z]+)"), "d-d m"),
    (re.compile(r"([a-z]+)[ ]([0-9]{1,2})[ ]?(?:-|to|until|till)[ ]?([0-9]{1,2})"), "m d-d"),
    (re.compile(r"([0-9]{1,2})月([0-9]{1,2})[号日]?[ ]?(?:到|至|-)[ ]?([0-9]{1,2})"), "zh d-d"),
    (re.compile(r"(early|mid|end|awal|pertengahan|hujung)[ ](?:of[ ])?([a-z]+)"), "part m"),
    (re.compile(r"([0-9]{1,2})月([初中底])"), "zh part"),
]


def _read_date(kind, g):
    if kind == "d m-d m" and month_key(g[1]) and month_key(g[3]):
        a, b = month_key(g[1]), month_key(g[3])
        if a == b:
            return f"{int(g[0])}-{int(g[2])} {a.capitalize()}"
        return f"{int(g[0])} {a.capitalize()} - {int(g[2])} {b.capitalize()}"
    if kind == "d-d m" and month_key(g[2]):
        return f"{int(g[0])}-{int(g[1])} {month_key(g[2]).capitalize()}"
    if kind == "m d-d" and month_key(g[0]):
        return f"{int(g[1])}-{int(g[2])} {month_key(g[0]).capitalize()}"
    if kind == "zh d-d" and 1 <= int(g[0]) <= 12:
        return f"{int(g[1])}-{int(g[2])} {MONTHS[int(g[0]) - 1].capitalize()}"
    if kind == "part m" and month_key(g[1]):
        which = {"awal": "early", "pertengahan": "mid", "hujung": "end"}.get(g[0], g[0])
        return f"{which} {month_key(g[1]).capitalize()}"
    if kind == "zh part" and 1 <= int(g[0]) <= 12:
        return f"{ {'初': 'early', '中': 'mid', '底': 'end'}[g[1]]} {MONTHS[int(g[0]) - 1].capitalize()}"
    return None


def parse_dates(text):
    """Canonical form ('12-16 Dec', 'end Dec') of the LAST date mentioned - in
    "9-12 Nov cannot, mid Aug?" the new suggestion comes last. Falls back to the
    raw matched phrase (e.g. '5d4n', 'school holiday')."""
    norm = normalize(text)
    best_pos, best = -1, None
    for rx, kind in DATE_PATTERNS:
        for m in rx.finditer(norm):
            val = _read_date(kind, m.groups())
            if val is not None and m.start() > best_pos:
                best_pos, best = m.start(), val
    if best is not None:
        return best
    m = DATE_RE.search(norm)
    return m.group(0) if m else None


# ---------------------------------------------------------------------------
# Decision rule (same definition as the gold labels)
# ---------------------------------------------------------------------------

def decision_status(stances, n_members, superseded):
    """Group decision for one topic. stances: (speaker, stance) in chat order, the
    proposer's own proposal counting as agreement. Each person's LAST stance counts.
    n_members is kept for reference (the earlier majority rule used it)."""
    latest = {}
    finalized = False
    for who, st in stances:
        if st in ("agree", "finalize", "propose"):
            latest[who] = "agree"
        elif st == "reject":
            latest[who] = "reject"
        elif st == "defer":
            latest[who] = "defer"
        if st == "finalize":
            finalized = True
    support = sum(1 for v in latest.values() if v == "agree")
    oppose = sum(1 for v in latest.values() if v == "reject")
    hesitant = sum(1 for v in latest.values() if v == "defer")
    # "Silence is consent": a proposal nobody argues against is agreed.
    if superseded:
        return "rejected"
    if oppose and oppose >= support + hesitant:
        return "rejected"       # objections outweigh everyone who backed or is still considering it
    if oppose:
        return "pending"        # contested: someone objected, more people support it
    if finalized:
        return "confirmed"
    if hesitant and support <= 1:
        return "pending"        # the only reactions are "let me think" - nobody else backed it
    return "confirmed"


# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------

def sigmoid(x):
    return 1 / (1 + math.exp(-max(-30.0, min(30.0, x))))


def textrank(vecs, nodes, d=0.85, iters=40):
    n = len(nodes)
    if n == 0:
        return {}
    W = [[0.0] * n for _ in range(n)]
    for a in range(n):
        for b in range(a + 1, n):
            s = cosine(vecs[nodes[a]], vecs[nodes[b]])
            if s > 0.05:
                W[a][b] = W[b][a] = s
    out_sum = [sum(row) for row in W]
    pr = [1.0 / n] * n
    for _ in range(iters):
        new = []
        for b in range(n):
            acc = 0.0
            for a in range(n):
                if W[a][b] > 0 and out_sum[a] > 0:
                    acc += pr[a] * W[a][b] / out_sum[a]
            new.append((1 - d) / n + d * acc)
        pr = new
    top = max(pr) or 1.0
    return {nodes[i]: pr[i] / top for i in range(n)}


def is_proposal(label, text, stance):
    """Does this topical message put forward a concrete option (vs. give info / ask)?"""
    norm = normalize(text)
    words = _words(norm)
    if label == "BUDGET":
        if not MONEY_RE.search(norm):
            return False
        if stance == "reject" or has_cue(norm, words, ["budget", "预算", "bajet"]):
            return True
        # "flight alone is RM800", "hotel will take RM500 each": a cost item, not the group budget
        if has_cue(norm, words, COST_ITEM_CUES):
            return False
        return has_cue(norm, words, BUDGET_CUES)
    if label == "DATE":
        return bool(DATE_RE.search(norm)) and parse_dates(text) is not None
    if stance == "reject":
        return True   # "X is too far, Y better?" - a counter-proposal
    if has_cue(norm, words, INFO_CUES) and not has_cue(norm, words, ["let's", "lets", "how about", "jom", "去", "吧"]):
        return False
    if QUESTION_RE.search(norm) and has_cue(norm, words, INFO_QUESTION_CUES) and not has_cue(norm, words, PROPOSE_CUES):
        return False
    return True


def summarise(messages, model, members=None, weights=None, highlight_ratio=0.2, gold_labels=None):
    """messages: [{"id", "speaker", "text"}] in chat order. Returns the summary dict.
    gold_labels (evaluation only): {message_id: label} replaces the classifier's
    labels, to measure how much of the error comes from classification."""
    w = dict(DEFAULT_WEIGHTS, **(weights or {}))
    speakers = []
    for m in messages:
        if m["speaker"] not in speakers:
            speakers.append(m["speaker"])
    n_members = max(len(members or []), len(speakers), 1)

    labels, vecs, rel = {}, {}, {}
    for m in messages:
        raw_lab, s, vec = model.predict(m["text"])
        lab = gate(raw_lab, m["text"], softmax_top(s), model.topic_min_prob)
        labels[m["id"]] = lab
        vecs[m["id"]] = vec
        k_other = model.labels.index("OTHER")
        best_other = max(s[k] for k in range(len(s)) if k != k_other)
        rel[m["id"]] = sigmoid(2.0 * (best_other - s[k_other])) if lab == raw_lab else 0.0
        if gold_labels is not None:
            labels[m["id"]] = gold_labels[m["id"]]
            rel[m["id"]] = 0.0 if labels[m["id"]] == "OTHER" else 1.0

    # ---- topics and stances ---------------------------------------------
    # topic: id, category, proposal (msg id), index, stances [(speaker, stance)],
    # messages (all attached), refs (proposal + info messages: what a reply can name), last
    topics = []
    stance_of = {}
    attach = {}
    pos = {m["id"]: i for i, m in enumerate(messages)}
    text_of_msg = {m["id"]: m["text"] for m in messages}

    def open_topics(i, category=None):
        return [t for t in topics if i - t["last"] <= WINDOW and (category is None or t["category"] == category)]

    for i, m in enumerate(messages):
        mid, lab = m["id"], labels[m["id"]]
        st = detect_stance(m["text"])
        if lab in TOPIC_CATS:
            same = open_topics(i, lab)
            best, best_sim = None, 0.0
            for t in same:
                sim = cosine(vecs[mid], vecs[t["proposal"]])
                if sim > best_sim:
                    best, best_sim = t, sim
            if not is_proposal(lab, m["text"], st):
                # information about an existing topic of this category (or nothing to attach to)
                if same:
                    tgt = best if best_sim >= REF_SIM else same[-1]
                    tgt["messages"].append(mid)
                    tgt["refs"].append(mid)
                    attach[mid] = tgt["id"]
                stance_of[mid] = "info"
                continue
            if best is not None and (best_sim >= SAME_TOPIC_SIM or
                                     (st in ("agree", "finalize") and best_sim >= REF_SIM)):
                # repeating an open proposal ("ok I book Jinjiang Inn") = supporting / finalising it
                st2 = "finalize" if st == "finalize" else "agree"
                best["stances"].append((m["speaker"], st2))
                best["messages"].append(mid)
                best["last"] = i
                attach[mid] = best["id"]
                stance_of[mid] = st2
                continue
            if st == "reject" and same:
                # "X too expensive, Y instead": rejects the latest open option of this category
                same[-1]["stances"].append((m["speaker"], "reject"))
            t = {"id": f"t{len(topics) + 1}", "category": lab, "proposal": mid, "index": i, "counter": st == "reject",
                 "stances": [(m["speaker"], "propose")], "messages": [mid], "refs": [mid], "last": i}
            topics.append(t)
            attach[mid] = t["id"]
            stance_of[mid] = "propose"
        elif lab == "DECISION":
            if st == "none":
                # a reaction with no clear cue: short ones are usually agreement ("go go go", "worth it");
                # longer ones with their own content are often not a reaction at all ("i'm hungry")
                st = "agree" if content_size(normalize(m["text"])) <= 1 else "none"
            cands = open_topics(i)
            if not cands:
                stance_of[mid] = st
                continue
            best, best_sim = None, 0.0
            for t in cands:
                sim = max(cosine(vecs[mid], vecs[x]) for x in t["refs"])
                if sim > best_sim:
                    best, best_sim = t, sim
            if best_sim >= REF_SIM:
                tgt = best
            else:
                latest = max(cands, key=lambda t: t["index"])
                # A bare "ok" answers the latest proposal. A reply that names something
                # we cannot match answers the latest proposal only if it is right after it.
                if content_size(normalize(m["text"])) == 0 or (
                        i - latest["last"] <= 2 and names_fit(m["text"], [text_of_msg[x] for x in latest["refs"]])):
                    tgt = latest
                else:
                    stance_of[mid] = st
                    continue
            tgt["stances"].append((m["speaker"], st))
            tgt["messages"].append(mid)
            tgt["last"] = i
            attach[mid] = tgt["id"]
            stance_of[mid] = st
        else:
            stance_of[mid] = "none"

    raw = {t["id"]: decision_status(t["stances"], n_members, False) for t in topics}
    for t in topics:
        superseded = t["category"] in SINGLE_VALUE and any(
            u["category"] == t["category"] and u["index"] > t["index"] and raw[u["id"]] == "confirmed" for u in topics)
        t["status"] = decision_status(t["stances"], n_members, superseded)
        latest = {}
        for who, s in t["stances"]:
            if s in ("agree", "finalize", "propose"):
                latest[who] = "agree"
            elif s == "reject":
                latest[who] = "reject"
            elif s == "defer":
                latest[who] = "defer"
        t["support"] = [p for p, v in latest.items() if v == "agree"]
        t["against"] = [p for p, v in latest.items() if v == "reject"]

    # ---- importance score -------------------------------------------------
    by_id = {t["id"]: t for t in topics}
    D = {}
    for m in messages:
        mid = m["id"]
        st = stance_of.get(mid, "none")
        t = by_id.get(attach.get(mid))
        if st == "propose" and t is not None:
            D[mid] = {"confirmed": 1.0, "pending": 0.7, "rejected": 0.5}[t["status"]]
        elif st == "finalize":
            D[mid] = 0.8
        elif labels[mid] == "PREFERENCE":
            D[mid] = 0.6
        elif st in ("agree", "reject", "defer") and t is not None:
            D[mid] = 0.25
        elif st == "info" and t is not None:
            D[mid] = 0.3
        else:
            D[mid] = 0.0
    N = {}
    for i, m in enumerate(messages):
        prev = [cosine(vecs[m["id"]], vecs[messages[j]["id"]]) for j in range(i)]
        N[m["id"]] = 1.0 - (max(prev) if prev else 0.0)
    relevant = [m["id"] for m in messages if labels[m["id"]] != "OTHER"]
    C = textrank(vecs, relevant)
    S = {}
    for m in messages:
        mid = m["id"]
        S[mid] = (w["R"] * rel[mid] + w["D"] * D[mid] + w["N"] * N[mid] + w["C"] * C.get(mid, 0.0))

    # ---- build the summary ------------------------------------------------
    text_of = {m["id"]: m["text"] for m in messages}
    speaker_of = {m["id"]: m["speaker"] for m in messages}

    def item(t):
        value = None
        if t["category"] == "BUDGET":
            amt = parse_money(text_of[t["proposal"]], last=t["counter"])
            if amt:
                basis = money_basis(text_of[t["proposal"]])
                value = f"RM{amt}" + {"per_person": " per person", "total": " in total"}.get(basis, "")
        elif t["category"] == "DATE":
            value = parse_dates(text_of[t["proposal"]])
        return {"topic": t["id"], "category": t["category"], "status": t["status"], "messageId": t["proposal"],
                "text": text_of[t["proposal"]], "value": value, "proposer": speaker_of[t["proposal"]],
                "support": t["support"], "against": t["against"], "score": round(S[t["proposal"]], 4)}

    sections = []
    for cat in TOPIC_CATS:
        ts = [t for t in topics if t["category"] == cat]
        if not ts:
            continue
        order = {"confirmed": 0, "pending": 1, "rejected": 2}
        ts.sort(key=lambda t: (order[t["status"]], -S[t["proposal"]], t["index"]))
        sections.append({"category": cat, "title": TITLES[cat], "items": [item(t) for t in ts]})

    facts = {"destination": None, "budget": None, "budget_basis": None, "dates": None}
    for cat in ("DESTINATION", "BUDGET", "DATE"):
        conf = [t for t in topics if t["category"] == cat and t["status"] == "confirmed"]
        if not conf:
            continue
        t = conf[-1]
        if cat == "DESTINATION":
            facts["destination"] = text_of[t["proposal"]]
        elif cat == "BUDGET":
            facts["budget"] = parse_money(text_of[t["proposal"]], last=t["counter"])
            facts["budget_basis"] = money_basis(text_of[t["proposal"]])
        else:
            facts["dates"] = parse_dates(text_of[t["proposal"]])

    prefs, seen_pref = [], []
    for m in messages:
        if labels[m["id"]] != "PREFERENCE":
            continue
        if any(cosine(vecs[m["id"]], vecs[p]) > 0.6 for p in seen_pref):
            continue
        seen_pref.append(m["id"])
        prefs.append({"speaker": m["speaker"], "text": m["text"], "messageId": m["id"]})

    pending = [item(t) for t in sorted(topics, key=lambda t: t["index"]) if t["status"] == "pending"]

    k = max(1, int(round(len(messages) * highlight_ratio)))
    ranked = sorted(messages, key=lambda m: (-S[m["id"]], pos[m["id"]]))
    hl_ids = sorted([m["id"] for m in ranked[:k] if labels[m["id"]] != "OTHER"], key=lambda x: pos[x])
    highlights = [{"messageId": x, "speaker": speaker_of[x], "text": text_of[x], "score": round(S[x], 4)} for x in hl_ids]

    summary = {
        "facts": facts,
        "sections": sections,
        "preferences": prefs,
        "pending": pending,
        "highlights": highlights,
        "messages": [{"id": m["id"], "label": labels[m["id"]], "stance": stance_of.get(m["id"], "none"),
                      "topic": attach.get(m["id"]), "score": round(S[m["id"]], 4),
                      "R": round(rel[m["id"]], 4), "D": D[m["id"]], "N": round(N[m["id"]], 4),
                      "C": round(C.get(m["id"], 0.0), 4)} for m in messages],
        "topics": [{"id": t["id"], "category": t["category"], "proposal": t["proposal"], "status": t["status"]}
                   for t in topics],
        "stats": {"messages": len(messages), "relevant": len(relevant), "topics": len(topics),
                  "confirmed": sum(1 for t in topics if t["status"] == "confirmed"),
                  "pending": len(pending), "highlights": len(highlights)},
    }
    summary["text"] = render_text(summary)
    summary["stats"]["compression"] = round(len(summary["text"]) / max(1, sum(len(m["text"]) for m in messages)), 4)
    return summary


def short(text, n=45):
    t = " ".join(str(text).split())
    return t if len(t) <= n else t[: n - 1] + "…"


def render_text(summary):
    words = (("confirmed", "agreed"), ("pending", "still undecided"), ("rejected", "turned down"))
    lines = []
    for sec in summary["sections"]:
        parts = []
        for status, word in words:
            vals = [it["value"] or short(it["text"]) for it in sec["items"] if it["status"] == status]
            if vals:
                parts.append(f"{word}: {', '.join(vals)}")
        lines.append(f"{sec['title']} - " + "; ".join(parts) + ".")
    if summary["preferences"]:
        lines.append("Preferences - " + "; ".join(f"{p['speaker']}: {short(p['text'], 45)}" for p in summary["preferences"]) + ".")
    if summary["pending"]:
        lines.append("Still to decide - " + ", ".join(it["value"] or short(it["text"], 35) for it in summary["pending"]) + ".")
    return "\n".join(lines)
