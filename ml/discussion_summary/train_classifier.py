"""Experiment A - message classifier.

Compares a majority-class baseline, Multinomial Naive Bayes, Logistic
Regression and Linear SVM, on word n-grams vs character n-grams, with and
without the money/date/question tags. Model selection uses 5-fold
GroupKFold cross-validation on the training chats only (grouped by chat, so
messages of one chat are never on both sides). The selected model is then
refit on all training data, scored once on every test split, and saved.

Output:
  models/classifier.joblib         the fitted sklearn Pipeline
  results/experiment_A.md          tables for the report
  results/experiment_A.json        same numbers, machine-readable
  results/confusion_<split>.csv    confusion matrices of the final model
"""

import json
import time

import joblib
import numpy as np
from sklearn.dummy import DummyClassifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline
from sklearn.svm import LinearSVC

from common import DATA, LABELS, MODELS, RESULTS, read_jsonl
from features import prepare

SPLITS = DATA / "splits"
TEST_SPLITS = ["test_seen", "test_unseen", "test_challenge", "test_challenge2", "test_smalltalk", "test_real",
               "test_public", "test_offtopic"]
# Not hand-written: count once in training and are left out of CV-hand.
BULK_SOURCES = ("template", "public")
PUBLIC_PREFIXES = ("mwoz", "cwoz", "dsum")      # conv_id prefixes from import_public_datasets.py
PUBLIC_LABELS = ["ATTRACTION", "ACCOMMODATION", "TRANSPORT", "OTHER"]   # the labels that exist in the public data


# Template chats are many but repetitive; hand-written chats are few but varied.
# A config's "w" says how many times each hand-written message counts in training.


def load_split(name):
    """texts, labels, groups (chat id), is_template flags."""
    p = SPLITS / f"{name}.jsonl"
    texts, labels, groups, tpl = [], [], [], []
    if not p.exists():
        return texts, labels, groups, tpl
    for c in read_jsonl(p):
        for m in c["messages"]:
            texts.append(m["text"])
            labels.append(m["label"])
            groups.append(c["conv_id"])
            tpl.append(c.get("source") in BULK_SOURCES)
    return texts, labels, groups, tpl


def vectorizer(kind):
    if kind == "word":
        # unicode word tokens; Chinese runs without spaces become one token, which is
        # exactly the weakness character n-grams are meant to fix.
        return TfidfVectorizer(analyzer="word", ngram_range=(1, 2), lowercase=False, token_pattern=r"(?u)\b\w+\b",
                               sublinear_tf=True, min_df=2)
    return TfidfVectorizer(analyzer="char_wb", ngram_range=(2, 5), lowercase=False, sublinear_tf=True, min_df=2,
                           max_features=20000)


def class_weights(y, how):
    """balanced = n / (k * count); sqrt = its square root (milder); none = all 1."""
    if how == "none":
        return None
    labels, counts = np.unique(y, return_counts=True)
    w = len(y) / (len(labels) * counts)
    if how == "sqrt":
        w = np.sqrt(w)
    return dict(zip(labels, w))


def classifier(kind, C=1.0, cw="balanced"):
    if kind == "majority":
        return DummyClassifier(strategy="most_frequent")
    if kind == "nb":
        return MultinomialNB(alpha=0.1)
    if kind == "lr":
        return LogisticRegression(C=C, max_iter=3000, class_weight=cw)
    if kind == "svm":
        return LinearSVC(C=C, class_weight=cw, random_state=0)
    raise ValueError(kind)


def cfg(name, clf, feat="char", tags=True, C=1.0, w=5.0, lex=False, cw="balanced"):
    return {"name": name, "clf": clf, "feat": feat, "tags": tags, "C": C, "w": w, "lex": lex, "cw": cw}


CONFIGS = [
    cfg("Majority class", "majority"),
    cfg("Naive Bayes + word", "nb", "word"),
    cfg("Naive Bayes + char", "nb"),
    cfg("LogReg + word", "lr", "word", C=10),
    cfg("LogReg + char, C=3", "lr", C=3),
    cfg("LogReg + char, C=10", "lr", C=10),
    cfg("LogReg + char, C=30", "lr", C=30),
    cfg("Linear SVM + word", "svm", "word"),
    cfg("Linear SVM + char (no tags), C=0.3", "svm", tags=False, C=0.3),
    cfg("Linear SVM + char, C=0.1", "svm", C=0.1),
    cfg("Linear SVM + char, C=0.3", "svm", C=0.3),
    cfg("Linear SVM + char, C=1", "svm", C=1.0),
    cfg("Linear SVM + char, C=3", "svm", C=3.0),
    cfg("Linear SVM + char, C=0.3, hand-written weight 1", "svm", C=0.3, w=1.0),
    cfg("Linear SVM + char, C=0.3, hand-written weight 15", "svm", C=0.3, w=15.0),
    cfg("LogReg + char, C=3, + stance-cue tags", "lr", C=3, lex=True),
    cfg("LogReg + char, C=3, sqrt class weights", "lr", C=3, cw="sqrt"),
    cfg("LogReg + char, C=3, no class weights", "lr", C=3, cw="none"),
    cfg("Linear SVM + char, C=0.3, sqrt class weights", "svm", C=0.3, cw="sqrt"),
]


def group_folds(groups, n_splits=5, seed=2026):
    """Our own GroupKFold: every chat goes to one fold, chosen by a seeded shuffle.
    Same folds on every scikit-learn version (sklearn's GroupKFold changed between versions)."""
    import random
    chats = sorted(set(groups))
    random.Random(seed).shuffle(chats)
    fold_of = {c: i % n_splits for i, c in enumerate(chats)}
    idx = np.arange(len(groups))
    f = np.array([fold_of[gr] for gr in groups])
    return [(idx[f != k], idx[f == k]) for k in range(n_splits)]


def make(c, y=None):
    cw = class_weights(y, c.get("cw", "balanced")) if y is not None else "balanced"
    return Pipeline([("tfidf", vectorizer(c["feat"])), ("clf", classifier(c["clf"], c["C"], cw))])


def fit(c, X, y, tpl):
    w = np.where(tpl, 1.0, c["w"])
    return make(c, y).fit(X, y, clf__sample_weight=w)


def prep(texts, with_tags, with_lex=False):
    return [prepare(t, with_tags, with_lex) for t in texts]


def scores(y_true, y_pred):
    return {
        "macro_f1": 100 * f1_score(y_true, y_pred, labels=LABELS, average="macro", zero_division=0),
        "accuracy": 100 * accuracy_score(y_true, y_pred),
    }


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--force-model", help='use this config as the final model instead of the best CV-hand one, '
                                          'e.g. "Linear SVM + char, C=0.3"')
    ap.add_argument("--quick", action="store_true",
                    help="skip the comparison grid and learning curve; just retrain the selected model "
                         "(the one named in results/experiment_A.json, or --force-model)")
    args = ap.parse_args()
    if args.quick:
        return quick(args.force_model)
    RESULTS.mkdir(exist_ok=True)
    MODELS.mkdir(exist_ok=True)
    X, y, g, tpl = load_split("train")
    y, tpl = np.array(y), np.array(tpl)
    tests = {name: load_split(name) for name in TEST_SPLITS}
    tests = {k: v for k, v in tests.items() if v[0]}
    print(f"train: {len(X)} messages from {len(set(g))} chats ({int((~tpl).sum())} hand-written); tests: " +
          ", ".join(f"{k}={len(v[0])}" for k, v in tests.items()))

    # Model selection uses only the training chats: 5-fold GroupKFold. Two CV scores:
    #   cv_all  - macro-F1 over every validation message (dominated by template chats)
    #   cv_hand - macro-F1 over the hand-written validation messages only (out-of-fold
    #             predictions pooled). These look like real chats, so the model is chosen by cv_hand.
    folds = group_folds(g)
    pub = np.array([gi.split("-")[0] in PUBLIC_PREFIXES for gi in g])
    rows = []
    for c in CONFIGS:
        Xp = np.array(prep(X, c["tags"], c["lex"]), dtype=object)
        oof = np.empty(len(y), dtype=object)
        fold = []
        t0 = time.time()
        for tr, va in folds:
            m = fit(c, Xp[tr], y[tr], tpl[tr])
            oof[va] = m.predict(Xp[va])
            fold.append(f1_score(y[va], oof[va], labels=LABELS, average="macro", zero_division=0) * 100)
        hand = ~tpl
        cv_hand = 100 * f1_score(y[hand], oof[hand], labels=LABELS, average="macro", zero_division=0) if hand.any() else 0.0
        cv_public = (100 * f1_score(y[pub], oof[pub], labels=PUBLIC_LABELS, average="macro", zero_division=0)
                     if pub.any() else None)
        model = fit(c, Xp, y, tpl)
        row = {"model": c["name"], "cv_macro_f1": float(np.mean(fold)), "cv_std": float(np.std(fold)),
               "cv_hand": float(cv_hand), "cv_public": cv_public,
               "select_score": float(cv_hand if cv_public is None else (cv_hand + cv_public) / 2), "train_seconds": round(time.time() - t0, 1)}
        for split, (tx, ty, _, _) in tests.items():
            row[split] = scores(ty, model.predict(prep(tx, c["tags"], c["lex"])))
        rows.append(row)
        print(f"{c['name']:50s} CV {row['cv_macro_f1']:.1f}  CV-hand {cv_hand:.1f}  CV-public {cv_public or 0:.1f}  " +
              "  ".join(f"{k} {v['macro_f1']:.1f}" for k, v in row.items() if isinstance(v, dict)))

    # Final model: best cv_hand among the character-n-gram linear models (only char_wb
    # models are exported: they need no Chinese word segmenter and are exactly
    # reproducible in JavaScript).
    # (stance-cue tags are only an ablation; they are not ported to JavaScript)
    candidates = [(r, c) for r, c in zip(rows, CONFIGS) if c["feat"] == "char" and c["clf"] in ("svm", "lr") and not c["lex"]]
    # Selection score: CV-hand alone, or - when the public datasets are in the training data - the mean of
    # CV-hand (our group-chat style) and CV-public (real people's messages). Only training data is used.
    best_row, best_cfg = max(candidates, key=lambda rc: (round(rc[0]["select_score"], 1), rc[0]["cv_macro_f1"]))
    if args.force_model:
        forced = [(r, c) for r, c in candidates if c["name"] == args.force_model]
        if not forced:
            raise SystemExit(f"--force-model: no exportable config named {args.force_model!r}")
        best_row, best_cfg = forced[0]
    print(f"\nselected: {best_row['model']}")
    final = fit(best_cfg, np.array(prep(X, best_cfg["tags"]), dtype=object), y, tpl)
    min_prob, thr_curve = tune_topic_threshold(best_cfg, X, y, tpl, folds)
    print(f"topic confidence cut-off (CV-hand): {min_prob}")
    joblib.dump({"pipeline": final, "with_tags": best_cfg["tags"], "name": best_row["model"], "labels": LABELS,
                 "topic_min_prob": min_prob}, MODELS / "classifier.joblib")

    # Experiment A2 - learning curve: CV-hand of the selected model when only part of
    # the hand-written training chats is available (templates always included).
    hand_chats = sorted({gi for gi, t in zip(g, tpl) if not t})
    rng = np.random.RandomState(0)
    order = list(rng.permutation(hand_chats))
    Xs = np.array(prep(X, best_cfg["tags"]), dtype=object)
    garr = np.array(g)
    curve = []
    for frac in (0.0, 0.25, 0.5, 0.75, 1.0):
        allowed = set(order[: int(round(len(order) * frac))])
        oof = np.empty(len(y), dtype=object)
        for tr, va in folds:
            tr = np.array([i for i in tr if tpl[i] or garr[i] in allowed], dtype=int)
            oof[va] = fit(best_cfg, Xs[tr], y[tr], tpl[tr]).predict(Xs[va])
        hand = ~tpl
        sc = 100 * f1_score(y[hand], oof[hand], labels=LABELS, average="macro", zero_division=0)
        curve.append({"hand_chats": len(allowed), "cv_hand": float(sc)})
        print(f"learning curve: {len(allowed):3d} hand-written chats -> CV-hand {sc:.1f}")

    per_class = {}
    for split, (tx, ty, _, _) in tests.items():
        pred = final.predict(prep(tx, best_cfg["tags"]))
        per_class[split] = classification_report(ty, pred, labels=LABELS, output_dict=True, zero_division=0)
        cm = confusion_matrix(ty, pred, labels=LABELS)
        with open(RESULTS / f"confusion_{split}.csv", "w", encoding="utf-8") as f:
            f.write("gold\\pred," + ",".join(LABELS) + "\n")
            for lab, r in zip(LABELS, cm):
                f.write(lab + "," + ",".join(map(str, r)) + "\n")

    json.dump({"rows": rows, "selected": best_row["model"], "per_class": per_class, "learning_curve": curve},
              open(RESULTS / "experiment_A.json", "w"), indent=1)
    write_report(rows, best_row["model"], per_class, len(X), len(set(g)), {k: len(v[0]) for k, v in tests.items()},
                 curve)


TOPIC_LABELS = ["DESTINATION", "ATTRACTION", "TRANSPORT", "ACCOMMODATION"]


def tune_topic_threshold(c, X, y, tpl, folds):
    """Cut-off on the classifier's probability: a place / transport / hotel / destination
    prediction below it becomes OTHER. Chosen by CV-hand on the training chats only."""
    if c["clf"] != "lr":
        return 0.0, []
    Xp = np.array(prep(X, c["tags"]), dtype=object)
    proba = np.zeros((len(y), len(LABELS)))
    classes = None
    for tr, va in folds:
        m = fit(c, Xp[tr], y[tr], tpl[tr])
        classes = list(m.classes_)
        proba[va] = m.predict_proba(Xp[va])
    hand = ~tpl
    curve = []
    for t in [0.0, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6]:
        pred = []
        for row in proba[hand]:
            k = int(np.argmax(row))
            lab = classes[k]
            pred.append("OTHER" if lab in TOPIC_LABELS and row[k] < t else lab)
        curve.append((t, 100 * f1_score(y[hand], pred, labels=LABELS, average="macro", zero_division=0)))
    best = max(curve, key=lambda tc: (round(tc[1], 1), -tc[0]))
    print("  cut-off curve: " + ", ".join(f"{t}:{f:.1f}" for t, f in curve))
    return best[0], curve


def quick(name=None):
    if name is None:
        p = RESULTS / "experiment_A.json"
        name = json.load(open(p))["selected"] if p.exists() else "LogReg + char, C=10"
    c = next((c for c in CONFIGS if c["name"] == name), None)
    if c is None:
        raise SystemExit(f"unknown model {name!r}")
    X, y, g, tpl = load_split("train")
    model = fit(c, np.array(prep(X, c["tags"]), dtype=object), np.array(y), np.array(tpl))
    min_prob, _ = tune_topic_threshold(c, X, np.array(y), np.array(tpl), group_folds(g))
    MODELS.mkdir(exist_ok=True)
    joblib.dump({"pipeline": model, "with_tags": c["tags"], "name": c["name"], "labels": LABELS,
                 "topic_min_prob": min_prob}, MODELS / "classifier.joblib")
    for split in TEST_SPLITS:
        tx, ty, _, _ = load_split(split)
        if tx:
            print(f"{split:16s} macro-F1 {scores(ty, model.predict(prep(tx, c['tags'])))['macro_f1']:.1f}")
    print(f"retrained {c['name']} on {len(X)} messages (quick mode; results/experiment_A.md not rewritten)")


def write_report(rows, selected, per_class, n_train, n_chats, n_tests, curve):
    splits = [s for s in TEST_SPLITS if s in n_tests]
    L = ["# Experiment A - message classification", "",
         f"Training data: {n_train} messages from {n_chats} chats. Test messages: " +
         ", ".join(f"{k} {v}" for k, v in n_tests.items()) + ".", "",
         "Macro-F1 (%) - every class counts equally, so the frequent DECISION/OTHER classes cannot hide weak ones.", "",
         "Model selection uses only the training chats (5-fold GroupKFold). *CV-hand* = macro-F1 on the",
         "hand-written training chats when they are in the validation fold; the model is chosen by CV-hand.", "",
         "*CV-public* = macro-F1 (over the 4 labels that exist there) on the public training chats when they are in",
         "the validation fold. With public data the model is chosen by the mean of CV-hand and CV-public.",
         "For test_public / test_offtopic use the accuracy table: they only contain 4 / 1 of the 9 labels.", "",
         "| Model | CV (all) | CV-hand | CV-public | " + " | ".join(splits) + " |",
         "|---|---|---|---|" + "---|" * len(splits)]
    for r in rows:
        mark = " **(selected)**" if r["model"] == selected else ""
        L.append(f"| {r['model']}{mark} | {r['cv_macro_f1']:.1f} ± {r['cv_std']:.1f} | {r['cv_hand']:.1f} | " +
                 (f"{r['cv_public']:.1f} | " if r.get("cv_public") is not None else "- | ") +
                 " | ".join(f"{r[s]['macro_f1']:.1f}" for s in splits) + " |")
    L += ["", "Accuracy (%):", "", "| Model | " + " | ".join(splits) + " |", "|---|" + "---|" * len(splits)]
    for r in rows:
        L.append(f"| {r['model']} | " + " | ".join(f"{r[s]['accuracy']:.1f}" for s in splits) + " |")
    L += ["", "## Learning curve (selected model, CV-hand)", "",
          "Templates always included; only the number of hand-written training chats changes.", "",
          "| Hand-written chats | CV-hand macro-F1 |", "|---|---|"]
    L += [f"| {p['hand_chats']} | {p['cv_hand']:.1f} |" for p in curve]
    for s in splits:
        rep = per_class[s]
        L += ["", f"## Selected model per class - {s}", "", "| Class | Precision | Recall | F1 | Support |", "|---|---|---|---|---|"]
        for lab in LABELS:
            c = rep[lab]
            L.append(f"| {lab} | {100 * c['precision']:.1f} | {100 * c['recall']:.1f} | {100 * c['f1-score']:.1f} | {int(c['support'])} |")
    (RESULTS / "experiment_A.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"wrote {RESULTS / 'experiment_A.md'}")


if __name__ == "__main__":
    main()
