const axios = require('axios');

const TMDB_API_KEY = 'f26e4183a1a1ea7149cfb88dd01979bb';
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

async function testWatchProviders() {
  console.log('🧪 TESTING WATCH PROVIDERS FOR NETFLIX MOVIES\n');

  try {
    // Step 1: Get Netflix movies
    console.log('1. Fetching Netflix movies...');
    const netflixQuery = {
      api_key: TMDB_API_KEY,
      with_watch_providers: '8',
      watch_region: 'US',
      sort_by: 'popularity.desc',
      include_adult: false,
      include_video: false,
      page: 1,
      'vote_count.gte': 10,
      'vote_average.gte': 5.0,
    };
    
    const netflixResponse = await axios.get(`${TMDB_BASE_URL}/discover/movie`, {
      params: netflixQuery,
      timeout: 10000
    });
    
    const netflixMovies = netflixResponse.data.results || [];
    console.log(`✅ Found ${netflixMovies.length} movies from Netflix filter`);
    console.log('');
    
    // Step 2: Check watch providers for each movie
    console.log('2. Checking watch providers for each movie...');
    let verifiedNetflixMovies = 0;
    let totalChecked = 0;
    
    for (const movie of netflixMovies.slice(0, 10)) { // Check first 10 movies
      try {
        console.log(`🔍 Checking: ${movie.title} (ID: ${movie.id})`);
        
        // Get watch providers for this movie
        const providersResponse = await axios.get(`${TMDB_BASE_URL}/movie/${movie.id}/watch/providers`, {
          params: { api_key: TMDB_API_KEY },
          timeout: 10000
        });
        
        const providers = providersResponse.data.results || {};
        const usProviders = providers.US || {};
        const flatrate = usProviders.flatrate || [];
        const free = usProviders.free || [];
        const ads = usProviders.ads || [];
        
        const allProviders = [...flatrate, ...free, ...ads];
        const netflixProvider = allProviders.find(p => p.provider_id === 8);
        
        if (netflixProvider) {
          console.log(`   ✅ CONFIRMED: Available on Netflix (${netflixProvider.provider_name})`);
          verifiedNetflixMovies++;
        } else {
          console.log(`   ❌ NOT FOUND: Not available on Netflix`);
          console.log(`   Available providers: ${allProviders.map(p => p.provider_name).join(', ')}`);
        }
        
        totalChecked++;
        
        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));
        
      } catch (error) {
        console.log(`   ⚠️ Error checking ${movie.title}: ${error.message}`);
      }
    }
    
    console.log('');
    console.log('📊 RESULTS:');
    console.log(`   Total movies checked: ${totalChecked}`);
    console.log(`   Movies confirmed on Netflix: ${verifiedNetflixMovies}`);
    console.log(`   Accuracy: ${((verifiedNetflixMovies / totalChecked) * 100).toFixed(1)}%`);
    
    if (verifiedNetflixMovies === 0) {
      console.log('');
      console.log('❌ PROBLEM: None of the returned movies are actually on Netflix!');
      console.log('   This suggests the TMDB with_watch_providers filter is not working correctly.');
      console.log('   Possible issues:');
      console.log('   1. Provider ID 8 is not correct for Netflix');
      console.log('   2. TMDB API has changed how watch providers work');
      console.log('   3. Regional availability issues');
    } else if (verifiedNetflixMovies < totalChecked * 0.8) {
      console.log('');
      console.log('⚠️ WARNING: Low accuracy - many movies are not actually on Netflix');
    } else {
      console.log('');
      console.log('✅ SUCCESS: Most movies are confirmed to be on Netflix');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('   Status:', error.response.status);
      console.error('   Data:', error.response.data);
    }
  }
}

// Run the test
testWatchProviders(); 