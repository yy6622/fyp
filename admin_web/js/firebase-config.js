// Voya — shared Firebase init for the Admin & Insurance Partner console.
// Same project the Flutter app uses (lib/firebase_options.dart -> web config),
// so this console reads/writes the real, live data.
import { initializeApp, getApps, getApp } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js";
import { getAuth, connectAuthEmulator } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";
import { getFirestore, connectFirestoreEmulator } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";
import { getStorage, connectStorageEmulator } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-storage.js";

const firebaseConfig = {
  apiKey: "AIzaSyCxXTqdMBZcmSzk3VnR3I1Z_QvozhAAreo",
  authDomain: "voya-f69f0.firebaseapp.com",
  projectId: "voya-f69f0",
  storageBucket: "voya-f69f0.firebasestorage.app",
  messagingSenderId: "1020854066179",
  appId: "1:1020854066179:web:ea9339cd6449d030208236",
  measurementId: "G-0WZKRWZD00",
};

export const app = getApps().length ? getApp() : initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Test mode for the automated web tests (tests/web/). Opening any page once
// with ?emulator=1 switches this browser tab to the local Firebase emulators
// (firebase emulators:start) for the rest of the session; ?emulator=0 switches
// back. Without the flag nothing changes and the console uses the live project.
let useEmulator = false;
try {
  const flag = new URLSearchParams(location.search).get("emulator");
  if (flag === "1") sessionStorage.setItem("voyaEmulator", "1");
  if (flag === "0") sessionStorage.removeItem("voyaEmulator");
  useEmulator = sessionStorage.getItem("voyaEmulator") === "1";
} catch (_) {
  useEmulator = false;
}
// firebase-config.js is imported under two different ?v= URLs, so this module
// can run twice; the emulators may only be connected once per page.
if (useEmulator && !globalThis.__voyaEmulatorConnected) {
  globalThis.__voyaEmulatorConnected = true;
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  connectFirestoreEmulator(db, "127.0.0.1", 8085);
  connectStorageEmulator(storage, "127.0.0.1", 9199);
}
