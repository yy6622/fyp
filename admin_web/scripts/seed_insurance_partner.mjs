// One-off script: registers a real Insurance Partner (PacificCare
// Insurance) exactly the way admin_web/partner/register.html does
// (createUserWithEmailAndPassword + an insurance_partners/{uid} doc via
// the same fields as auth-guard.js's registerWithRole), then publishes a
// handful of real plans exactly the way partner/plans.html's "Save plan"
// does (one insurance_plans/{id} doc per plan, same field names/shape
// data.js's createPlan writes). Uses the same public Firebase web config
// admin_web/js/firebase-config.js uses — this is the real voya-f69f0
// project, so everything written here is exactly what the Flutter app's
// InsuranceRepository.watchPlans() reads.
//
// Run from this folder (admin_web/scripts/):
//   npm install
//   node seed_insurance_partner.mjs
//
// Safe to re-run — it signs back in (instead of re-registering) if the
// partner account already exists, and skips any plan whose name already
// exists for that partner instead of creating a duplicate.
import { initializeApp } from "firebase/app";
import { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword } from "firebase/auth";
import { getFirestore, doc, setDoc, updateDoc, collection, addDoc, serverTimestamp, getDocs, query, where } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyCxXTqdMBZcmSzk3VnR3I1Z_QvozhAAreo",
  authDomain: "voya-f69f0.firebaseapp.com",
  projectId: "voya-f69f0",
  storageBucket: "voya-f69f0.firebasestorage.app",
  messagingSenderId: "1020854066179",
  appId: "1:1020854066179:web:ea9339cd6449d030208236",
  measurementId: "G-0WZKRWZD00",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const EMAIL = "partner.pacificcare@voya-demo.app";
const PASSWORD = "VoyaPartner2026!";

const PROFILE = {
  companyName: "PacificCare Insurance",
  providerId: "pacificcare-insurance",
  registrationNumber: "SSM-2024-881023",
  phone: "+60 3-2168 4521",
  supportEmail: EMAIL,
  logoUrl: "",
  address: {
    line1: "Level 12, Menara PacificCare, Jalan Sultan Ismail",
    city: "Kuala Lumpur",
    state: "Wilayah Persekutuan",
    postalCode: "50250",
  },
  contact: { fullName: "Nurul Haziqah", designation: "Partnerships Manager", email: EMAIL, phone: "+60 3-2168 4521" },
};

const PLANS = [
  { name: "Single Trip Essential", tripType: "Single Trip", coverage: 50000, premium: 38 },
  { name: "Single Trip Premier", tripType: "Single Trip", coverage: 150000, premium: 89 },
  { name: "Annual Multi-Trip Shield", tripType: "Annual", coverage: 200000, premium: 320 },
  { name: "Family Travel Care", tripType: "Family", coverage: 250000, premium: 210 },
];

async function main() {
  let uid;
  try {
    const cred = await createUserWithEmailAndPassword(auth, EMAIL, PASSWORD);
    uid = cred.user.uid;
    console.log("Created new partner auth account:", uid);
    await setDoc(doc(db, "insurance_partners", uid), {
      ...PROFILE,
      email: EMAIL,
      status: "pending",
      createdAt: serverTimestamp(),
    });
    console.log("Wrote insurance_partners/" + uid);
  } catch (err) {
    if (err.code === "auth/email-already-in-use") {
      console.log("Partner account already exists, signing in instead.");
      const cred = await signInWithEmailAndPassword(auth, EMAIL, PASSWORD);
      uid = cred.user.uid;
    } else {
      throw err;
    }
  }

  // Approve the partner (same effect as an admin clicking "Approve" in
  // System Settings) — rules let a partner update their own doc, and
  // this shouldn't sit on "pending" for a clean demo.
  await updateDoc(doc(db, "insurance_partners", uid), { status: "approved" });
  console.log("Marked partner approved.");

  const existing = await getDocs(query(collection(db, "insurance_plans"), where("partnerId", "==", uid)));
  const existingNames = new Set(existing.docs.map((d) => d.data().name));

  let created = 0;
  for (const plan of PLANS) {
    if (existingNames.has(plan.name)) {
      console.log("Skipping (already exists):", plan.name);
      continue;
    }
    await addDoc(collection(db, "insurance_plans"), {
      ...plan,
      status: "active",
      partnerId: uid,
      providerName: PROFILE.companyName,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    created++;
    console.log("Created plan:", plan.name);
  }

  console.log(`Done. Partner uid=${uid}, ${created} new plan(s) created (${PLANS.length - created} already existed).`);
  process.exit(0);
}

main().catch((err) => {
  console.error("FAILED:", err);
  process.exit(1);
});
