// In-memory stand-in for firebase-admin's Firestore, just big enough for the
// four Voya Cloud Functions. Every write is recorded in `db.writes` so a test
// can prove what a function did (or did not) change.
//
// Usage: const db = createFakeDb({ "trips/t1": {...}, "trips/t1/messages/m1": {...} });

class DocSnap {
  constructor(id, path, data, ref) {
    this.id = id;
    this.ref = ref;
    this._data = data;
    this.exists = data !== undefined;
  }
  data() { return this._data === undefined ? undefined : JSON.parse(JSON.stringify(this._data)); }
  get(field) {
    if (this._data === undefined) return undefined;
    return field.split(".").reduce((o, k) => (o == null ? undefined : o[k]), this._data);
  }
}

function matches(data, [field, op, value]) {
  const v = field.split(".").reduce((o, k) => (o == null ? undefined : o[k]), data);
  switch (op) {
    case "==": return v === value;
    case "!=": return v !== value;
    case "in": return value.includes(v);
    case "array-contains": return Array.isArray(v) && v.includes(value);
    case "array-contains-any": return Array.isArray(v) && v.some((x) => value.includes(x));
    case ">=": return v >= value;
    case "<=": return v <= value;
    case ">": return v > value;
    case "<": return v < value;
    default: throw new Error(`fake Firestore: unsupported operator ${op}`);
  }
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([k, v]) => [k, JSON.parse(JSON.stringify(v))]));
  const writes = [];

  const applyWrite = (kind, path, data, opts = {}) => {
    writes.push({ kind, path, data });
    if (kind === "delete") { store.delete(path); return; }
    if (kind === "set" && !opts.merge) { store.set(path, JSON.parse(JSON.stringify(data))); return; }
    const current = store.get(path) || {};
    for (const [k, v] of Object.entries(data)) {
      const parts = k.split(".");
      let o = current;
      for (const p of parts.slice(0, -1)) { o[p] = o[p] && typeof o[p] === "object" ? o[p] : {}; o = o[p]; }
      o[parts[parts.length - 1]] = v;
    }
    store.set(path, current);
  };

  const docRef = (path) => {
    const id = path.split("/").pop();
    const ref = {
      id, path,
      get: async () => new DocSnap(id, path, store.get(path), ref),
      set: async (data, opts) => applyWrite("set", path, data, opts),
      update: async (data) => {
        if (!store.has(path)) { const e = new Error("not-found"); e.code = 5; throw e; }
        applyWrite("update", path, data);
      },
      delete: async () => applyWrite("delete", path),
      collection: (sub) => collRef(`${path}/${sub}`),
    };
    return ref;
  };

  const query = (path, filters = [], order = null, max = null) => ({
    where: (f, op, v) => query(path, [...filters, [f, op, v]], order, max),
    orderBy: (field, dir = "asc") => query(path, filters, { field, dir }, max),
    limit: (n) => query(path, filters, order, n),
    get: async () => {
      const depth = path.split("/").length + 1;
      let rows = [...store.entries()]
        .filter(([k]) => k.startsWith(`${path}/`) && k.split("/").length === depth)
        .filter(([, d]) => filters.every((f) => matches(d, f)));
      if (order) {
        rows.sort(([, a], [, b]) => {
          const x = a[order.field]; const y = b[order.field];
          const c = x < y ? -1 : x > y ? 1 : 0;
          return order.dir === "desc" ? -c : c;
        });
      }
      if (max != null) rows = rows.slice(0, max);
      const docs = rows.map(([k, d]) => new DocSnap(k.split("/").pop(), k, d, docRef(k)));
      return { docs, size: docs.length, empty: docs.length === 0 };
    },
  });

  const collRef = (path) => ({
    ...query(path),
    doc: (id) => docRef(`${path}/${id || `auto_${Math.random().toString(36).slice(2, 10)}`}`),
    add: async (data) => { const r = docRef(`${path}/auto_${Math.random().toString(36).slice(2, 10)}`); await r.set(data); return r; },
  });

  return {
    writes,
    store,
    collection: (name) => collRef(name),
    doc: (path) => docRef(path),
    batch: () => {
      const ops = [];
      return {
        set: (ref, data, opts) => ops.push(["set", ref.path, data, opts]),
        update: (ref, data) => ops.push(["update", ref.path, data]),
        delete: (ref) => ops.push(["delete", ref.path]),
        commit: async () => ops.forEach(([k, p, d, o]) => applyWrite(k, p, d, o)),
      };
    },
    runTransaction: async (fn) => fn({
      get: (ref) => ref.get(),
      set: (ref, data, opts) => applyWrite("set", ref.path, data, opts),
      update: (ref, data) => applyWrite("update", ref.path, data),
    }),
  };
}

module.exports = { createFakeDb };
