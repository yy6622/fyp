"""Score a model on the held-back test sets, so base vs tuned can be compared.

    python evaluate.py --model gemini-3.5-flash --label base
    python evaluate.py --model projects/.../locations/us/endpoints/123 --label tuned
    python evaluate.py --report          # table of every run in results/
    python evaluate.py --rescore         # re-score saved predictions (no API calls)
    python evaluate.py --selftest        # checks the scorer itself, no API calls

Metrics (all 0-100, higher is better):
    valid_json      a JSON answer in the expected shape could be read (the first
                    JSON object is used, exactly as the Cloud Function does)
    add_f1          things to ADD: right place on the right day, where a place still
                    counts if it is named a little differently. add_p / add_r are its
                    precision and recall:
                    low precision = adds things the group never agreed on,
                    low recall    = misses things the group agreed on.
    add_exact_f1    strict version: right day AND exactly the reference name
                    (for saved places that is the name in the saved list)
    time_acc        of correctly placed additions, how many have the exact time
    saved_acc       of correctly placed additions, how many are correctly flagged as
                    "from the saved list" / "not from the saved list"
    update_f1       changes to what is already planned: right item, right new day,
                    right new time
    remove_f1       removals of what is already planned
    change_p        of all update/remove suggestions the model made, how many were
                    right - a wrong one here would damage the user's existing plan
    unresolved_f1   the "raised but not decided" list
    exact           the whole answer is identical to the expected one
"""
import argparse
import difflib
import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
SPLITS = ["test_seen", "test_unseen"]


def norm(s):
    return re.sub(r"[^a-z0-9]+", " ", str(s).lower()).strip()


def fuzzy(a, b):
    a, b = norm(a), norm(b)
    return a == b or (a and b and difflib.SequenceMatcher(None, a, b).ratio() >= 0.8)


def same_place(a, b):
    """Same place, allowing a shorter/longer form of the name."""
    if fuzzy(a, b):
        return True
    ta, tb = set(norm(a).split()), set(norm(b).split())
    return bool(ta) and bool(tb) and (ta <= tb or tb <= ta)


def parse_answer(text):
    """Returns the answer dict (all four lists present), or None if it isn't
    JSON in the right shape."""
    if not text:
        return None
    start = text.find("{")
    if start < 0:
        return None
    try:  # first JSON object only: a tuned model occasionally repeats its answer
        obj, _ = json.JSONDecoder().raw_decode(text[start:])
    except Exception:
        return None
    if not isinstance(obj, dict) or not isinstance(obj.get("add"), list):
        return None
    out = {}
    for key in ("add", "update", "remove", "unresolved"):
        value = obj.get(key, [])
        if not isinstance(value, list):
            return None
        out[key] = value
    if any(not isinstance(i, dict) or "label" not in i for i in out["add"] + out["update"] + out["remove"]):
        return None
    out["unresolved"] = [u for u in out["unresolved"] if isinstance(u, str)]
    return out


def _match(gold, pred, same):
    """Greedy one-to-one matching; returns [(gold_item, pred_item)]."""
    used, pairs = set(), []
    for g in gold:
        for k, p in enumerate(pred):
            if k not in used and same(g, p):
                used.add(k)
                pairs.append((g, p))
                break
    return pairs


def score_one(gold, pred):
    """Raw counts for one example; summed over the split by aggregate()."""
    c = dict(n=1, valid=0, exact=0,
             g_add=len(gold["add"]), p_add=0, add_tp=0, add_exact_tp=0, time_ok=0, saved_ok=0,
             g_upd=len(gold["update"]), p_upd=0, upd_tp=0,
             g_rem=len(gold["remove"]), p_rem=0, rem_tp=0,
             g_unres=len(gold["unresolved"]), p_unres=0, unres_tp=0)
    if pred is None:
        return c
    c["valid"] = 1
    c["exact"] = int(json.dumps(gold, sort_keys=True) == json.dumps(pred, sort_keys=True))

    c["p_add"] = len(pred["add"])
    pairs = _match(gold["add"], pred["add"], lambda g, p: p.get("day") == g["day"] and same_place(p["label"], g["label"]))
    c["add_tp"] = len(pairs)
    c["time_ok"] = sum(p.get("time") == g["time"] for g, p in pairs)
    c["saved_ok"] = sum(bool(p.get("saved")) == g["saved"] for g, p in pairs)
    c["add_exact_tp"] = len(_match(gold["add"], pred["add"],
                                   lambda g, p: p.get("day") == g["day"] and norm(p["label"]) == norm(g["label"])))

    c["p_upd"] = len(pred["update"])
    c["upd_tp"] = len(_match(gold["update"], pred["update"],
                             lambda g, p: same_place(p["label"], g["label"]) and p.get("from_day") == g["from_day"]
                             and p.get("day") == g["day"] and p.get("time") == g["time"]))
    c["p_rem"] = len(pred["remove"])
    c["rem_tp"] = len(_match(gold["remove"], pred["remove"],
                             lambda g, p: p.get("day") == g["day"] and same_place(p["label"], g["label"])))
    c["p_unres"] = len(pred["unresolved"])
    c["unres_tp"] = len(_match(gold["unresolved"], pred["unresolved"], same_place))
    return c


def aggregate(counts):
    t = {k: sum(c[k] for c in counts) for k in counts[0]}

    def f1(tp, g, p):
        if g == 0 and p == 0:
            return 100.0
        prec, rec = (tp / p if p else 0), (tp / g if g else 0)
        return 100 * 2 * prec * rec / (prec + rec) if prec + rec else 0.0

    pct = lambda a, b: 100 * a / b if b else 100.0
    return {
        "n": t["n"],
        "valid_json": round(pct(t["valid"], t["n"]), 1),
        "add_f1": round(f1(t["add_tp"], t["g_add"], t["p_add"]), 1),
        "add_p": round(pct(t["add_tp"], t["p_add"]), 1),
        "add_r": round(pct(t["add_tp"], t["g_add"]), 1),
        "add_exact_f1": round(f1(t["add_exact_tp"], t["g_add"], t["p_add"]), 1),
        "time_acc": round(pct(t["time_ok"], t["add_tp"]), 1),
        "saved_acc": round(pct(t["saved_ok"], t["add_tp"]), 1),
        "update_f1": round(f1(t["upd_tp"], t["g_upd"], t["p_upd"]), 1),
        "remove_f1": round(f1(t["rem_tp"], t["g_rem"], t["p_rem"]), 1),
        "change_p": round(pct(t["upd_tp"] + t["rem_tp"], t["p_upd"] + t["p_rem"]), 1),
        "unresolved_f1": round(f1(t["unres_tp"], t["g_unres"], t["p_unres"]), 1),
        "exact": round(pct(t["exact"], t["n"]), 1),
    }


def load(split):
    rows = []
    with open(HERE / "data" / f"{split}.jsonl", encoding="utf-8") as f:
        for line in f:
            r = json.loads(line)
            rows.append({"system": r["systemInstruction"]["parts"][0]["text"],
                         "user": r["contents"][0]["parts"][0]["text"],
                         "gold": json.loads(r["contents"][1]["parts"][0]["text"])})
    return rows


def run(args):
    from google import genai
    from google.genai import types

    # A tuned endpoint must be called in the location it lives in (the
    # tuning job may place it in the "us" multi-region, not us-central1).
    in_name = re.search(r"/locations/([^/]+)/", args.model)
    location = in_name.group(1) if in_name else args.location
    client = genai.Client(vertexai=True, project=args.project, location=location)
    out_dir = HERE / "results"
    out_dir.mkdir(exist_ok=True)
    summary = {"model": args.model, "label": args.label, "splits": {}}
    for split in SPLITS:
        rows = load(split)[: args.limit]
        counts = []
        with open(out_dir / f"{args.label}.{split}.predictions.jsonl", "w", encoding="utf-8") as f:
            for n, row in enumerate(rows, 1):
                text = None
                for attempt in range(4):  # ride out rate limits
                    try:
                        resp = client.models.generate_content(
                            model=args.model, contents=row["user"],
                            config=types.GenerateContentConfig(system_instruction=row["system"], temperature=0,
                                                               response_mime_type="application/json",
                                                               max_output_tokens=8192))
                        text = resp.text
                        break
                    except Exception as e:  # noqa: BLE001
                        if "NOT_FOUND" in str(e) or "PERMISSION_DENIED" in str(e):
                            # retrying can't fix a wrong model name / location / missing access
                            sys.exit(f"\ncannot call {args.model} in location '{location}':\n{e}\n"
                                     "try another --location (global, us, us-central1) or check the model name")
                        print(f"  retry {attempt + 1}: {e}", file=sys.stderr)
                        time.sleep(5 * (attempt + 1))
                pred = parse_answer(text)
                counts.append(score_one(row["gold"], pred))
                f.write(json.dumps({"prediction": text, "gold": row["gold"]}, ensure_ascii=False) + "\n")
                print(f"\r{split}: {n}/{len(rows)}", end="", flush=True)
        summary["splits"][split] = aggregate(counts)
        print("  ", summary["splits"][split])
    (out_dir / f"{args.label}.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    report()


COLS = ["valid_json", "add_f1", "add_p", "add_r", "add_exact_f1", "time_acc", "saved_acc", "update_f1", "remove_f1",
        "change_p", "unresolved_f1", "exact"]


def report():
    runs = sorted((HERE / "results").glob("*.json")) if (HERE / "results").exists() else []
    if not runs:
        sys.exit("no results yet - run evaluate.py --model ... --label ... first")
    lines = ["| run | split | n | " + " | ".join(COLS) + " |", "|---|---|---|" + "---|" * len(COLS)]
    for path in runs:
        s = json.loads(path.read_text(encoding="utf-8"))
        for split, m in s["splits"].items():
            lines.append(f"| {s['label']} | {split} | {m['n']} | " + " | ".join(str(m[c]) for c in COLS) + " |")
    table = "\n".join(lines)
    (HERE / "results" / "report.md").write_text(table + "\n", encoding="utf-8")
    print("\n" + table)


def rescore():
    """Re-score every saved predictions file with the current metrics."""
    out_dir = HERE / "results"
    for path in sorted(out_dir.glob("*.json")):
        summary = json.loads(path.read_text(encoding="utf-8"))
        for split in list(summary["splits"]):
            pred_file = out_dir / f"{summary['label']}.{split}.predictions.jsonl"
            rows = [json.loads(line) for line in open(pred_file, encoding="utf-8")]
            summary["splits"][split] = aggregate([score_one(r["gold"], parse_answer(r["prediction"])) for r in rows])
        path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    report()


def selftest():
    rows = load("test_seen")
    perfect = aggregate([score_one(r["gold"], parse_answer(json.dumps(r["gold"]))) for r in rows])
    assert all(perfect[k] == 100.0 for k in perfect if k != "n"), perfect

    assert aggregate([score_one(r["gold"], parse_answer("sorry, I cannot")) for r in rows])["valid_json"] == 0

    # a model that understands nothing about the existing plan or the saved list:
    # everything on day 1, wrong time, never "saved", and it deletes a planned item it should not
    def clueless(gold):
        return {"add": [dict(a, day=1, time="23:59", saved=False) for a in gold["add"]],
                "update": [], "remove": [{"day": 1, "label": "Something Planned"}], "unresolved": []}
    worse = aggregate([score_one(r["gold"], clueless(r["gold"])) for r in rows])
    assert worse["add_f1"] < 70 and worse["time_acc"] == 0 and worse["saved_acc"] < 80, worse
    assert worse["update_f1"] == 0 and worse["change_p"] == 0 and worse["exact"] == 0, worse

    assert parse_answer('```json\n{"add":[],"update":[],"remove":[],"unresolved":[]}\n```') is not None
    assert parse_answer('{"add":[]}\n{"add":[{"day":1,"lab') == {"add": [], "update": [], "remove": [], "unresolved": []}
    assert parse_answer('{"days":[]}') is None  # the old v1 shape is not accepted
    assert same_place("Tim Ho Wan", "Tim Ho Wan (Sham Shui Po)") and not same_place("Chinatown", "Petaling Street")
    print("scorer ok:", perfect, "|", worse)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default="voya-f69f0")
    ap.add_argument("--location", default="global",
                    help="where to call a base model; a tuned endpoint always uses its own location")
    ap.add_argument("--model")
    ap.add_argument("--label")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--rescore", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        selftest()
    elif a.rescore:
        rescore()
    elif a.report:
        report()
    elif a.model and a.label:
        run(a)
    else:
        ap.error("give --model and --label, or --report, --rescore, or --selftest")
