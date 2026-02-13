/**
 * Firebase client configuration for the Web Dashboard.
 * This is the same Firebase project the iOS app connects to — single source of truth.
 *
 * IMPORTANT: Set these values via environment variables in production.
 */
import { initializeApp, getApps } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "YOUR_FIREBASE_API_KEY",
  authDomain: `${process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "boxofficer-app"}.firebaseapp.com`,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "boxofficer-app",
  storageBucket: `${process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "boxofficer-app"}.appspot.com`,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "",
};

// Initialize Firebase (prevent duplicate init in dev with hot reload)
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
const db = getFirestore(app);

export { app, db };
