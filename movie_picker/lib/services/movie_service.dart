import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'dart:io';
import '../models/movie.dart';
import '../models/user_preferences.dart';
import 'performance_service.dart';
import 'request_manager.dart';
import 'firebase_platform_service.dart';

// Helper class for platform page results
class PlatformPageResult {
  final List<Movie> movies;
  final int currentPage;
  final int totalPages; 
  final int totalResults;
  
  PlatformPageResult({
    required this.movies,
    required this.currentPage,
    required this.totalPages,
    required this.totalResults,
  });
}

class MovieService {
  final Dio _dio;
  final PerformanceService _performanceService = PerformanceService();
  final RequestManager _requestManager = RequestManager();
  final FirebasePlatformService _firebasePlatformService = FirebasePlatformService();
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  // Get API key from environment variables for security
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  Map<int, String>? _genreCache;

  // Reference to recommendation service for user preferences
  dynamic _recommendationService;
  
  // Reference to privacy service for adult content settings
  dynamic _privacyService;

  // Local movie cache for instant filtering
  final List<Movie> _movieCache = [];
  final Set<int> _cachedMovieIds = {}; // Track IDs to avoid duplicates
  int _lastFetchedPage = 0;
  bool _isPreloading = false;

  // Network connectivity tracking
  bool _hasNetworkIssues = false;
  DateTime? _lastNetworkError;

  // Keyword cache to avoid repeated API calls
  final Map<int, List<String>> _keywordCache = {};
  // External IDs cache (e.g., IMDb)
  final Map<int, Map<String, String>> _externalIdsCache = {};

  // Current filter state for API calls
  String? _selectedLanguage;
  double? _minVoteAverage;
  double? _maxVoteAverage;
  int? _releaseYear;
  int? _minRuntime;
  int? _maxRuntime;
  String? _releaseStatus;
  String? _selectedPerson; // New person filter
  String? _selectedPersonType; // 'actor' or 'director'

  // Map of genre names to IDs for discover endpoint
  Map<String, int> _genreNameToId = {};

  // Cache for filter combinations to avoid redundant processing
  final Map<String, List<Movie>> _filterCache = {};

  // Cache for cast and crew data
  final Map<int, Map<String, dynamic>> _castCrewCache = {};

  // Cache for person search results to avoid repeated API calls
  final Map<String, int?> _personIdCache = {};
  final Map<String, List<Movie>> _personMoviesCache = {};

  // Cache for watch providers to avoid repeated API calls
  final Map<int, Map<String, dynamic>> _watchProvidersCache = {};

  // Add this field to store the user service reference
  dynamic _userService;

  // Platform filter state management
  String? _selectedPlatform = null;  // 'netflix', 'amazon_prime', 'disney_plus', etc.
  bool _isPlatformFetching = false;  // Prevents duplicate platform fetches
  List<Movie> _platformMovieStack = [];  // Complete platform movie collection
  int _platformFetchProgress = 0;  // Current page being fetched
  int _totalPlatformPages = 0;  // Total pages available for this platform
  bool _platformFetchComplete = false;  // All pages fetched for current platform
  
  // Dynamic loading state
  bool _isLoadingMorePlatformMovies = false;
  bool _hasMorePlatformPages = true;
  int _currentPlatformPage = 1;
  String? _currentPlatformProviderId;

  // Platform mapping for API calls (TMDB provider IDs)
  static const Map<String, String> PLATFORM_PROVIDERS = {
    'netflix': '8',        // Netflix provider ID
    'amazon_prime': '119', // Amazon Prime provider ID  
    'disney_plus': '337',  // Disney+ provider ID
    'hbo_max': '384',      // HBO Max provider ID
    'hulu': '15',          // Hulu provider ID
    'apple_tv': '350',     // Apple TV+ provider ID
    'paramount_plus': '531', // Paramount+ provider ID
    'peacock': '386',      // Peacock provider ID
    'crunchyroll': '283',  // Crunchyroll provider ID
  };

  // Platform filter getters
  String? get selectedPlatform => _selectedPlatform;
  bool get isPlatformFetching => _isPlatformFetching;
  List<Movie> get platformMovieStack => List.unmodifiable(_platformMovieStack);
  int get platformFetchProgress => _platformFetchProgress;
  int get totalPlatformPages => _totalPlatformPages;
  bool get platformFetchComplete => _platformFetchComplete;
  bool get isLoadingMorePlatformMovies => _isLoadingMorePlatformMovies;
  bool get hasMorePlatformPages => _hasMorePlatformPages;
  int get currentPlatformPage => _currentPlatformPage;
  String? get currentPlatformProviderId => _currentPlatformProviderId;

  MovieService() : _dio = Dio() {
    // Validate API key is loaded
    if (_apiKey.isEmpty) {
      throw Exception('TMDB API key not configured. Check your .env file.');
    }
    
    _dio.options.queryParameters = {'api_key': _apiKey};
    _dio.options.validateStatus = (status) => status! < 500;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.sendTimeout = const Duration(seconds: 10);
    
    // Add network error interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        _handleNetworkError(error);
        handler.next(error);
      },
    ));
  }

  // Handle network errors with detailed logging
  void _handleNetworkError(DioException error) {
    _hasNetworkIssues = true;
    _lastNetworkError = DateTime.now();
    
    String errorMessage = 'Unknown network error';
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage = 'Connection timeout - check internet connection';
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Response timeout - slow internet connection';
        break;
      case DioExceptionType.connectionError:
        if (error.error is SocketException) {
          final socketError = error.error as SocketException;
          if (socketError.osError?.errorCode == 7) {
            errorMessage = 'DNS resolution failed - no internet or blocked';
          } else {
            errorMessage = 'Network connection failed: ${socketError.message}';
          }
        } else {
          errorMessage = 'Connection error: ${error.error}';
        }
        break;
      case DioExceptionType.badResponse:
        errorMessage = 'Server error: ${error.response?.statusCode}';
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request cancelled';
        break;
      case DioExceptionType.unknown:
        errorMessage = 'Unknown error: ${error.error}';
        break;
      default:
        errorMessage = 'Network error: ${error.message}';
    }
    
    debugPrint('🚨 NETWORK ERROR: $errorMessage');
    debugPrint('🚨 Request URL: ${error.requestOptions.uri}');
    debugPrint('🚨 Error Type: ${error.type}');
    
    if (kDebugMode) {
      debugPrint('🚨 Full error details: ${error.toString()}');
    }
  }

  // Check network connectivity before making requests
  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Quick connectivity test with Google DNS
      final result = await InternetAddress.lookup('8.8.8.8');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _hasNetworkIssues = false;
        debugPrint('🌐 Network connectivity: OK');
        return true;
      }
    } catch (e) {
      debugPrint('🚨 Network connectivity check failed: $e');
    }
    
    _hasNetworkIssues = true;
    _lastNetworkError = DateTime.now();
    return false;
  }

  // Get network status for UI
  bool get hasNetworkIssues => _hasNetworkIssues;
  DateTime? get lastNetworkError => _lastNetworkError;

  // Set the recommendation service reference for tag-based scoring
  void setRecommendationService(dynamic recommendationService) {
    _recommendationService = recommendationService;
  }

  // Get user preferences for scoring
  dynamic get _userPreferences => _recommendationService?.userPreferences;

  // Set the user service reference in movie service
  void setUserService(dynamic userService) {
    _userService = userService;
  }

  // Set the privacy service reference
  void setPrivacyService(dynamic privacyService) {
    _privacyService = privacyService;
  }

  // Helper method to get adult content setting
  bool _shouldIncludeAdultContent() {
    final result = _privacyService?.isAdultContentEnabled() ?? false;
    debugPrint('🔞 Adult content check: enabled=$result, privacyService=${_privacyService != null}');
    return result;
  }

  // Setters for filters
  void setLanguage(String? language) => _selectedLanguage = language;
  void setVoteAverageRange(double? min, double? max) {
    _minVoteAverage = min;
    _maxVoteAverage = max;
  }

  void setReleaseYear(int? year) => _releaseYear = year;
  void setRuntimeRange(int? min, int? max) {
    _minRuntime = min;
    _maxRuntime = max;
  }

  void setReleaseStatus(String? status) => _releaseStatus = status;
  void setPerson(String? person, String? personType) {
    _selectedPerson = person;
    _selectedPersonType = personType;
  }

  // Clear cache when privacy settings change
  void clearCacheForPrivacyChange() {
    _movieCache.clear();
    _cachedMovieIds.clear();
    _filterCache.clear();
    debugPrint('🔞 Cleared movie cache due to privacy settings change');
  }

  // Reset all filters
  void resetFilters() {
    _selectedLanguage = null;
    _minVoteAverage = null;
    _maxVoteAverage = null;
    _releaseYear = null;
    _minRuntime = null;
    _maxRuntime = null;
    _releaseStatus = null;
    _selectedPerson = null;
    _selectedPersonType = null;
    _filterCache.clear();
    debugPrint('🔄 All movie filters reset');
  }

  // Create a unique request key based on filter parameters
  String _createRequestKey({
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds,
    int targetCount = 100,
    int maxPages = 500,
    String? person,
    String? personType,
  }) {
    final parts = <String>[];
    
    if (selectedGenres != null && selectedGenres.isNotEmpty) {
      parts.add('genres:${selectedGenres.join(',')}');
    }
    
    if (language != null && language.isNotEmpty) {
      parts.add('lang:$language');
    }
    
    if (timePeriod != null && timePeriod != 'All Years') {
      parts.add('time:$timePeriod');
    }
    
    if (minRating != null && minRating > 0) {
      parts.add('rating:$minRating');
    }
    
    if (excludeIds != null && excludeIds.isNotEmpty) {
      parts.add('exclude:${excludeIds.length}'); // Just count, not all IDs
    }
    
    if (person != null && personType != null) {
      parts.add('person:$personType:$person');
    }
    
    parts.add('target:$targetCount');
    parts.add('maxPages:$maxPages');
    
    return parts.join('|');
  }

  // Get request manager stats for debugging
  Map<String, dynamic> getRequestManagerStats() {
    return _requestManager.getStats();
  }

  // Get current cache size
  int get cacheSize => _movieCache.length;

  // Check if we have enough movies in cache
  bool get hasEnoughMovies => _movieCache.length >= 200;

  // Preload movies into local cache
  Future<void> preloadMovies({
    int targetCount = 200,
    List<String>? preferredGenres,
  }) async {
    if (_movieCache.length >= targetCount) return;

    final requestKey = 'preload_movies_${preferredGenres?.join('_') ?? 'all'}_$targetCount';
    
    return await _requestManager.deduplicate(requestKey, () async {
    return await _performanceService.monitorApiCall('preload_movies', () async {
      await _ensureGenreMap();

      while (_movieCache.length < targetCount && _lastFetchedPage < 500) {
        try {
          _lastFetchedPage++;

          final queryParams = {
            'api_key': _apiKey,
            'page': _lastFetchedPage,
            'sort_by': 'popularity.desc',
            'include_adult': _shouldIncludeAdultContent(),
            'vote_count.gte': 100,
            'vote_average.gte': 5.0,
          };

          // Add genre filter if preferred genres are specified
          if (preferredGenres != null && preferredGenres.isNotEmpty) {
            final genreIds =
                preferredGenres
                    .map((genre) => _genreNameToId[genre])
                    .where((id) => id != null)
                    .toList();
            if (genreIds.isNotEmpty) {
              queryParams['with_genres'] = genreIds.join(',');
            }
          }

          final response = await _dio.get(
            '$_baseUrl/discover/movie',
            queryParameters: queryParams,
          );

          if (response.statusCode == 200) {
            final results = response.data['results'] as List;
            final newMovies = _processMovieResults(results);

            int addedCount = 0;
            for (final movie in newMovies) {
              if (!_cachedMovieIds.contains(movie.id)) {
                _movieCache.add(movie);
                _cachedMovieIds.add(movie.id);
                addedCount++;
              }
            }

            if (addedCount == 0) {
              break;
            }
          }
        } catch (e) {
          debugPrint('Error fetching page $_lastFetchedPage: $e');
          break;
        }
      }

      // Start background keyword fetching for movies without keywords
      _fetchKeywordsInBackground();
      });
    });
  }

  // Background keyword fetching
  void _fetchKeywordsInBackground() async {
    final moviesToFetch =
        _movieCache.where((movie) => movie.keywords.isEmpty).take(50).toList();

    if (moviesToFetch.isNotEmpty) {
      for (final movie in moviesToFetch) {
        try {
          final keywords = await fetchMovieKeywords(movie.id);
          // Update the movie in cache with keywords
          final index = _movieCache.indexWhere((m) => m.id == movie.id);
          if (index != -1) {
            _movieCache[index] = movie.copyWith(keywords: keywords);
          }
        } catch (e) {
          // Silently continue with other movies
        }
      }
    }
  }

  // Fetch movies from API for a specific page
  Future<List<Movie>> _fetchMoviesFromApi({
    required int page,
    List<String>? preferredGenres,
  }) async {
    await _ensureGenreMap();

    final queryParams = {
      'page': page,
      'api_key': _apiKey,
      'sort_by': 'popularity.desc',
      'include_adult': _shouldIncludeAdultContent(),
      'include_video': false,
    };

    // Add genre filter if specified (use API filtering to reduce data)
    if (preferredGenres != null && preferredGenres.isNotEmpty) {
      List<int> genreIds = [];
      for (var genre in preferredGenres) {
        final genreId = _genreNameToId[genre];
        if (genreId != null) {
          genreIds.add(genreId);
        }
      }
      if (genreIds.isNotEmpty) {
        queryParams['with_genres'] = genreIds.join(',');
      }
    }

    // Add other API filters to reduce data transfer
    if (_selectedLanguage != null && _selectedLanguage!.isNotEmpty) {
      queryParams['with_original_language'] = _selectedLanguage!;
    }

    if (_releaseYear != null) {
      queryParams['primary_release_year'] = _releaseYear.toString();
    }

    final response = await _dio.get(
      '$_baseUrl/discover/movie',
      queryParameters: queryParams,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load movies: ${response.statusCode}');
    }

    final results = response.data['results'];
    return _processMovieResults(results);
  }

  // Enhanced filtering with IMMEDIATE direct API query as primary method
  Future<List<Movie>> findMoviesWithFilters({
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds,
    int targetCount = 100,
    int maxPages = 500, // Increased for more comprehensive search
    String? person,
    String? personType,
  }) async {
    // Create a unique request key based on all parameters
    final requestKey = _createRequestKey(
      selectedGenres: selectedGenres,
      language: language,
      timePeriod: timePeriod,
      minRating: minRating,
      excludeIds: excludeIds,
      targetCount: targetCount,
      maxPages: maxPages,
      person: person,
      personType: personType,
    );

    return await _requestManager.deduplicate(requestKey, () async {
    // STEP 1: IMMEDIATE direct TMDB API query with exact filters (PRIMARY METHOD)
    final directApiResults = await _queryTmdbDirectlyWithFilters(
      selectedGenres: selectedGenres,
      language: language,
      timePeriod: timePeriod,
      minRating: minRating,
      excludeIds: excludeIds,
      targetCount: targetCount,
      maxPages: maxPages,
      person: person,
      personType: personType,
    );

    // If we got good results from direct API, use them as primary source
    if (directApiResults.isNotEmpty) {
      // Add new discoveries to cache for future use (but don't rely on cache)
      int addedToCache = 0;
      for (final movie in directApiResults) {
        if (!_cachedMovieIds.contains(movie.id)) {
          _movieCache.add(movie);
          _cachedMovieIds.add(movie.id);
          addedToCache++;
        }
      }

      // Clear filter cache since we have fresh data
      _filterCache.clear();

      return sortMoviesByQuality(
        directApiResults,
        userPreferences: _userPreferences,
      );
    }

    // STEP 2: FALLBACK to cached movies only if direct API returned nothing
    final cachedMatches = await _filterCachedMoviesWithOptions(
      selectedGenres: selectedGenres,
      language: language,
      timePeriod: timePeriod,
      minRating: minRating,
      excludeIds: excludeIds,
      person: person,
      personType: personType,
    );

    return sortMoviesByQuality(
      cachedMatches,
      userPreferences: _userPreferences,
    );
    });
  }

  // IMMEDIATE TMDB API query with comprehensive search strategies
  Future<List<Movie>> _queryTmdbDirectlyWithFilters({
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds,
    int targetCount = 100,
    int maxPages = 500,
    String? person,
    String? personType,
  }) async {
    await _ensureGenreMap();

    // FAST PERSON FILTERING: Use direct TMDB person endpoints
    if (person != null && personType != null) {
      return await _searchMoviesByPersonOptimized(
        personName: person,
        personType: personType,
        selectedGenres: selectedGenres,
        language: language,
        timePeriod: timePeriod,
        minRating: minRating,
        excludeIds: excludeIds,
        targetCount: targetCount,
      );
    }

    final allMatches = <Movie>[];
    int pagesSearched = 0;

    // Use multiple search strategies for comprehensive coverage
    final searchStrategies = [
      {
        'sort': 'popularity.desc',
        'weight': 0.4,
        'pages': (maxPages * 0.4).round(),
      },
      {
        'sort': 'vote_average.desc',
        'weight': 0.3,
        'pages': (maxPages * 0.3).round(),
      },
      {
        'sort': 'release_date.desc',
        'weight': 0.2,
        'pages': (maxPages * 0.2).round(),
      },
      {
        'sort': 'revenue.desc',
        'weight': 0.1,
        'pages': (maxPages * 0.1).round(),
      },
    ];

    for (final strategy in searchStrategies) {
      if (allMatches.length >= targetCount) break;

      final sortBy = strategy['sort'] as String;
      final maxPagesForStrategy = strategy['pages'] as int;

      int currentPage = 1;
      int strategyPages = 0;

      while (allMatches.length < targetCount &&
          strategyPages < maxPagesForStrategy &&
          pagesSearched < maxPages) {
        try {
          // Build exact query parameters for TMDB API
          final queryParams = await _buildPreciseApiQuery(
            page: currentPage,
            selectedGenres: selectedGenres,
            language: language,
            timePeriod: timePeriod,
            minRating: minRating,
            sortBy: sortBy,
          );

          final response = await _dio.get(
            '$_baseUrl/discover/movie',
            queryParameters: queryParams,
          );

          if (response.statusCode != 200) {
            break;
          }

          final results = response.data['results'] as List?;
          if (results == null || results.isEmpty) {
            break;
          }

          final newMovies = _processMovieResults(results);

          // Apply exclusion filters and deduplication
          final finalFilteredMovies =
              newMovies.where((movie) {
                // Skip if already in results
                if (allMatches.any((m) => m.id == movie.id)) return false;

                // Skip excluded movies
                if (excludeIds != null && excludeIds.contains(movie.id))
                  return false;

                // Apply additional client-side filters
                if (minRating != null && movie.voteAverage < minRating)
                  return false;

                return true;
              }).toList();

          allMatches.addAll(finalFilteredMovies);

          currentPage++;
          strategyPages++;
          pagesSearched++;

          // Small delay to respect API rate limits
          if (pagesSearched % 10 == 0) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        } catch (e) {
          currentPage++;
          strategyPages++;
          pagesSearched++;
        }
      }

    }

    return allMatches;
  }

  // Build precise API query parameters for exact TMDB filtering
  Future<Map<String, dynamic>> _buildPreciseApiQuery({
    required int page,
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    String? sortBy,
  }) async {
    await _ensureGenreMap();

    final queryParams = <String, dynamic>{
      'page': page,
      'api_key': _apiKey,
      'sort_by': sortBy ?? 'popularity.desc',
      'include_adult': _shouldIncludeAdultContent(),
      'include_video': false,
      'vote_count.gte': 10, // Ensure movies have some votes for reliability
      // Extra safety: prefer non-erotic certifications
      'certification_country': 'US',
      'certification.lte': 'R',
    };

    // EXACT genre filtering using TMDB genre IDs
    if (selectedGenres != null && selectedGenres.isNotEmpty) {
      List<int> genreIds = [];
      for (var genre in selectedGenres) {
        final genreId = _genreNameToId[genre];
        if (genreId != null) {
          genreIds.add(genreId);
        }
      }
      if (genreIds.isNotEmpty) {
        queryParams['with_genres'] = genreIds.join(',');
      }
    }

    // EXACT language filtering
    if (language != null && language.isNotEmpty) {
      queryParams['with_original_language'] = language;
    }

    // EXACT rating filtering
    if (minRating != null && minRating > 0) {
      queryParams['vote_average.gte'] = minRating;
    }

    // EXACT time period filtering using precise date ranges
    if (timePeriod != null && timePeriod != 'All Years') {
      final dateRange = _getExactDateRange(timePeriod);
      if (dateRange != null) {
        if (dateRange['start'] != null) {
          queryParams['primary_release_date.gte'] = dateRange['start'];
        }
        if (dateRange['end'] != null) {
          queryParams['primary_release_date.lte'] = dateRange['end'];
        }
      }
    }

    return queryParams;
  }

  // Get exact date ranges for time periods
  Map<String, String?>? _getExactDateRange(String timePeriod) {
    switch (timePeriod) {
      case '2020-2024':
        return {'start': '2020-01-01', 'end': '2024-12-31'};
      case '2010-2019':
        return {'start': '2010-01-01', 'end': '2019-12-31'};
      case '2000-2009':
        return {'start': '2000-01-01', 'end': '2009-12-31'};
      case '1990-1999':
        return {'start': '1990-01-01', 'end': '1999-12-31'};
      case '1980-1989':
        return {'start': '1980-01-01', 'end': '1989-12-31'};
      case '1970-1979':
        return {'start': '1970-01-01', 'end': '1979-12-31'};
      case '1960-1969':
        return {'start': '1960-01-01', 'end': '1969-12-31'};
      case '1950-1959':
        return {'start': '1950-01-01', 'end': '1959-12-31'};
      case 'Before 1950':
        return {'start': null, 'end': '1949-12-31'};
      default:
        return null;
    }
  }

  // Client-side filtering of cached movies
  Future<List<Movie>> filterCachedMovies({
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds, // Movies to exclude (watched, not interested, etc.)
    String? person,
    String? personType,
  }) async {
    // Create a filter signature for caching
    final filterSignature = _createFilterSignature(
      selectedGenres,
      language,
      timePeriod,
      minRating,
      excludeIds,
      person,
      personType,
    );

    // Check if we have cached results for this filter combination
    if (_filterCache.containsKey(filterSignature)) {
      return List<Movie>.from(_filterCache[filterSignature]!);
    }

    List<Movie> filtered = [];

    for (final movie in _movieCache) {
      // Exclude movies that are watched, not interested, etc.
      if (excludeIds != null && excludeIds.contains(movie.id)) {
        continue;
      }

      // Adult content filter - CRITICAL: Apply this filter FIRST and ALWAYS
      if (movie.adult && !_shouldIncludeAdultContent()) {
        debugPrint('🔞 Filtering out adult movie: ${movie.title}');
        continue;
      }

      // Genre filter
      if (selectedGenres != null && selectedGenres.isNotEmpty) {
        bool hasMatchingGenre = false;
        for (final genre in selectedGenres) {
          if (movie.genre.toLowerCase().contains(genre.toLowerCase()) ||
              movie.subgenre.toLowerCase().contains(genre.toLowerCase())) {
            hasMatchingGenre = true;
            break;
          }
        }
        if (!hasMatchingGenre) continue;
      }

      // Language filter
      if (language != null && language.isNotEmpty) {
        if (movie.language != language) continue;
      }

      // Time period filter
      if (timePeriod != null && timePeriod != 'All Years') {
        final releaseYear = int.tryParse(movie.releaseDate);
        if (releaseYear != null) {
          switch (timePeriod) {
            case '2020-2024':
              if (releaseYear < 2020 || releaseYear > 2024) continue;
              break;
            case '2010-2019':
              if (releaseYear < 2010 || releaseYear > 2019) continue;
              break;
            case '2000-2009':
              if (releaseYear < 2000 || releaseYear > 2009) continue;
              break;
            case '1990-1999':
              if (releaseYear < 1990 || releaseYear > 1999) continue;
              break;
            case '1980-1989':
              if (releaseYear < 1980 || releaseYear > 1989) continue;
              break;
            case '1970-1979':
              if (releaseYear < 1970 || releaseYear > 1979) continue;
              break;
            case '1960-1969':
              if (releaseYear < 1960 || releaseYear > 1969) continue;
              break;
            case '1950-1959':
              if (releaseYear < 1950 || releaseYear > 1959) continue;
              break;
            case 'Before 1950':
              if (releaseYear >= 1950) continue;
              break;
          }
        }
      }

      // Rating filter
      if (minRating != null && movie.voteAverage < minRating) {
        continue;
      }

      // Person filter
      if (person != null && personType != null) {
        if (!await movieHasPerson(movie.id, person, personType)) {
          continue;
        }
      }

      filtered.add(movie);
    }

    // Sort by quality score instead of shuffling
    final sortedFiltered = sortMoviesByQuality(
      filtered,
      userPreferences: _userPreferences,
    );

    // Cache the results
    _filterCache[filterSignature] = List<Movie>.from(sortedFiltered);

    return sortedFiltered;
  }

  // Create a unique signature for filter combinations
  String _createFilterSignature(
    List<String>? genres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds,
    String? person,
    String? personType,
  ) {
    final parts = [
      genres?.join(',') ?? 'no-genres',
      language ?? 'no-language',
      timePeriod ?? 'no-time',
      minRating?.toString() ?? 'no-rating',
      excludeIds?.length.toString() ?? 'no-excludes',
      person ?? 'no-person',
      personType ?? 'no-person-type',
    ];
    return parts.join('|');
  }

  // Simple infinite loading - fetch more movies when cache is low
  Future<void> maybePreloadMore({
    int threshold = 20, // Lower default threshold for more aggressive loading
    List<String>? preferredGenres,
  }) async {
    if (_isPreloading) return;

    // Check if we're in platform mode
    if (isInPlatformMode) {
      // Platform mode: check if we need more from the platform stack
      if (_movieCache.length < threshold && _platformMovieStack.isNotEmpty) {
        refillFromPlatformStack();
      }
      return;
    }

    // Regular mode: use existing infinite loading
    if (_movieCache.length < threshold) {
      _isPreloading = true;

      try {
        // Use sequential pagination starting from where we left off
        final newMovies = await _fetchMoviesFromApi(
          page: _lastFetchedPage + 1,
          preferredGenres: preferredGenres,
        );

        // Add new movies to cache
        int addedCount = 0;
        for (final movie in newMovies) {
          if (!_cachedMovieIds.contains(movie.id)) {
            _movieCache.add(movie);
            _cachedMovieIds.add(movie.id);
            addedCount++;
          }
        }

        // Update the last fetched page
        _lastFetchedPage++;
        
        // If we got no new movies, we've reached the end
        if (addedCount == 0) {
          debugPrint('⚠️ No more movies available from TMDB API');
        }

      } catch (e) {
        debugPrint('❌ Error fetching more movies: $e');
        // Don't increment page on error to retry later
      } finally {
        _isPreloading = false;
      }
    }
  }

  // Dynamic platform loading - load more when user scrolls near the end
  Future<void> maybeLoadMorePlatformMovies(int currentIndex) async {
    if (!isInPlatformMode) return;
    
    // Check if we should load more (when user is 5 items away from end)
    if (shouldLoadMorePlatformMovies(currentIndex)) {
      await loadMorePlatformMovies();
    }
  }

  // Explore random pages to find more diverse movies
  Future<void> _exploreRandomPages({List<String>? preferredGenres}) async {
    final random = Random();
    final pagesToTry = 20; // Try 20 random pages

    for (int i = 0; i < pagesToTry; i++) {
      // Generate random page numbers between 1 and 500 (TMDB has thousands of pages)
      final randomPage = random.nextInt(500) + 1;

      try {
        final newMovies = await _fetchMoviesFromApi(
          page: randomPage,
          preferredGenres: preferredGenres,
        );

        // Add new movies to cache
        int addedCount = 0;
        for (final movie in newMovies) {
          if (!_cachedMovieIds.contains(movie.id)) {
            _movieCache.add(movie);
            _cachedMovieIds.add(movie.id);
            addedCount++;
          }
        }

      } catch (e) {
      }
    }
  }

  // Explore with different sort orders to find diverse movies
  Future<void> _exploreWithDifferentSorts({
    List<String>? preferredGenres,
  }) async {
    final sortOptions = [
      'vote_average.desc',
      'release_date.desc',
      'revenue.desc',
      'vote_count.desc',
      'original_title.asc',
    ];

    for (final sortBy in sortOptions) {
      // Try a few pages with each sort order
      for (int page = 1; page <= 10; page++) {
        try {
          final queryParams = {
            'page': page,
            'api_key': _apiKey,
            'sort_by': sortBy,
            'include_adult': false,
            'include_video': false,
          };

          // Add genre filter if specified
          if (preferredGenres != null && preferredGenres.isNotEmpty) {
            await _ensureGenreMap();
            List<int> genreIds = [];
            for (var genre in preferredGenres) {
              final genreId = _genreNameToId[genre];
              if (genreId != null) {
                genreIds.add(genreId);
              }
            }
            if (genreIds.isNotEmpty) {
              queryParams['with_genres'] = genreIds.join(',');
            }
          }

          final response = await _dio.get(
            '$_baseUrl/discover/movie',
            queryParameters: queryParams,
          );

          if (response.statusCode == 200) {
            final results = response.data['results'];
            final newMovies = _processMovieResults(results);

            // Add new movies to cache
            int addedCount = 0;
            for (final movie in newMovies) {
              if (!_cachedMovieIds.contains(movie.id)) {
                _movieCache.add(movie);
                _cachedMovieIds.add(movie.id);
                addedCount++;
              }
            }

          }
        } catch (e) {
        }
      }
    }
  }

  // Explore time periods and languages to find more diverse movies
  Future<void> _exploreTimePeriodsAndLanguages({
    List<String>? preferredGenres,
  }) async {
    // Different time periods to explore
    final timePeriods = [
      {'start': '2020-01-01', 'end': '2024-12-31'},
      {'start': '2010-01-01', 'end': '2019-12-31'},
      {'start': '2000-01-01', 'end': '2009-12-31'},
      {'start': '1990-01-01', 'end': '1999-12-31'},
      {'start': '1980-01-01', 'end': '1989-12-31'},
      {'start': '1970-01-01', 'end': '1979-12-31'},
    ];

    // Different languages to explore
    final languages = ['en', 'es', 'fr', 'de', 'it', 'ja', 'ko', 'zh'];

    for (final period in timePeriods) {
      for (final language in languages) {
        // Try a few pages for each combination
        for (int page = 1; page <= 5; page++) {
          try {
            final queryParams = {
              'page': page,
              'api_key': _apiKey,
              'sort_by': 'popularity.desc',
              'include_adult': false,
              'include_video': false,
              'primary_release_date.gte': period['start'],
              'primary_release_date.lte': period['end'],
              'with_original_language': language,
            };

            // Add genre filter if specified
            if (preferredGenres != null && preferredGenres.isNotEmpty) {
              await _ensureGenreMap();
              List<int> genreIds = [];
              for (var genre in preferredGenres) {
                final genreId = _genreNameToId[genre];
                if (genreId != null) {
                  genreIds.add(genreId);
                }
              }
              if (genreIds.isNotEmpty) {
                queryParams['with_genres'] = genreIds.join(',');
              }
            }

            final response = await _dio.get(
              '$_baseUrl/discover/movie',
              queryParameters: queryParams,
            );

            if (response.statusCode == 200) {
              final results = response.data['results'];
              final newMovies = _processMovieResults(results);

              // Add new movies to cache
              int addedCount = 0;
              for (final movie in newMovies) {
                if (!_cachedMovieIds.contains(movie.id)) {
                  _movieCache.add(movie);
                  _cachedMovieIds.add(movie.id);
                  addedCount++;
                }
              }

              if (addedCount > 0) {
              }
            }
          } catch (e) {
            // Silently continue on error to avoid spam
          }
        }
      }
    }
  }

  // Clear filter cache when it gets too large
  void _cleanupFilterCache() {
    if (_filterCache.length > 20) {
      _filterCache.clear();
    }
  }

  // Process movie results from API response
  List<Movie> _processMovieResults(List<dynamic> results) {
    return results
        .map((movie) {
          try {
            final adult = movie['adult'] ?? false;
            final title = movie['title'] ?? 'Unknown Title';
            final overview = (movie['overview'] ?? '').toString();
            
            // CRITICAL: Filter out adult content immediately during processing
            if (adult && !_shouldIncludeAdultContent()) {
              debugPrint('🔞 FILTERED OUT adult movie during processing: $title (adult: $adult)');
              return null; // This will be filtered out by whereType<Movie>()
            }
            
            // Additional heuristic blacklist for erotic content leakage
            if (!_shouldIncludeAdultContent()) {
              const bannedTerms = [
                'erotic', 'porn', 'xxx', 'softcore', 'hardcore', 'hentai', 'nsfw', 'pornographic', 'adult film',
              ];
              final haystack = '$title\n$overview'.toLowerCase();
              final hasBanned = bannedTerms.any((t) => haystack.contains(t));
              if (hasBanned) {
                debugPrint('🔞 FILTERED OUT by keyword: $title');
                return null;
              }
            }
            
            // Debug log for adult content that passes through
            if (adult) {
              debugPrint('🔞 ALLOWING adult movie: $title (adult: $adult, filter enabled: ${!_shouldIncludeAdultContent()})');
            }

            final genreIds = movie['genre_ids'] as List?;
            String genreName = 'Other';
            String subgenreName = 'Other';

            if (genreIds != null &&
                genreIds.isNotEmpty &&
                _genreCache != null) {
              genreName = _genreCache![genreIds[0]] ?? 'Other';
              subgenreName =
                  genreIds.length > 1
                      ? (_genreCache![genreIds[1]] ?? 'Other')
                      : genreName;
            }

            final releaseDateStr = movie['release_date'];
            DateTime? releaseDate;

            if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
              releaseDate = DateTime.tryParse(releaseDateStr);
            }

            // Filter out future releases
            if (releaseDate != null && releaseDate.isAfter(DateTime.now())) {
              return null;
            }

            final movieObj = Movie(
              id: movie['id'],
              title: title,
              description: overview.isNotEmpty ? overview : 'No description available',
              posterUrl:
                  movie['poster_path'] != null
                      ? '$_imageBaseUrl${movie['poster_path']}'
                      : 'https://via.placeholder.com/500x750?text=No+Poster',
              genre: genreName,
              subgenre: subgenreName,
              releaseDate: releaseDateStr?.substring(0, 4) ?? 'Unknown',
              voteAverage: (movie['vote_average'] as num?)?.toDouble() ?? 0.0,
              language: movie['original_language'] ?? 'N/A',
              adult: adult, // Keep the adult field for reference
              keywords:
                  [], // Will be populated later via API or text extraction
            );

            // Extract keywords from text as immediate fallback
            final textKeywords = _extractKeywordsFromText(movieObj);
            return movieObj.copyWith(keywords: textKeywords);
          } catch (e) {
            return null;
          }
        })
        .whereType<Movie>()
        .toList();
  }

  // Existing methods for compatibility...

  Future<void> _loadGenres() async {
    const requestKey = 'load_genres';
    
    return await _requestManager.deduplicate(requestKey, () async {
    if (_genreCache != null) return;

    try {
      final response = await _dio.get('$_baseUrl/genre/movie/list');

      if (response.statusCode == 200) {
        final genres = response.data['genres'] as List;
        _genreCache = {
          for (var genre in genres) genre['id'] as int: genre['name'] as String,
        };
      } else {
        throw Exception('Failed to load genres: ${response.statusCode}');
      }
    } catch (e) {
      _genreCache = {}; // Set empty cache to avoid repeated failures
    }
    });
  }

  Future<void> _ensureGenreMap() async {
    const requestKey = 'ensure_genre_map';
    
    return await _requestManager.deduplicate(requestKey, () async {
    await _loadGenres();
    if (_genreNameToId.isEmpty && _genreCache != null) {
      _genreNameToId = {
        for (var entry in _genreCache!.entries) entry.value: entry.key,
      };
    }
    });
  }

  List<String> getAllGenres() {
    return _genreCache?.values.toList() ?? [];
  }

  Future<List<String>> fetchCast(int movieId) async {
    final requestKey = 'fetch_cast_$movieId';
    
    return await _requestManager.deduplicate(requestKey, () async {
    try {
      final response = await _dio.get('$_baseUrl/movie/$movieId/credits');
      if (response.statusCode == 200) {
        final cast = response.data['cast'] as List;
        return cast.take(10).map((actor) => actor['name'] as String).toList();
      }
    } catch (e) {
    }
    return [];
    });
  }

  // Fetch cast and crew for a movie
  Future<Map<String, dynamic>> fetchCastAndCrew(int movieId) async {
    final requestKey = 'fetch_cast_crew_$movieId';
    
    return await _requestManager.deduplicate(requestKey, () async {
    // Check cache first
    if (_castCrewCache.containsKey(movieId)) {
      return _castCrewCache[movieId]!;
    }

    try {
      final response = await _dio.get('$_baseUrl/movie/$movieId/credits');

      if (response.statusCode == 200) {
        final data = response.data;
        final cast =
            (data['cast'] as List? ?? [])
                .take(10) // Limit to top 10 cast members
                .map(
                  (actor) => {
                    'name': actor['name'] ?? '',
                    'character': actor['character'] ?? '',
                  },
                )
                .where((actor) => actor['name'].isNotEmpty)
                .toList();

        final crew =
            (data['crew'] as List? ?? [])
                .where(
                  (member) =>
                      member['job'] == 'Director' ||
                      member['job'] == 'Producer' ||
                      member['job'] == 'Writer' ||
                      member['job'] == 'Screenplay',
                )
                .map(
                  (member) => {
                    'name': member['name'] ?? '',
                    'job': member['job'] ?? '',
                  },
                )
                .where((member) => member['name'].isNotEmpty)
                .toList();

        final result = {'cast': cast, 'crew': crew};

        // Cache the result
        _castCrewCache[movieId] = result;
        return result;
      }
    } catch (e) {
    }

    return {'cast': [], 'crew': []};
    });
  }

  // Check if a movie has a specific person in cast or crew
  Future<bool> movieHasPerson(
    int movieId,
    String personName,
    String personType,
  ) async {
    final castAndCrew = await fetchCastAndCrew(movieId);

    if (personType == 'actor') {
      final cast = castAndCrew['cast'] as List;
      return cast.any(
        (actor) => (actor['name'] as String).toLowerCase().contains(
          personName.toLowerCase(),
        ),
      );
    } else {
      final crew = castAndCrew['crew'] as List;
      return crew.any(
        (member) =>
            (member['name'] as String).toLowerCase().contains(
              personName.toLowerCase(),
            ) &&
            (member['job'] as String).toLowerCase().contains(
              personType.toLowerCase(),
            ),
      );
    }
  }

  // Search movies by person (actor, director, etc.)
  Future<List<Movie>> searchMoviesByPerson(
    String personName, {
    int? personId,
  }) async {
    try {
      List<Movie> allResults = [];

      // Method 1: If we have person ID, use discover endpoint with person filter
      if (personId != null) {
        final discoverResults = await _searchMoviesByPersonId(personId);
        allResults.addAll(discoverResults);
      }

      // Method 2: Search in cached movies by person name
      final cachedResults = _searchCachedMoviesByPerson(personName);
      allResults.addAll(cachedResults);

      // Method 3: Use general search and filter by person involvement
      final searchResults = await _searchMoviesWithPersonInvolved(personName);
      allResults.addAll(searchResults);

      // Deduplicate results
      final seenIds = <int>{};
      final uniqueResults = <Movie>[];

      for (final movie in allResults) {
        if (!seenIds.contains(movie.id)) {
          uniqueResults.add(movie);
          seenIds.add(movie.id);

          // Add to cache if not already there
          if (!_cachedMovieIds.contains(movie.id)) {
            _movieCache.add(movie);
            _cachedMovieIds.add(movie.id);
          }
        }
      }

      // Sort by quality and recency
      return sortMoviesByQuality(
        uniqueResults,
        userPreferences: _userPreferences,
      );
    } catch (e) {
    }
      return [];
  }

  // Search movies using person ID (most accurate)
  Future<List<Movie>> _searchMoviesByPersonId(int personId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/discover/movie',
        queryParameters: {
          'api_key': _apiKey,
          'with_people': personId.toString(),
          'sort_by': 'popularity.desc',
          'include_adult': false,
        },
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return _processMovieResults(results);
      }
    } catch (e) {
    }
    return [];
  }

  // Search cached movies by person name
  List<Movie> _searchCachedMoviesByPerson(String personName) {
    // This is a basic implementation - in a real app, we'd need to store
    // cast/crew info with each cached movie for better searching
    return [];
  }

  // Search movies with person involved using general search
  Future<List<Movie>> _searchMoviesWithPersonInvolved(String personName) async {
    try {
      // Search for the person first to get their filmography
      final personResponse = await _dio.get(
        '$_baseUrl/search/person',
        queryParameters: {'api_key': _apiKey, 'query': personName},
      );

      if (personResponse.statusCode == 200) {
        final people = personResponse.data['results'] as List;
        if (people.isNotEmpty) {
          final person = people.first;
          final personId = person['id'] as int;

          // Get their movie credits
          final creditsResponse = await _dio.get(
            '$_baseUrl/person/$personId/movie_credits',
            queryParameters: {'api_key': _apiKey},
          );

          if (creditsResponse.statusCode == 200) {
            final cast = creditsResponse.data['cast'] as List? ?? [];
            final crew = creditsResponse.data['crew'] as List? ?? [];

            // Combine cast and crew movies
            final allMovies = [...cast, ...crew];

            // Process and return movies
            return _processMovieResults(allMovies);
          }
        }
      }
    } catch (e) {
    }
    return [];
  }

  // Get person details by ID
  Future<Map<String, dynamic>?> getPersonDetails(int personId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/person/$personId',
        queryParameters: {'api_key': _apiKey},
      );

      if (response.statusCode == 200) {
        final person = response.data;
        return {
          'id': person['id'],
          'name': person['name'],
          'biography': person['biography'] ?? '',
          'birthday': person['birthday'],
          'place_of_birth': person['place_of_birth'],
          'profile_path': person['profile_path'],
          'known_for_department': person['known_for_department'],
        };
      }
    } catch (e) {
    }
    return null;
  }

  // Fetch keywords for a movie from TMDB API
  Future<List<String>> fetchMovieKeywords(int movieId) async {
    final requestKey = 'fetch_keywords_$movieId';
    
    return await _requestManager.deduplicate(requestKey, () async {
    // Check cache first
    if (_keywordCache.containsKey(movieId)) {
      return _keywordCache[movieId]!;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/movie/$movieId/keywords',
        queryParameters: {'api_key': _apiKey},
      );

      if (response.statusCode == 200) {
        final keywordsData = response.data['keywords'] as List? ?? [];
        final keywords =
            keywordsData
                .map((keyword) => keyword['name'] as String? ?? '')
                .where((name) => name.isNotEmpty)
                .map((name) => name.toLowerCase().trim())
                .toList();

        // Cache the keywords
        _keywordCache[movieId] = keywords;
        return keywords;
      }
    } catch (e) {
    }

    // Return empty list if fetch fails
    _keywordCache[movieId] = [];
    return [];
    });
  }

  // Fetch external IDs (IMDb, etc.) for a movie
  Future<Map<String, String>> fetchExternalIds(int movieId) async {
    final requestKey = 'fetch_external_ids_$movieId';
    return await _requestManager.deduplicate(requestKey, () async {
      if (_externalIdsCache.containsKey(movieId)) {
        return _externalIdsCache[movieId]!;
      }
      try {
        final response = await _dio.get(
          '$_baseUrl/movie/$movieId/external_ids',
          queryParameters: {'api_key': _apiKey},
        );
        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final imdbId = (data['imdb_id'] as String?)?.trim();
          final map = <String, String>{
            if (imdbId != null && imdbId.isNotEmpty) 'imdb_id': imdbId,
          };
          _externalIdsCache[movieId] = map;
          return map;
        }
      } catch (e) {
      }
      _externalIdsCache[movieId] = {};
      return {};
    });
  }

  // Fetch trailer URL (YouTube) from TMDB videos for a movie
  Future<String?> fetchTrailerUrl(int movieId) async {
    final requestKey = 'fetch_trailer_$movieId';
    return await _requestManager.deduplicate(requestKey, () async {
      try {
        final response = await _dio.get(
          '$_baseUrl/movie/$movieId/videos',
          queryParameters: {'api_key': _apiKey},
        );
        if (response.statusCode == 200) {
          final results = response.data['results'] as List? ?? [];
          // Prefer official trailer in English, then any trailer
          final prioritized = [
            ...results.where((v) => (v['type'] == 'Trailer') && (v['official'] == true) && (v['site'] == 'YouTube') && (v['iso_639_1'] == 'en')),
            ...results.where((v) => (v['type'] == 'Trailer') && (v['site'] == 'YouTube')),
          ];
          if (prioritized.isNotEmpty) {
            final key = prioritized.first['key'];
            if (key is String && key.isNotEmpty) {
              return 'https://www.youtube.com/watch?v=' + key;
            }
          }
        }
      } catch (e) {
      }
      return null;
    });
  }

  // Fetch keywords for multiple movies in batch
  Future<void> fetchKeywordsForMovies(List<Movie> movies) async {
    final futures = <Future<void>>[];

    for (final movie in movies) {
      if (!_keywordCache.containsKey(movie.id)) {
        futures.add(
          fetchMovieKeywords(movie.id).then((keywords) {
            // Update the movie in cache with keywords if it exists
            final cacheIndex = _movieCache.indexWhere((m) => m.id == movie.id);
            if (cacheIndex != -1) {
              _movieCache[cacheIndex] = _movieCache[cacheIndex].copyWith(
                keywords: keywords,
              );
            }
          }),
        );
      }
    }

    // Wait for all keyword fetches to complete
    await Future.wait(futures);
  }

  // Extract keywords from movie description and title as fallback
  List<String> _extractKeywordsFromText(Movie movie) {
    final text = '${movie.title} ${movie.description}'.toLowerCase();
    final words = text.split(RegExp(r'[^\w]+'));

    // Common stop words to filter out
    final stopWords = {
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'may',
      'might',
      'must',
      'can',
      'this',
      'that',
      'these',
      'those',
      'i',
      'you',
      'he',
      'she',
      'it',
      'we',
      'they',
      'me',
      'him',
      'her',
      'us',
      'them',
      'my',
      'your',
      'his',
      'her',
      'its',
      'our',
      'their',
      'mine',
      'yours',
      'hers',
      'ours',
      'theirs',
      'who',
      'what',
      'when',
      'where',
      'why',
      'how',
      'which',
      'whose',
      'whom',
      'all',
      'any',
      'both',
      'each',
      'few',
      'more',
      'most',
      'other',
      'some',
      'such',
      'no',
      'nor',
      'not',
      'only',
      'own',
      'same',
      'so',
      'than',
      'too',
      'very',
      's',
      't',
      'just',
      'don',
      'now',
      'during',
      'before',
      'after',
      'above',
      'below',
      'up',
      'down',
      'out',
      'off',
      'over',
      'under',
      'again',
      'further',
      'then',
      'once',
    };

    // Filter meaningful keywords
    final keywords =
        words
            .where((word) => word.length > 2 && !stopWords.contains(word))
            .where((word) => RegExp(r'^[a-zA-Z]+$').hasMatch(word))
            .take(10) // Limit to 10 keywords
            .toList();

    return keywords;
  }

  // Movie quality scoring system
  double getMovieScore(Movie movie) {
    double score = 0.0;

    // Rating component (0-40 points) - Most important factor
    // Movies with rating >= 7.0 get full points, scale down from there
    if (movie.voteAverage >= 7.0) {
      score += 40.0;
    } else if (movie.voteAverage >= 6.0) {
      score += 30.0;
    } else if (movie.voteAverage >= 5.0) {
      score += 20.0;
    } else if (movie.voteAverage >= 4.0) {
      score += 10.0;
    } else if (movie.voteAverage >= 3.0) {
      score += 5.0;
    }
    // Movies below 3.0 rating get 0 points for rating

    // Poster availability (0-20 points) - Visual appeal is important
    if (movie.posterUrl.isNotEmpty &&
        !movie.posterUrl.contains('placeholder') &&
        !movie.posterUrl.contains('No+Poster')) {
      score += 20.0;
    }

    // Vote count component (0-20 points) - Popularity/reliability indicator
    // This is a rough estimate since we don't have exact vote count from our Movie model
    // We'll use a heuristic based on the fact that higher-rated movies with posters
    // are likely to have more votes
    if (movie.voteAverage > 0) {
      // Assume movies with ratings have some votes
      if (movie.voteAverage >= 6.0) {
        score += 20.0; // Likely many votes
      } else if (movie.voteAverage >= 4.0) {
        score += 15.0; // Moderate votes
      } else {
        score += 10.0; // Few votes
      }
    }

    // Release date recency bonus (0-10 points) - Newer movies get slight preference
    final releaseYear = int.tryParse(movie.releaseDate);
    if (releaseYear != null) {
      final currentYear = DateTime.now().year;
      final yearDiff = currentYear - releaseYear;

      if (yearDiff <= 3) {
        score += 10.0; // Very recent
      } else if (yearDiff <= 10) {
        score += 7.0; // Recent
      } else if (yearDiff <= 20) {
        score += 5.0; // Somewhat recent
      } else {
        score += 2.0; // Classic (still gets some points)
      }
    }

    // Genre bonus (0-10 points) - Well-known genres get slight preference
    final popularGenres = [
      'Action',
      'Comedy',
      'Drama',
      'Thriller',
      'Adventure',
      'Romance',
    ];
    if (popularGenres.any(
      (genre) => movie.genre.toLowerCase().contains(genre.toLowerCase()),
    )) {
      score += 5.0;
    }

    return score;
  }

  // Check if a movie meets minimum quality standards
  bool isHighQualityMovie(Movie movie) {
    return movie.voteAverage >= 3.0 &&
        movie.posterUrl.isNotEmpty &&
        !movie.posterUrl.contains('placeholder') &&
        !movie.posterUrl.contains('No+Poster');
  }

  // Sort movies by quality score
  List<Movie> sortMoviesByQuality(
    List<Movie> movies, {
    dynamic userPreferences,
  }) {
    // Create a list of movies with their scores
    final moviesWithScores =
        movies
            .map(
              (movie) => {
                'movie': movie,
                'score':
                    userPreferences != null
                        ? scoreMovie(movie, userPreferences: userPreferences)
                        : getMovieScore(
                          movie,
                        ), // Fallback to old scoring if no user preferences
                'isHighQuality': isHighQualityMovie(movie),
              },
            )
            .toList();

    // Sort by score (highest first), then by rating as tiebreaker
    moviesWithScores.sort((a, b) {
      final scoreComparison = (b['score'] as double).compareTo(
        a['score'] as double,
      );
      if (scoreComparison != 0) return scoreComparison;

      // Tiebreaker: higher rating wins
      final movieA = a['movie'] as Movie;
      final movieB = b['movie'] as Movie;
      return movieB.voteAverage.compareTo(movieA.voteAverage);
    });

    // Extract the sorted movies
    final sortedMovies =
        moviesWithScores.map((item) => item['movie'] as Movie).toList();

    return sortedMovies;
  }

  // Search for movies by title
  Future<List<Movie>> searchMovies(String query) async {
    if (query.trim().isEmpty) return [];

    return await _performanceService.monitorApiCall('movie_search', () async {
      // Step 1: Search in cached movies first for instant results
      final cachedResults = _searchInCache(query);

      // Step 2: Search via API for more comprehensive results
      final apiResults = await _searchViaApi(query);

      // Step 3: Combine and deduplicate results
      final allResults = <Movie>[];
      final seenIds = <int>{};

      // Add cached results first (they're instant)
      for (final movie in cachedResults) {
        if (!seenIds.contains(movie.id)) {
          allResults.add(movie);
          seenIds.add(movie.id);
        }
      }

      // Add API results that aren't already in cache
      for (final movie in apiResults) {
        if (!seenIds.contains(movie.id)) {
          allResults.add(movie);
          seenIds.add(movie.id);

          // Add new movies to cache for future searches
          if (!_cachedMovieIds.contains(movie.id)) {
            _movieCache.add(movie);
            _cachedMovieIds.add(movie.id);
          }
        }
      }

      // Sort by relevance and quality
      return _sortSearchResults(allResults, query);
    });
  }

  // Search in cached movies
  List<Movie> _searchInCache(String query) {
    final queryLower = query.toLowerCase();

    return _movieCache.where((movie) {
      final titleLower = movie.title.toLowerCase();
      return titleLower.contains(queryLower);
    }).toList();
  }

  // Search via TMDB API
  Future<List<Movie>> _searchViaApi(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/search/movie',
        queryParameters: {
          'api_key': _apiKey,
          'query': query,
          'include_adult': false,
          'page': 1,
        },
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return _processMovieResults(results);
      }
    } catch (e) {
    }

    return [];
  }

  // Sort search results by relevance and quality
  List<Movie> _sortSearchResults(List<Movie> movies, String query) {
    final queryLower = query.toLowerCase();

    // Create scored results
    final scoredResults =
        movies.map((movie) {
          double relevanceScore = 0.0;
          final titleLower = movie.title.toLowerCase();

          // Exact match gets highest score
          if (titleLower == queryLower) {
            relevanceScore = 100.0;
          }
          // Starts with query gets high score
          else if (titleLower.startsWith(queryLower)) {
            relevanceScore = 80.0;
          }
          // Contains query gets medium score
          else if (titleLower.contains(queryLower)) {
            relevanceScore = 60.0;
          }
          // Word match gets lower score
          else {
            final queryWords = queryLower.split(' ');
            final titleWords = titleLower.split(' ');
            int matchingWords = 0;

            for (final queryWord in queryWords) {
              for (final titleWord in titleWords) {
                if (titleWord.contains(queryWord) ||
                    queryWord.contains(titleWord)) {
                  matchingWords++;
                  break;
                }
              }
            }

            relevanceScore = (matchingWords / queryWords.length) * 40.0;
          }

          // Combine relevance with quality score
          final qualityScore = getMovieScore(movie);
          final combinedScore =
              relevanceScore +
              (qualityScore * 0.3); // Weight relevance more heavily

          return {
            'movie': movie,
            'score': combinedScore,
            'relevance': relevanceScore,
            'quality': qualityScore,
          };
        }).toList();

    // Sort by combined score
    scoredResults.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    // Extract sorted movies
    final sortedMovies =
        scoredResults.map((item) => item['movie'] as Movie).toList();

    return sortedMovies;
  }

  // NEW: Tag-based movie scoring system that learns from user preferences
  double scoreMovie(Movie movie, {required dynamic userPreferences}) {
    double score = 0.0;

    // Base quality score (40% weight) - ensures we don't recommend terrible movies
    final qualityScore = _calculateQualityScore(movie);
    score += qualityScore * 0.4;

    // Tag overlap score (60% weight) - main personalization factor
    if (userPreferences != null && movie.keywords.isNotEmpty) {
      final tagScore = userPreferences.calculateTagOverlapScore(movie.keywords);
      score += tagScore * 0.6;
    }

    // Diversity bonus - slight preference for exploring new tags
    final diversityBonus = _calculateDiversityBonus(movie, userPreferences);
    score += diversityBonus * 0.1;

    return score;
  }

  // Calculate base quality score for a movie
  double _calculateQualityScore(Movie movie) {
    double score = 0.0;

    // TMDB rating component (most important for quality)
    if (movie.voteAverage >= 8.0) {
      score += 100.0;
    } else if (movie.voteAverage >= 7.0) {
      score += 80.0;
    } else if (movie.voteAverage >= 6.0) {
      score += 60.0;
    } else if (movie.voteAverage >= 5.0) {
      score += 40.0;
    } else if (movie.voteAverage >= 4.0) {
      score += 20.0;
    } else if (movie.voteAverage >= 3.0) {
      score += 10.0;
    }
    // Movies below 3.0 get 0 points

    // Poster availability bonus
    if (movie.posterUrl.isNotEmpty &&
        !movie.posterUrl.contains('placeholder') &&
        !movie.posterUrl.contains('No+Poster')) {
      score += 20.0;
    }

    // Recency bonus (newer movies get slight preference)
    final releaseYear = int.tryParse(movie.releaseDate);
    if (releaseYear != null) {
      final currentYear = DateTime.now().year;
      final yearDiff = currentYear - releaseYear;

      if (yearDiff <= 3) {
        score += 15.0; // Very recent
      } else if (yearDiff <= 10) {
        score += 10.0; // Recent
      } else if (yearDiff <= 20) {
        score += 5.0; // Somewhat recent
      }
    }

    return score;
  }

  // Calculate diversity bonus to encourage exploration
  double _calculateDiversityBonus(Movie movie, dynamic userPreferences) {
    if (userPreferences == null || movie.keywords.isEmpty) return 0.0;

    double diversityScore = 0.0;
    int newTags = 0;

    // Count how many of the movie's tags are new to the user
    for (final keyword in movie.keywords) {
      final normalizedKeyword = keyword.toLowerCase().trim();
      final hasLiked = userPreferences.userLikedTags.containsKey(
        normalizedKeyword,
      );
      final hasDisliked = userPreferences.userDislikedTags.containsKey(
        normalizedKeyword,
      );

      if (!hasLiked && !hasDisliked) {
        newTags++;
      }
    }

    // Bonus for movies with new tags (encourages exploration)
    if (newTags > 0) {
      diversityScore = (newTags / movie.keywords.length) * 20.0;
    }

    return diversityScore;
  }

  // OPTIMIZED person search using direct TMDB person endpoints
  Future<List<Movie>> _searchMoviesByPersonOptimized({
    required String personName,
    required String personType,
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds,
    int targetCount = 100,
  }) async {
    final cacheKey = '${personName.toLowerCase()}_$personType';

    // Check cache first
    if (_personMoviesCache.containsKey(cacheKey)) {
      return _applyAdditionalFilters(
        _personMoviesCache[cacheKey]!,
        selectedGenres: selectedGenres,
        language: language,
        timePeriod: timePeriod,
        minRating: minRating,
        excludeIds: excludeIds,
      );
    }

    try {
      // STEP 1: Find person ID using search endpoint
      final personId = await _findPersonId(personName);
      if (personId == null) {
        _personMoviesCache[cacheKey] = []; // Cache empty result
        return [];
      }

      // STEP 2: Get movies directly using person credits endpoint
      final movies = await _getMoviesFromPersonCredits(personId, personType);

      // Cache the results
      _personMoviesCache[cacheKey] = movies;

      // STEP 3: Apply additional filters
      return _applyAdditionalFilters(
        movies,
        selectedGenres: selectedGenres,
        language: language,
        timePeriod: timePeriod,
        minRating: minRating,
        excludeIds: excludeIds,
      );
    } catch (e) {
    }
      return [];
  }

  // Find person ID using TMDB search endpoint
  Future<int?> _findPersonId(String personName) async {
    final cacheKey = personName.toLowerCase();

    // Check cache first
    if (_personIdCache.containsKey(cacheKey)) {
      return _personIdCache[cacheKey];
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/search/person',
        queryParameters: {'api_key': _apiKey, 'query': personName},
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          final personId = results.first['id'] as int;
          _personIdCache[cacheKey] = personId;
          return personId;
        }
      }
    } catch (e) {
    }

    // Cache null result to avoid repeated searches
    _personIdCache[cacheKey] = null;
    return null;
  }

  // Get movies from person credits endpoint
  Future<List<Movie>> _getMoviesFromPersonCredits(
    int personId,
    String personType,
  ) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/person/$personId/movie_credits',
        queryParameters: {'api_key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> movieData = [];

        // Get appropriate movie list based on person type
        if (personType == 'actor') {
          movieData = data['cast'] as List? ?? [];
        } else {
          // For directors, writers, producers, etc.
          final crew = data['crew'] as List? ?? [];
          movieData =
              crew.where((member) {
                final job = (member['job'] as String? ?? '').toLowerCase();
                return job.contains(personType.toLowerCase()) ||
                    (personType == 'director' && job == 'director') ||
                    (personType == 'writer' &&
                        (job == 'writer' || job == 'screenplay')) ||
                    (personType == 'producer' && job.contains('producer'));
              }).toList();
        }

        // Process movie data
        final movies =
            movieData
                .map((movie) {
                  try {
                    return _processMovieFromCredits(movie);
                  } catch (e) {
                  }
                })
                .whereType<Movie>()
                .toList();

        // Sort by popularity/rating
        movies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

        return movies;
      }
    } catch (e) {
    }

    return [];
  }

  // Process movie data from credits endpoint
  Movie _processMovieFromCredits(Map<String, dynamic> movieData) {
    final genreIds = movieData['genre_ids'] as List?;
    String genreName = 'Other';
    String subgenreName = 'Other';

    if (genreIds != null && genreIds.isNotEmpty && _genreCache != null) {
      genreName = _genreCache![genreIds[0]] ?? 'Other';
      subgenreName =
          genreIds.length > 1
              ? (_genreCache![genreIds[1]] ?? 'Other')
              : genreName;
    }

    final releaseDateStr = movieData['release_date'] as String?;

    return Movie(
      id: movieData['id'] as int,
      title: movieData['title'] as String? ?? 'Unknown Title',
      description:
          movieData['overview'] as String? ?? 'No description available',
      posterUrl:
          movieData['poster_path'] != null
              ? '$_imageBaseUrl${movieData['poster_path']}'
              : 'https://via.placeholder.com/500x750?text=No+Poster',
      genre: genreName,
      subgenre: subgenreName,
      releaseDate: releaseDateStr?.substring(0, 4) ?? 'Unknown',
      voteAverage: (movieData['vote_average'] as num?)?.toDouble() ?? 0.0,
      language: movieData['original_language'] as String? ?? 'N/A',
      adult: movieData['adult'] ?? false, // Parse adult field from TMDB
      keywords: [], // Will be populated later if needed
    );
  }

  // Apply additional filters to person search results
  List<Movie> _applyAdditionalFilters(
    List<Movie> movies, {
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds,
  }) {
    return movies.where((movie) {
      // Skip excluded movies
      if (excludeIds != null && excludeIds.contains(movie.id)) return false;

      // Genre filter
      if (selectedGenres != null && selectedGenres.isNotEmpty) {
        bool hasMatchingGenre = false;
        for (final genre in selectedGenres) {
          if (movie.genre.toLowerCase().contains(genre.toLowerCase()) ||
              movie.subgenre.toLowerCase().contains(genre.toLowerCase())) {
            hasMatchingGenre = true;
            break;
          }
        }
        if (!hasMatchingGenre) return false;
      }

      // Language filter
      if (language != null && language.isNotEmpty) {
        if (movie.language != language) return false;
      }

      // Time period filter
      if (timePeriod != null && timePeriod != 'All Years') {
        final releaseYear = int.tryParse(movie.releaseDate);
        if (releaseYear != null) {
          final dateRange = _getExactDateRange(timePeriod);
          if (dateRange != null) {
            if (dateRange['start'] != null) {
              final startYear = int.parse(dateRange['start']!.substring(0, 4));
              if (releaseYear < startYear) return false;
            }
            if (dateRange['end'] != null) {
              final endYear = int.parse(dateRange['end']!.substring(0, 4));
              if (releaseYear > endYear) return false;
            }
          }
        }
      }

      // Rating filter
      if (minRating != null && movie.voteAverage < minRating) return false;

      return true;
    }).toList();
  }

  // Filter cached movies with all options (replacement for the deleted method)
  Future<List<Movie>> _filterCachedMoviesWithOptions({
    List<String>? selectedGenres,
    String? language,
    String? timePeriod,
    double? minRating,
    Set<int>? excludeIds,
    String? person,
    String? personType,
  }) async {
    return filterCachedMovies(
      selectedGenres: selectedGenres,
      language: language,
      timePeriod: timePeriod,
      minRating: minRating,
      excludeIds: excludeIds,
      person: person,
      personType: personType,
    );
  }

  // NEW: Fetch a single movie by ID from TMDB API
  Future<Movie?> fetchMovieById(int movieId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/movie/$movieId',
        queryParameters: {
          'api_key': _apiKey,
          'append_to_response': 'keywords',
        },
      );

      if (response.statusCode == 200) {
        final movieData = response.data;
        
        // Extract keywords if available
        List<String> keywords = [];
        if (movieData['keywords'] != null && movieData['keywords']['keywords'] != null) {
          final keywordsData = movieData['keywords']['keywords'] as List;
          keywords = keywordsData
              .map((keyword) => keyword['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .map((name) => name.toLowerCase().trim())
              .toList();
        }

        // Get genre information
        await _ensureGenreMap();
        final genreIds = movieData['genres'] as List?;
        String genreName = 'Other';
        String subgenreName = 'Other';

        if (genreIds != null && genreIds.isNotEmpty) {
          final genreId = genreIds[0]['id'] as int;
          genreName = _genreNameToId.entries
              .firstWhere((entry) => entry.value == genreId, 
                         orElse: () => MapEntry('Other', 0))
              .key;
          
          if (genreIds.length > 1) {
            final subgenreId = genreIds[1]['id'] as int;
            subgenreName = _genreNameToId.entries
                .firstWhere((entry) => entry.value == subgenreId, 
                           orElse: () => MapEntry('Other', 0))
                .key;
          } else {
            subgenreName = genreName;
          }
        }

        final releaseDateStr = movieData['release_date'] as String?;

        final movie = Movie(
          id: movieData['id'] as int,
          title: movieData['title'] as String? ?? 'Unknown Title',
          description: movieData['overview'] as String? ?? 'No description available',
          posterUrl: movieData['poster_path'] != null
              ? '$_imageBaseUrl${movieData['poster_path']}'
              : 'https://via.placeholder.com/500x750?text=No+Poster',
          genre: genreName,
          subgenre: subgenreName,
          releaseDate: releaseDateStr?.substring(0, 4) ?? 'Unknown',
          voteAverage: (movieData['vote_average'] as num?)?.toDouble() ?? 0.0,
          language: movieData['original_language'] as String? ?? 'N/A',
          adult: movieData['adult'] ?? false,
          keywords: keywords,
        );

        return movie;
      }
    } catch (e) {
      debugPrint('❌ Error fetching movie $movieId: $e');
    }
    
    return null;
  }

  // NEW: Add a movie to the cache
  void addMovieToCache(Movie movie) {
    if (!_cachedMovieIds.contains(movie.id)) {
      _movieCache.add(movie);
      _cachedMovieIds.add(movie.id);
    }
  }

  // Platform selection handler - now uses Firebase for speed
  Future<void> onPlatformFilterSelected(String platformName) async {
    // Validate platform exists
    if (!PLATFORM_PROVIDERS.containsKey(platformName)) {
      throw Exception('Unsupported platform: $platformName');
    }

    // Clear existing state
    _clearCurrentMovieStack();
    
    // Set new platform
    _selectedPlatform = platformName;
    _currentPlatformProviderId = PLATFORM_PROVIDERS[platformName]!;
    _currentPlatformPage = 1;
    _hasMorePlatformPages = true;
    _platformFetchComplete = false;
    _platformFetchProgress = 0;
    
    // Load platform movies from Firebase (much faster than TMDB API)
    await _loadPlatformMoviesFromFirebase(platformName);
  }

  // Load platform movies from Firebase
  Future<void> _loadPlatformMoviesFromFirebase(String platformName) async {
    if (_isPlatformFetching) return;
    
    _isPlatformFetching = true;
    _platformMovieStack.clear();
    
    try {
      debugPrint('🔄 Loading $platformName movies from Firebase...');
      
      // Get movies from Firebase platform service
      final platformMovies = await _firebasePlatformService.getPlatformMovies(platformName);
      
      if (platformMovies.isNotEmpty) {
        // Add to platform stack
        _platformMovieStack.addAll(platformMovies);
        _platformFetchComplete = true;
        _hasMorePlatformPages = false; // Firebase has all movies
        
        debugPrint('✅ Loaded ${platformMovies.length} $platformName movies from Firebase');
        
        // Populate UI immediately with Firebase results
        populateMovieStackFromPlatform();
    } else {
        debugPrint('⚠️ No $platformName movies found in Firebase, falling back to TMDB API...');
        // Fallback to TMDB API if Firebase has no data
        await _loadInitialPlatformBatch(platformName);
      }
      
    } catch (error) {
      debugPrint('❌ Error loading platform movies from Firebase: $error');
      // Fallback to TMDB API
      await _loadInitialPlatformBatch(platformName);
    } finally {
      _isPlatformFetching = false;
    }
  }

  // Load initial batch of platform movies (20-30 movies)
  Future<void> _loadInitialPlatformBatch(String platformName) async {
    if (_isPlatformFetching) return;
    
    _isPlatformFetching = true;
    _platformMovieStack.clear();
    
    try {
      debugPrint('🔄 Loading initial $platformName movies...');
      
      // Load first batch immediately
      final initialBatch = await _fetchPlatformBatch(
        providerId: _currentPlatformProviderId!,
        page: 1,
        platformName: platformName,
      );
      
      // Add to platform stack
      _platformMovieStack.addAll(initialBatch.movies);
      _currentPlatformPage = 1;
      _totalPlatformPages = initialBatch.totalPages;
      _hasMorePlatformPages = _currentPlatformPage < initialBatch.totalPages;
      
      debugPrint('✅ Initial $platformName batch loaded: ${initialBatch.movies.length} movies');
      debugPrint('📊 Total pages available: ${initialBatch.totalPages}');
      
      // Populate UI immediately with initial results
      populateMovieStackFromPlatform();
      
    } catch (error) {
      debugPrint('❌ Error loading initial platform batch: $error');
      _handlePlatformFetchError(error, platformName);
    } finally {
      _isPlatformFetching = false;
    }
  }

  // Load more platform movies on demand
  Future<void> loadMorePlatformMovies() async {
    if (_isLoadingMorePlatformMovies || !_hasMorePlatformPages || _currentPlatformProviderId == null) {
      return;
    }
    
    _isLoadingMorePlatformMovies = true;
    
    try {
      debugPrint('🔄 Loading more ${_selectedPlatform} movies (page ${_currentPlatformPage + 1})...');
      
      final nextBatch = await _fetchPlatformBatch(
        providerId: _currentPlatformProviderId!,
        page: _currentPlatformPage + 1,
        platformName: _selectedPlatform!,
      );
      
      if (nextBatch.movies.isNotEmpty) {
        // Add new movies to platform stack
        _platformMovieStack.addAll(nextBatch.movies);
        _currentPlatformPage++;
        _hasMorePlatformPages = _currentPlatformPage < nextBatch.totalPages;
        
        debugPrint('✅ Loaded ${nextBatch.movies.length} more ${_selectedPlatform} movies');
        debugPrint('📊 Total ${_selectedPlatform} movies: ${_platformMovieStack.length}');
        
        // Update UI with new movies
        _addMoreMoviesToCache(nextBatch.movies);
      } else {
        _hasMorePlatformPages = false;
        debugPrint('⚠️ No more ${_selectedPlatform} movies available');
      }
      
    } catch (error) {
      debugPrint('❌ Error loading more platform movies: $error');
    } finally {
      _isLoadingMorePlatformMovies = false;
    }
  }

  // Add more movies to cache without clearing existing ones
  Future<void> _addMoreMoviesToCache(List<Movie> newMovies) async {
    // Build blacklist from current user data if available
    final excluded = <int>{};
    try {
      final user = await _userService?.getCurrentUserData();
      if (user != null) {
        excluded.addAll(user.watchedMovieIds);
        excluded.addAll(user.skippedMovieIds);
        excluded.addAll(user.bookmarkedMovieIds);
      }
    } catch (_) {}
    for (final movie in newMovies) {
      if (excluded.contains(movie.id)) continue;
      if (!_cachedMovieIds.contains(movie.id)) {
        _movieCache.add(movie);
        _cachedMovieIds.add(movie.id);
      }
    }
  }

  // Check if we should load more movies (when user is near the end)
  bool shouldLoadMorePlatformMovies(int currentIndex) {
    if (!_hasMorePlatformPages || _isLoadingMorePlatformMovies) return false;
    
    // Load more when user is 5 items away from the end
    return currentIndex >= _platformMovieStack.length - 5;
  }

  // Clear current movie stack
  void _clearCurrentMovieStack() {
    _movieCache.clear();
    _cachedMovieIds.clear();
    _filterCache.clear();
    _lastFetchedPage = 0;
  }

  // Multi-page platform fetching engine
  Future<void> _fetchAllPlatformMovies(String platformName) async {
    if (_isPlatformFetching) return;
    
    _isPlatformFetching = true;
    _platformMovieStack.clear();
    
    try {
      final providerId = PLATFORM_PROVIDERS[platformName]!;
      int currentPage = 1;
      bool hasMorePages = true;
      
      // Fetch ALL pages, not just first page
      while (hasMorePages && currentPage <= 500) { // Safety limit of 500 pages
        debugPrint('🔄 Fetching $platformName movies - Page $currentPage');
        
        // Update progress for user feedback
        _platformFetchProgress = currentPage;
        
        // Make API call for this page
        final pageResults = await _fetchPlatformMoviesPage(
          providerId: providerId,
          page: currentPage,
          platformName: platformName
        );
        
        // Check if we got results
        if (pageResults.movies.isEmpty) {
          debugPrint('⚠️ No more $platformName movies found at page $currentPage');
          hasMorePages = false;
          break;
        }
        
        // Add movies to platform stack
        _platformMovieStack.addAll(pageResults.movies);
        
        // Update total pages info
        _totalPlatformPages = pageResults.totalPages;
        
        // Check if we've reached the last page
        if (currentPage >= pageResults.totalPages) {
          hasMorePages = false;
        }
        
        currentPage++;
        
        // Optional: Add small delay to avoid hitting rate limits
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _platformFetchComplete = true;
      debugPrint('✅ Platform fetch complete: ${_platformMovieStack.length} $platformName movies loaded');
      
    } catch (error) {
      debugPrint('❌ Error fetching platform movies: $error');
      _handlePlatformFetchError(error, platformName);
    } finally {
      _isPlatformFetching = false;
    }
  }

  // Individual page fetching method
  Future<PlatformPageResult> _fetchPlatformMoviesPage({
    required String providerId,
    required int page,
    required String platformName,
  }) async {
    
    // Build API request for this specific platform and page
    final params = {
      'api_key': _apiKey,
      'with_watch_providers': providerId,
      'watch_region': 'US', // or user's region
      'page': page.toString(),
      'sort_by': 'popularity.desc',
      'include_adult': _shouldIncludeAdultContent(),
      'vote_count.gte': 10,
      'vote_average.gte': 5.0,
      // Include current filters if any (genre, year, etc.)
      ..._buildCurrentFilterParams(),
    };
    
    final response = await _dio.get(
      '$_baseUrl/discover/movie',
      queryParameters: params,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Platform API call failed: ${response.statusCode}');
    }
    
    final data = response.data;
    
    return PlatformPageResult(
      movies: _processMovieResults(data['results'] ?? []),
      currentPage: data['page'] ?? page,
      totalPages: data['total_pages'] ?? 1,
      totalResults: data['total_results'] ?? 0,
    );
  }

  // Helper class for page results
  // Build current filter parameters for platform requests
  Map<String, dynamic> _buildCurrentFilterParams() {
    final params = <String, dynamic>{};
    
    // Add existing genre filters
    if (_selectedLanguage != null && _selectedLanguage!.isNotEmpty) {
      params['with_original_language'] = _selectedLanguage!;
    }
    
    // Add year filters
    if (_releaseYear != null) {
      params['primary_release_year'] = _releaseYear.toString();
    }
    
    // Add rating filters
    if (_minVoteAverage != null) {
      params['vote_average.gte'] = _minVoteAverage.toString();
    }
    
    // Add person filters (actor/director)
    if (_selectedPerson != null && _selectedPersonType != null) {
      // Note: Person filters might need to be handled differently for platform requests
      // as TMDB might not support combining person filters with watch providers
    }
    
    return params;
  }

  // Platform filter clearing
  void clearPlatformFilter() {
    _selectedPlatform = null;
    _platformMovieStack.clear();
    _platformFetchComplete = false;
    _platformFetchProgress = 0;
    _totalPlatformPages = 0;
    
    // Reload movies with regular discovery (no platform restriction)
    _loadRegularMovies();
  }

  Future<void> _loadRegularMovies() async {
    // Return to normal movie loading without platform restrictions
    _movieCache.clear();
    _cachedMovieIds.clear();
    _filterCache.clear();
    _lastFetchedPage = 0;
    
    // Reload initial movies
    await preloadMovies(targetCount: 200);
  }

  // Stack population strategy
  Future<void> populateMovieStackFromPlatform() async {
    // Clear existing movie cache
    _movieCache.clear();
    _cachedMovieIds.clear();
    
    // Shuffle platform movies for variety
    final shuffledPlatformMovies = List<Movie>.from(_platformMovieStack);
    shuffledPlatformMovies.shuffle();
    
    // Build blacklist from current user data if available
    final excluded = <int>{};
    try {
      final user = await _userService?.getCurrentUserData();
      if (user != null) {
        excluded.addAll(user.watchedMovieIds);
        excluded.addAll(user.skippedMovieIds);
        excluded.addAll(user.bookmarkedMovieIds);
      }
    } catch (_) {}
    
    // Add to main movie cache, skipping excluded
    for (final movie in shuffledPlatformMovies) {
      if (excluded.contains(movie.id)) continue;
      if (!_cachedMovieIds.contains(movie.id)) {
        _movieCache.add(movie);
        _cachedMovieIds.add(movie.id);
      }
    }
    
    debugPrint('✅ Movie stack populated with ${_movieCache.length} ${_selectedPlatform} movies (excluded: ${excluded.length})');
  }

  // Error handling for platform fetching
  void _handlePlatformFetchError(dynamic error, String platformName) {
    debugPrint('❌ Platform fetch error for $platformName: $error');
    
    // Clear platform state on error
    _selectedPlatform = null;
    _platformMovieStack.clear();
    _platformFetchComplete = false;
    _platformFetchProgress = 0;
    _totalPlatformPages = 0;
    
    // Fall back to regular movies
    _loadRegularMovies();
  }

  // Check if we're in platform mode
  bool get isInPlatformMode => _selectedPlatform != null;

  // Get platform movies for infinite loading
  List<Movie> getAvailablePlatformMovies() {
    if (!isInPlatformMode) return [];
    
    // Return movies from platform stack that aren't in current cache
    return _platformMovieStack.where((movie) => 
      !_cachedMovieIds.contains(movie.id)
    ).toList();
  }

  // Refill from platform stack for infinite loading
  void refillFromPlatformStack() {
    if (!isInPlatformMode) return;
    
    // Move more movies from platform stack to active cache
    final remainingMovies = getAvailablePlatformMovies().take(50).toList();
    
    for (final movie in remainingMovies) {
      if (!_cachedMovieIds.contains(movie.id)) {
        _movieCache.add(movie);
        _cachedMovieIds.add(movie.id);
      }
    }
    
    debugPrint('🔄 Refilled cache with ${remainingMovies.length} more ${_selectedPlatform} movies');
  }

  // Fetch a single batch of platform movies (20-30 movies per batch)
  Future<PlatformPageResult> _fetchPlatformBatch({
    required String providerId,
    required int page,
    required String platformName,
  }) async {
    
    // Build API request for this specific platform and page
    final params = {
      'api_key': _apiKey,
      'with_watch_providers': providerId,
      'watch_region': 'US', // or user's region
      'page': page.toString(),
      'sort_by': 'popularity.desc',
      'include_adult': _shouldIncludeAdultContent(),
      'vote_count.gte': 10,
      'vote_average.gte': 5.0,
      // Include current filters if any (genre, year, etc.)
      ..._buildCurrentFilterParams(),
    };
    
    final response = await _dio.get(
      '$_baseUrl/discover/movie',
      queryParameters: params,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Platform API call failed: ${response.statusCode}');
    }
    
    final data = response.data;
    
    return PlatformPageResult(
      movies: _processMovieResults(data['results'] ?? []),
      currentPage: data['page'] ?? page,
      totalPages: data['total_pages'] ?? 1,
      totalResults: data['total_results'] ?? 0,
    );
  }
}
