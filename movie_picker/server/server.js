const express = require('express');
const cors = require('cors');
const axios = require('axios');
const NodeCache = require('node-cache');
require('dotenv').config();
const OpenAI = require('openai');

// Initialize OpenAI client if key present
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || process.env.OPENAI_API_TOKEN;
const openai = OPENAI_API_KEY ? new OpenAI({ apiKey: OPENAI_API_KEY }) : null;

// Simple cosine similarity
function cosineSim(a, b) {
  if (!a || !b || a.length !== b.length) return 0;
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    const x = a[i];
    const y = b[i];
    dot += x * y;
    na += x * x;
    nb += y * y;
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

// In-memory embedding cache and mini index
const embeddingCache = new NodeCache({ stdTTL: 86400 });
const movieEmbeddingCache = new NodeCache({ stdTTL: 86400 });

async function embedText(text) {
  const key = `q:${Buffer.from(text).toString('base64')}`;
  const cached = embeddingCache.get(key);
  if (cached) return cached;
  if (!openai) throw new Error('OpenAI API key not configured');
  const resp = await openai.embeddings.create({ model: 'text-embedding-3-small', input: text.slice(0, 8000) });
  const vector = resp.data[0].embedding;
  embeddingCache.set(key, vector);
  return vector;
}

async function embedMovie(movie) {
  const key = `m:${movie.id}`;
  const cached = movieEmbeddingCache.get(key);
  if (cached) return cached;
  const text = `${movie.title} (${movie.release_date || ''})\n${movie.overview || ''}`.trim();
  const vec = await embedText(text);
  movieEmbeddingCache.set(key, vec);
  return vec;
}

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Cache configuration
const platformCache = new NodeCache({ 
  stdTTL: parseInt(process.env.PLATFORM_CACHE_TTL) || 86400 // 24 hours
});
const queryCache = new NodeCache({ 
  stdTTL: parseInt(process.env.QUERY_CACHE_TTL) || 600 // 10 minutes
});
// Images metadata cache (7 days)
const imagesCache = new NodeCache({ stdTTL: 60 * 60 * 24 * 7 });

// TMDB API configuration
const TMDB_API_KEY = process.env.TMDB_API_KEY;
const TMDB_BASE_URL = process.env.TMDB_BASE_URL || 'https://api.themoviedb.org/3';

if (!TMDB_API_KEY) {
  console.error('❌ TMDB_API_KEY is required in environment variables');
  process.exit(1);
}

// Platform name to TMDB provider ID mapping (updated with verified IDs)
const PLATFORM_TO_PROVIDER_MAP = {
  // US Providers (verified with TMDB)
  'netflix': 8,
  'amazon_prime': 9,
  'disney_plus': 2,
  'hbo_max': 118, // Fixed: HBO Max is actually 118, not 384
  'hulu': 15,
  'apple_tv': 350,
  'paramount_plus': 531,
  'peacock': 386,
  'crunchyroll': 283,
  
  // UK Providers
  'bbc_iplayer': 318,
  'itv_hub': 319,
  'all4': 320,
  'my5': 321,
  'britbox': 322,
  'now_tv': 39,
  'sky_go': 29,
  'bt_tv': 323,
  'virgin_tv': 324,
  
  // International Providers
  'canal_plus': 230,
  'm6': 231,
  'tf1': 232,
  'arte': 233,
  'rtl_plus': 234,
  'prosieben': 235,
  'zdf': 236,
  'mediaset': 237,
  'rai_play': 238,
  'movistar_plus': 149,
  'atresplayer': 240,
  
  // Anime and International
  'funimation': 283,
  'hidive': 284,
  'vrv': 285,
};

// Reverse mapping for provider ID to platform name
const PROVIDER_TO_PLATFORM_MAP = {};
Object.entries(PLATFORM_TO_PROVIDER_MAP).forEach(([platform, id]) => {
  PROVIDER_TO_PLATFORM_MAP[id] = platform;
});

// New: Fetch movie images (backdrops) with caching
app.get('/images/:movieId', async (req, res) => {
  try {
    const movieId = parseInt(req.params.movieId, 10);
    if (!movieId || Number.isNaN(movieId)) {
      return res.status(400).json({ success: false, error: 'Invalid movieId' });
    }

    const cacheKey = `images:${movieId}`;
    const cached = imagesCache.get(cacheKey);
    if (cached) {
      return res.json({ success: true, data: cached, cached: true });
    }

    const url = `${TMDB_BASE_URL}/movie/${movieId}/images`;
    const params = {
      api_key: TMDB_API_KEY,
      include_image_language: 'null,en',
      language: 'en',
    };

    const resp = await axios.get(url, { params });
    const backdrops = Array.isArray(resp.data?.backdrops) ? resp.data.backdrops : [];

    // Sort by vote_average desc and take top N
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
        url_w780: `https://image.tmdb.org/t/p/w780${b.file_path}`,
        url_original: `https://image.tmdb.org/t/p/original${b.file_path}`,
      }));

    imagesCache.set(cacheKey, top);
    return res.json({ success: true, data: top, cached: false });
  } catch (err) {
    console.error('❌ Error fetching images:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to fetch images' });
  }
});

// Helper function to get provider IDs for platforms with comprehensive logging
function getProviderIds(platforms, region = 'US') {
  console.log(`🔍 Mapping platforms to provider IDs for region: ${region}`);
  console.log(`   Requested platforms: ${platforms.join(', ')}`);
  
  const providerIds = [];
  const unmappedPlatforms = [];
  
  for (const platform of platforms) {
    const normalizedPlatform = platform.toLowerCase().trim();
    const providerId = PLATFORM_TO_PROVIDER_MAP[normalizedPlatform];
    
    if (providerId) {
      providerIds.push(providerId);
      console.log(`   ✅ ${platform} → ${providerId}`);
    } else {
      unmappedPlatforms.push(platform);
      console.log(`   ❌ ${platform} → NOT FOUND`);
    }
  }
  
  if (unmappedPlatforms.length > 0) {
    console.log(`⚠️ Unmapped platforms: ${unmappedPlatforms.join(', ')}`);
    console.log(`   Available platforms: ${Object.keys(PLATFORM_TO_PROVIDER_MAP).join(', ')}`);
  }
  
  console.log(`   Final provider IDs: [${providerIds.join(', ')}]`);
  return providerIds;
}

// Helper function to create cache key
function createCacheKey(platforms, region, type) {
  const sortedPlatforms = platforms.sort().join(',');
  return `streaming_${type}_${region}_${sortedPlatforms}`;
}

// Main streaming filter endpoint with comprehensive logging and pagination support
app.post('/filter/streaming', async (req, res) => {
  try {
    const { platforms, region = 'US', type = 'movie', page = 1, targetCount = 20 } = req.body;
    
    console.log('\n🎬 ===== STREAMING FILTER REQUEST =====');
    console.log(`📥 Incoming request:`, {
      platforms,
      region,
      type,
      page,
      targetCount,
      timestamp: new Date().toISOString()
    });
    
    // Validate input
    if (!platforms || !Array.isArray(platforms) || platforms.length === 0) {
      console.log('❌ Invalid platforms parameter');
      return res.status(400).json({
        error: 'Invalid platforms parameter. Must be a non-empty array.'
      });
    }
    
    if (!['movie', 'tv'].includes(type)) {
      console.log('❌ Invalid type parameter');
      return res.status(400).json({
        error: 'Invalid type parameter. Must be "movie" or "tv".'
      });
    }
    
    // Check cache first (include page in cache key)
    const cacheKey = `${createCacheKey(platforms, region, type)}_page_${page}`;
    const cachedResult = queryCache.get(cacheKey);
    
    if (cachedResult) {
      console.log(`✅ Returning cached result for ${cacheKey}`);
      return res.json({
        success: true,
        cached: true,
        data: cachedResult,
        count: cachedResult.length,
        page: page,
        hasMore: cachedResult.length >= targetCount
      });
    }
    
    // Get provider IDs for the requested platforms
    console.log(`🔍 Mapping platforms to provider IDs...`);
    const providerIds = getProviderIds(platforms, region);
    
    if (providerIds.length === 0) {
      console.log('❌ No valid platforms found');
      return res.status(400).json({
        error: 'No valid platforms found. Check platform names.',
        available_platforms: Object.keys(PLATFORM_TO_PROVIDER_MAP)
      });
    }
    
    console.log(`✅ Provider IDs: [${providerIds.join(', ')}]`);
    
    // Build TMDB API query parameters with pagination
    const queryParams = {
      api_key: TMDB_API_KEY,
      with_watch_providers: providerIds.join('|'),
      watch_region: region,
      sort_by: 'popularity.desc',
      include_adult: false,
      include_video: false,
      page: page, // Use the requested page
      'vote_count.gte': 10,
      'vote_average.gte': 5.0,
    };
    
    // Make request to TMDB discover endpoint
    const tmdbUrl = `${TMDB_BASE_URL}/discover/${type}`;
    const fullUrl = `${tmdbUrl}?${new URLSearchParams(queryParams).toString()}`;
    
    console.log(`🌐 TMDB Request Details:`);
    console.log(`   URL: ${tmdbUrl}`);
    console.log(`   Full URL: ${fullUrl}`);
    console.log(`   Query Params:`, queryParams);
    
    const tmdbResponse = await axios.get(tmdbUrl, {
      params: queryParams,
      timeout: 10000
    });
    
    if (tmdbResponse.status !== 200) {
      console.log(`❌ TMDB API error: ${tmdbResponse.status}`);
      return res.status(500).json({
        error: `TMDB API error: ${tmdbResponse.status}`
      });
    }
    
    const results = tmdbResponse.data.results || [];
    const totalPages = tmdbResponse.data.total_pages || 0;
    const totalResults = tmdbResponse.data.total_results || 0;
    
    console.log(`✅ TMDB Response:`);
    console.log(`   Status: ${tmdbResponse.status}`);
    console.log(`   Results: ${results.length} movies`);
    console.log(`   Total Results: ${totalResults}`);
    console.log(`   Total Pages: ${totalPages}`);
    console.log(`   Current Page: ${page}`);
    console.log(`   Sample results:`, results.slice(0, 3).map(m => m.title));
    
    // Cache the results
    queryCache.set(cacheKey, results);
    
    console.log(`✅ Cached results for key: ${cacheKey}`);
    
    res.json({
      success: true,
      cached: false,
      data: results,
      count: results.length,
      page: page,
      totalPages: totalPages,
      totalResults: totalResults,
      hasMore: page < totalPages && results.length >= targetCount,
      query_info: {
        platforms: platforms,
        region: region,
        type: type,
        provider_ids: providerIds,
        tmdb_url: fullUrl,
        pagination: {
          current_page: page,
          total_pages: totalPages,
          total_results: totalResults,
          has_more: page < totalPages
        }
      }
    });
    
  } catch (error) {
    console.error('❌ Streaming filter error:', error);
    console.error('   Stack trace:', error.stack);
    res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
});

// Test endpoint to verify TMDB provider IDs and filtering
app.get('/test-provider', async (req, res) => {
  try {
    const { platform, region = 'US' } = req.query;
    
    if (!platform) {
      return res.status(400).json({
        error: 'Platform parameter is required'
      });
    }
    
    console.log(`🧪 Testing provider for platform: ${platform} in region: ${region}`);
    
    const providerId = PLATFORM_TO_PROVIDER_MAP[platform.toLowerCase()];
    
    if (!providerId) {
      return res.status(400).json({
        error: `Unknown platform: ${platform}`,
        available_platforms: Object.keys(PLATFORM_TO_PROVIDER_MAP)
      });
    }
    
    // Test the provider ID with TMDB
    const queryParams = {
      api_key: TMDB_API_KEY,
      with_watch_providers: providerId.toString(),
      watch_region: region,
      sort_by: 'popularity.desc',
      include_adult: false,
      include_video: false,
      page: 1,
      'vote_count.gte': 10,
      'vote_average.gte': 5.0,
    };
    
    const tmdbUrl = `${TMDB_BASE_URL}/discover/movie`;
    const fullUrl = `${tmdbUrl}?${new URLSearchParams(queryParams).toString()}`;
    
    console.log(`🧪 Testing provider ID ${providerId} for platform ${platform}`);
    console.log(`🔗 Test URL: ${fullUrl}`);
    
    const tmdbResponse = await axios.get(tmdbUrl, {
      params: queryParams,
      timeout: 10000
    });
    
    const results = tmdbResponse.data.results || [];
    
    console.log(`✅ Test completed: ${results.length} movies found`);
    
    res.json({
      success: true,
      platform,
      provider_id: providerId,
      region,
      tmdb_url: fullUrl,
      results_count: results.length,
      sample_results: results.slice(0, 5).map(item => ({
        id: item.id,
        title: item.title,
        vote_average: item.vote_average
      }))
    });
    
  } catch (error) {
    console.error('❌ Error testing provider:', error.message);
    res.status(500).json({
      error: 'Test failed',
      message: error.message
    });
  }
});

// Debug endpoint to test TMDB provider IDs directly
app.get('/debug-providers', async (req, res) => {
  try {
    const { platform, region = 'US' } = req.query;
    
    if (!platform) {
      return res.status(400).json({
        error: 'Platform parameter is required'
      });
    }
    
    console.log(`🔍 Debugging provider for platform: ${platform}`);
    
    // Test different provider IDs for common platforms
    const testProviderIds = {
      'netflix': [8, 213, 119], // Try different possible IDs
      'amazon_prime': [9, 10, 119], // Try different possible IDs
      'disney_plus': [2, 3, 4], // Try different possible IDs
    };
    
    const platformKey = platform.toLowerCase();
    const providerIdsToTest = testProviderIds[platformKey] || [PLATFORM_TO_PROVIDER_MAP[platformKey]];
    
    const results = [];
    
    for (const providerId of providerIdsToTest) {
      try {
        const queryParams = {
          api_key: TMDB_API_KEY,
          with_watch_providers: providerId.toString(),
          watch_region: region,
          sort_by: 'popularity.desc',
          include_adult: false,
          include_video: false,
          page: 1,
          'vote_count.gte': 10,
          'vote_average.gte': 5.0,
        };
        
        const tmdbUrl = `${TMDB_BASE_URL}/discover/movie`;
        console.log(`🧪 Testing provider ID ${providerId} for ${platform}`);
        
        const tmdbResponse = await axios.get(tmdbUrl, {
          params: queryParams,
          timeout: 10000
        });
        
        const movieResults = tmdbResponse.data.results || [];
        
        results.push({
          provider_id: providerId,
          results_count: movieResults.length,
          sample_titles: movieResults.slice(0, 3).map(item => item.title),
          tmdb_url: `${tmdbUrl}?${new URLSearchParams(queryParams).toString()}`
        });
        
        console.log(`✅ Provider ID ${providerId}: ${movieResults.length} movies`);
        
      } catch (error) {
        console.log(`❌ Provider ID ${providerId} failed: ${error.message}`);
        results.push({
          provider_id: providerId,
          results_count: 0,
          error: error.message,
          sample_titles: []
        });
      }
    }
    
    res.json({
      success: true,
      platform,
      region,
      current_provider_id: PLATFORM_TO_PROVIDER_MAP[platformKey],
      test_results: results
    });
    
  } catch (error) {
    console.error('❌ Error debugging providers:', error.message);
    res.status(500).json({
      error: 'Debug failed',
      message: error.message
    });
  }
});

// Fetch TMDB's official provider list for validation
app.get('/tmdb-providers', async (req, res) => {
  try {
    console.log('🔍 Fetching TMDB official provider list...');
    
    const response = await axios.get(`${TMDB_BASE_URL}/watch/providers/movie`, {
      params: { api_key: TMDB_API_KEY },
      timeout: 10000
    });
    
    if (response.status !== 200) {
      throw new Error(`TMDB API returned status ${response.status}`);
    }
    
    const providers = response.data.results || [];
    console.log(`✅ Fetched ${providers.length} providers from TMDB`);
    
    // Cache the provider list for 24 hours
    platformCache.set('tmdb_providers', providers, 86400);
    
    res.json({
      success: true,
      count: providers.length,
      providers: providers.map(provider => ({
        id: provider.provider_id,
        name: provider.provider_name,
        logo_path: provider.logo_path,
        display_priority: provider.display_priority
      }))
    });
    
  } catch (error) {
    console.error('❌ Error fetching TMDB providers:', error.message);
    res.status(500).json({
      error: 'Failed to fetch TMDB providers',
      message: error.message
    });
  }
});

// Validate our provider IDs against TMDB's official list
app.get('/validate-providers', async (req, res) => {
  try {
    console.log('🔍 Validating our provider IDs against TMDB...');
    
    // Get cached TMDB providers or fetch them
    let tmdbProviders = platformCache.get('tmdb_providers');
    if (!tmdbProviders) {
      const response = await axios.get(`${TMDB_BASE_URL}/watch/providers/movie`, {
        params: { api_key: TMDB_API_KEY },
        timeout: 10000
      });
      tmdbProviders = response.data.results || [];
      platformCache.set('tmdb_providers', tmdbProviders, 86400);
    }
    
    const tmdbProviderIds = new Set(tmdbProviders.map(p => p.provider_id));
    const validationResults = [];
    
    for (const [platform, ourId] of Object.entries(PLATFORM_TO_PROVIDER_MAP)) {
      const isValid = tmdbProviderIds.has(ourId);
      const tmdbProvider = tmdbProviders.find(p => p.provider_id === ourId);
      
      validationResults.push({
        platform,
        our_provider_id: ourId,
        is_valid: isValid,
        tmdb_provider_name: tmdbProvider?.provider_name || 'Not found',
        tmdb_provider_id: tmdbProvider?.provider_id || null
      });
    }
    
    const validCount = validationResults.filter(r => r.is_valid).length;
    const invalidCount = validationResults.filter(r => !r.is_valid).length;
    
    console.log(`✅ Provider validation: ${validCount} valid, ${invalidCount} invalid`);
    
    res.json({
      success: true,
      total_providers: validationResults.length,
      valid_count: validCount,
      invalid_count: invalidCount,
      results: validationResults
    });
    
  } catch (error) {
    console.error('❌ Error validating providers:', error.message);
    res.status(500).json({
      error: 'Failed to validate providers',
      message: error.message
    });
  }
});

// Get available platforms endpoint
app.get('/platforms', (req, res) => {
  const platforms = Object.keys(PLATFORM_TO_PROVIDER_MAP).map(platform => ({
    id: platform,
    name: platform.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()),
    provider_id: PLATFORM_TO_PROVIDER_MAP[platform]
  }));
  
  res.json({
    success: true,
    platforms,
    count: platforms.length
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    cache_stats: {
      platform_cache_size: platformCache.keys().length,
      query_cache_size: queryCache.keys().length
    },
    openai_configured: !!OPENAI_API_KEY,
    openai_initialized: !!openai,
    environment: process.env.NODE_ENV || 'development'
  });
});

// Clear cache endpoint (for development)
app.delete('/cache', (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ error: 'Cache clearing not allowed in production' });
  }
  
  platformCache.flushAll();
  queryCache.flushAll();
  
  res.json({
    success: true,
    message: 'Cache cleared',
    timestamp: new Date().toISOString()
  });
});

// -------- Semantic search endpoints --------

// Rank a free-form description against TMDB discover/search results and return similarity score
app.post('/semantic/search', async (req, res) => {
  try {
    const { description, yearFrom, yearTo, language = 'en', page = 1, maxPages = 2 } = req.body || {};
    if (!description || typeof description !== 'string' || description.trim().length < 3) {
      return res.status(400).json({ error: 'description is required' });
    }

    if (!openai) {
      // Graceful fallback when OpenAI is not configured
      try {
        const q = (req.body && req.body.description) || '';
        const params = { api_key: TMDB_API_KEY, query: q.slice(0, 500), include_adult: false, page: 1 };
        const url = `${TMDB_BASE_URL}/search/movie`;
        const resp = await axios.get(url, { params, timeout: 10000 });
        const list = (resp.data && resp.data.results) || [];
        const mapped = list.slice(0, 50).map(m => ({
          id: m.id,
          title: m.title,
          overview: m.overview,
          release_date: m.release_date,
          vote_average: m.vote_average,
          poster_path: m.poster_path,
          similarity: null,
        }));
        return res.json({ success: true, fallback: true, reason: 'OPENAI_API_KEY not configured', count: mapped.length, results: mapped });
      } catch (fallbackErr) {
        return res.status(503).json({ error: 'Semantic search unavailable and fallback failed', message: fallbackErr.message });
      }
    }

    const qVec = await embedText(description);

    // Gather candidate movies from multiple TMDB sources so free-form queries can still find the right film
    const candidates = [];

    // 1) Direct search by free-form description (often pulls the obvious match like "Shrek")
    try {
      const searchParams = {
        api_key: TMDB_API_KEY,
        query: description.slice(0, 500),
        include_adult: false,
        page: 1,
      };
      const searchUrl = `${TMDB_BASE_URL}/search/movie`;
      const searchResp = await axios.get(searchUrl, { params: searchParams, timeout: 10000 });
      const searchList = (searchResp.data && searchResp.data.results) || [];
      for (const m of searchList) {
        if (!candidates.some(c => c.id === m.id)) candidates.push(m);
      }
    } catch (e) {
      console.warn('⚠️ TMDB search fallback failed:', e.message);
    }

    // 2) Discover with broad sorts to pull in high-signal, popular titles
    const sorts = ['popularity.desc', 'vote_average.desc'];
    for (const sort_by of sorts) {
      for (let p = 1; p <= Math.max(1, Math.min(maxPages, 5)); p++) {
        const params = {
          api_key: TMDB_API_KEY,
          sort_by,
          include_adult: false,
          include_video: false,
          page: p,
          with_original_language: language,
          'vote_count.gte': 10,
        };
        if (yearFrom) params['primary_release_date.gte'] = `${yearFrom}-01-01`;
        if (yearTo) params['primary_release_date.lte'] = `${yearTo}-12-31`;

        const url = `${TMDB_BASE_URL}/discover/movie`;
        const resp = await axios.get(url, { params, timeout: 10000 });
        const list = (resp.data && resp.data.results) || [];
        for (const m of list) {
          // De-dup by id
          if (!candidates.some(c => c.id === m.id)) candidates.push(m);
        }
      }
    }

    // 3) Keyword-assisted discover: derive top tokens from description -> keyword IDs -> discover
    try {
      const tokens = Array.from(new Set(
        (description || '')
          .toLowerCase()
          .split(/[^a-z0-9]+/g)
          .filter(w => w && w.length >= 4 && !['movie', 'about', 'with', 'from', 'that', 'this', 'which'].includes(w))
      ));
      const topTokens = tokens.slice(0, 5);
      for (const tok of topTokens) {
        try {
          const kwResp = await axios.get(`${TMDB_BASE_URL}/search/keyword`, {
            params: { api_key: TMDB_API_KEY, query: tok, page: 1 },
            timeout: 10000,
          });
          const kwList = (kwResp.data && kwResp.data.results) || [];
          if (kwList.length === 0) continue;
          const keywordId = kwList[0].id;
          const dParams = {
            api_key: TMDB_API_KEY,
            with_keywords: keywordId,
            include_adult: false,
            include_video: false,
            sort_by: 'popularity.desc',
            page: 1,
            with_original_language: language,
            'vote_count.gte': 10,
          };
          const dUrl = `${TMDB_BASE_URL}/discover/movie`;
          const dResp = await axios.get(dUrl, { params: dParams, timeout: 10000 });
          const dList = (dResp.data && dResp.data.results) || [];
          for (const m of dList) {
            if (!candidates.some(c => c.id === m.id)) candidates.push(m);
          }
        } catch (inner) {
          // skip token on failure
          continue;
        }
      }
    } catch (kwErr) {
      console.warn('⚠️ Keyword-assisted discover failed:', kwErr.message);
    }

    // Compute embeddings and similarity
    const scored = [];
    for (const m of candidates) {
      const mVec = await embedMovie(m);
      const score = cosineSim(qVec, mVec);
      scored.push({
        id: m.id,
        title: m.title,
        overview: m.overview,
        release_date: m.release_date,
        vote_average: m.vote_average,
        poster_path: m.poster_path,
        similarity: score,
      });
    }

    scored.sort((a, b) => b.similarity - a.similarity || (b.vote_average || 0) - (a.vote_average || 0));
    return res.json({ success: true, count: scored.length, results: scored.slice(0, 100) });
  } catch (err) {
    console.error('❌ Semantic search error:', err.message);
    // Fallback: keyword search so the client still gets useful results
    try {
      const q = (req.body && req.body.description) || '';
      const params = { api_key: TMDB_API_KEY, query: q.slice(0, 500), include_adult: false, page: 1 };
      const url = `${TMDB_BASE_URL}/search/movie`;
      const resp = await axios.get(url, { params, timeout: 10000 });
      const list = (resp.data && resp.data.results) || [];
      const mapped = list.slice(0, 50).map(m => ({
        id: m.id,
        title: m.title,
        overview: m.overview,
        release_date: m.release_date,
        vote_average: m.vote_average,
        poster_path: m.poster_path,
        similarity: null,
      }));
      return res.json({ success: true, fallback: true, reason: err.message, count: mapped.length, results: mapped });
    } catch (fallbackErr) {
      console.error('❌ Fallback keyword search failed:', fallbackErr.message);
      return res.status(500).json({ error: 'semantic_search_failed', message: err.message });
    }
  }
});

// Rank against platform-filtered cache (if client wants “only streaming on X” semantics)
app.post('/semantic/streaming', async (req, res) => {
  try {
    const { description, platforms, region = 'US', language = 'en' } = req.body || {};
    if (!description) return res.status(400).json({ error: 'description is required' });
    if (!Array.isArray(platforms) || platforms.length === 0) {
      return res.status(400).json({ error: 'platforms array required' });
    }
    if (!openai) return res.status(503).json({ error: 'Semantic search unavailable: missing OPENAI_API_KEY' });

    const providerIds = getProviderIds(platforms, region);
    if (providerIds.length === 0) return res.status(400).json({ error: 'No valid platforms' });

    const qVec = await embedText(description);

    const params = {
      api_key: TMDB_API_KEY,
      with_watch_providers: providerIds.join('|'),
      watch_region: region,
      include_adult: false,
      include_video: false,
      sort_by: 'popularity.desc',
      page: 1,
      with_original_language: language,
      'vote_count.gte': 10,
    };
    const url = `${TMDB_BASE_URL}/discover/movie`;
    const resp = await axios.get(url, { params, timeout: 10000 });
    const list = (resp.data && resp.data.results) || [];

    const scored = [];
    for (const m of list) {
      const mVec = await embedMovie(m);
      const score = cosineSim(qVec, mVec);
      scored.push({ id: m.id, title: m.title, overview: m.overview, poster_path: m.poster_path, similarity: score });
    }
    scored.sort((a, b) => b.similarity - a.similarity);
    return res.json({ success: true, count: scored.length, results: scored.slice(0, 50) });
  } catch (err) {
    console.error('❌ Semantic streaming error:', err.message);
    // Fallback: popular discover for requested providers
    try {
      const { platforms, region = 'US', language = 'en' } = req.body || {};
      const providerIds = Array.isArray(platforms) ? getProviderIds(platforms, region) : [];
      const params = {
        api_key: TMDB_API_KEY,
        with_watch_providers: providerIds.join('|'),
        watch_region: region,
        include_adult: false,
        include_video: false,
        sort_by: 'popularity.desc',
        page: 1,
        with_original_language: language,
        'vote_count.gte': 10,
      };
      const url = `${TMDB_BASE_URL}/discover/movie`;
      const resp = await axios.get(url, { params, timeout: 10000 });
      const list = (resp.data && resp.data.results) || [];
      const mapped = list.slice(0, 50).map(m => ({
        id: m.id,
        title: m.title,
        overview: m.overview,
        poster_path: m.poster_path,
        similarity: null,
      }));
      return res.json({ success: true, fallback: true, reason: err.message, count: mapped.length, results: mapped });
    } catch (fallbackErr) {
      console.error('❌ Fallback streaming discover failed:', fallbackErr.message);
      return res.status(500).json({ error: 'semantic_streaming_failed', message: err.message });
    }
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Streaming filter server running on port ${PORT}`);
  console.log(`📡 TMDB API Key: ${TMDB_API_KEY ? '✅ Configured' : '❌ Missing'}`);
  console.log(`🌐 Health check: http://localhost:${PORT}/health`);
  console.log(`🎬 Streaming filter: http://localhost:${PORT}/filter/streaming`);
  console.log(`📋 Available platforms: http://localhost:${PORT}/platforms`);
});

module.exports = app; 