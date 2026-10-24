"""Experiment A3 - does training on public, human-written datasets help?

The selected classifier (results/experiment_A.json) is trained with different amounts of
the public data from import_public_datasets.py and scored on every test split:

  CV-hand          5-fold CV on our hand-written training chats (group chats, the target style)
  challenge(2)     macro-F1 on the hand-written test chats
  smalltalk        % of the 126 small-talk messages labelled OTHER
  public           MultiWOZ + CrossWOZ test user turns (real people, other style): accuracy and
                   macro-F1 over the four labels that exist there
  offtopic         % of DialogSum everyday-chat test messages labelled OTHER

Writes results/experiment_public.md / .json.  Run after build_dataset.py.
"""

import json

import numpy as np
from sklearn.metrics import accuracy_score, f1_score

from common import LABELS, RESULTS
from train_classifier import CONFIGS, group_folds, load_split, make, prep

PUBLIC_LABELS = ["ATTRACTION", "ACCOMMODATION", "TRANSPORT", "OTHER"]


def load_train():
    from common import DATA, read_jsonl
    X, y, g, src = [], [], [], []
    for c in read_jsonl(DATA / "splits" / "train.jsonl"):
        kind = c["source"]
        if kind == "public":
            kind = "public-" + c["conv_id"].split("-")[0]       # mwoz / cwoz / dsum
        for m in c["messages"]:
            X.append(m["text"]); y.append(m["label"]); g.append(c["conv_id"]); src.append(kind)
    return X, np.array(y), g, np.array(src)


VARIANTS = [
    # name, which public sources are used, weight of a public message
    ("No public data (before)", set(), 0.0),
    ("+ all public, weight 1", {"public-mwoz", "public-cwoz", "public-dsum"}, 1.0),
    ("+ all public, weight 0.5", {"public-mwoz", "public-cwoz", "public-dsum"}, 0.5),
    ("+ all public, weight 0.3", {"public-mwoz", "public-cwoz", "public-dsum"}, 0.3),
    ("+ DialogSum only (chit-chat), weight 1", {"public-dsum"}, 1.0),
    ("+ MultiWOZ + CrossWOZ only, weight 1", {"public-mwoz", "public-cwoz"}, 1.0),
]


def main():
    sel = json.load(open(RESULTS / "experiment_A.json"))["selected"]
    c = next(x for x in CONFIGS if x["name"] == sel)
    X, y, g, src = load_train()
    Xp = np.array(prep(X, c["tags"]), dtype=object)
    hand = src == "manual"
    tests = {n: load_split(n) for n in ["test_challenge", "test_challenge2", "test_smalltalk", "test_public", "test_offtopic"]}
    tests = {k: (prep(v[0], c["tags"]), v[1]) for k, v in tests.items() if v[0]}
    folds = group_folds(g)
    print(f"model: {sel}; train messages by source: " +
          ", ".join(f"{s} {int((src == s).sum())}" for s in sorted(set(src))))

    def weights(keep, wpub):
        w = np.where(src == "manual", c["w"], 1.0)
        pub = np.char.startswith(src.astype(str), "public")
        w = np.where(pub, wpub, w)
        return w, (~pub) | np.isin(src, list(keep))

    rows = []
    for name, keep, wpub in VARIANTS:
        w, use = weights(keep, wpub)
        oof = np.empty(len(y), dtype=object)
        for tr, va in folds:
            tr = tr[use[tr]]
            oof[va] = make(c, y[tr]).fit(Xp[tr], y[tr], clf__sample_weight=w[tr]).predict(Xp[va])
        row = {"variant": name, "train_messages": int(use.sum()),
               "cv_hand": 100 * f1_score(y[hand], oof[hand], labels=LABELS, average="macro", zero_division=0)}
        # CV-public: out-of-fold macro-F1 on the public training chats. Always computed on ALL of
        # them, also when a variant does not train on them, so variants can be compared.
        pub = np.char.startswith(src.astype(str), "public")
        if not use[pub].all():
            for tr, va in folds:
                tr = tr[use[tr]]
                va = va[~use[va]]
                if len(va):
                    oof[va] = make(c, y[tr]).fit(Xp[tr], y[tr], clf__sample_weight=w[tr]).predict(Xp[va])
        row["cv_public"] = 100 * f1_score(y[pub], oof[pub], labels=PUBLIC_LABELS, average="macro", zero_division=0)
        row["select_score"] = (row["cv_hand"] + row["cv_public"]) / 2
        m = make(c, y[use]).fit(Xp[use], y[use], clf__sample_weight=w[use])
        for split, (tx, ty) in tests.items():
            p = m.predict(tx)
            if split in ("test_challenge", "test_challenge2"):
                row[split] = 100 * f1_score(ty, p, labels=LABELS, average="macro", zero_division=0)
            elif split == "test_public":
                row["public_acc"] = 100 * accuracy_score(ty, p)
                row["public_f1"] = 100 * f1_score(ty, p, labels=PUBLIC_LABELS, average="macro", zero_division=0)
            else:
                row[split] = 100 * accuracy_score(ty, p)
        rows.append(row)
        print(f"{name:42s} n={row['train_messages']:6d} CV-hand {row['cv_hand']:.1f} CV-public {row['cv_public']:.1f}  ch {row.get('test_challenge', 0):.1f}  "
              f"ch2 {row.get('test_challenge2', 0):.1f}  smalltalk {row.get('test_smalltalk', 0):.1f}  "
              f"public acc {row.get('public_acc', 0):.1f} F1 {row.get('public_f1', 0):.1f}  offtopic {row.get('test_offtopic', 0):.1f}")
    best = max(rows, key=lambda r: r["select_score"])
    print(f"selected (best mean of CV-hand and CV-public, no test set used): {best['variant']}")
    json.dump({"model": sel, "rows": rows, "selected": best["variant"]}, open(RESULTS / "experiment_public.json", "w"), indent=1)
    L = ["# Experiment A3 - adding public human-written datasets", "",
         f"Model: {sel}. Public data: MultiWOZ 2.2 (English), CrossWOZ (Chinese), DialogSum (English chit-chat), "
         "converted by import_public_datasets.py.", "",
         "Selection uses only cross-validation on the training data: the variant with the best mean of CV-hand "
         "(our hand-written group chats) and CV-public (the public training chats) is chosen. "
         f"Selected: **{best['variant']}**.", "",
         "| Training data | Messages | CV-hand F1 | CV-public F1 | challenge F1 | challenge2 F1 | small talk → OTHER % | "
         "public test acc | public test F1 | off-topic → OTHER % |", "|---|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        L.append(f"| {r['variant']} | {r['train_messages']} | {r['cv_hand']:.1f} | {r['cv_public']:.1f} | {r.get('test_challenge', 0):.1f} | "
                 f"{r.get('test_challenge2', 0):.1f} | {r.get('test_smalltalk', 0):.1f} | {r.get('public_acc', 0):.1f} | "
                 f"{r.get('public_f1', 0):.1f} | {r.get('test_offtopic', 0):.1f} |")
    (RESULTS / "experiment_public.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"wrote {RESULTS / 'experiment_public.md'}")


if __name__ == "__main__":
    main()
