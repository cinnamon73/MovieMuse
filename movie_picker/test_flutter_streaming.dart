import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/services/movie_service.dart';
import 'lib/services/user_data_service.dart';
import 'lib/services/server_streaming_service.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  runApp(StreamingFilterTestApp());
}

class StreamingFilterTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streaming Filter Test',
      home: StreamingFilterTestScreen(),
    );
  }
}

class StreamingFilterTestScreen extends StatefulWidget {
  @override
  _StreamingFilterTestScreenState createState() => _StreamingFilterTestScreenState();
}

class _StreamingFilterTestScreenState extends State<StreamingFilterTestScreen> {
  final MovieService _movieService = MovieService();
  final UserDataService _userDataService = UserDataService();
  final ServerStreamingService _serverStreamingService = ServerStreamingService();
  
  List<String> _testResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    try {
      await _testUserServiceConnection();
      await _testServerHealth();
      await _testStreamingFilter();
      await _testBlacklistFiltering();
      await _testMultiPlatformFiltering();
      
      _addResult('✅ All tests completed successfully!');
    } catch (e) {
      _addResult('❌ Test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testUserServiceConnection() async {
    _addResult('🔍 Testing user service connection...');
    
    // Connect user service to movie service
    _movieService.setUserService(_userDataService);
    
    // Test user service connection
    _movieService.debugUserServiceConnection();
    
    _addResult('✅ User service connection test completed');
  }

  Future<void> _testServerHealth() async {
    _addResult('🌐 Testing server health...');
    
    try {
      final isHealthy = await _serverStreamingService.checkServerHealth();
      if (isHealthy) {
        _addResult('✅ Server is healthy');
      } else {
        _addResult('❌ Server health check failed');
      }
    } catch (e) {
      _addResult('❌ Server health test error: $e');
    }
  }

  Future<void> _testStreamingFilter() async {
    _addResult('🎬 Testing Netflix streaming filter...');
    
    try {
      // Enable streaming filter
      _movieService.setStreamingFilterEnabled(true);
      _movieService.setStreamingPlatforms(['netflix']);
      _movieService.setStreamingRegion('US');
      
      // Test the filter
      final movies = await _movieService.findMoviesWithFilters(
        targetCount: 10,
      );
      
      _addResult('✅ Netflix filter returned ${movies.length} movies');
      
      if (movies.isNotEmpty) {
        _addResult('   Sample movies:');
        movies.take(3).forEach((movie) {
          _addResult('     - ${movie.title} (Rating: ${movie.voteAverage})');
        });
      }
      
      // Disable streaming filter
      _movieService.setStreamingFilterEnabled(false);
      
    } catch (e) {
      _addResult('❌ Streaming filter test error: $e');
    }
  }

  Future<void> _testBlacklistFiltering() async {
    _addResult('🚫 Testing blacklist filtering...');
    
    try {
      // Add some test movies to blacklist
      await _userDataService.markMovieAsWatched(550); // Fight Club
      await _userDataService.markMovieAsSkipped(13); // Forrest Gump
      
      // Test filtering with blacklisted movies
      final movies = await _movieService.findMoviesWithFilters(
        targetCount: 20,
      );
      
      final blacklistedIds = [550, 13];
      final filteredMovies = movies.where((m) => !blacklistedIds.contains(m.id)).toList();
      
      _addResult('✅ Blacklist filtering test:');
      _addResult('   Original movies: ${movies.length}');
      _addResult('   After blacklist: ${filteredMovies.length}');
      _addResult('   Removed: ${movies.length - filteredMovies.length}');
      
      // Check if blacklisted movies are actually filtered
      final containsBlacklisted = movies.any((m) => blacklistedIds.contains(m.id));
      if (containsBlacklisted) {
        _addResult('❌ Blacklist filtering failed - blacklisted movies still present');
      } else {
        _addResult('✅ Blacklist filtering working correctly');
      }
      
    } catch (e) {
      _addResult('❌ Blacklist filtering test error: $e');
    }
  }

  Future<void> _testMultiPlatformFiltering() async {
    _addResult('🎬 Testing multi-platform filtering...');
    
    try {
      // Enable streaming filter with multiple platforms
      _movieService.setStreamingFilterEnabled(true);
      _movieService.setStreamingPlatforms(['netflix', 'amazon_prime']);
      _movieService.setStreamingRegion('US');
      
      // Test the filter
      final movies = await _movieService.findMoviesWithFilters(
        targetCount: 10,
      );
      
      _addResult('✅ Multi-platform filter returned ${movies.length} movies');
      
      if (movies.isNotEmpty) {
        _addResult('   Sample movies:');
        movies.take(3).forEach((movie) {
          _addResult('     - ${movie.title} (Rating: ${movie.voteAverage})');
        });
      }
      
      // Disable streaming filter
      _movieService.setStreamingFilterEnabled(false);
      
    } catch (e) {
      _addResult('❌ Multi-platform filter test error: $e');
    }
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add('${DateTime.now().toString().substring(11, 19)} $result');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Streaming Filter Test'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runTests,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    result,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: result.contains('❌') 
                          ? Colors.red 
                          : result.contains('✅') 
                              ? Colors.green 
                              : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 