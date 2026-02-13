/**
 * BoxOfficer Firebase Cloud Functions
 *
 * Secure API proxy — all API keys live here (server-side), never in the client.
 * Both the iOS app and Next.js web dashboard call these functions
 * to get TMDB, Trakt, and OMDb data.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const cors = require("cors")({ origin: true });

admin.initializeApp();
const db = admin.firestore();

// -------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------

function env(key) {
  // Firebase Functions v2 config / process.env
  return process.env[key] || functions.config()?.[key.toLowerCase()] || "";
}

const TMDB_BASE = "https://api.themoviedb.org/3";
const TRAKT_BASE = "https://api.trakt.tv";
const OMDB_BASE = "https://www.omdbapi.com";

async function tmdbFetch(path, extraParams = {}) {
  const params = new URLSearchParams({
    api_key: env("TMDB_API_KEY"),
    language: "en-US",
    ...extraParams,
  });
  const url = `${TMDB_BASE}${path}?${params}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`TMDB ${res.status}: ${await res.text()}`);
  return res.json();
}

async function traktFetch(path) {
  const res = await fetch(`${TRAKT_BASE}${path}`, {
    headers: {
      "Content-Type": "application/json",
      "trakt-api-version": "2",
      "trakt-api-key": env("TRAKT_CLIENT_ID"),
    },
  });
  if (!res.ok) throw new Error(`Trakt ${res.status}: ${await res.text()}`);
  return res.json();
}

async function omdbFetch(imdbID) {
  const key = env("OMDB_API_KEY");
  if (!key) return null;
  const res = await fetch(`${OMDB_BASE}/?i=${imdbID}&apikey=${key}`);
  if (!res.ok) return null;
  return res.json();
}

// -------------------------------------------------------------------
// Cloud Functions
// -------------------------------------------------------------------

/**
 * GET /nowPlaying — TMDB Now Playing
 */
exports.nowPlaying = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const data = await tmdbFetch("/movie/now_playing", { page: 1 });
      // Cache in Firestore
      await db.doc("cache/nowPlaying").set({
        results: data.results,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.json(data.results);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: err.message });
    }
  });
});

/**
 * GET /trending — TMDB Weekly Trending
 */
exports.trending = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const data = await tmdbFetch("/trending/movie/week");
      await db.doc("cache/trending").set({
        results: data.results,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.json(data.results);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: err.message });
    }
  });
});

/**
 * GET /traktTrending — Trakt Trending, hydrated with TMDB posters
 */
exports.traktTrending = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const items = await traktFetch("/movies/trending");
      const limited = items.slice(0, 20);

      const hydrated = await Promise.all(
        limited.map(async (item) => {
          const tmdbID = item.movie?.ids?.tmdb;
          if (!tmdbID) return null;
          try {
            const details = await tmdbFetch(`/movie/${tmdbID}`);
            return {
              id: details.id,
              title: details.title,
              overview: details.overview,
              release_date: details.release_date,
              poster_path: details.poster_path,
              backdrop_path: details.backdrop_path,
              vote_average: details.vote_average,
              popularity: details.popularity,
              genre_ids: (details.genres || []).map((g) => g.id),
              watchers: item.watchers,
            };
          } catch {
            return null;
          }
        })
      );

      const results = hydrated.filter(Boolean);
      await db.doc("cache/traktTrending").set({
        results,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.json(results);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: err.message });
    }
  });
});

/**
 * GET /movieDetails?id=123 — Full TMDB movie details + OMDb enrichment
 */
exports.movieDetails = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const id = req.query.id;
      if (!id) return res.status(400).json({ error: "id required" });

      const details = await tmdbFetch(`/movie/${id}`);
      const credits = await tmdbFetch(`/movie/${id}/credits`);
      const providers = await tmdbFetch(`/movie/${id}/watch/providers`);
      const externalIds = await tmdbFetch(`/movie/${id}/external_ids`);

      // Enrich with OMDb (Rotten Tomatoes, box office)
      let omdbData = null;
      if (externalIds.imdb_id) {
        omdbData = await omdbFetch(externalIds.imdb_id);
      }

      const result = {
        ...details,
        credits,
        watchProviders: providers.results?.US || null,
        externalIds,
        omdb: omdbData,
      };

      // Cache individual movie
      await db.doc(`movies/${id}`).set({
        ...result,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.json(result);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: err.message });
    }
  });
});

/**
 * GET /search?q=avatar — Movie search
 */
exports.search = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const q = req.query.q;
      if (!q) return res.status(400).json({ error: "q required" });
      const data = await tmdbFetch("/search/movie", { query: q, page: 1 });
      res.json(data.results);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: err.message });
    }
  });
});

/**
 * GET /topRated?region=US&pages=2
 */
exports.topRated = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const region = req.query.region || "";
      const pages = Math.min(parseInt(req.query.pages) || 1, 5);
      let all = [];
      for (let page = 1; page <= pages; page++) {
        const params = { page };
        if (region) params.region = region;
        const data = await tmdbFetch("/movie/top_rated", params);
        all = all.concat(data.results);
      }
      res.json(all);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: err.message });
    }
  });
});

/**
 * GET /topGrossing?pages=2
 */
exports.topGrossing = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const pages = Math.min(parseInt(req.query.pages) || 1, 5);
      let all = [];
      for (let page = 1; page <= pages; page++) {
        const data = await tmdbFetch("/discover/movie", {
          sort_by: "revenue.desc",
          page,
          "vote_count.gte": 500,
        });
        all = all.concat(data.results);
      }
      res.json(all);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: err.message });
    }
  });
});
