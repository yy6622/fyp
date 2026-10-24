"""Text preprocessing shared by training, the summariser and (ported 1:1) the
Cloud Function in functions/discussion_summary/. Any change here must be
mirrored in functions/discussion_summary/textproc.js — test_parity.py checks
that both give the same output.

Rules kept deliberately simple and portable (no \\w, \\b or \\d, which mean
different things in Python and JavaScript for non-English text).
"""

import json
import re
import unicodedata
from pathlib import Path

with open(Path(__file__).resolve().parent / "lexicons.json", encoding="utf-8") as _f:
    LEX = json.load(_f)

URL_RE = re.compile(r"https?://[^ ]+")
SPACE_RE = re.compile(r"\s+")

# money: currency + number, number + k/currency, Chinese amounts with 千/万/块
MONEY_RE = re.compile(
    r"(rm|myr|usd|sgd|\$|¥|￥|rmb)[ ]?[0-9][0-9,.]*k?"
    r"|[0-9][0-9,.]*[ ]?(k|rm|myr|ringgit|块|元|千|万)(?![a-z])"
    r"|[一二两三四五六七八九十][千万]"
)
MONTHS = "jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec|januari|februari|mac|april|mei|julai|ogos|oktober|disember"
DATE_RE = re.compile(
    r"[0-9]{1,2}[ ]?(-|to|hingga|until|till)[ ]?[0-9]{1,2}[ ]?(" + MONTHS + r")"
    r"|(" + MONTHS + r")[a-z]*[ ][0-9]{1,2}"
    r"|[0-9]{1,2}[ ]?(" + MONTHS + r")(?![a-z])"
    r"|(early|mid|end|awal|hujung|pertengahan)[ ](of[ ])?(" + MONTHS + r")"
    r"|[0-9]{1,2}月[0-9一二三四五六七八九十]{0,3}[号日初中底]?"
    r"|[0-9]+[ ]?(d|days?|hari)[ ]?[0-9]*[ ]?(n|nights?|malam)?(?![a-z])"
    r"|(school holiday|cuti sekolah|weekend|long weekend|public holiday|假期|周末)"
)
QUESTION_RE = re.compile(r"[?？]|(^| )(how about|what about|apa kata|nak tak|boleh tak|ok tak)( |$)|要不要|怎么样|好不好|吗")


def normalize(text):
    """Lower-case, NFKC (full-width -> half-width), URLs out, spaces collapsed."""
    t = unicodedata.normalize("NFKC", str(text)).lower()
    t = URL_RE.sub(" ", t)
    return SPACE_RE.sub(" ", t).strip()


def tags(norm_text):
    out = []
    if MONEY_RE.search(norm_text):
        out.append("zzmoney")
    if DATE_RE.search(norm_text):
        out.append("zzdate")
    if QUESTION_RE.search(norm_text):
        out.append("zzquestion")
    return out


_WORD_SPLIT = re.compile(r"[^a-z0-9+'\u00c0-\u024f]+")
_LATIN = re.compile(r"[a-z+]")


def words(norm):
    """Space-padded word string, so " ok " can be matched as a whole word."""
    return " " + " ".join(w for w in _WORD_SPLIT.split(norm) if w) + " "


def has_cue(norm, ws, cues):
    """English / Malay cues match whole words; Chinese cues match substrings."""
    for c in cues:
        if _LATIN.search(c):
            if " " + c + " " in ws:
                return True
        elif c in norm:
            return True
    return False


# (tag, cue lists) - which kinds of cue words a message contains
LEX_TAGS = [
    ("zzagree", ("AGREE", "SPECIAL_AGREE")),
    ("zzreject", ("REJECT",)),
    ("zzfinal", ("FINALIZE",)),
    ("zzdefer", ("DEFER", "SPECIAL_DEFER")),
    ("zzpropose", ("PROPOSE_CUES",)),
    ("zzinfo", ("INFO_CUES",)),
    ("zzbudget", ("BUDGET_CUES",)),
    ("zzcost", ("COST_ITEM_CUES",)),
]


def lex_tags(norm):
    ws = words(norm)
    out = [tag for tag, lists in LEX_TAGS if any(has_cue(norm, ws, LEX[k]) for k in lists)]
    size = len(ws.split()) + sum(1 for ch in norm if "\u4e00" <= ch <= "\u9fff") // 2
    if size <= 3:
        out.append("zzshort")
    return out


def prepare(text, with_tags=True, with_lex=False):
    """The exact string the vectoriser sees."""
    t = normalize(text)
    tg = (tags(t) if with_tags else []) + (lex_tags(t) if with_lex else [])
    if tg:
        t = t + " " + " ".join(tg)
    return t
