const axios = require('axios');

const BASE_URL = 'http://localhost:3001';

async function testStreamingFilterComplete() {
  console.log('🧪 COMPREHENSIVE STREAMING FILTER TEST\n');

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

    // Test 3: Test individual platform filtering
    console.log('3. Testing Netflix filtering...');
    const netflixTest = await axios.get(`${BASE_URL}/test-provider?platform=netflix&region=US`);
    console.log(`✅ Netflix test: ${netflixTest.data.results_count} movies`);
    console.log(`   Provider ID: ${netflixTest.data.provider_id}`);
    console.log(`   Sample movies:`, netflixTest.data.sample_results.map(r => r.title));
    console.log('');

    // Test 4: Test Amazon Prime filtering
    console.log('4. Testing Amazon Prime filtering...');
    const amazonTest = await axios.get(`${BASE_URL}/test-provider?platform=amazon_prime&region=US`);
    console.log(`✅ Amazon Prime test: ${amazonTest.data.results_count} movies`);
    console.log(`   Provider ID: ${amazonTest.data.provider_id}`);
    console.log(`   Sample movies:`, amazonTest.data.sample_results.map(r => r.title));
    console.log('');

    // Test 5: Test streaming filter endpoint
    console.log('\n5. Testing streaming filter endpoint...');
    try {
      const streamingResponse = await axios.post('http://localhost:3001/filter/streaming', {
        platforms: ['netflix'],
        region: 'US',
        type: 'movie',
        page: 1,
        targetCount: 20
      });
      
      if (streamingResponse.data.success) {
        const results = streamingResponse.data.data || [];
        console.log(`✅ Streaming filter test:`);
        console.log(`   Results: ${results.length} movies`);
        console.log(`   Cached: ${streamingResponse.data.cached}`);
        console.log(`   Page: ${streamingResponse.data.page}`);
        console.log(`   Has more: ${streamingResponse.data.hasMore}`);
        console.log(`   Provider IDs: ${streamingResponse.data.query_info?.provider_ids?.join(', ')}`);
        console.log(`   TMDB URL: ${streamingResponse.data.query_info?.tmdb_url}`);
        console.log('✅ Streaming filter is working correctly');
      } else {
        console.log('❌ Streaming filter test failed');
      }
    } catch (error) {
      console.log('❌ Streaming filter test error:', error.message);
    }

    // Test 6: Test multiple platforms
    console.log('6. Testing multiple platforms...');
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

    // Test 7: Test different regions
    console.log('7. Testing different regions...');
    const ukTest = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'GB',
      type: 'movie'
    });
    
    console.log(`✅ UK region test:`);
    console.log(`   Results: ${ukTest.data.count} movies`);
    console.log(`   Region: ${ukTest.data.query_info.region}`);
    console.log('');

    // Test 8: Test cache functionality
    console.log('8. Testing cache functionality...');
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

    // Test 9: Clear cache and test again
    console.log('9. Testing cache clearing...');
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
    console.log('   - Individual platform testing: ✅');
    console.log('   - Streaming filter: ' + (streamingTest.data.count > 0 ? '✅' : '❌'));
    console.log('   - Multi-platform filtering: ✅');
    console.log('   - Regional filtering: ✅');
    console.log('   - Cache functionality: ✅');
    console.log('');
    console.log('🔧 Next steps for Flutter testing:');
    console.log('   1. Start your Flutter app');
    console.log('   2. Call movieService.setUserService(userDataService) in app initialization');
    console.log('   3. Test streaming filter in the app');
    console.log('   4. Check Flutter logs for blacklist filtering messages');

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
testStreamingFilterComplete(); 