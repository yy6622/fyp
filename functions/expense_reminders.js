const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

if (getApps().length === 0) initializeApp();

const REMINDER_INTERVAL_MS = 5 * 24 * 60 * 60 * 1000;
const MAX_AUTO_REMINDERS = 3;

function labelFor(data) {
  if (data.title && data.title.trim()) return data.title.trim();
  if (data.note && data.note.trim()) return data.note.trim();
  return data.category || "expense";
}

async function runRemindUnpaidExpenses() {
  const db = getFirestore();
  const now = Date.now();
  const snap = await db.collectionGroup("expenses").get();

  for (const doc of snap.docs) {
    const data = doc.data();
    const participants = data.participants || {};
    const unpaid = Object.entries(participants).filter(([uid, p]) => uid !== data.paidBy && !p.paid);
    if (unpaid.length === 0) continue;

    const count = data.autoReminderCount || 0;
    if (count >= MAX_AUTO_REMINDERS) continue;

    const lastAt = data.lastAutoReminderAt
      ? data.lastAutoReminderAt.toMillis()
      : (data.createdAt ? data.createdAt.toMillis() : 0);
    if (now - lastAt < REMINDER_INTERVAL_MS) continue;

    const batch = db.batch();
    for (const [uid, p] of unpaid) {
      const ref = db.collection("users").doc(uid).collection("notifications").doc();
      batch.set(ref, {
        type: "trip_expense_payment_reminder",
        title: "Payment reminder",
        body: `${data.paidByName} reminds you to pay your RM ${Number(p.share || 0).toFixed(2)} share for "${labelFor(data)}".`,
        data: { tripId: data.tripId, expenseId: doc.id },
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    batch.update(doc.ref, {
      autoReminderCount: count + 1,
      lastAutoReminderAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

exports.remindUnpaidExpenses = onSchedule("every day 10:00", runRemindUnpaidExpenses);
exports._runRemindUnpaidExpenses = runRemindUnpaidExpenses;
