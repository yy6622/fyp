// Helpers for the web-console tests: talk to the local Firebase emulators
// directly (admin rights via "Bearer owner"), to set up and inspect data.
const PROJECT = process.env.FIREBASE_PROJECT || "voya-f69f0";
const HOST = process.env.EMULATOR_HOST || "127.0.0.1";
const DOCS = `http://${HOST}:8085/v1/projects/${PROJECT}/databases/(default)/documents`;
const OWNER = { Authorization: "Bearer owner", "Content-Type": "application/json" };

function encode(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === "string") return { stringValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)])) } };
}

function decode(v) {
  if ("nullValue" in v) return null;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("stringValue" in v) return v.stringValue;
  if ("timestampValue" in v) return new Date(v.timestampValue);
  if ("arrayValue" in v) return (v.arrayValue.values || []).map(decode);
  if ("mapValue" in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, decode(x)]));
  return undefined;
}

async function reset() {
  await fetch(`http://${HOST}:8085/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: "DELETE" });
  await fetch(`http://${HOST}:9099/emulator/v1/projects/${PROJECT}/accounts`, { method: "DELETE" });
}

async function createAuthUser(email, password) {
  const res = await fetch(
    `http://${HOST}:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key`,
    { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, password, returnSecureToken: true }) },
  );
  const body = await res.json();
  if (!body.localId) throw new Error(`createAuthUser failed: ${JSON.stringify(body)}`);
  return body.localId;
}

async function setDoc(path, data) {
  const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, encode(v)]));
  const res = await fetch(`${DOCS}/${path}`, { method: "PATCH", headers: OWNER, body: JSON.stringify({ fields }) });
  if (!res.ok) throw new Error(`setDoc ${path}: ${res.status} ${await res.text()}`);
}

async function getDoc(path) {
  const res = await fetch(`${DOCS}/${path}`, { headers: OWNER });
  if (res.status === 404) return null;
  const body = await res.json();
  return Object.fromEntries(Object.entries(body.fields || {}).map(([k, v]) => [k, decode(v)]));
}

module.exports = { reset, createAuthUser, setDoc, getDoc };
