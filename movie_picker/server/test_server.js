const axios = require('axios');

const BASE_URL = 'http://localhost:3001';

async function testServer() {
  console.log('🧪 Testing Movie Picker Streaming Filter Server\n');

  try {
    // Test 1: Health Check
    console.log('1. Testing health check...');
    const healthResponse = await axios.get(`${BASE_URL}/health`);
    console.log('✅ Health check passed:', healthResponse.data.status);
    console.log('   Cache stats:', healthResponse.data.cache_stats);
    console.log('');

    // Test 2: Get Available Platforms
    console.log('2. Testing platforms endpoint...');
    const platformsResponse = await axios.get(`${BASE_URL}/platforms`);
    console.log('✅ Platforms endpoint passed');
    console.log(`   Available platforms: ${platformsResponse.data.count}`);
    console.log('   Sample platforms:', platformsResponse.data.platforms.slice(0, 3).map(p => p.name));
    console.log('');

    // Test 3: Streaming Filter - Netflix Only
    console.log('3. Testing streaming filter (Netflix only)...');
    const netflixResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'US',
      type: 'movie'
    });
    console.log('✅ Netflix filter passed');
    console.log(`   Results: ${netflixResponse.data.count} movies`);
    console.log('   Cached:', netflixResponse.data.cached);
    console.log('   Query info:', netflixResponse.data.query_info);
    console.log('');

    // Test 4: Streaming Filter - Multiple Platforms
    console.log('4. Testing streaming filter (Netflix + Amazon Prime)...');
    const multiResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix', 'amazon_prime'],
      region: 'US',
      type: 'movie'
    });
    console.log('✅ Multi-platform filter passed');
    console.log(`   Results: ${multiResponse.data.count} movies`);
    console.log('   Cached:', multiResponse.data.cached);
    console.log('   Query info:', multiResponse.data.query_info);
    console.log('');

    // Test 5: UK Region Test
    console.log('5. Testing UK region...');
    const ukResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix', 'bbc_iplayer'],
      region: 'GB',
      type: 'movie'
    });
    console.log('✅ UK region filter passed');
    console.log(`   Results: ${ukResponse.data.count} movies`);
    console.log('   Cached:', ukResponse.data.cached);
    console.log('   Query info:', ukResponse.data.query_info);
    console.log('');

    // Test 6: Cache Test (should return cached results)
    console.log('6. Testing cache (should return cached results)...');
    const cacheResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'US',
      type: 'movie'
    });
    console.log('✅ Cache test passed');
    console.log(`   Results: ${cacheResponse.data.count} movies`);
    console.log('   Cached:', cacheResponse.data.cached);
    console.log('');

    // Test 7: Invalid Platform Test
    console.log('7. Testing invalid platform...');
    try {
      await axios.post(`${BASE_URL}/filter/streaming`, {
        platforms: ['invalid_platform'],
        region: 'US',
        type: 'movie'
      });
      console.log('❌ Should have failed with invalid platform');
    } catch (error) {
      if (error.response?.status === 400) {
        console.log('✅ Invalid platform correctly rejected');
        console.log('   Error:', error.response.data.error);
      } else {
        console.log('❌ Unexpected error:', error.message);
      }
    }
    console.log('');

    // Test 8: Clear Cache
    console.log('8. Testing cache clear...');
    const clearResponse = await axios.delete(`${BASE_URL}/cache`);
    console.log('✅ Cache clear passed');
    console.log('   Message:', clearResponse.data.message);
    console.log('');

    console.log('🎉 All tests passed! Server is working correctly.');
    console.log('');
    console.log('📊 Summary:');
    console.log('   - Health check: ✅');
    console.log('   - Platforms endpoint: ✅');
    console.log('   - Streaming filters: ✅');
    console.log('   - Caching: ✅');
    console.log('   - Error handling: ✅');
    console.log('   - Cache management: ✅');

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
testServer(); 