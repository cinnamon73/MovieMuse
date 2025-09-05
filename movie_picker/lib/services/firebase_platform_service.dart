import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';

class FirebasePlatformService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for platform movies
  final Map<String, List<Movie>> _platformCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(hours: 24);

  // Platform mapping
  static const Map<String, String> PLATFORM_NAMES = {
    'netflix': 'Netflix',
    'amazon_prime': 'Amazon Prime',
    'disney_plus': 'Disney+',
    'hulu': 'Hulu',
    'apple_tv': 'Apple TV+',
    'paramount_plus': 'Paramount+',
    'peacock': 'Peacock',
    'crunchyroll': 'Crunchyroll',
  };

  // Get movies for a specific platform
  Future<List<Movie>> getPlatformMovies(String platformKey) async {
    // Check cache first
    if (_isCacheValid(platformKey)) {
      debugPrint('📦 Using cached ${PLATFORM_NAMES[platformKey]} movies');
      return _platformCache[platformKey]!;
    }

    try {
      debugPrint('🔄 Fetching ${PLATFORM_NAMES[platformKey]} movies from Firestore...');
      
      final doc = await _firestore
          .collection('platformMovies')
          .doc(platformKey)
          .get();

      if (!doc.exists) {
        debugPrint('⚠️ No data found for $platformKey in Firestore');
        return [];
      }

      final data = doc.data();
      if (data == null || !data.containsKey('movies')) {
        debugPrint('⚠️ No movies data found for $platformKey');
        return [];
      }

      final List<dynamic> moviesData = data['movies'] as List<dynamic>;
      final List<Movie> movies = [];

      for (final movieData in moviesData) {
        try {
          final movie = _convertFirebaseMovieToMovie(movieData as Map<String, dynamic>);
          if (movie != null) {
            movies.add(movie);
          }
        } catch (e) {
          debugPrint('❌ Error converting movie: $e');
        }
      }

      // Cache the results
      _platformCache[platformKey] = movies;
      _cacheTimestamps[platformKey] = DateTime.now();

      debugPrint('✅ Loaded ${movies.length} ${PLATFORM_NAMES[platformKey]} movies from Firestore');
      return movies;

    } catch (error) {
      debugPrint('❌ Error fetching platform movies: $error');
      return [];
    }
  }

  // Affiliate override lookup: allow pasting provider-specific direct URLs
  // Collection: affiliate_overrides
  // Doc ID: movie_<movieId>
  // Field name pattern: <provider>_<countryCode>, e.g., amazon_prime_gb
  Future<String?> getDirectProviderUrl({
    required int movieId,
    required String provider,
    String countryCode = 'GB',
  }) async {
    try {
      final docId = 'movie_${movieId.toString()}';
      final doc = await _firestore.collection('affiliate_overrides').doc(docId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      final key = '${provider.toLowerCase()}_${countryCode.toLowerCase()}';
      final url = data[key] as String?;
      return url;
    } catch (e) {
      return null;
    }
  }

  // Convert Firebase movie data to Movie model
  Movie? _convertFirebaseMovieToMovie(Map<String, dynamic> movieData) {
    try {
      final id = movieData['id'] as int?;
      if (id == null) return null;

      final title = movieData['title'] as String? ?? 'Unknown Title';
      final overview = movieData['overview'] as String? ?? 'No description available';
      final posterPath = movieData['poster_path'] as String?;
      final releaseDate = movieData['release_date'] as String?;
      final voteAverage = (movieData['vote_average'] as num?)?.toDouble() ?? 0.0;
      final originalLanguage = movieData['original_language'] as String? ?? 'en';
      final adult = movieData['adult'] as bool? ?? false;

      // Extract genre info
      final genreIds = movieData['genre_ids'] as List<dynamic>?;
      String genreName = 'Other';
      String subgenreName = 'Other';

      if (genreIds != null && genreIds.isNotEmpty) {
        // You might want to maintain a genre mapping here
        genreName = _getGenreName(genreIds[0] as int);
        subgenreName = genreIds.length > 1 ? _getGenreName(genreIds[1] as int) : genreName;
      }

      return Movie(
        id: id,
        title: title,
        description: overview,
        posterUrl: posterPath != null 
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : 'https://via.placeholder.com/500x750?text=No+Poster',
        genre: genreName,
        subgenre: subgenreName,
        releaseDate: releaseDate?.substring(0, 4) ?? 'Unknown',
        voteAverage: voteAverage,
        language: originalLanguage,
        adult: adult,
        keywords: [], // Will be populated later if needed
      );
    } catch (e) {
      debugPrint('❌ Error converting Firebase movie data: $e');
      return null;
    }
  }

  // Simple genre mapping (you might want to expand this)
  String _getGenreName(int genreId) {
    const genreMap = {
      28: 'Action',
      12: 'Adventure',
      16: 'Animation',
      35: 'Comedy',
      80: 'Crime',
      99: 'Documentary',
      18: 'Drama',
      10751: 'Family',
      14: 'Fantasy',
      36: 'History',
      27: 'Horror',
      10402: 'Music',
      9648: 'Mystery',
      10749: 'Romance',
      878: 'Science Fiction',
      10770: 'TV Movie',
      53: 'Thriller',
      10752: 'War',
      37: 'Western',
    };
    return genreMap[genreId] ?? 'Other';
  }

  // Check if cache is still valid
  bool _isCacheValid(String platformKey) {
    if (!_platformCache.containsKey(platformKey)) return false;
    
    final timestamp = _cacheTimestamps[platformKey];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  // Clear cache for a specific platform
  void clearCache(String platformKey) {
    _platformCache.remove(platformKey);
    _cacheTimestamps.remove(platformKey);
    debugPrint('🗑️ Cleared cache for $platformKey');
  }

  // Clear all cache
  void clearAllCache() {
    _platformCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Cleared all platform cache');
  }

  // Get cache status
  Map<String, dynamic> getCacheStatus() {
    final status = <String, dynamic>{};
    
    for (final platform in PLATFORM_NAMES.keys) {
      final hasCache = _platformCache.containsKey(platform);
      final timestamp = _cacheTimestamps[platform];
      final isValid = hasCache && timestamp != null && 
          DateTime.now().difference(timestamp) < _cacheExpiry;
      
      status[platform] = {
        'hasCache': hasCache,
        'isValid': isValid,
        'movieCount': hasCache ? _platformCache[platform]!.length : 0,
        'lastUpdated': timestamp?.toIso8601String(),
      };
    }
    
    return status;
  }

  // Get all supported platforms
  List<String> getSupportedPlatforms() {
    return PLATFORM_NAMES.keys.toList();
  }

  // Get platform display name
  String getPlatformDisplayName(String platformKey) {
    return PLATFORM_NAMES[platformKey] ?? platformKey;
  }
} 