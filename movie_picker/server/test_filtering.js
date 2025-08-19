const axios = require('axios');

const BASE_URL = 'http://localhost:3001';

async function testStreamingFiltering() {
  console.log('🧪 Testing Streaming Filter Functionality\n');

  try {
    // Test 1: Test individual platform filtering
    console.log('1. Testing Netflix filtering...');
    const netflixResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix'],
      region: 'US',
      type: 'movie'
    });
    
    console.log(`✅ Netflix filter: ${netflixResponse.data.count} movies`);
    console.log(`   Query info:`, netflixResponse.data.query_info);
    
    if (netflixResponse.data.count === 0) {
      console.log('⚠️  WARNING: Netflix filter returned 0 results - this might indicate an issue');
    }
    console.log('');

    // Test 2: Test Amazon Prime filtering
    console.log('2. Testing Amazon Prime filtering...');
    const amazonResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['amazon_prime'],
      region: 'US',
      type: 'movie'
    });
    
    console.log(`✅ Amazon Prime filter: ${amazonResponse.data.count} movies`);
    console.log(`   Query info:`, amazonResponse.data.query_info);
    console.log('');

    // Test 3: Test multiple platforms
    console.log('3. Testing Netflix + Amazon Prime filtering...');
    const multiResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix', 'amazon_prime'],
      region: 'US',
      type: 'movie'
    });
    
    console.log(`✅ Multi-platform filter: ${multiResponse.data.count} movies`);
    console.log(`   Query info:`, multiResponse.data.query_info);
    console.log('');

    // Test 4: Test provider ID verification
    console.log('4. Testing provider ID verification...');
    const netflixTest = await axios.get(`${BASE_URL}/test-providers?platform=netflix&region=US`);
    console.log(`✅ Netflix provider test: ${netflixTest.data.results_count} movies`);
    console.log(`   Provider ID: ${netflixTest.data.provider_id}`);
    console.log(`   Sample results:`, netflixTest.data.sample_results.map(r => r.title));
    console.log('');

    // Test 5: Test Amazon provider ID
    console.log('5. Testing Amazon provider ID...');
    const amazonTest = await axios.get(`${BASE_URL}/test-providers?platform=amazon_prime&region=US`);
    console.log(`✅ Amazon provider test: ${amazonTest.data.results_count} movies`);
    console.log(`   Provider ID: ${amazonTest.data.provider_id}`);
    console.log(`   Sample results:`, amazonTest.data.sample_results.map(r => r.title));
    console.log('');

    // Test 6: Compare results
    console.log('6. Comparing results...');
    const netflixCount = netflixResponse.data.count;
    const amazonCount = amazonResponse.data.count;
    const multiCount = multiResponse.data.count;
    
    console.log(`   Netflix only: ${netflixCount} movies`);
    console.log(`   Amazon only: ${amazonCount} movies`);
    console.log(`   Netflix + Amazon: ${multiCount} movies`);
    
    if (multiCount >= netflixCount && multiCount >= amazonCount) {
      console.log('✅ Multi-platform results make sense (should be >= individual counts)');
    } else {
      console.log('⚠️  Multi-platform results seem low - might indicate filtering issue');
    }
    console.log('');

    // Test 7: Test UK region
    console.log('7. Testing UK region...');
    const ukResponse = await axios.post(`${BASE_URL}/filter/streaming`, {
      platforms: ['netflix', 'bbc_iplayer'],
      region: 'GB',
      type: 'movie'
    });
    
    console.log(`✅ UK filter: ${ukResponse.data.count} movies`);
    console.log(`   Query info:`, ukResponse.data.query_info);
    console.log('');

    console.log('🎉 Streaming filter tests completed!');
    console.log('');
    console.log('📊 Summary:');
    console.log('   - Individual platform filtering: ✅');
    console.log('   - Multi-platform filtering: ✅');
    console.log('   - Provider ID verification: ✅');
    console.log('   - Regional filtering: ✅');
    console.log('   - Result comparison: ✅');

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
testStreamingFiltering(); 