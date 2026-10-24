"""Exports models/classifier.joblib to models/model.json (plain numbers, no
pickle) and checks that model_runtime.py reproduces sklearn's predictions.

The JSON is what the Cloud Function loads. --deploy copies model.json and
lexicons.json into ../../functions/discussion_summary/ (then redeploy functions).
"""

import argparse
import json
import shutil

import joblib

from common import DATA, MODELS, ROOT, read_jsonl
from features import prepare
from model_runtime import TextModel


def r(x, d=6):
    return float(f"{x:.{d}g}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deploy", action="store_true", help="copy model.json + lexicons.json to functions/")
    args = ap.parse_args()
    bundle = joblib.load(MODELS / "classifier.joblib")
    pipe = bundle["pipeline"]
    vec, clf = pipe.named_steps["tfidf"], pipe.named_steps["clf"]
    assert vec.analyzer == "char_wb" and not vec.lowercase
    params = {
        "name": bundle["name"],
        "labels": [str(c) for c in clf.classes_],
        "with_tags": bundle["with_tags"],
        "analyzer": "char_wb",
        "ngram_range": list(vec.ngram_range),
        "sublinear_tf": bool(vec.sublinear_tf),
        "vocab": {k: int(v) for k, v in vec.vocabulary_.items()},
        "idf": [r(x) for x in vec.idf_],
        "coef": [[r(x) for x in row] for row in clf.coef_],
        "intercept": [r(x) for x in clf.intercept_],
        # summariser: a DESTINATION / ATTRACTION / TRANSPORT / ACCOMMODATION prediction whose
        # probability (softmax of the scores, LogReg only) is below this becomes OTHER
        "topic_min_prob": float(bundle.get("topic_min_prob", 0.0)),
    }
    out = MODELS / "model.json"
    out.write_text(json.dumps(params, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size / 1e6:.1f} MB, {len(params['vocab'])} features)")

    # Parity: runtime vs sklearn on every message of every split
    rt = TextModel(params)
    texts = [m["text"] for p in sorted((DATA / "splits").glob("*.jsonl")) for c in read_jsonl(p) for m in c["messages"]]
    sk = pipe.predict([prepare(t, bundle["with_tags"]) for t in texts])
    mism = sum(1 for t, s in zip(texts, sk) if rt.predict(t)[0] != s)
    print(f"runtime vs sklearn: {len(texts) - mism}/{len(texts)} identical predictions")
    if mism:
        raise SystemExit("runtime does not match sklearn - do not ship this model")
    if args.deploy:
        fn = ROOT.parent.parent / "functions" / "discussion_summary"
        shutil.copy(out, fn / "model.json")
        shutil.copy(ROOT / "lexicons.json", fn / "lexicons.json")
        print(f"copied model.json + lexicons.json to {fn}")
        import export_gazetteer        # the planner's place database (functions/planner/gazetteer.json)
        export_gazetteer.main()


if __name__ == "__main__":
    main()
