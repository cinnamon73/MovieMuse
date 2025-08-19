import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ServerStreamingService {
  final Dio _dio;
  // Use localhost for Windows Flutter, 10.0.2.2 for Android emulator, and your computer's IP for physical devices
  static String get _serverBaseUrl {
    // 1) .env override (preferred)
    final dotEnvOverride = dotenv.env['SEMANTIC_SERVER_URL'];
    if (dotEnvOverride != null && dotEnvOverride.isNotEmpty) return dotEnvOverride;

    // 2) Compile-time or process environment (fallbacks)
    const compileTime = String.fromEnvironment('SEMANTIC_SERVER_URL');
    if (compileTime.isNotEmpty) return compileTime;
    try {
      final procEnv = Platform.environment['SEMANTIC_SERVER_URL'];
      if (procEnv != null && procEnv.isNotEmpty) return procEnv;
    } catch (_) {}

    // 3) Platform defaults
    if (kIsWeb) return 'http://localhost:3001';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3001';
      if (Platform.isIOS) return 'http://localhost:3001';
      // In production builds where no overrides are set, prefer the hosted server
      // so end-users don't need a local server.
      if (kReleaseMode) return 'https://moviemuse-s49g.onrender.com';
      return 'http://localhost:3001';
    } catch (_) {
      return 'http://localhost:3001';
    }
  }
  
  // Cache for platform mappings and query results
  final Map<String, dynamic> _platformCache = {};
  final Map<String, List<Movie>> _queryCache = {};
  
  // Cache TTL settings
  static const int _platformCacheTTL = 86400; // 24 hours in seconds
  static const int _queryCacheTTL = 600; // 10 minutes in seconds
  
  // Cache timestamps
  final Map<String, DateTime> _cacheTimestamps = {};

  ServerStreamingService() : _dio = Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.sendTimeout = const Duration(seconds: 10);
  }

  // Check if cache entry is still valid
  bool _isCacheValid(String key, int ttlSeconds) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    
    final now = DateTime.now();
    final age = now.difference(timestamp).inSeconds;
    return age < ttlSeconds;
  }

  // Get cached data if valid
  T? _getCachedData<T>(String key, int ttlSeconds) {
    if (_isCacheValid(key, ttlSeconds)) {
      return _cacheTimestamps.containsKey(key) ? _cacheTimestamps[key] as T : null;
    }
    return null;
  }

  // Set cache data with timestamp
  void _setCachedData<T>(String key, T data) {
    _cacheTimestamps[key] = DateTime.now();
    if (data is List<Movie>) {
      _queryCache[key] = data;
    } else {
      _platformCache[key] = data;
    }
  }

  // Get available platforms from server
  Future<List<Map<String, dynamic>>> getAvailablePlatforms() async {
    const cacheKey = 'available_platforms';
    
    // Check cache first
    final cached = _getCachedData<List<Map<String, dynamic>>>(cacheKey, _platformCacheTTL);
    if (cached != null) {
      debugPrint('✅ Returning cached platforms');
      return cached;
    }

    try {
      debugPrint('🌐 Fetching available platforms from server...');
      
      final response = await _dio.get('$_serverBaseUrl/platforms');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final platforms = List<Map<String, dynamic>>.from(data['platforms']);
          
          // Cache the results
          _setCachedData(cacheKey, platforms);
          
          debugPrint('✅ Fetched ${platforms.length} platforms from server');
          return platforms;
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching platforms: $e');
    }
    
    // Return empty list if server is unavailable
    return [];
  }

  // Filter movies by streaming platforms using server with pagination support
  Future<List<Movie>> filterMoviesByStreamingPlatforms({
    required List<String> platforms,
    String region = 'US',
    String type = 'movie',
    int targetCount = 100,
    int page = 1, // NEW: Support for pagination
  }) async {
    if (platforms.isEmpty) {
      debugPrint('⚠️ No platforms specified for streaming filter');
      return [];
    }

    // Create cache key with page number
    final cacheKey = 'streaming_${type}_${region}_${platforms.join(',')}_page_$page';
    
    // Check cache first
    final cached = _getCachedData<List<Movie>>(cacheKey, _queryCacheTTL);
    if (cached != null) {
      debugPrint('✅ Returning cached streaming filter results for page $page');
      return cached;
    }

    try {
      debugPrint('🎬 Filtering movies by streaming platforms: ${platforms.join(', ')}');
      debugPrint('   → Region: $region');
      debugPrint('   → Type: $type');
      debugPrint('   → Page: $page');
      debugPrint('   → Target count: $targetCount');
      debugPrint('   → Server URL: $_serverBaseUrl/filter/streaming');
      
      final response = await _dio.post(
        '$_serverBaseUrl/filter/streaming',
        data: {
          'platforms': platforms,
          'region': region,
          'type': type,
          'page': page, // NEW: Send page number to server
          'targetCount': targetCount, // NEW: Send target count to server
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final results = data['data'] as List;
          final movies = _processServerResults(results);
          
          // Cache the results
          _setCachedData(cacheKey, movies);
          
          debugPrint('✅ Server returned ${movies.length} movies for streaming filter (page $page)');
          debugPrint('   → Cached: ${data['cached']}');
          debugPrint('   → Query info: ${data['query_info']}');
          
          // NEW: Extract pagination information from server response
          final pagination = data['query_info']?['pagination'];
          if (pagination != null) {
            debugPrint('   → Pagination info:');
            debugPrint('     - Current page: ${pagination['current_page']}');
            debugPrint('     - Total pages: ${pagination['total_pages']}');
            debugPrint('     - Total results: ${pagination['total_results']}');
            debugPrint('     - Has more: ${pagination['has_more']}');
          }
          
          return movies;
        } else {
          debugPrint('❌ Server returned success: false');
          debugPrint('   → Error: ${data['error']}');
        }
      } else {
        debugPrint('❌ Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in server streaming filter: $e');
      debugPrint('   → This might be a connection issue to $_serverBaseUrl');
      debugPrint('   → Make sure the server is running and accessible');
    }
    
    // Return empty list if server is unavailable
    debugPrint('⚠️ Returning empty list due to server error');
    return [];
  }

  // Process server results into Movie objects
  List<Movie> _processServerResults(List<dynamic> results) {
    return results.map((item) {
      try {
        final bool isAdult = item['adult'] == true;

        // Drop adult content unless user has explicitly enabled it (handled in MovieService pipeline).
        // Since this service may be used independently, defensively filter here as well when possible.
        // Note: We don't have direct access to PrivacyService here, so only propagate the flag.

        final genreIds = item['genre_ids'] as List?;
        String genreName = 'Other';
        String subgenreName = 'Other';

        // Basic genre mapping (you might want to use the existing genre cache)
        if (genreIds != null && genreIds.isNotEmpty) {
          // This is a simplified mapping - in production, use the existing genre cache
          final genreMap = {
            28: 'Action', 12: 'Adventure', 16: 'Animation', 35: 'Comedy',
            80: 'Crime', 99: 'Documentary', 18: 'Drama', 10751: 'Family',
            14: 'Fantasy', 36: 'History', 27: 'Horror', 10402: 'Music',
            9648: 'Mystery', 10749: 'Romance', 878: 'Science Fiction',
            10770: 'TV Movie', 53: 'Thriller', 10752: 'War', 37: 'Western'
          };
          
          final firstGenreId = genreIds[0];
          genreName = genreMap[firstGenreId] ?? 'Other';
          
          if (genreIds.length > 1) {
            final secondGenreId = genreIds[1];
            subgenreName = genreMap[secondGenreId] ?? genreName;
          } else {
            subgenreName = genreName;
          }
        }

        final releaseDateStr = item['release_date'] as String?;
        final posterPath = item['poster_path'] as String?;
        final imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

        return Movie(
          id: item['id'] as int,
          title: item['title'] as String? ?? 'Unknown Title',
          description: item['overview'] as String? ?? 'No description available',
          posterUrl: posterPath != null 
              ? '$imageBaseUrl$posterPath'
              : 'https://via.placeholder.com/500x750?text=No+Poster',
          genre: genreName,
          subgenre: subgenreName,
          releaseDate: releaseDateStr?.substring(0, 4) ?? 'Unknown',
          voteAverage: (item['vote_average'] as num?)?.toDouble() ?? 0.0,
          language: item['original_language'] as String? ?? 'N/A',
          adult: isAdult,
          keywords: [], // Will be populated later if needed
        );
      } catch (e) {
        debugPrint('❌ Error processing server result: $e');
        return null;
      }
    }).whereType<Movie>().toList();
  }

  // NEW: Semantic search against general catalog via server embeddings
  Future<List<Map<String, dynamic>>> semanticSearch({
    required String description,
    int? yearFrom,
    int? yearTo,
    String language = 'en',
    int maxPages = 2,
  }) async {
    try {
      final response = await _dio.post('$_serverBaseUrl/semantic/search', data: {
        'description': description,
        'yearFrom': yearFrom,
        'yearTo': yearTo,
        'language': language,
        'maxPages': maxPages,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        final results = List<Map<String, dynamic>>.from(response.data['results']);
        return results;
      }
    } catch (e) {
      debugPrint('❌ Semantic search failed: $e');
    }
    return [];
  }

  // NEW: Semantic search constrained to platforms
  Future<List<Map<String, dynamic>>> semanticSearchOnPlatforms({
    required String description,
    required List<String> platforms,
    String region = 'US',
    String language = 'en',
  }) async {
    try {
      final response = await _dio.post('$_serverBaseUrl/semantic/streaming', data: {
        'description': description,
        'platforms': platforms,
        'region': region,
        'language': language,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['results']);
      }
    } catch (e) {
      debugPrint('❌ Semantic search (platforms) failed: $e');
    }
    return [];
  }

  // Check server streaming service health
  Future<bool> checkServerHealth() async {
    try {
      debugPrint('🌐 Checking server health at $_serverBaseUrl/health');
      
      final response = await _dio.get('$_serverBaseUrl/health');
      
      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('✅ Server is healthy: ${data['status']}');
        return true;
      } else {
        debugPrint('❌ Server health check failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Server health check error: $e');
      debugPrint('   → Server might not be running or accessible');
      return false;
    }
  }

  // Clear all caches
  void clearCache() {
    _platformCache.clear();
    _queryCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Cleared all server streaming service caches');
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'platformCacheSize': _platformCache.length,
      'queryCacheSize': _queryCache.length,
      'cacheEntries': _cacheTimestamps.length,
    };
  }

  // New: Fetch movie images (backdrops) from server with small cache
  final Map<int, List<Map<String, dynamic>>> _imagesCache = {};
  final Map<int, DateTime> _imagesCacheTs = {};
  static const int _imagesTTL = 60 * 60; // 1 hour

  Future<List<Map<String, dynamic>>> fetchMovieImages(int movieId) async {
    final ts = _imagesCacheTs[movieId];
    if (ts != null && DateTime.now().difference(ts).inSeconds < _imagesTTL) {
      final cached = _imagesCache[movieId];
      if (cached != null) return cached;
    }

    try {
      final resp = await _dio.get('$_serverBaseUrl/images/$movieId');
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final List<Map<String, dynamic>> images = List<Map<String, dynamic>>.from(resp.data['data'] ?? []);
        _imagesCache[movieId] = images;
        _imagesCacheTs[movieId] = DateTime.now();
        return images;
      }
    } catch (e) {
      debugPrint('❌ Error fetching images for $movieId: $e');
    }
    return [];
  }

  // Test the server connection
  Future<void> testServerConnection() async {
    debugPrint('🧪 Testing server connection...');
    
    try {
      final healthResponse = await _dio.get('$_serverBaseUrl/health');
      debugPrint('✅ Server health: ${healthResponse.data}');
      
      final platformsResponse = await _dio.get('$_serverBaseUrl/platforms');
      debugPrint('✅ Available platforms: ${platformsResponse.data['count']} platforms');
      
    } catch (e) {
      debugPrint('❌ Server connection test failed: $e');
    }
  }
} 