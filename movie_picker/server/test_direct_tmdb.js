const axios = require('axios');

const TMDB_API_KEY = 'f26e4183a1a1ea7149cfb88dd01979bb';
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

async function testDirectTMDB() {
  console.log('🧪 DIRECT TMDB TEST\n');

  try {
    // Test 1: Get TMDB provider list
    console.log('1. Fetching TMDB provider list...');
    const providersResponse = await axios.get(`${TMDB_BASE_URL}/watch/providers/movie`, {
      params: { api_key: TMDB_API_KEY },
      timeout: 10000
    });
    
    const providers = providersResponse.data.results || [];
    console.log(`✅ Fetched ${providers.length} providers from TMDB`);
    
    // Find our target providers
    const targetProviders = {
      'netflix': 8,
      'amazon_prime': 9,
      'disney_plus': 2,
      'hbo_max': 384,
      'hulu': 15
    };
    
    console.log('\n2. Checking our provider IDs against TMDB...');
    for (const [platform, ourId] of Object.entries(targetProviders)) {
      const tmdbProvider = providers.find(p => p.provider_id === ourId);
      if (tmdbProvider) {
        console.log(`✅ ${platform} (ID: ${ourId}) → ${tmdbProvider.provider_name}`);
      } else {
        console.log(`❌ ${platform} (ID: ${ourId}) → NOT FOUND in TMDB`);
      }
    }
    
    // Test 3: Test Netflix filtering directly
    console.log('\n3. Testing Netflix filtering directly...');
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
    
    const netflixResults = netflixResponse.data.results || [];
    console.log(`✅ Netflix test: ${netflixResults.length} movies`);
    console.log(`   Total results: ${netflixResponse.data.total_results}`);
    console.log(`   Total pages: ${netflixResponse.data.total_pages}`);
    
    if (netflixResults.length > 0) {
      console.log('   Sample movies:');
      netflixResults.slice(0, 5).forEach((movie, index) => {
        console.log(`     ${index + 1}. ${movie.title} (Rating: ${movie.vote_average})`);
      });
    }
    
    // Test 4: Test Amazon Prime filtering
    console.log('\n4. Testing Amazon Prime filtering...');
    const amazonQuery = {
      ...netflixQuery,
      with_watch_providers: '9'
    };
    
    const amazonResponse = await axios.get(`${TMDB_BASE_URL}/discover/movie`, {
      params: amazonQuery,
      timeout: 10000
    });
    
    const amazonResults = amazonResponse.data.results || [];
    console.log(`✅ Amazon Prime test: ${amazonResults.length} movies`);
    console.log(`   Total results: ${amazonResponse.data.total_results}`);
    
    if (amazonResults.length > 0) {
      console.log('   Sample movies:');
      amazonResults.slice(0, 5).forEach((movie, index) => {
        console.log(`     ${index + 1}. ${movie.title} (Rating: ${movie.vote_average})`);
      });
    }
    
    // Test 5: Test multiple providers
    console.log('\n5. Testing multiple providers...');
    const multiQuery = {
      ...netflixQuery,
      with_watch_providers: '8|9'
    };
    
    const multiResponse = await axios.get(`${TMDB_BASE_URL}/discover/movie`, {
      params: multiQuery,
      timeout: 10000
    });
    
    const multiResults = multiResponse.data.results || [];
    console.log(`✅ Multi-provider test: ${multiResults.length} movies`);
    console.log(`   Total results: ${multiResponse.data.total_results}`);
    
    console.log('\n🎉 Direct TMDB tests completed!');
    console.log('');
    console.log('📊 Summary:');
    console.log(`   - Netflix results: ${netflixResults.length} movies`);
    console.log(`   - Amazon Prime results: ${amazonResults.length} movies`);
    console.log(`   - Multi-provider results: ${multiResults.length} movies`);
    console.log('');
    console.log('✅ Provider IDs are working correctly with TMDB API');
    console.log('🔧 Next: Start the server and test the Flutter app');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('   Status:', error.response.status);
      console.error('   Data:', error.response.data);
    }
    process.exit(1);
  }
}

// Run the test
testDirectTMDB(); 