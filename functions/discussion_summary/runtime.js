// Port of ml/discussion_summary/model_runtime.py: TF-IDF (char_wb n-grams) +
// linear classifier, loaded from model.json (exported by export_model.py).

const { prepare } = require("./textproc");

class TextModel {
  constructor(params) {
    this.labels = params.labels;
    this.withTags = params.with_tags;
    [this.minN, this.maxN] = params.ngram_range;
    this.sublinear = params.sublinear_tf;
    this.vocab = new Map(Object.entries(params.vocab));
    this.idf = params.idf;
    this.coef = params.coef;
    this.intercept = params.intercept;
    this.topicMinProb = params.topic_min_prob || 0;
  }

  /** sklearn analyzer='char_wb': n-grams inside space-padded words (code points). */
  ngrams(text) {
    const out = [];
    for (const raw of text.split(" ")) {
      if (!raw) continue;
      const w = " " + raw + " ";
      const chars = Array.from(w);
      const L = chars.length;
      for (let n = this.minN; n <= this.maxN; n++) {
        if (L <= n) { out.push(w); break; }
        for (let i = 0; i <= L - n; i++) out.push(chars.slice(i, i + n).join(""));
      }
    }
    return out;
  }

  /** L2-normalised TF-IDF vector as Map(featureIndex -> weight), in first-seen order. */
  vector(text) {
    const counts = new Map();
    for (const g of this.ngrams(prepare(text, this.withTags))) {
      const j = this.vocab.get(g);
      if (j !== undefined) counts.set(j, (counts.get(j) || 0) + 1);
    }
    const vec = new Map();
    for (const [j, c] of counts) {
      const tf = this.sublinear ? 1 + Math.log(c) : c;
      vec.set(j, tf * this.idf[j]);
    }
    let sq = 0;
    for (const v of vec.values()) sq += v * v;
    const norm = Math.sqrt(sq);
    if (norm > 0) for (const [j, v] of vec) vec.set(j, v / norm);
    return vec;
  }

  scores(vec) {
    return this.coef.map((row, k) => {
      let s = 0;
      for (const [j, v] of vec) s += row[j] * v;
      return this.intercept[k] + s;
    });
  }

  predict(text) {
    const vec = this.vector(text);
    const s = this.scores(vec);
    let best = 0;
    for (let k = 1; k < s.length; k++) if (s[k] > s[best]) best = k;
    return [this.labels[best], s, vec];
  }
}

/** Probability of the best class (LogReg: softmax of the decision scores). */
function softmaxTop(scores) {
  const top = Math.max(...scores);
  let total = 0;
  for (const s of scores) total += Math.exp(s - top);
  return 1 / total;
}

/** Both vectors are already L2-normalised. */
function cosine(a, b) {
  if (a.size > b.size) [a, b] = [b, a];
  let s = 0;
  for (const [j, v] of a) s += v * (b.get(j) || 0);
  return s;
}

module.exports = { TextModel, cosine, softmaxTop };
