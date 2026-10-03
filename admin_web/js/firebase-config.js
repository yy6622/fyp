// Voya — shared Firebase init for the Admin & Insurance Partner console.
// Same project the Flutter app uses (lib/firebase_options.dart -> web config),
// so this console reads/writes the real, live data.
import { initializeApp, getApps, getApp } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";
import { getStorage } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-storage.js";

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
