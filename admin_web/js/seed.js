// Voya — demo-data dev tool (same idea as the Flutter app's
// lib/services/dev_seed_service.dart: fills the screens that the mobile
// app doesn't generate data for yet — claims, transactions, plans, partner
// orgs, reported content — so the console is demoable without waiting on
// real activity). Every doc it writes is tagged isDemoSeed: true so it can
// be told apart / cleared later.
import { db } from "./firebase-config.js";
import {
  collection, doc, getDocs, addDoc, updateDoc, deleteDoc, query, where, limit, serverTimestamp,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";
import { newClaimRef, newTxnRef } from "./data.js";

const PROVIDERS = ["AIA", "Prudential", "Great Eastern", "Allianz Travel", "AIG Travel Guard"];
const NAMES = ["Ahmad Farhan", "Siti Aisyah", "M. Iqbal", "Chan Mei Ling", "Tan Ah Bu", "Nurul Aisyah", "Muhammad Faiz", "Lim Wei Sheng", "Rizal Hakim"];
const PLAN_NAMES = ["Travel Care Premium", "Annual Explorer", "Family Essential", "Adventure Plus", "Health Shield Gold", "Critical Care"];
const DESTINATIONS = [
  { location: "Tokyo, Japan", category: "Landmark" },
  { location: "Osaka, Japan", category: "Cultural" },
  { location: "Beijing, China", category: "Heritage" },
  { location: "Hokkaido, Japan", category: "Nature" },
  { location: "Jakarta, Indonesia", category: "Museum" },
];
const CHANNELS = ["Mobile App", "Web", "Partner Referral", "Travel Agent", "Walk-in"];

const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

async function isEmpty(collectionName, extraWhere = null) {
  const col = collection(db, collectionName);
  const q = extraWhere ? query(col, extraWhere, limit(1)) : query(col, limit(1));
  const snap = await getDocs(q);
  return snap.empty;
}

/** Run from the Admin console: fills platform-wide demo data. */
export async function seedAdminDemoData(partners = []) {
  const notes = [];
  const providerFor = (i) =>
    partners.length ? partners[i % partners.length] : { id: "demo", companyName: PROVIDERS[i % PROVIDERS.length] };

  // Transactions
  if (await isEmpty("insurance_transactions")) {
    for (let i = 0; i < 10; i++) {
      const p = providerFor(i);
      await addDoc(collection(db, "insurance_transactions"), {
        txnRef: newTxnRef(),
        partnerId: p.id,
        providerName: p.companyName,
        customerName: pick(NAMES),
        customerEmail: `${pick(NAMES).toLowerCase().replace(/\s+/g, "")}@example.com`,
        premium: rand(80, 2200),
        status: pick(["paid", "paid", "paid", "pending", "rejected"]),
        destination: pick(DESTINATIONS).location,
        channel: pick(CHANNELS),
        createdAt: serverTimestamp(),
        isDemoSeed: true,
      });
    }
    notes.push("10 sample insurance transactions");
  }

  // Plans
  if (await isEmpty("insurance_plans")) {
    for (let i = 0; i < 6; i++) {
      const p = providerFor(i);
      await addDoc(collection(db, "insurance_plans"), {
        partnerId: p.id,
        providerName: p.companyName,
        name: PLAN_NAMES[i % PLAN_NAMES.length],
        tripType: pick(["Single Trip", "Annual", "Family"]),
        coverage: pick([10000, 50000, 100000, 250000]),
        premium: rand(80, 480),
        status: i === 5 ? "draft" : "active",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        isDemoSeed: true,
      });
    }
    notes.push("6 sample insurance plans");
  }

  // Claims
  if (await isEmpty("claims")) {
    const statuses = ["new", "under_review", "under_review", "approved", "approved", "rejected"];
    for (let i = 0; i < 8; i++) {
      const p = providerFor(i);
      const status = statuses[i % statuses.length];
      await addDoc(collection(db, "claims"), {
        claimRef: newClaimRef(),
        partnerId: p.id,
        providerName: p.companyName,
        policyholderName: pick(NAMES),
        policyholderEmail: `${pick(NAMES).toLowerCase().replace(/\s+/g, "")}@gmail.com`,
        planName: pick(PLAN_NAMES),
        amount: rand(400, 13000),
        category: pick(["Medical", "Trip Cancellation", "Baggage Loss", "Flight Delay"]),
        documents: ["Medical Report.pdf", "Hospital Bill.pdf"],
        assignee: { name: "Alex Lee", role: "Claims Officer" },
        status,
        timeline: [
          { status: "new", at: new Date(Date.now() - 86400000 * 3).toISOString(), note: "Claim submitted" },
          ...(status !== "new" ? [{ status: "under_review", at: new Date(Date.now() - 86400000 * 2).toISOString(), note: "Assigned for review" }] : []),
          ...(status === "approved" || status === "rejected"
            ? [{ status, at: new Date(Date.now() - 86400000).toISOString(), note: status === "approved" ? "Approved for payout" : "Documents insufficient" }]
            : []),
        ],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        isDemoSeed: true,
      });
    }
    notes.push("8 sample claims");
  }

  // Flag a couple of real community posts as reported, if there are any
  // unreported ones — so Content Moderation has something to review.
  const postsSnap = await getDocs(query(collection(db, "posts"), limit(6)));
  const candidates = postsSnap.docs.filter((d) => !d.data().reported);
  if (candidates.length) {
    for (const d of candidates.slice(0, 2)) {
      await updateDoc(doc(db, "posts", d.id), {
        reported: true,
        reportReason: pick(["Misleading information", "Inappropriate content", "Spam"]),
        reportedBy: pick(NAMES),
        reportedAt: serverTimestamp(),
      });
    }
    notes.push(`${Math.min(2, candidates.length)} community post(s) flagged for review`);
  }

  // Backfill status/updatedAt on attractions that predate those fields.
  const attractionsSnap = await getDocs(collection(db, "catalog_attractions"));
  let backfilled = 0;
  for (const d of attractionsSnap.docs) {
    if (!d.data().status) {
      await updateDoc(doc(db, "catalog_attractions", d.id), { status: "active", updatedAt: serverTimestamp() });
      backfilled++;
    }
  }
  if (backfilled) notes.push(`${backfilled} attraction(s) backfilled with a status`);

  return notes.length ? notes : ["Nothing to seed — demo data already present."];
}

/** Run from a Partner console: fills demo data scoped to just this partner. */
export async function seedPartnerDemoData(partnerId, providerName) {
  const notes = [];
  if (await isEmpty("insurance_plans", where("partnerId", "==", partnerId))) {
    for (let i = 0; i < 4; i++) {
      await addDoc(collection(db, "insurance_plans"), {
        partnerId, providerName,
        name: PLAN_NAMES[i % PLAN_NAMES.length],
        tripType: pick(["Single Trip", "Annual", "Family"]),
        coverage: pick([10000, 50000, 100000, 250000]),
        premium: rand(80, 480),
        status: i === 3 ? "draft" : "active",
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(), isDemoSeed: true,
      });
    }
    notes.push("4 sample plans");
  }
  if (await isEmpty("insurance_transactions", where("partnerId", "==", partnerId))) {
    for (let i = 0; i < 6; i++) {
      await addDoc(collection(db, "insurance_transactions"), {
        txnRef: newTxnRef(), partnerId, providerName,
        customerName: pick(NAMES),
        customerEmail: `${pick(NAMES).toLowerCase().replace(/\s+/g, "")}@example.com`,
        premium: rand(80, 2200),
        status: pick(["paid", "paid", "pending", "rejected"]),
        destination: pick(DESTINATIONS).location,
        channel: pick(CHANNELS),
        createdAt: serverTimestamp(), isDemoSeed: true,
      });
    }
    notes.push("6 sample transactions");
  }
  if (await isEmpty("claims", where("partnerId", "==", partnerId))) {
    const statuses = ["new", "under_review", "approved", "rejected"];
    for (let i = 0; i < 5; i++) {
      const status = statuses[i % statuses.length];
      await addDoc(collection(db, "claims"), {
        claimRef: newClaimRef(), partnerId, providerName,
        policyholderName: pick(NAMES),
        policyholderEmail: `${pick(NAMES).toLowerCase().replace(/\s+/g, "")}@gmail.com`,
        planName: pick(PLAN_NAMES),
        amount: rand(400, 13000),
        category: pick(["Medical", "Trip Cancellation", "Baggage Loss", "Flight Delay"]),
        documents: ["Medical Report.pdf", "Hospital Bill.pdf"],
        assignee: { name: "Alex Lee", role: "Claims Officer" },
        status,
        timeline: [{ status: "new", at: new Date(Date.now() - 86400000 * 2).toISOString(), note: "Claim submitted" }],
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(), isDemoSeed: true,
      });
    }
    notes.push("5 sample claims");
  }
  return notes.length ? notes : ["Nothing to seed — you already have data."];
}

/** Deletes every isDemoSeed:true doc across the collections this tool writes to. */
export async function clearDemoData() {
  let count = 0;
  for (const name of ["insurance_transactions", "insurance_plans", "claims"]) {
    const snap = await getDocs(query(collection(db, name), where("isDemoSeed", "==", true)));
    for (const d of snap.docs) {
      await deleteDoc(doc(db, name, d.id));
      count++;
    }
  }
  return count;
}
