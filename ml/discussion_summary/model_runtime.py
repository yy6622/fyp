"""Dependency-free inference for the exported classifier (models/model.json).

The same ~60 lines exist in JavaScript (functions/discussion_summary/runtime.js),
so the Cloud Function gives exactly the predictions measured here.
export_model.py checks this runtime against the sklearn pipeline.
"""

import json
import math

from features import prepare


class TextModel:
    def __init__(self, params):
        self.labels = params["labels"]
        self.with_tags = params["with_tags"]
        self.min_n, self.max_n = params["ngram_range"]
        self.sublinear = params["sublinear_tf"]
        self.vocab = params["vocab"]
        self.idf = params["idf"]
        self.coef = params["coef"]          # [class][feature]
        self.intercept = params["intercept"]
        self.topic_min_prob = params.get("topic_min_prob", 0.0)

    @classmethod
    def load(cls, path):
        with open(path, encoding="utf-8") as f:
            return cls(json.load(f))

    def ngrams(self, text):
        """sklearn's analyzer='char_wb': n-grams inside space-padded words."""
        out = []
        for w in text.split(" "):
            if not w:
                continue
            w = " " + w + " "
            chars = list(w)
            L = len(chars)
            for n in range(self.min_n, self.max_n + 1):
                if L <= n:
                    # sklearn emits the whole (short) padded word once, then stops
                    out.append(w)
                    break
                for i in range(0, L - n + 1):
                    out.append("".join(chars[i:i + n]))
        return out

    def vector(self, text):
        """L2-normalised TF-IDF vector as {feature_index: weight}."""
        counts = {}
        for g in self.ngrams(prepare(text, self.with_tags)):
            j = self.vocab.get(g)
            if j is not None:
                counts[j] = counts.get(j, 0) + 1
        vec = {}
        for j, c in counts.items():
            tf = 1 + math.log(c) if self.sublinear else c
            vec[j] = tf * self.idf[j]
        norm = math.sqrt(sum(v * v for v in vec.values()))
        if norm > 0:
            for j in vec:
                vec[j] /= norm
        return vec

    def scores(self, vec):
        return [self.intercept[k] + sum(row[j] * v for j, v in vec.items()) for k, row in enumerate(self.coef)]

    def predict(self, text):
        vec = self.vector(text)
        s = self.scores(vec)
        best = max(range(len(s)), key=lambda k: s[k])
        return self.labels[best], s, vec


def softmax_top(scores):
    """Probability of the best class (LogReg: softmax of the decision scores)."""
    top = max(scores)
    total = sum(math.exp(s - top) for s in scores)
    return 1.0 / total


def cosine(a, b):
    """Both vectors are already L2-normalised."""
    if len(a) > len(b):
        a, b = b, a
    return sum(v * b.get(j, 0.0) for j, v in a.items())
