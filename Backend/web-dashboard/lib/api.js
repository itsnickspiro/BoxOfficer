/**
 * API client for BoxOfficer Cloud Functions.
 * Falls back to direct Firestore reads from cache collections.
 */
import { db } from "./firebase";
import { doc, getDoc, collection, getDocs, query, orderBy, limit } from "firebase/firestore";

const FUNCTIONS_BASE =
  process.env.NEXT_PUBLIC_FUNCTIONS_URL ||
  "https://us-central1-boxofficer-app.cloudfunctions.net";

async function fetchFromFunction(endpoint, params = {}) {
  const url = new URL(`${FUNCTIONS_BASE}/${endpoint}`);
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));
  const res = await fetch(url.toString());
  if (!res.ok) throw new Error(`API error ${res.status}`);
  return res.json();
}

// --- Firestore cache fallbacks ---

export async function getTrending() {
  try {
    return await fetchFromFunction("trending");
  } catch {
    // Fallback: read from Firestore cache
    const snap = await getDoc(doc(db, "cache", "trending"));
    return snap.exists() ? snap.data().results : [];
  }
}

export async function getNowPlaying() {
  try {
    return await fetchFromFunction("nowPlaying");
  } catch {
    const snap = await getDoc(doc(db, "cache", "nowPlaying"));
    return snap.exists() ? snap.data().results : [];
  }
}

export async function getTraktTrending() {
  try {
    return await fetchFromFunction("traktTrending");
  } catch {
    const snap = await getDoc(doc(db, "cache", "traktTrending"));
    return snap.exists() ? snap.data().results : [];
  }
}

export async function getMovieDetails(id) {
  try {
    return await fetchFromFunction("movieDetails", { id });
  } catch {
    const snap = await getDoc(doc(db, "movies", String(id)));
    return snap.exists() ? snap.data() : null;
  }
}

export async function searchMovies(q) {
  return fetchFromFunction("search", { q });
}

export async function getTopRated(region = "US", pages = 1) {
  return fetchFromFunction("topRated", { region, pages });
}

export async function getTopGrossing(pages = 1) {
  return fetchFromFunction("topGrossing", { pages });
}
