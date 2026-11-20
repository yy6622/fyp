/**
 * One-off migration for an existing large catalog_attractions collection.
 * Populate normalized lookup fields required by the new paginated admin UI.
 *
 * Usage (from admin_web/scripts):
 *   npm install firebase-admin (once, from admin_web/scripts)
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/your-service-account.json
 *   node backfill-attraction-indexes.mjs --dry-run
 *   node backfill-attraction-indexes.mjs
 *
 * Requires a privileged local/CI account; do NOT expose service-account keys
 * to the browser or commit them to the repo. Back up Firestore first.
 */
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldPath, FieldValue } from 'firebase-admin/firestore';

const dryRun = process.argv.includes('--dry-run');
initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const normalize = (value) => String(value || '').normalize('NFKC').trim().toLowerCase().replace(/\s+/g, ' ');
const collection = db.collection('catalog_attractions');
const pageSize = 300;
let cursor = null;
let scanned = 0;
let updated = 0;
const countries = new Set();
const categories = new Set();
const writer = db.bulkWriter();
writer.onWriteError((error) => {
  console.error(`Write failed for ${error.documentRef.path}: ${error.message}`);
  return error.failedAttempts < 3;
});

while (true) {
  let q = collection.orderBy(FieldPath.documentId()).limit(pageSize);
  if (cursor) q = q.startAfter(cursor);
  const snapshot = await q.get();
  if (snapshot.empty) break;
  for (const doc of snapshot.docs) {
    scanned++;
    const data = doc.data();
    const location = String(data.location || '');
    const country = location.split(',').map((s) => s.trim()).filter(Boolean).pop() || '';
    if (country) countries.add(country);
    if (data.category) categories.add(String(data.category));
    const fields = {
      nameNormalized: normalize(data.name),
      locationNormalized: normalize(location),
      countryKey: normalize(country),
      destinationQuery: normalize(location),
      status: data.status || 'active',
      // Sorting by updatedAt excludes documents missing this field.
      updatedAt: data.updatedAt || data.createdAt || FieldValue.serverTimestamp(),
    };
    const changes = Object.fromEntries(Object.entries(fields).filter(([key, value]) =>
      key === 'updatedAt' ? !data.updatedAt : data[key] !== value));
    if (Object.keys(changes).length) {
      updated++;
      if (!dryRun) writer.update(doc.ref, changes);
    }
  }
  cursor = snapshot.docs[snapshot.docs.length - 1];
  console.log(`Scanned ${scanned}, ${dryRun ? 'would update' : 'queued'} ${updated}`);
}
if (!dryRun) {
  await writer.close();
  // A compact dropdown-options document for the admin UI.
  await db.collection('catalog_meta').doc('attractions').set({
    countries: [...countries].sort(),
    categories: [...categories].sort(),
    indexedAt: FieldValue.serverTimestamp(),
  });
} else {
  await writer.close();
}
console.log(`${dryRun ? 'DRY RUN: ' : ''}${scanned} scanned, ${updated} to update. Countries: ${countries.size}; categories: ${categories.size}`);
