import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/movie_service.dart';
import 'services/user_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simple test to verify streaming filter is working
void testStreamingFilter() async {
  debugPrint('🧪 Testing Streaming Filter Integration');
  
  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  final userDataService = UserDataService(prefs);
  final movieService = MovieService();
  
  // Connect services
  movieService.setUserService(userDataService);
  await userDataService.initialize();
  
  // Debug user service connection
  movieService.debugUserServiceConnection();
  
  // Test streaming filter
  debugPrint('\n🎬 Testing streaming filter...');
  movieService.setStreamingFilterEnabled(true);
  movieService.setStreamingPlatforms(['netflix']);
  movieService.setStreamingRegion('US');
  
  debugPrint('✅ Streaming filter enabled with Netflix');
  
  // Test finding movies
  try {
    final movies = await movieService.findMoviesWithFilters(targetCount: 10);
    debugPrint('✅ Found ${movies.length} movies with streaming filter');
    
    if (movies.isNotEmpty) {
      debugPrint('   Sample movies:');
      movies.take(3).forEach((movie) {
        debugPrint('   - ${movie.title} (ID: ${movie.id})');
      });
    }
  } catch (e) {
    debugPrint('❌ Error finding movies: $e');
  }
  
  debugPrint('\n🎉 Streaming filter test completed!');
}

// Run this in your app to test
void main() {
  testStreamingFilter();
} 