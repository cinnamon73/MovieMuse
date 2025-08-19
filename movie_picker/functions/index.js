const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

const TMDB_API_KEY = "f26e4183a1a1ea7149cfb88dd01979bb";

// Comprehensive platform mapping
const PLATFORMS = {
  netflix: { id: 8, name: "Netflix" },
  amazon_prime: { id: 119, name: "Amazon Prime" },
  disney_plus: { id: 337, name: "Disney+" },
  hbo_max: { id: 384, name: "HBO Max" },
  hulu: { id: 15, name: "Hulu" },
  apple_tv: { id: 350, name: "Apple TV+" },
  paramount_plus: { id: 531, name: "Paramount+" },
  peacock: { id: 386, name: "Peacock" },
  crunchyroll: { id: 283, name: "Crunchyroll" },
};

// Fetch and cache movie images (backdrops) in Firestore
exports.fetchMovieImages = functions.https.onRequest(async (req, res) => {
  // Basic CORS support
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  try {
    const movieIdParam = req.method === 'GET' ? req.query.movieId : req.body?.movieId;
    const movieId = parseInt(movieIdParam, 10);
    if (!movieId || Number.isNaN(movieId)) {
      return res.status(400).json({ success: false, error: 'Missing or invalid movieId' });
    }

    // Fetch from TMDB
    const tmdbUrl = `https://api.themoviedb.org/3/movie/${movieId}/images`;
    const params = {
      api_key: TMDB_API_KEY,
      include_image_language: 'null,en',
      language: 'en',
    };

    const response = await axios.get(tmdbUrl, { params, timeout: 10000 });
    const backdrops = Array.isArray(response.data?.backdrops) ? response.data.backdrops : [];

    // Rank and reduce payload
    const top = backdrops
      .filter(b => !!b.file_path)
      .sort((a, b) => (b.vote_average || 0) - (a.vote_average || 0))
      .slice(0, 8)
      .map(b => ({
        file_path: b.file_path,
        width: b.width,
        height: b.height,
        vote_average: b.vote_average || 0,
        iso_639_1: b.iso_639_1 || null,
      }));

    // Write to Firestore
    await db.collection('movieImages').doc(String(movieId)).set({
      backdrops: top,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return res.json({ success: true, movieId, count: top.length });
  } catch (err) {
    console.error('❌ fetchMovieImages error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to fetch movie images' });
  }
});

// Manual sync endpoint for testing
exports.syncPlatformMovies = functions.https.onRequest(async (req, res) => {
  const REGION = "US";
  const maxPages = 50; // Increased for more comprehensive data

  try {
    console.log("🚀 Starting platform sync...");

    for (const [platformKey, platform] of Object.entries(PLATFORMS)) {
    const allMovies = [];
    let page = 1;
      let hasMorePages = true;

      console.log(`📡 Syncing ${platform.name} (ID: ${platform.id})...`);

      while (hasMorePages && page <= maxPages) {
    try {
        const response = await axios.get("https://api.themoviedb.org/3/discover/movie", {
          params: {
            api_key: TMDB_API_KEY,
              with_watch_providers: platform.id,
            watch_region: REGION,
            page: page,
            sort_by: "popularity.desc",
            include_adult: false,
              vote_count_gte: 10,
              vote_average_gte: 5.0,
          },
        });

          const data = response.data;
          const results = data.results || [];
          
          if (results.length === 0) {
            hasMorePages = false;
            break;
          }

          // Process and clean movie data
          const processedMovies = results.map(movie => ({
            id: movie.id,
            title: movie.title,
            overview: movie.overview,
            poster_path: movie.poster_path,
            backdrop_path: movie.backdrop_path,
            release_date: movie.release_date,
            vote_average: movie.vote_average,
            vote_count: movie.vote_count,
            genre_ids: movie.genre_ids,
            original_language: movie.original_language,
            adult: movie.adult,
            popularity: movie.popularity,
            // Add platform info
            streaming_platforms: [platformKey],
          }));

          allMovies.push(...processedMovies);
          
          console.log(`📄 Page ${page}: ${results.length} movies for ${platform.name}`);
          
        page++;

          // Rate limiting
          await new Promise(resolve => setTimeout(resolve, 200));
          
        } catch (error) {
          console.error(`❌ Error fetching page ${page} for ${platform.name}:`, error.message);
          break;
        }
      }

      // Store in Firestore
      if (allMovies.length > 0) {
        await db.collection("platformMovies").doc(platformKey).set({
        movies: allMovies,
          platform: platform.name,
          provider_id: platform.id,
          total_movies: allMovies.length,
          last_sync: admin.firestore.FieldValue.serverTimestamp(),
          region: REGION,
      });

        console.log(`✅ Synced ${allMovies.length} movies for ${platform.name}`);
      }
    }

    console.log("🎉 Platform sync complete!");
    res.status(200).json({ 
      success: true, 
      message: "Platform sync complete",
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error("❌ Sync failed:", error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// Get movies by platform (for client use)
exports.getPlatformMovies = functions.https.onRequest(async (req, res) => {
  const { platform } = req.query;
  
  if (!platform || !PLATFORMS[platform]) {
    return res.status(400).json({ 
      error: "Invalid platform. Supported platforms: " + Object.keys(PLATFORMS).join(", ") 
    });
  }

  try {
    const doc = await db.collection("platformMovies").doc(platform).get();
    
    if (!doc.exists) {
      return res.status(404).json({ 
        error: `No data found for ${platform}. Run sync first.` 
      });
    }

    const data = doc.data();
    res.status(200).json({
      platform: platform,
      movies: data.movies || [],
      total: data.total_movies || 0,
      last_sync: data.last_sync,
    });

  } catch (error) {
    console.error("❌ Error fetching platform movies:", error);
    res.status(500).json({ error: error.message });
    }
});

// Scheduled monthly sync (runs on the 1st of each month at 2 AM)
exports.scheduledPlatformSync = functions.scheduler.onSchedule('0 2 1 * *', async (event) => {
  console.log("🕐 Running monthly platform sync...");
  
  try {
    // Call the sync function
    const syncFunction = require('./index').syncPlatformMovies;
    const mockReq = { method: 'GET' };
    const mockRes = {
      status: (code) => ({ json: (data) => console.log('Response:', data) }),
      json: (data) => console.log('Response:', data)
    };
    
    await syncFunction(mockReq, mockRes);
    console.log("✅ Monthly platform sync completed successfully");
    return null;
  } catch (error) {
    console.error("❌ Monthly platform sync failed:", error);
    return null;
  }
});
