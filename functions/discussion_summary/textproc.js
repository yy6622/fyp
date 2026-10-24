// Port of ml/discussion_summary/features.py - keep the two identical.
// (Checked by ml/discussion_summary/test_parity.py.)

const URL_RE = /https?:\/\/[^ ]+/gu;
const SPACE_RE = /\s+/gu;

const MONEY_RE = new RegExp(
  "(rm|myr|usd|sgd|\\$|¥|￥|rmb)[ ]?[0-9][0-9,.]*k?" +
  "|[0-9][0-9,.]*[ ]?(k|rm|myr|ringgit|块|元|千|万)(?![a-z])" +
  "|[一二两三四五六七八九十][千万]", "u");
const MONTHS = "jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec|januari|februari|mac|april|mei|julai|ogos|oktober|disember";
const DATE_RE = new RegExp(
  "[0-9]{1,2}[ ]?(-|to|hingga|until|till)[ ]?[0-9]{1,2}[ ]?(" + MONTHS + ")" +
  "|(" + MONTHS + ")[a-z]*[ ][0-9]{1,2}" +
  "|[0-9]{1,2}[ ]?(" + MONTHS + ")(?![a-z])" +
  "|(early|mid|end|awal|hujung|pertengahan)[ ](of[ ])?(" + MONTHS + ")" +
  "|[0-9]{1,2}月[0-9一二三四五六七八九十]{0,3}[号日初中底]?" +
  "|[0-9]+[ ]?(d|days?|hari)[ ]?[0-9]*[ ]?(n|nights?|malam)?(?![a-z])" +
  "|(school holiday|cuti sekolah|weekend|long weekend|public holiday|假期|周末)", "u");
const QUESTION_RE = /[?？]|(^| )(how about|what about|apa kata|nak tak|boleh tak|ok tak)( |$)|要不要|怎么样|好不好|吗/u;

/** Lower-case, NFKC (full-width -> half-width), URLs out, spaces collapsed. */
function normalize(text) {
  const t = String(text).normalize("NFKC").toLowerCase().replace(URL_RE, " ");
  return t.replace(SPACE_RE, " ").trim();
}

function tags(norm) {
  const out = [];
  if (MONEY_RE.test(norm)) out.push("zzmoney");
  if (DATE_RE.test(norm)) out.push("zzdate");
  if (QUESTION_RE.test(norm)) out.push("zzquestion");
  return out;
}

/** The exact string the vectoriser sees. */
function prepare(text, withTags = true) {
  let t = normalize(text);
  if (withTags) {
    const tg = tags(t);
    if (tg.length) t = t + " " + tg.join(" ");
  }
  return t;
}

module.exports = { normalize, tags, prepare, MONEY_RE, DATE_RE, QUESTION_RE };
