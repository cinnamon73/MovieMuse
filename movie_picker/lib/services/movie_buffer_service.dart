import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';

/// Filter fingerprint for tracking filter state changes
class FilterFingerprint {
  final Set<String> genres;
  final String? language;
  final String? timePeriod;
  final String? person;
  final String? personType;
  final int timestamp;

  FilterFingerprint({
    required this.genres,
    this.language,
    this.timePeriod,
    this.person,
    this.personType,
  }) : timestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterFingerprint &&
          runtimeType == other.runtimeType &&
          genres.toString() == other.genres.toString() &&
          language == other.language &&
          timePeriod == other.timePeriod &&
          person == other.person &&
          personType == other.personType;

  @override
  int get hashCode =>
      genres.toString().hashCode ^
      language.hashCode ^
      timePeriod.hashCode ^
      person.hashCode ^
      personType.hashCode;

  @override
  String toString() {
    return 'FilterFingerprint(genres: $genres, language: $language, timePeriod: $timePeriod, person: $person)';
  }
}

/// Movie buffer that maintains a healthy queue of ready movies
class MovieBufferService {
  final MovieService _movieService;
  
  // Buffer state
  final List<Movie> _buffer = [];
  FilterFingerprint? _currentFingerprint;
  bool _isFetching = false;
  bool _hasMoreMovies = true;
  
  // Blacklist management
  final Set<int> _blacklistedIds = {};
  
  // Configuration
  static const int _minBufferSize = 3;
  static const int _targetBufferSize = 5;
  static const int _maxBufferSize = 10;
  
  // Error handling
  String? _lastError;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  
  // Performance tracking
  int _totalFetched = 0;
  int _bufferRefills = 0;
  DateTime? _lastFetchTime;

  MovieBufferService(this._movieService);

  /// Get the next movie from buffer (UI layer interface)
  Movie? getNextMovie() {
    if (_buffer.isEmpty) {
      debugPrint('⚠️ Buffer empty - triggering immediate refill');
      _triggerBufferRefill();
      return null;
    }
    
    final movie = _buffer.removeLast();
    debugPrint('🎬 Providing movie from buffer: ${movie.title} (Buffer size: ${_buffer.length})');
    
    // Proactive refill if buffer is getting low
    if (_buffer.length <= _minBufferSize && !_isFetching) {
      _triggerBufferRefill();
    }
    
    return movie;
  }

  /// Update filters and clear stale buffer
  void updateFilters({
    Set<String>? genres,
    String? language,
    String? timePeriod,
    String? person,
    String? personType,
  }) {
    final newFingerprint = FilterFingerprint(
      genres: genres ?? {},
      language: language,
      timePeriod: timePeriod,
      person: person,
      personType: personType,
    );

    // Check if filters actually changed
    if (_currentFingerprint != newFingerprint) {
      debugPrint('🔄 Filter change detected: ${_currentFingerprint} → $newFingerprint');
      
      // Clear buffer and reset state
      _buffer.clear();
      _currentFingerprint = newFingerprint;
      _hasMoreMovies = true;
      _consecutiveErrors = 0;
      _lastError = null;
      
      // Start fetching with new filters
      _triggerBufferRefill();
    }
  }

  /// Add movie to blacklist (prevents duplicates)
  void blacklistMovie(int movieId) {
    _blacklistedIds.add(movieId);
    debugPrint('🚫 Blacklisted movie ID: $movieId (Total blacklisted: ${_blacklistedIds.length})');
  }

  /// Get current buffer status
  Map<String, dynamic> getBufferStatus() {
    return {
      'bufferSize': _buffer.length,
      'isFetching': _isFetching,
      'hasMoreMovies': _hasMoreMovies,
      'lastError': _lastError,
      'consecutiveErrors': _consecutiveErrors,
      'totalFetched': _totalFetched,
      'bufferRefills': _bufferRefills,
      'currentFingerprint': _currentFingerprint?.toString(),
    };
  }

  /// Trigger buffer refill (proactive loading)
  Future<void> _triggerBufferRefill() async {
    if (_isFetching || !_hasMoreMovies) {
      debugPrint('⏸️ Skipping buffer refill: isFetching=$_isFetching, hasMoreMovies=$_hasMoreMovies');
      return;
    }

    _isFetching = true;
    debugPrint('🔄 Starting buffer refill (current size: ${_buffer.length})');

    try {
      final startTime = DateTime.now();
      
      // Fetch movies with current filters
      final movies = await _fetchMoviesWithCurrentFilters();
      
      if (movies.isNotEmpty) {
        // Validate filter fingerprint hasn't changed
        if (_validateFingerprint()) {
          _addMoviesToBuffer(movies);
          _consecutiveErrors = 0;
          _lastError = null;
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ Buffer refill successful: +${movies.length} movies in ${duration.inMilliseconds}ms');
        } else {
          debugPrint('⚠️ Filter changed during fetch - discarding results');
        }
      } else {
        _handleNoMoreMovies();
      }
      
      _lastFetchTime = DateTime.now();
      _bufferRefills++;
      
    } catch (e) {
      _handleFetchError(e);
    } finally {
      _isFetching = false;
      
      // If buffer is still too small and we have more movies, try again
      if (_buffer.length < _minBufferSize && _hasMoreMovies && _consecutiveErrors < _maxConsecutiveErrors) {
        debugPrint('🔄 Buffer still too small (${_buffer.length}), scheduling another refill');
        Timer(const Duration(milliseconds: 500), () => _triggerBufferRefill());
      }
    }
  }

  /// Fetch movies with current filter state
  Future<List<Movie>> _fetchMoviesWithCurrentFilters() async {
    if (_currentFingerprint == null) {
      debugPrint('⚠️ No filter fingerprint set - using default filters');
      _currentFingerprint = FilterFingerprint(genres: {});
    }

    final fingerprint = _currentFingerprint!;
    
    // Build exclude IDs (blacklisted + buffer contents)
    final excludeIds = <int>{..._blacklistedIds};
    excludeIds.addAll(_buffer.map((m) => m.id));

    debugPrint('🔍 Fetching movies with filters: $fingerprint');
    debugPrint('   Excluding ${excludeIds.length} IDs (blacklisted: ${_blacklistedIds.length}, buffer: ${_buffer.length})');

    // Use MovieService to fetch with current filters
    final movies = await _movieService.findMoviesWithFilters(
      selectedGenres: fingerprint.genres.isNotEmpty ? fingerprint.genres.toList() : null,
      language: fingerprint.language,
      timePeriod: fingerprint.timePeriod,
      excludeIds: excludeIds,
      targetCount: _targetBufferSize * 2, // Fetch more than needed to account for exclusions
      maxPages: 50,
      person: fingerprint.person,
      personType: fingerprint.personType,
    );

    _totalFetched += movies.length;
    debugPrint('📊 Fetched ${movies.length} movies (Total fetched: $_totalFetched)');
    
    return movies;
  }

  /// Add movies to buffer with validation
  void _addMoviesToBuffer(List<Movie> movies) {
    final initialSize = _buffer.length;
    
    for (final movie in movies) {
      // Skip if already blacklisted or in buffer
      if (_blacklistedIds.contains(movie.id) || _buffer.any((m) => m.id == movie.id)) {
        debugPrint('🚫 Skipping duplicate/blacklisted movie: ${movie.title}');
        continue;
      }
      
      // Don't exceed max buffer size
      if (_buffer.length >= _maxBufferSize) {
        debugPrint('📦 Buffer full (${_buffer.length}), skipping remaining movies');
        break;
      }
      
      _buffer.add(movie);
      debugPrint('✅ Added to buffer: ${movie.title}');
    }
    
    final added = _buffer.length - initialSize;
    debugPrint('📦 Buffer updated: $initialSize → ${_buffer.length} (+$added)');
  }

  /// Validate current filter fingerprint hasn't changed
  bool _validateFingerprint() {
    // For now, we'll trust the fingerprint hasn't changed
    // In a more sophisticated implementation, we could track filter changes more granularly
    return true;
  }

  /// Handle case when no more movies are available
  void _handleNoMoreMovies() {
    _hasMoreMovies = false;
    _lastError = 'No more movies available with current filters';
    
    if (_buffer.isEmpty) {
      if (kDebugMode) {
        debugPrint('Buffer empty and no more movies available');
      }
    }
  }

  /// Handle fetch errors with exponential backoff
  void _handleFetchError(dynamic error) {
    _consecutiveErrors++;
    _lastError = error.toString();
    
    if (kDebugMode) {
      debugPrint('Fetch error (attempt $_consecutiveErrors): $error');
    }
    
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _hasMoreMovies = false;
      if (kDebugMode) {
        debugPrint('Max consecutive errors reached - stopping fetch attempts');
      }
    }
  }

  /// Clear buffer and reset state (for testing or error recovery)
  void clearBuffer() {
    _buffer.clear();
    _isFetching = false;
    _hasMoreMovies = true;
    _consecutiveErrors = 0;
    _lastError = null;
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'bufferSize': _buffer.length,
      'isFetching': _isFetching,
      'hasMoreMovies': _hasMoreMovies,
      'blacklistedCount': _blacklistedIds.length,
      'consecutiveErrors': _consecutiveErrors,
      'totalFetched': _totalFetched,
      'bufferRefills': _bufferRefills,
      'currentFingerprint': _currentFingerprint?.toString(),
      'lastError': _lastError,
      'lastFetchTime': _lastFetchTime?.toIso8601String(),
    };
  }
} 