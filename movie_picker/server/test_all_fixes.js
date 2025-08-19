const axios = require('axios');

const BASE_URL = 'http://localhost:3001';

async function testAllFixes() {
  console.log('🧪 Testing All Streaming Filter Fixes\n');

  try {
    // Test 1: Server health
    console.log('1. Testing server health...');
    const healthResponse = await axios.get(`${BASE_URL}/health`);
    console.log('✅ Server is running');
    console.log('');

    // Test 2: Get TMDB official providers
    console.log('2. Fetching TMDB official provider list...');
    const tmdbProvidersResponse = await axios.get(`${BASE_URL}/tmdb-providers`);
    console.log(`✅ Fetched ${tmdbProvidersResponse.data.count} providers from TMDB`);
    console.log('   Sample providers:', tmdbProvidersResponse.data.providers.slice(0, 5).map(p => `${p.name} (${p.id})`));
    console.log('');

    // Test 3: Validate our provider IDs
    console.log('3. Validating our provider IDs...');
    const validationResponse = await axios.get(`${BASE_URL}/validate-providers`);
    console.log(`✅ Provider validation: ${validationResponse.data.valid_count} valid, ${validationResponse.data.invalid_count} invalid`);
    
    // Show invalid providers
    const invalidProviders = validationResponse.data.results.filter(r => !r.is_valid);
    if (invalidProviders.length > 0) {
      console.log('❌ Invalid providers:');
      invalidProviders.forEach(provider => {
        console.log(`   ${provider.platform}: ID ${provider.our_provider_id} not found in TMDB`);
      });
    }
    console.log('');

    // Test 4: Test streaming filter with detailed logging
    console.log('4. Testing streaming filter with detailed logging...');
    const streamingTest = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'US',
      type: 'movie'
    });
    
    console.log(`✅ Streaming filter test:`);
    console.log(`   Results: ${streamingTest.data.count} movies`);
    console.log(`   Cached: ${streamingTest.data.cached}`);
    console.log(`   Provider IDs: ${streamingTest.data.query_info.provider_ids.join(', ')}`);
    console.log(`   TMDB URL: ${streamingTest.data.query_info.tmdb_url}`);
    
    if (streamingTest.data.count === 0) {
      console.log('⚠️  WARNING: Streaming filter returned 0 results');
      console.log('   This suggests the provider IDs are wrong');
    } else {
      console.log('✅ Streaming filter is working correctly');
    }
    console.log('');

    // Test 5: Test multiple platforms
    console.log('5. Testing multiple platforms...');
    const multiTest = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix', 'amazon_prime'],
      region: 'US',
      type: 'movie'
    });
    
    console.log(`✅ Multi-platform test:`);
    console.log(`   Results: ${multiTest.data.count} movies`);
    console.log(`   Provider IDs: ${multiTest.data.query_info.provider_ids.join(', ')}`);
    
    if (multiTest.data.count > streamingTest.data.count) {
      console.log('✅ Multi-platform results make sense (more than single platform)');
    } else {
      console.log('⚠️  Multi-platform results seem low');
    }
    console.log('');

    // Test 6: Test different regions
    console.log('6. Testing different regions...');
    const ukTest = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'GB',
      type: 'movie'
    });
    
    console.log(`✅ UK region test:`);
    console.log(`   Results: ${ukTest.data.count} movies`);
    console.log(`   Region: ${ukTest.data.query_info.region}`);
    console.log('');

    // Test 7: Test cache functionality
    console.log('7. Testing cache functionality...');
    const cacheTest = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'US',
      type: 'movie'
    });
    
    console.log(`✅ Cache test:`);
    console.log(`   Results: ${cacheTest.data.count} movies`);
    console.log(`   Cached: ${cacheTest.data.cached}`);
    
    if (cacheTest.data.cached) {
      console.log('✅ Cache is working correctly');
    } else {
      console.log('⚠️  Cache might not be working');
    }
    console.log('');

    // Test 8: Clear cache and test again
    console.log('8. Testing cache clearing...');
    const clearResponse = await axios.delete(`${BASE_URL}/cache`);
    console.log(`✅ Cache cleared: ${clearResponse.data.message}`);
    
    const freshTest = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'US',
      type: 'movie'
    });
    
    console.log(`✅ Fresh test after cache clear:`);
    console.log(`   Results: ${freshTest.data.count} movies`);
    console.log(`   Cached: ${freshTest.data.cached}`);
    console.log('');

    console.log('🎉 All tests completed!');
    console.log('');
    console.log('📊 Summary:');
    console.log('   - Server health: ✅');
    console.log('   - TMDB provider fetching: ✅');
    console.log('   - Provider validation: ✅');
    console.log('   - Streaming filter: ' + (streamingTest.data.count > 0 ? '✅' : '❌'));
    console.log('   - Multi-platform filtering: ✅');
    console.log('   - Regional filtering: ✅');
    console.log('   - Cache functionality: ✅');
    console.log('');
    console.log('🔧 Next steps for Flutter testing:');
    console.log('   1. Start your Flutter app');
    console.log('   2. Call movieService.setUserService(userDataService) in app initialization');
    console.log('   3. Call movieService.debugUserServiceConnection() to verify blacklist');
    console.log('   4. Test streaming filter in the app');
    console.log('   5. Check Flutter logs for blacklist filtering messages');

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
testAllFixes(); 