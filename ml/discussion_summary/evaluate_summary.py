"""Experiment B - summary quality, decision accuracy, and the importance-score ablation.

  python evaluate_summary.py            # all test splits, weights tuned on train
  python evaluate_summary.py --quick    # skip the weight grid search (uses defaults)

Writes results/experiment_B.md and results/experiment_B.json.

Metrics (per split):
  topic_f1          did we find the right proposals (matched by message id)
  decision_acc      status (confirmed / rejected / pending) of the topics we found
  false_confirm     share of NOT-confirmed topics that we reported as confirmed
                    (= a suggestion summarised as a final decision - the worst error)
  status_f1         end to end: (proposal, status) pairs right
  stance_acc        agree / reject / defer / finalize of reactions
  attach_acc        a reaction was linked to the right topic
  coverage          share of confirmed + pending topics present in the summary
  fact_*            budget amount, budget basis, dates, destination correct
  rouge1 / rougeL   F1 word overlap with the reference summary
  compression       summary length / chat length (characters)
Highlights (top 20% of messages by S(m)) are scored against the gold important
messages (proposals of confirmed / pending topics, finalising messages,
preferences) for each weighting of S(m) and for Lead-k / Random-k baselines.
"""

import argparse
import itertools
import json
import random
import re

from common import DATA, RESULTS, read_jsonl
from features import normalize
from kb import CITY_NAMES
from model_runtime import TextModel
from summariser import DEFAULT_WEIGHTS, parse_dates, summarise

SPLITS = ["test_seen", "test_unseen", "test_challenge", "test_challenge2", "test_smalltalk", "test_real", "test_offtopic"]
REACTIONS = {"agree", "reject", "defer", "finalize"}


# --------------------------------------------------------------------------- ROUGE

def rtok(text):
    return re.findall(r"[a-z0-9]+|[一-鿿]", normalize(text))


def rouge1(pred, ref):
    p, r = rtok(pred), rtok(ref)
    if not p or not r:
        return 0.0
    from collections import Counter
    overlap = sum((Counter(p) & Counter(r)).values())
    if overlap == 0:
        return 0.0
    prec, rec = overlap / len(p), overlap / len(r)
    return 2 * prec * rec / (prec + rec)


def rougeL(pred, ref):
    p, r = rtok(pred), rtok(ref)
    if not p or not r:
        return 0.0
    prev = [0] * (len(r) + 1)
    for a in p:
        cur = [0]
        for j, b in enumerate(r):
            cur.append(prev[j] + 1 if a == b else max(prev[j + 1], cur[j]))
        prev = cur
    lcs = prev[-1]
    if lcs == 0:
        return 0.0
    prec, rec = lcs / len(p), lcs / len(r)
    return 2 * prec * rec / (prec + rec)


# --------------------------------------------------------------------------- helpers

def f1(p, r):
    return 0.0 if p + r == 0 else 2 * p * r / (p + r)


def gold_important(conv):
    imp = {t["proposal"] for t in conv["topics"] if t["status"] in ("confirmed", "pending")}
    imp |= {m["id"] for m in conv["messages"] if m.get("stance") == "finalize" or m["label"] == "PREFERENCE"}
    return imp


def select(summary, weights, ratio=0.2):
    msgs = summary["messages"]
    k = max(1, int(round(len(msgs) * ratio)))
    sc = {m["id"]: sum(weights[c] * m[c] for c in "RDNC") for m in msgs}
    order = sorted(range(len(msgs)), key=lambda i: (-sc[msgs[i]["id"]], i))
    return {msgs[i]["id"] for i in order[:k] if msgs[i]["label"] != "OTHER"}


def dest_ok(gold, pred):
    if gold is None or pred is None:
        return gold is None and pred is None
    names = {gold.lower()}
    for full, alias in CITY_NAMES.items():
        if gold.lower() in [a.lower() for a in alias] + [full.lower(), full.split(",")[0].lower()]:
            names |= {a.lower() for a in alias} | {full.split(",")[0].lower()}
    p = normalize(pred)
    return any(n in p for n in names)


def dates_ok(gold, pred):
    if gold is None or pred is None:
        return gold is None and pred is None
    g = parse_dates(gold) or normalize(gold)
    return normalize(g) == normalize(pred)


def evaluate_split(convs, model, weights, gold_labels=False):
    agg = {k: 0 for k in ["gold_topics", "pred_topics", "matched", "status_ok", "not_conf", "false_conf",
                          "pair_ok", "react", "stance_ok", "attach_n", "attach_ok", "important", "covered",
                          "msgs", "label_ok"]}
    facts = {k: [0, 0] for k in ["budget", "basis", "dates", "destination"]}
    r1, rl, comp = [], [], []
    summaries = []
    for c in convs:
        gl = {m["id"]: m["label"] for m in c["messages"]} if gold_labels else None
        s = summarise(c["messages"], model, c.get("members"), weights=weights, gold_labels=gl)
        summaries.append(s)
        gold_t = {t["proposal"]: t for t in c["topics"]}
        pred_t = {t["proposal"]: t for t in s["topics"]}
        gid2prop = {t["id"]: t["proposal"] for t in c["topics"]}
        pid2prop = {t["id"]: t["proposal"] for t in s["topics"]}
        agg["gold_topics"] += len(gold_t)
        agg["pred_topics"] += len(pred_t)
        for prop, g in gold_t.items():
            if prop in pred_t:
                agg["matched"] += 1
                ok = pred_t[prop]["status"] == g["status"]
                agg["status_ok"] += ok
                agg["pair_ok"] += ok
                if g["status"] != "confirmed":
                    agg["not_conf"] += 1
                    agg["false_conf"] += pred_t[prop]["status"] == "confirmed"
            if g["status"] in ("confirmed", "pending"):
                agg["important"] += 1
                agg["covered"] += prop in pred_t
        pm = {m["id"]: m for m in s["messages"]}
        for m in c["messages"]:
            agg["msgs"] += 1
            agg["label_ok"] += pm[m["id"]]["label"] == m["label"]
        for m in c["messages"]:
            if m.get("stance") in REACTIONS:
                agg["react"] += 1
                agg["stance_ok"] += pm[m["id"]]["stance"] == m["stance"]
                if m.get("topic") in gid2prop:
                    agg["attach_n"] += 1
                    agg["attach_ok"] += pid2prop.get(pm[m["id"]]["topic"]) == gid2prop[m["topic"]]
        gf, pf = c["facts"], s["facts"]
        for key, ok in (("budget", gf.get("budget") == pf["budget"] or (gf.get("budget") is not None and pf["budget"] is not None and abs(float(gf["budget"]) - pf["budget"]) < 1)),
                        ("basis", gf.get("budget_basis") == pf["budget_basis"]),
                        ("dates", dates_ok(gf.get("dates"), pf["dates"])),
                        ("destination", dest_ok(gf.get("destination"), pf["destination"]))):
            facts[key][0] += bool(ok)
            facts[key][1] += 1
        if c.get("reference_summary"):
            r1.append(rouge1(s["text"], c["reference_summary"]))
            rl.append(rougeL(s["text"], c["reference_summary"]))
        comp.append(s["stats"]["compression"])
    P = agg["matched"] / max(1, agg["pred_topics"])
    R = agg["matched"] / max(1, agg["gold_topics"])
    out = {
        "chats": len(convs),
        "topic_p": 100 * P, "topic_r": 100 * R, "topic_f1": 100 * f1(P, R),
        "decision_acc": 100 * agg["status_ok"] / max(1, agg["matched"]),
        "false_confirm": 100 * agg["false_conf"] / max(1, agg["not_conf"]),
        "status_f1": 100 * f1(agg["pair_ok"] / max(1, agg["pred_topics"]), agg["pair_ok"] / max(1, agg["gold_topics"])),
        "stance_acc": 100 * agg["stance_ok"] / max(1, agg["react"]),
        "attach_acc": 100 * agg["attach_ok"] / max(1, agg["attach_n"]),
        "coverage": 100 * agg["covered"] / max(1, agg["important"]),
        "rouge1": 100 * sum(r1) / max(1, len(r1)), "rougeL": 100 * sum(rl) / max(1, len(rl)),
        "compression": sum(comp) / max(1, len(comp)),
        "label_acc": 100 * agg["label_ok"] / max(1, agg["msgs"]),
        "topics_per_chat": agg["pred_topics"] / max(1, len(convs)),
    }
    for k, (ok, n) in facts.items():
        out[f"fact_{k}"] = 100 * ok / max(1, n)
    return out, summaries


def highlight_scores(convs, summaries, weights, ratio=0.2):
    tp = fp = fn = 0
    for c, s in zip(convs, summaries):
        gold = gold_important(c)
        pred = select(s, weights, ratio)
        tp += len(gold & pred)
        fp += len(pred - gold)
        fn += len(gold - pred)
    P, R = tp / max(1, tp + fp), tp / max(1, tp + fn)
    return 100 * f1(P, R)


def baseline_highlights(convs, kind, ratio=0.2, seed=0):
    tp = fp = fn = 0
    rng = random.Random(seed)
    for c in convs:
        ids = [m["id"] for m in c["messages"]]
        k = max(1, int(round(len(ids) * ratio)))
        pred = set(ids[:k]) if kind == "lead" else set(rng.sample(ids, k))
        gold = gold_important(c)
        tp += len(gold & pred)
        fp += len(pred - gold)
        fn += len(gold - pred)
    P, R = tp / max(1, tp + fp), tp / max(1, tp + fn)
    return 100 * f1(P, R)


def tune_weights(train, model):
    """Grid search over the simplex (step 0.1) maximising highlight F1 on train chats."""
    _, sums = evaluate_split(train, model, DEFAULT_WEIGHTS)
    best, best_w = -1, None
    steps = [i / 10 for i in range(11)]
    for wr, wd, wn in itertools.product(steps, repeat=3):
        wc = round(1 - wr - wd - wn, 2)
        if wc < -1e-9:
            continue
        w = {"R": wr, "D": wd, "N": wn, "C": wc}
        sc = highlight_scores(train, sums, w)
        if sc > best + 1e-9:
            best, best_w = sc, w
    return best_w, best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    args = ap.parse_args()
    model = TextModel.load(DATA.parent / "models" / "model.json")
    # public datasets have message labels only (no group decisions), so they are not used here
    train = [c for c in read_jsonl(DATA / "splits" / "train.jsonl") if c.get("source") != "public"]
    splits = {}
    for name in SPLITS:
        p = DATA / "splits" / f"{name}.jsonl"
        if p.exists() and p.stat().st_size > 0:
            splits[name] = read_jsonl(p)

    if args.quick:
        tuned, tuned_score = DEFAULT_WEIGHTS, None
    else:
        tuned, tuned_score = tune_weights(train, model)
        print(f"tuned weights on train: {tuned} (highlight F1 {tuned_score:.1f})")

    results = {"tuned_weights": tuned, "splits": {}}
    for name, convs in splits.items():
        main_res, sums = evaluate_split(convs, model, tuned)
        oracle_res, _ = evaluate_split(convs, model, tuned, gold_labels=True)
        variants = {
            "Lead-20%": baseline_highlights(convs, "lead"),
            "Random-20%": sum(baseline_highlights(convs, "random", seed=s) for s in range(5)) / 5,
            "R only (relevance)": highlight_scores(convs, sums, {"R": 1, "D": 0, "N": 0, "C": 0}),
            "D only (decision)": highlight_scores(convs, sums, {"R": 0, "D": 1, "N": 0, "C": 0}),
            "N only (novelty)": highlight_scores(convs, sums, {"R": 0, "D": 0, "N": 1, "C": 0}),
            "C only (TextRank)": highlight_scores(convs, sums, {"R": 0, "D": 0, "N": 0, "C": 1}),
            "S default weights": highlight_scores(convs, sums, DEFAULT_WEIGHTS),
            "S tuned weights": highlight_scores(convs, sums, tuned),
        }
        for comp in "RDNC":
            w = dict(tuned)
            w[comp] = 0.0
            variants[f"S tuned without {comp}"] = highlight_scores(convs, sums, w)
        results["splits"][name] = {"main": main_res, "oracle_labels": oracle_res, "highlights": variants}
        print(f"{name:14s} topic F1 {main_res['topic_f1']:.1f}  decision acc {main_res['decision_acc']:.1f}  "
              f"false-confirm {main_res['false_confirm']:.1f}  ROUGE-L {main_res['rougeL']:.1f}  "
              f"highlights F1 {variants['S tuned weights']:.1f}")
    RESULTS.mkdir(exist_ok=True)
    json.dump(results, open(RESULTS / "experiment_B.json", "w"), indent=1)
    write_report(results)


def write_report(res):
    names = list(res["splits"])
    rows = [("Topic detection F1", "topic_f1"), ("Decision (status) accuracy", "decision_acc"),
            ("False 'confirmed' rate (lower is better)", "false_confirm"), ("End-to-end status F1", "status_f1"),
            ("Stance accuracy", "stance_acc"), ("Reply-to-topic linking accuracy", "attach_acc"),
            ("Coverage of confirmed + pending topics", "coverage"), ("Fact: budget amount", "fact_budget"),
            ("Fact: budget per person / total", "fact_basis"), ("Fact: dates", "fact_dates"),
            ("Fact: destination", "fact_destination"), ("ROUGE-1 F1", "rouge1"), ("ROUGE-L F1", "rougeL"),
            ("Compression (summary / chat chars)", "compression"),
            ("Message label accuracy (classifier + rules)", "label_acc"),
            ("Topics created per chat (small talk should be 0)", "topics_per_chat")]
    L = ["# Experiment B - summary quality", "",
         f"Importance weights tuned on the training chats: {res['tuned_weights']}", "",
         "All numbers are %, except compression (a ratio). In brackets: the same pipeline fed the gold message labels "
         "(an oracle classifier), which shows how much error comes from classification versus the summary rules.", "",
         "| Metric | " + " | ".join(names) + " |", "|---|" + "---|" * len(names)]
    for title, key in rows:
        cells = []
        for n in names:
            a, b = res["splits"][n]["main"][key], res["splits"][n]["oracle_labels"][key]
            cells.append(f"{a:.2f} ({b:.2f})" if key in ("compression", "topics_per_chat") else f"{a:.1f} ({b:.1f})")
        L.append(f"| {title} | " + " | ".join(cells) + " |")
    L += ["", "## Highlights: which messages does S(m) pick? (F1 % against gold important messages, top 20%)", "",
          "| Selection | " + " | ".join(names) + " |", "|---|" + "---|" * len(names)]
    for v in next(iter(res["splits"].values()))["highlights"]:
        L.append(f"| {v} | " + " | ".join(f"{res['splits'][n]['highlights'][v]:.1f}" for n in names) + " |")
    L += ["", "Chats per split: " + ", ".join(f"{n} {res['splits'][n]['main']['chats']}" for n in names)]
    (RESULTS / "experiment_B.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"wrote {RESULTS / 'experiment_B.md'}")


if __name__ == "__main__":
    main()
