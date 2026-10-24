"""Turns three public, human-written dialogue datasets into Voya's message format.

No external API is used. Files are downloaded once from GitHub into data/public/raw/.

  MultiWOZ 2.2  (English, MIT licence)        github.com/budzianowski/multiwoz
      ~10k crowd-sourced dialogues: a person books hotels, finds attractions and
      restaurants, takes trains and taxis in Cambridge. Every user turn has
      human-annotated dialogue acts such as Hotel-Inform or general-thank.
  CrossWOZ      (Chinese, Apache-2.0)         github.com/thu-coai/CrossWOZ
      ~6k crowd-sourced Chinese dialogues about a trip in Beijing: attractions (景点),
      restaurants (餐馆), hotels (酒店), metro (地铁) and taxis (出租), with dialogue acts.
  DialogSum     (English, CC BY-NC-SA 4.0)    github.com/cylnlp/dialogsum
      ~13k everyday conversations (job interviews, shopping, the weather...), each
      with a topic. Only chats whose topic and text have nothing to do with travel are kept:
      every message is then OTHER (chit-chat, nothing for the trip plan).

How a turn gets its Voya label (only USER turns are used; the clerk/system side does not
sound like a friend in a group chat):
  dialogue-act domain  hotel / 酒店                       -> ACCOMMODATION
                       attraction, restaurant / 景点, 餐馆 -> ATTRACTION   (food places are ATTRACTION in Voya)
                       train, taxi / 地铁, 出租            -> TRANSPORT
                       only general acts (greet, thank, bye) -> OTHER
  a turn whose acts span two different Voya labels is ambiguous and dropped;
  MultiWOZ "Booking" acts take the domain the dialogue was last about;
  MultiWOZ police / hospital dialogues are dropped (nothing to do with a trip).

These datasets have no group decisions (one person talks to a clerk), so they only give
message labels: topics and stances are left empty and they are not used for Experiment B,
except the DialogSum test chats, which check that ordinary chat does not turn into trip items.

Output:
  data/public_train.jsonl   training chats (source "public"), sampled to the sizes below
  data/public_test.jsonl    test_public   - MultiWOZ + CrossWOZ official TEST splits
  data/offtopic_test.jsonl  test_offtopic - DialogSum official TEST split, non-travel chats

Usage:
  python import_public_datasets.py                      # default sizes
  python import_public_datasets.py --mwoz 3000 --crosswoz 3000 --dialogsum 3000
"""

import argparse
import json
import random
import re
import zipfile
from collections import Counter
from pathlib import Path
from urllib.request import urlopen

from common import DATA, write_jsonl

RAW = DATA / "public" / "raw"
GH = "https://raw.githubusercontent.com"
FILES = {
    "mwoz_dialog_acts.json": f"{GH}/budzianowski/multiwoz/master/data/MultiWOZ_2.2/dialog_acts.json",
    **{f"mwoz_train_dialogues_00{i}.json": f"{GH}/budzianowski/multiwoz/master/data/MultiWOZ_2.2/train/dialogues_00{i}.json"
       for i in range(1, 5)},
    **{f"mwoz_test_dialogues_00{i}.json": f"{GH}/budzianowski/multiwoz/master/data/MultiWOZ_2.2/test/dialogues_00{i}.json"
       for i in range(1, 3)},
    "crosswoz_train.json.zip": f"{GH}/thu-coai/CrossWOZ/master/data/crosswoz/train.json.zip",
    "crosswoz_test.json.zip": f"{GH}/thu-coai/CrossWOZ/master/data/crosswoz/test.json.zip",
    "dialogsum_train.jsonl": f"{GH}/cylnlp/dialogsum/main/DialogSum_Data/dialogsum.train.jsonl",
    "dialogsum_test.jsonl": f"{GH}/cylnlp/dialogsum/main/DialogSum_Data/dialogsum.test.jsonl",
}

MWOZ_DOMAIN = {"hotel": "ACCOMMODATION", "attraction": "ATTRACTION", "restaurant": "ATTRACTION",
               "train": "TRANSPORT", "taxi": "TRANSPORT"}
CROSS_DOMAIN = {"酒店": "ACCOMMODATION", "景点": "ATTRACTION", "餐馆": "ATTRACTION", "地铁": "TRANSPORT", "出租": "TRANSPORT"}

# DialogSum chats about any of these could contain real trip talk: left out, so every kept
# message really is OTHER.
TRAVEL_WORDS = re.compile(
    r"travel|trip|tour|vacation|holiday|hotel|flight|plane|airport|air ?line|taxi|train|bus|subway|metro|"
    r"ticket|book|reserv|check[ -]?in|check[ -]?out|room|restaurant|dinner|lunch|breakfast|food|eat|menu|"
    r"direction|the way|map|visit|museum|park|beach|sightsee|abroad|passport|visa|luggage|baggage|"
    r"weekend|plan|invit|party|budget|price|cost|cheap|expensive|\$|dollar|yuan|pound|car|drive|station|"
    r"city|country|place|go out|going out|camping|hiking|cruise|resort|rent", re.I)


def download():
    RAW.mkdir(parents=True, exist_ok=True)
    for name, url in FILES.items():
        p = RAW / name
        if not p.exists():
            print(f"downloading {name} ...")
            p.write_bytes(urlopen(url, timeout=300).read())


def mwoz(files, acts):
    convs = []
    for fn in files:
        for d in json.load(open(RAW / fn, encoding="utf-8")):
            if set(d["services"]) & {"police", "hospital"}:
                continue
            msgs, last = [], None
            for t in d["turns"]:
                a = acts.get(d["dialogue_id"], {}).get(t["turn_id"], {}).get("dialog_act", {})
                doms = [k.split("-")[0].lower() for k in a]
                topical = [x for x in doms if x in MWOZ_DOMAIN]
                if topical:
                    last = topical[-1]
                if t["speaker"] != "USER" or not a:
                    continue
                labs = {MWOZ_DOMAIN[x] for x in topical}
                if "booking" in doms and last:
                    labs.add(MWOZ_DOMAIN[last])
                if not labs and all(x == "general" for x in doms):
                    labs = {"OTHER"}
                if len(labs) != 1:
                    continue
                msgs.append((t["utterance"].strip(), labs.pop()))
            if msgs:
                convs.append(conv(f"mwoz-{d['dialogue_id'].replace('.json', '')}", "public", msgs))
    return convs


def crosswoz(zip_name):
    z = zipfile.ZipFile(RAW / zip_name)
    data = json.load(z.open(z.namelist()[0]))
    convs = []
    for did, d in data.items():
        msgs = []
        for m in d["messages"]:
            if m["role"] != "usr":
                continue
            doms = {a[1] for a in m["dialog_act"]}
            labs = {CROSS_DOMAIN[x] for x in doms if x in CROSS_DOMAIN}
            if not labs and doms and doms <= {"greet", "thank", "bye", "welcome", "General", "none"}:
                labs = {"OTHER"}
            if not labs and any(a[0] == "General" for a in m["dialog_act"]) and not (doms - {"greet", "thank", "bye", "welcome"}):
                labs = {"OTHER"}
            if len(labs) != 1:
                continue
            msgs.append((m["content"].strip(), labs.pop()))
        if msgs:
            convs.append(conv(f"cwoz-{did}", "public", msgs))
    return convs


def dialogsum(name):
    convs = []
    for line in open(RAW / name, encoding="utf-8"):
        r = json.loads(line)
        topics = " ".join(str(v) for k, v in r.items() if k.startswith("topic"))
        if TRAVEL_WORDS.search(topics) or TRAVEL_WORDS.search(r["dialogue"]):
            continue
        msgs = []
        for ln in r["dialogue"].split("\n"):
            m = re.match(r"\s*#(Person\d)#\s*:\s*(.+)", ln)
            if m and m.group(2).strip():
                msgs.append((m.group(2).strip(), "OTHER", m.group(1)))
        if msgs:
            convs.append(conv(f"dsum-{r['fname']}", "public", msgs))
    return convs


def conv(conv_id, source, msgs):
    out = []
    for i, m in enumerate(msgs):
        speaker = m[2].replace("Person", "Person ") if len(m) > 2 else "User"
        out.append({"id": f"m{i + 1:03d}", "speaker": speaker, "text": m[0], "label": m[1], "topic": None, "stance": "none"})
    return {"conv_id": conv_id, "source": source, "destination": None, "members": sorted({m["speaker"] for m in out}),
            "messages": out, "topics": [], "preferences": [], "facts": {}, "reference_summary": ""}


def sample(convs, n_messages, rng):
    """Whole chats, picked at random until about n_messages messages."""
    convs = list(convs)
    rng.shuffle(convs)
    out, n = [], 0
    for c in convs:
        if n >= n_messages:
            break
        out.append(c)
        n += len(c["messages"])
    return out


def describe(name, convs):
    cnt = Counter(m["label"] for c in convs for m in c["messages"])
    print(f"{name:28s} {len(convs):5d} chats {sum(cnt.values()):6d} messages  " +
          ", ".join(f"{k} {v}" for k, v in cnt.most_common()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mwoz", type=int, default=3000, help="MultiWOZ training messages (0 = none)")
    ap.add_argument("--crosswoz", type=int, default=3000, help="CrossWOZ training messages (0 = none)")
    ap.add_argument("--dialogsum", type=int, default=3000, help="DialogSum (OTHER) training messages (0 = none)")
    ap.add_argument("--test-chats", type=int, default=150, help="chats per dataset in the test sets")
    ap.add_argument("--seed", type=int, default=2026)
    args = ap.parse_args()
    download()
    rng = random.Random(args.seed)
    acts = json.load(open(RAW / "mwoz_dialog_acts.json", encoding="utf-8"))

    mw_tr = mwoz([f"mwoz_train_dialogues_00{i}.json" for i in range(1, 5)], acts)
    mw_te = mwoz(["mwoz_test_dialogues_001.json", "mwoz_test_dialogues_002.json"], acts)
    cw_tr, cw_te = crosswoz("crosswoz_train.json.zip"), crosswoz("crosswoz_test.json.zip")
    ds_tr, ds_te = dialogsum("dialogsum_train.jsonl"), dialogsum("dialogsum_test.jsonl")
    for name, c in [("MultiWOZ train (all usable)", mw_tr), ("CrossWOZ train (all usable)", cw_tr),
                    ("DialogSum train (non-travel)", ds_tr)]:
        describe(name, c)

    train = sample(mw_tr, args.mwoz, rng) + sample(cw_tr, args.crosswoz, rng) + sample(ds_tr, args.dialogsum, rng)
    for c in train:
        c["source"] = "public"
    tsub = lambda cs: rng.sample(cs, min(args.test_chats, len(cs)))
    test = tsub(mw_te) + tsub(cw_te)
    off = tsub(ds_te)
    for c in test:
        c["source"] = "public_test"
    for c in off:
        c["source"] = "offtopic"
    write_jsonl(DATA / "public_train.jsonl", train)
    write_jsonl(DATA / "public_test.jsonl", test)
    write_jsonl(DATA / "offtopic_test.jsonl", off)
    print()
    describe("public_train.jsonl", train)
    describe("public_test.jsonl", test)
    describe("offtopic_test.jsonl", off)


if __name__ == "__main__":
    main()
