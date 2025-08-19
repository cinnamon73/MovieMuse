import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';

/// User behavior tracking for adaptive refill triggering
class UserBehaviorTracker {
  final List<DateTime> _recentSwipes = [];
  static const int _maxTrackedSwipes = 10;
  static const Duration _swipeWindow = Duration(minutes: 5);
  
  /// Track a swipe event
  void trackSwipe() {
    final now = DateTime.now();
    _recentSwipes.add(now);
    
    // Keep only recent swipes
    _recentSwipes.removeWhere((time) => now.difference(time) > _swipeWindow);
    
    if (_recentSwipes.length > _maxTrackedSwipes) {
      _recentSwipes.removeRange(0, _recentSwipes.length - _maxTrackedSwipes);
    }
  }
  
  /// Calculate user type based on swipe velocity
  UserType getUserType() {
    if (_recentSwipes.length < 3) {
      return UserType.normal; // Not enough data
    }
    
    final now = DateTime.now();
    final recentSwipes = _recentSwipes.where(
      (time) => now.difference(time) <= _swipeWindow
    ).toList();
    
    if (recentSwipes.length < 3) {
      return UserType.normal;
    }
    
    // Calculate average time between swipes
    final intervals = <Duration>[];
    for (int i = 1; i < recentSwipes.length; i++) {
      intervals.add(recentSwipes[i].difference(recentSwipes[i - 1]));
    }
    
    final avgInterval = intervals.fold<Duration>(
      Duration.zero,
      (sum, interval) => sum + interval
    ) ~/ intervals.length;
    
    debugPrint('📊 User behavior: ${recentSwipes.length} swipes, avg interval: ${avgInterval.inSeconds}s');
    
    if (avgInterval.inSeconds < 3) {
      return UserType.fast;
    } else if (avgInterval.inSeconds > 10) {
      return UserType.slow;
    } else {
      return UserType.normal;
    }
  }
  
  /// Get recommended refill trigger based on user type
  int getRefillTrigger() {
    final userType = getUserType();
    switch (userType) {
      case UserType.fast:
        return 50; // Trigger early for fast swipers
      case UserType.normal:
        return 30; // Balanced trigger
      case UserType.slow:
        return 20; // Keep current behavior for slow users
    }
  }
  
  /// Get recommended refill amount based on user type
  int getRefillAmount() {
    final userType = getUserType();
    switch (userType) {
      case UserType.fast:
        return 300; // More movies for fast swipers
      case UserType.normal:
        return 200; // Current amount
      case UserType.slow:
        return 150; // Less for slow users to save API calls
    }
  }
  
  /// Get recommended initial load based on user type
  int getInitialLoadAmount() {
    final userType = getUserType();
    switch (userType) {
      case UserType.fast:
        return 150; // More initial movies
      case UserType.normal:
        return 100; // Current amount
      case UserType.slow:
        return 75; // Less for slow users
    }
  }
}

/// User types for adaptive behavior
enum UserType { fast, normal, slow }

/// Enhanced queue service that works with existing system
class EnhancedQueueService {
  final MovieService _movieService;
  final UserBehaviorTracker _behaviorTracker = UserBehaviorTracker();
  
  // Refill state
  bool _isRefilling = false;
  int _consecutiveRefillFailures = 0;
  static const int _maxConsecutiveFailures = 3;
  
  // Performance tracking
  int _totalRefills = 0;
  int _successfulRefills = 0;
  DateTime? _lastRefillTime;
  
  // Filter state tracking
  String? _currentFilterHash;
  
  EnhancedQueueService(this._movieService);
  
  /// Enhanced refill check with user behavior awareness
  Future<bool> shouldRefillQueue(int currentQueueSize) async {
    final triggerPoint = _behaviorTracker.getRefillTrigger();
    final shouldRefill = currentQueueSize <= triggerPoint;
    
    if (shouldRefill) {
      final userType = _behaviorTracker.getUserType();
      debugPrint('🔄 Refill check: Queue size $currentQueueSize <= trigger $triggerPoint (User type: $userType)');
    }
    
    return shouldRefill;
  }
  
  /// Robust background refill with retry logic
  Future<List<Movie>> refillQueue({
    required Set<String> selectedGenres,
    required String? selectedLanguage,
    required String? selectedTimePeriod,
    required String? selectedPerson,
    required String? selectedPersonType,
    required Set<int> excludeIds,
  }) async {
    if (_isRefilling) {
      debugPrint('⏸️ Refill already in progress, skipping');
      return [];
    }
    
    _isRefilling = true;
    final startTime = DateTime.now();
    
    try {
      // Update filter hash for validation
      _currentFilterHash = _generateFilterHash(
        selectedGenres, selectedLanguage, selectedTimePeriod, 
        selectedPerson, selectedPersonType
      );
      
      final refillAmount = _behaviorTracker.getRefillAmount();
      final userType = _behaviorTracker.getUserType();
      
      debugPrint('🔄 Starting enhanced refill: $refillAmount movies for $userType user');
      
      final movies = await _fetchWithRetry(
        selectedGenres: selectedGenres,
        selectedLanguage: selectedLanguage,
        selectedTimePeriod: selectedTimePeriod,
        selectedPerson: selectedPerson,
        selectedPersonType: selectedPersonType,
        excludeIds: excludeIds,
        targetCount: refillAmount,
      );
      
      // Validate filter hash hasn't changed during fetch
      if (_validateFilterHash(selectedGenres, selectedLanguage, selectedTimePeriod, 
          selectedPerson, selectedPersonType)) {
        
        _consecutiveRefillFailures = 0;
        _successfulRefills++;
        _lastRefillTime = DateTime.now();
        
        final duration = DateTime.now().difference(startTime);
        debugPrint('✅ Enhanced refill successful: +${movies.length} movies in ${duration.inMilliseconds}ms');
        
        return movies;
      } else {
        debugPrint('⚠️ Filter changed during refill - discarding results');
        return [];
      }
      
    } catch (e) {
      _handleRefillError(e);
      return [];
    } finally {
      _isRefilling = false;
      _totalRefills++;
    }
  }
  
  /// Fetch with exponential backoff retry logic
  Future<List<Movie>> _fetchWithRetry({
    required Set<String> selectedGenres,
    required String? selectedLanguage,
    required String? selectedTimePeriod,
    required String? selectedPerson,
    required String? selectedPersonType,
    required Set<int> excludeIds,
    required int targetCount,
  }) async {
    int attempt = 0;
    const maxAttempts = 3;
    
    while (attempt < maxAttempts) {
      try {
        attempt++;
        debugPrint('🔄 Fetch attempt $attempt/$maxAttempts');
        
        final movies = await _movieService.findMoviesWithFilters(
          selectedGenres: selectedGenres.isNotEmpty ? selectedGenres.toList() : null,
          language: selectedLanguage,
          timePeriod: selectedTimePeriod,
          excludeIds: excludeIds,
          targetCount: targetCount,
          maxPages: 50,
          person: selectedPerson,
          personType: selectedPersonType,
        );
        
        return movies;
        
      } catch (e) {
        debugPrint('❌ Fetch attempt $attempt failed: $e');
        
        if (attempt >= maxAttempts) {
          rethrow; // Give up after max attempts
        }
        
        // Exponential backoff: 2s, 4s, 8s
        final delay = Duration(seconds: 2 * (1 << (attempt - 1)));
        debugPrint('⏳ Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
      }
    }
    
    throw Exception('All fetch attempts failed');
  }
  
  /// Handle refill errors gracefully
  void _handleRefillError(dynamic error) {
    _consecutiveRefillFailures++;
    
    debugPrint('❌ Refill error (attempt $_consecutiveRefillFailures): $error');
    
    if (_consecutiveRefillFailures >= _maxConsecutiveFailures) {
      debugPrint('🚨 Max consecutive refill failures reached - pausing refills');
    }
  }
  
  /// Track user swipe for behavior analysis
  void trackUserSwipe() {
    _behaviorTracker.trackSwipe();
  }
  
  /// Generate filter hash for validation
  String _generateFilterHash(
    Set<String> genres,
    String? language,
    String? timePeriod,
    String? person,
    String? personType,
  ) {
    final parts = [
      genres.toList()..sort(),
      language ?? '',
      timePeriod ?? '',
      person ?? '',
      personType ?? '',
    ];
    return parts.join('|');
  }
  
  /// Validate filter hash hasn't changed
  bool _validateFilterHash(
    Set<String> genres,
    String? language,
    String? timePeriod,
    String? person,
    String? personType,
  ) {
    final currentHash = _generateFilterHash(genres, language, timePeriod, person, personType);
    final isValid = currentHash == _currentFilterHash;
    
    if (!isValid) {
      debugPrint('⚠️ Filter hash changed during fetch: $_currentFilterHash → $currentHash');
    }
    
    return isValid;
  }
  
  /// Get adaptive initial load amount
  int getInitialLoadAmount() {
    return _behaviorTracker.getInitialLoadAmount();
  }
  
  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final successRate = _totalRefills > 0 ? (_successfulRefills / _totalRefills * 100) : 0.0;
    final userType = _behaviorTracker.getUserType();
    
    return {
      'userType': userType.toString(),
      'totalRefills': _totalRefills,
      'successfulRefills': _successfulRefills,
      'successRate': successRate.toStringAsFixed(1),
      'consecutiveFailures': _consecutiveRefillFailures,
      'lastRefillTime': _lastRefillTime?.toIso8601String(),
      'recommendedTrigger': _behaviorTracker.getRefillTrigger(),
      'recommendedRefillAmount': _behaviorTracker.getRefillAmount(),
      'recommendedInitialLoad': _behaviorTracker.getInitialLoadAmount(),
    };
  }
  
  /// Reset error state (for testing or recovery)
  void resetErrorState() {
    _consecutiveRefillFailures = 0;
    debugPrint('🔄 Reset error state - refills enabled');
  }
} 