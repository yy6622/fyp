// Deletes read notifications older than 30 days (users/{uid}/notifications).
// Unread notifications are never touched here, however old — only ones the
// traveller has actually seen (read: true) age out, so nothing unread
// disappears on them silently.
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

if (getApps().length === 0) initializeApp();

const RETENTION_MS = 30 * 24 * 60 * 60 * 1000;

async function runCleanupReadNotifications() {
  const db = getFirestore();
  const now = Date.now();
  // Filtered in-memory on purpose (like remindUnpaidExpenses) so this needs
  // no composite collection-group index.
  const snap = await db.collectionGroup("notifications").where("read", "==", true).get();

  const stale = snap.docs.filter((doc) => {
    const data = doc.data();
    const at = data.readAt || data.createdAt;
    const ms = at && typeof at.toMillis === "function" ? at.toMillis() : null;
    return ms !== null && now - ms > RETENTION_MS;
  });

  for (let i = 0; i < stale.length; i += 450) {
    const batch = db.batch();
    for (const doc of stale.slice(i, i + 450)) batch.delete(doc.ref);
    await batch.commit();
  }
  return { checked: snap.docs.length, deleted: stale.length };
}

// Runs once a day. A notification only gets auto-deleted once it has been
// read AND it's been 30+ days since it was read (readAt), falling back to
// createdAt for older notifications marked read before readAt existed.
exports.cleanupReadNotifications = onSchedule("every day 03:00", async () => {
  const result = await runCleanupReadNotifications();
  console.log(`cleanupReadNotifications: checked ${result.checked}, deleted ${result.deleted}`);
});
exports._runCleanupReadNotifications = runCleanupReadNotifications;
