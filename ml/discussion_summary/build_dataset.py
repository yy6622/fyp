"""Merges every data source and writes the train / test splits. No external API is used.

Sources (whatever exists is used):
  data/template.jsonl       generate_template_data.py   (training + test_seen / test_unseen)
  data/manual.jsonl         manual_data.py              (hand-written training chats)
  data/challenge.jsonl      challenge_data.py           (hand-written, test only)
  data/challenge2.jsonl     challenge_data.py           (second hand-written test set, see README)
  data/real_*.csv           prepare_real_labelling.py + your corrections (real chats, test only)
  data/public_train.jsonl   import_public_datasets.py   (MultiWOZ + CrossWOZ + DialogSum, training)
  data/public_test.jsonl    import_public_datasets.py   (their official test splits)
  data/offtopic_test.jsonl  import_public_datasets.py   (DialogSum test chats with no travel talk)

Splits (always grouped by conversation, so no chat is split between train and test):
  train           template chats (seen destinations) + manual_data.py chats + public datasets
  test_seen       template chats, destinations also in train
  test_unseen     template chats from Osaka and Kota Kinabalu (never in train)
  test_challenge  hand-written chats, written while designing the system
  test_challenge2 hand-written chats, written before the final training round and never looked at
  test_smalltalk  greetings / chit-chat that must all be OTHER (smalltalk_test.py)
  test_real       your real Firestore chats (never trained on) - the most honest test
  test_public     real human-written MultiWOZ / CrossWOZ test dialogues (user turns, labels from their annotations)
  test_offtopic   real everyday DialogSum test chats with no travel talk: every message must be OTHER
"""

import csv
import random
from collections import defaultdict

from common import DATA, LABELS, STATUSES, TOPIC_CATEGORIES, read_jsonl, write_jsonl
from kb import HELD_OUT

SPLITS = DATA / "splits"
STANCES = {"propose", "agree", "reject", "defer", "finalize", "info", "ask", "none"}


def load(name):
    p = DATA / name
    return read_jsonl(p) if p.exists() else []


def read_csv(name):
    p = DATA / name
    return list(csv.DictReader(open(p, encoding="utf-8-sig"))) if p.exists() else []


def load_real():
    """Real chats from the three CSV files written by prepare_real_labelling.py."""
    labels, topics, facts = read_csv("real_labels.csv"), read_csv("real_topics.csv"), read_csv("real_facts.csv")
    if not labels:
        return [], 0, 0
    changed = 0
    msgs = defaultdict(list)
    for r in labels:
        lab = (r["label"] or r["model_label"]).strip().upper()
        st = (r["stance"] or r["model_stance"]).strip().lower()
        tp = (r["topic"] or r["model_topic"]).strip()
        if r["label"].strip() or r["stance"].strip() or r["topic"].strip():
            changed += 1
        if lab not in LABELS or st not in STANCES:
            raise SystemExit(f"real_labels.csv: bad label/stance in message {r['message_id']}: {lab} / {st}")
        msgs[r["conv_id"]].append({"id": r["message_id"], "speaker": r["speaker"], "text": r["message"],
                                   "label": lab, "topic": None if tp in ("", "-") else tp, "stance": st})
    tops = defaultdict(list)
    for r in topics:
        status = (r["status"] or r["model_status"]).strip().lower()
        if status == "drop":
            continue
        if r["category"] not in TOPIC_CATEGORIES or status not in STATUSES:
            raise SystemExit(f"real_topics.csv: bad category/status for {r['conv_id']} {r['topic']}")
        tops[r["conv_id"]].append({"id": r["topic"], "category": r["category"], "value": r["value"],
                                   "proposal": r["proposal_message_id"], "status": status})
    fact_by = {r["conv_id"]: r for r in facts}
    convs = []
    for conv_id, ms in msgs.items():
        ids = {t["id"] for t in tops[conv_id]}
        for m in ms:
            if m["topic"] not in ids:
                m["topic"] = None
        f = fact_by.get(conv_id, {})
        budget = f.get("budget", "").strip()
        prefs = [{"speaker": m["speaker"], "text": m["text"], "message": m["id"]} for m in ms if m["label"] == "PREFERENCE"]
        ref = f.get("reference_summary", "").strip() or None
        convs.append({
            "conv_id": f"real-{conv_id}", "source": "firestore", "destination": f.get("destination"),
            "members": sorted({m["speaker"] for m in ms}), "messages": ms, "topics": tops[conv_id], "preferences": prefs,
            "facts": {"destination": f.get("destination") or None, "budget": float(budget) if budget else None,
                      "budget_basis": f.get("budget_basis") or None, "dates": f.get("dates") or None},
            # without a human-written reference the ROUGE score is skipped for this chat
            "reference_summary": ref or "",
        })
    return convs, changed, len(labels)


def main(seed=2026):
    rng = random.Random(seed)
    template = load("template.jsonl")
    manual = load("manual.jsonl")
    challenge = load("challenge.jsonl")
    challenge2 = load("challenge2.jsonl")
    smalltalk = load("smalltalk.jsonl")
    real, changed, n_real = load_real()
    public = load("public_train.jsonl")
    public_test = load("public_test.jsonl")
    offtopic = load("offtopic_test.jsonl")

    unseen = [c for c in template if c["destination"] in HELD_OUT]
    seen = [c for c in template if c["destination"] not in HELD_OUT]
    rng.shuffle(seen)
    n_test = max(1, int(len(seen) * 0.2))
    test_seen, train = seen[:n_test], seen[n_test:]
    train = train + manual + public

    splits = {"train": train, "test_seen": test_seen, "test_unseen": unseen, "test_challenge": challenge,
              "test_challenge2": challenge2, "test_smalltalk": smalltalk, "test_real": real,
              "test_public": public_test, "test_offtopic": offtopic}
    SPLITS.mkdir(parents=True, exist_ok=True)
    for old in SPLITS.glob("test_openai*"):
        old.unlink()
    for name, convs in splits.items():
        write_jsonl(SPLITS / f"{name}.jsonl", convs)
        with open(SPLITS / f"{name}_messages.csv", "w", newline="", encoding="utf-8-sig") as f:
            w = csv.writer(f)
            w.writerow(["message_id", "conv_id", "source", "speaker", "message", "label"])
            for c in convs:
                for m in c["messages"]:
                    w.writerow([m["id"], c["conv_id"], c["source"], m["speaker"], m["text"], m["label"]])
        print(f"{name:16s} {len(convs):4d} chats {sum(len(c['messages']) for c in convs):6d} messages")
    if real:
        print(f"(real chats: you corrected {changed} of {n_real} pre-filled message rows)")


if __name__ == "__main__":
    main()
