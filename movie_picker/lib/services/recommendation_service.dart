import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import '../models/user_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie_recommendation.dart';
import '../models/friendship.dart';
import 'user_data_service.dart';

class RecommendationService {
  static const String _preferencesKey = 'user_preferences';
  UserPreferences _userPreferences = UserPreferences();
  SharedPreferences? _prefs;

  // Cache for user preferences to avoid repeated loading
  final Map<String, UserPreferences> _userPreferencesCache = {};

  // Weights for different factors in recommendation scoring
  static const double genreWeight = 0.3;
  static const double languageWeight = 0.15;
  static const double decadeWeight = 0.2;
  static const double ratingWeight = 0.25;
  static const double qualityWeight = 0.1;

  // Public getter for user preferences (legacy support)
  UserPreferences get userPreferences => _userPreferences;

  // Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadUserPreferences();
  }

  // Load user preferences from storage (legacy method)
  Future<void> _loadUserPreferences() async {
    final prefsJson = _prefs?.getString(_preferencesKey);
    if (prefsJson != null) {
      try {
        final prefsMap = jsonDecode(prefsJson);
        _userPreferences = UserPreferences.fromJson(prefsMap);
      } catch (e) {
        debugPrint('Error loading user preferences: $e');
        _userPreferences = UserPreferences();
      }
    }
  }

  // Save user preferences to storage (legacy method)
  Future<void> _saveUserPreferences() async {
    final prefsJson = jsonEncode(_userPreferences.toJson());
    await _prefs?.setString(_preferencesKey, prefsJson);
  }

  // Get current Firebase user ID
  String? get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Clear cache for a specific user (or all users if userId is null)
  void clearUserPreferencesCache(String? userId) {
    if (userId == null) {
      _userPreferencesCache.clear();
    } else {
      _userPreferencesCache.remove(userId);
    }
  }

  // Get user preferences for current Firebase user
  Future<UserPreferences> getUserPreferences() async {
    final userId = _currentUserId;
    if (userId == null) {
      return UserPreferences(); // Return default preferences for non-authenticated users
    }
    return _loadUserPreferencesForUser(userId);
  }

  // Record interaction for current Firebase user
  Future<void> recordInteraction({
    required Movie movie,
    required String interactionType,
    double? rating,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) {
        debugPrint('⚠️ No user signed in - cannot record interaction');
      }
      return; // Don't record interactions for non-authenticated users
    }
    
    if (kDebugMode) {
      debugPrint('📝 Recording interaction for user $userId: $interactionType - ${movie.title}');
    }
    
    await recordInteractionForUser(
      userId: userId,
      movie: movie,
      interactionType: interactionType,
      rating: rating,
    );
  }

  // Get recommendations for current Firebase user
  Future<List<Movie>> getRecommendations(
    List<Movie> movies, {
    int limit = 50,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      // Return movies sorted by quality for non-authenticated users
      return movies.take(limit).toList();
    }
    return getRecommendationsForUser(movies, userId, limit: limit);
  }

  // Get user insights for current Firebase user
  Future<Map<String, dynamic>> getUserInsights() async {
    final userId = _currentUserId;
    if (userId == null) {
      return {
        'totalInteractions': 0,
        'genrePreferences': <String, double>{},
        'languagePreferences': <String, double>{},
        'decadePreferences': <String, double>{},
        'averageRating': 0.0,
      };
    }
    return getUserInsightsForUser(userId);
  }

  // Load user-specific preferences
  Future<UserPreferences> _loadUserPreferencesForUser(String userId) async {
    // Check cache first
    if (_userPreferencesCache.containsKey(userId)) {
      return _userPreferencesCache[userId]!;
    }

    final prefsJson = _prefs?.getString('user_preferences_$userId');
    if (prefsJson != null) {
      try {
        final prefsMap = jsonDecode(prefsJson);
        final userPrefs = UserPreferences.fromJson(prefsMap);
        _userPreferencesCache[userId] = userPrefs;
        return userPrefs;
      } catch (e) {
        debugPrint('Error loading preferences for user $userId: $e');
      }
    }

    // Return default preferences if not found
    final defaultPrefs = UserPreferences();
    _userPreferencesCache[userId] = defaultPrefs;
    return defaultPrefs;
  }

  // Save user-specific preferences
  Future<void> _saveUserPreferencesForUser(String userId, UserPreferences userPrefs) async {
    try {
      final prefsJson = jsonEncode(userPrefs.toJson());
      await _prefs?.setString('user_preferences_$userId', prefsJson);
      _userPreferencesCache[userId] = userPrefs;
    } catch (e) {
      debugPrint('Error saving preferences for user $userId: $e');
    }
  }

  // Record a user interaction and update preferences for specific user
  Future<void> recordInteractionForUser({
    required String userId,
    required Movie movie,
    required String interactionType,
    double? rating,
  }) async {
    final userPrefs = await _loadUserPreferencesForUser(userId);

    // Update preferences based on interaction
    _updatePreferencesFromInteractionForUser(
      userPrefs,
      movie,
      interactionType,
      rating,
    );

    // Update statistics
    _updateStatisticsForUser(userPrefs, interactionType, rating);

    // Save updated preferences
    await _saveUserPreferencesForUser(userId, userPrefs);

    // Update cache
    _userPreferencesCache[userId] = userPrefs;
  }

  // Update preferences based on movie interaction for specific user
  void _updatePreferencesFromInteractionForUser(
    UserPreferences userPrefs,
    Movie movie,
    String interactionType,
    double? rating,
  ) {
    // Update genre preferences
    _updateGenrePreferencesForUser(userPrefs, movie.genre, interactionType, rating);
    _updateGenrePreferencesForUser(userPrefs, movie.subgenre, interactionType, rating);

    // Update language preferences
    _updateLanguagePreferencesForUser(userPrefs, movie.language, interactionType, rating);
    
    // Update decade preferences
    final decade = _getDecadeFromYear(movie.releaseDate);
    if (decade != null) {
      _updateDecadePreferencesForUser(userPrefs, decade, interactionType, rating);
    }
    
    // Update tag preferences from keywords
    for (final keyword in movie.keywords) {
      _updateTagPreferencesForUser(userPrefs, keyword, interactionType, rating);
    }
    }

  // Update genre preferences for specific user
  void _updateGenrePreferencesForUser(
    UserPreferences userPrefs,
    String genre,
    String interactionType,
    double? rating,
  ) {
    if (genre.isEmpty) return;
    
    final normalizedGenre = genre.toLowerCase().trim();
    
    switch (interactionType) {
      case 'watched':
        userPrefs.genrePreferences[normalizedGenre] = 
            (userPrefs.genrePreferences[normalizedGenre] ?? 0.0) + 1.0;
        break;
      case 'skipped':
        userPrefs.genrePreferences[normalizedGenre] = 
            (userPrefs.genrePreferences[normalizedGenre] ?? 0.0) - 0.5;
        break;
      case 'rated':
        if (rating != null) {
          final currentScore = userPrefs.genrePreferences[normalizedGenre] ?? 0.0;
          final ratingBonus = (rating - 5.0) * 0.2; // Scale rating to preference
          userPrefs.genrePreferences[normalizedGenre] = currentScore + ratingBonus;
        }
        break;
      case 'bookmarked':
        userPrefs.genrePreferences[normalizedGenre] = 
            (userPrefs.genrePreferences[normalizedGenre] ?? 0.0) + 0.5;
        break;
    }
  }

  // Update language preferences for specific user
  void _updateLanguagePreferencesForUser(
    UserPreferences userPrefs,
    String language,
    String interactionType,
    double? rating,
  ) {
    if (language.isEmpty) return;

    switch (interactionType) {
      case 'watched':
        userPrefs.languagePreferences[language] = 
            (userPrefs.languagePreferences[language] ?? 0.0) + 1.0;
        break;
      case 'skipped':
        userPrefs.languagePreferences[language] = 
            (userPrefs.languagePreferences[language] ?? 0.0) - 0.5;
        break;
      case 'rated':
        if (rating != null) {
          final currentScore = userPrefs.languagePreferences[language] ?? 0.0;
          final ratingBonus = (rating - 5.0) * 0.2;
          userPrefs.languagePreferences[language] = currentScore + ratingBonus;
        }
        break;
      case 'bookmarked':
        userPrefs.languagePreferences[language] = 
            (userPrefs.languagePreferences[language] ?? 0.0) + 0.5;
        break;
    }
  }

  // Update decade preferences for specific user
  void _updateDecadePreferencesForUser(
    UserPreferences userPrefs,
    String decade,
    String interactionType,
    double? rating,
  ) {
    switch (interactionType) {
      case 'watched':
        userPrefs.decadePreferences[decade] = 
            (userPrefs.decadePreferences[decade] ?? 0.0) + 1.0;
        break;
      case 'skipped':
        userPrefs.decadePreferences[decade] = 
            (userPrefs.decadePreferences[decade] ?? 0.0) - 0.5;
        break;
      case 'rated':
        if (rating != null) {
          final currentScore = userPrefs.decadePreferences[decade] ?? 0.0;
          final ratingBonus = (rating - 5.0) * 0.2;
          userPrefs.decadePreferences[decade] = currentScore + ratingBonus;
        }
        break;
      case 'bookmarked':
        userPrefs.decadePreferences[decade] = 
            (userPrefs.decadePreferences[decade] ?? 0.0) + 0.5;
        break;
    }
  }

  // Update tag preferences for specific user
  void _updateTagPreferencesForUser(
    UserPreferences userPrefs,
    String tag,
    String interactionType,
    double? rating,
  ) {
    if (tag.isEmpty) return;
    
    final normalizedTag = tag.toLowerCase().trim();
    
    switch (interactionType) {
      case 'watched':
        userPrefs.userLikedTags[normalizedTag] = 
            (userPrefs.userLikedTags[normalizedTag] ?? 0.0) + 1.0;
        break;
      case 'skipped':
        userPrefs.userDislikedTags[normalizedTag] = 
            (userPrefs.userDislikedTags[normalizedTag] ?? 0.0) + 0.5;
        break;
      case 'rated':
        if (rating != null) {
          if (rating >= 6.0) {
            userPrefs.userLikedTags[normalizedTag] = 
                (userPrefs.userLikedTags[normalizedTag] ?? 0.0) + (rating - 5.0) * 0.2;
          } else {
            userPrefs.userDislikedTags[normalizedTag] = 
                (userPrefs.userDislikedTags[normalizedTag] ?? 0.0) + (5.0 - rating) * 0.2;
          }
        }
        break;
      case 'bookmarked':
        userPrefs.userLikedTags[normalizedTag] = 
            (userPrefs.userLikedTags[normalizedTag] ?? 0.0) + 0.5;
        break;
    }
  }

  // Update overall statistics for specific user
  void _updateStatisticsForUser(
    UserPreferences userPrefs,
    String interactionType,
    double? rating,
  ) {
    switch (interactionType) {
      case 'watched':
        userPrefs.totalWatchedMovies++;
        break;
      case 'skipped':
        userPrefs.totalSkippedMovies++;
        break;
      case 'rated':
        if (rating != null) {
          userPrefs.totalRatedMovies++;
          // Update average rating
          final totalRating =
              userPrefs.averageUserRating * (userPrefs.totalRatedMovies - 1) +
              rating;
          userPrefs.averageUserRating =
              totalRating / userPrefs.totalRatedMovies;
        }
        break;
    }
  }

  // Get decade from year
  String? _getDecadeFromYear(String year) {
    final yearInt = int.tryParse(year);
    if (yearInt == null) return null;
    
    final decade = (yearInt ~/ 10) * 10;
    return '${decade}s';
  }

  // Get personalized recommendations for a specific user
  Future<List<Movie>> getRecommendationsForUser(
    List<Movie> movies,
    String userId, {
    int limit = 50,
  }) async {
    final userPrefs = await _loadUserPreferencesForUser(userId);

    // Hard filter: never recommend adult content if the app privacy setting is off
    final filteredPool = movies.where((m) => !m.adult).toList();

    // Score each movie based on user preferences
    final scoredMovies = filteredPool.map((movie) {
      final score = _calculatePersonalizedScoreForUser(movie, userPrefs);
          return {'movie': movie, 'score': score};
        }).toList();

    // Sort by score (highest first), then by TMDB rating as a stable tiebreaker
    scoredMovies.sort((a, b) {
      final ds = (b['score'] as double).compareTo(a['score'] as double);
      if (ds != 0) return ds;
      final am = a['movie'] as Movie;
      final bm = b['movie'] as Movie;
      return bm.voteAverage.compareTo(am.voteAverage);
    });

    // Return top movies
    return scoredMovies
        .take(limit)
        .map((item) => item['movie'] as Movie)
        .toList();
  }

  // Calculate personalized score for a movie for specific user
  double _calculatePersonalizedScoreForUser(Movie movie, UserPreferences userPrefs) {
    double score = 0.0;
    
    // Safety: adult content should not be scored positively
    if (movie.adult) return -9999.0;
    
    // Genre score
    final genreScore = (userPrefs.genrePreferences[movie.genre.toLowerCase()] ?? 0.0) +
                      (userPrefs.genrePreferences[movie.subgenre.toLowerCase()] ?? 0.0);
    score += genreScore * genreWeight;
    
    // Language score
    final languageScore = userPrefs.languagePreferences[movie.language] ?? 0.0;
    score += languageScore * languageWeight;
    
    // Decade score
    final decade = _getDecadeFromYear(movie.releaseDate);
    if (decade != null) {
      final decadeScore = userPrefs.decadePreferences[decade] ?? 0.0;
      score += decadeScore * decadeWeight;
    }
    
    // Rating score (TMDB rating)
    score += movie.voteAverage * ratingWeight;
    
    // Tag score (from keywords) — increase influence a bit for better alignment
    double tagScore = 0.0;
    int tagCount = 0;
    for (final keyword in movie.keywords) {
      final normalizedKeyword = keyword.toLowerCase().trim();
      final likedScore = userPrefs.userLikedTags[normalizedKeyword] ?? 0.0;
      final dislikedScore = userPrefs.userDislikedTags[normalizedKeyword] ?? 0.0;
      tagScore += likedScore - dislikedScore;
      tagCount++;
    }
    if (tagCount > 0) {
      score += (tagScore / tagCount) * 0.45; // Stronger tag preference influence
    }

    // Quality bonus for high-rated movies
    if (movie.voteAverage >= 7.0) {
      score += 2.0 * qualityWeight;
    } else if (movie.voteAverage >= 6.0) {
      score += 1.0 * qualityWeight;
    }

    // Fallback smoothing when user genre prefs are sparse
    final hasGenrePrefs = userPrefs.genrePreferences.isNotEmpty;
    if (!hasGenrePrefs) {
      // Lightly prefer mainstream genres to avoid randomness for cold-start
      const mainstream = {
        'action', 'comedy', 'drama', 'thriller', 'adventure', 'romance', 'animation', 'family'
      };
      if (mainstream.contains(movie.genre.toLowerCase()) || mainstream.contains(movie.subgenre.toLowerCase())) {
        score += 0.5; // small nudge
      }
    }
    
    return score;
  }

  // Get user insights for specific user
  Future<Map<String, dynamic>> getUserInsightsForUser(String userId) async {
    final userPrefs = await _loadUserPreferencesForUser(userId);
    
    // Get top genres
    final sortedGenres = userPrefs.genrePreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(5).map((e) => e.key).toList();
    
    // Get top languages
    final sortedLanguages = userPrefs.languagePreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLanguages = sortedLanguages.take(3).map((e) => e.key).toList();
    
    // Get top decades
    final sortedDecades = userPrefs.decadePreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDecades = sortedDecades.take(3).map((e) => e.key).toList();
    
    // Calculate total interactions
    final totalInteractions = userPrefs.totalWatchedMovies + 
                             userPrefs.totalSkippedMovies + 
                             userPrefs.totalRatedMovies;
    
    return {
      'topGenres': topGenres,
      'topLanguages': topLanguages,
      'topDecades': topDecades,
      'totalWatchedMovies': userPrefs.totalWatchedMovies,
      'totalSkippedMovies': userPrefs.totalSkippedMovies,
      'totalRatedMovies': userPrefs.totalRatedMovies,
      'totalInteractions': totalInteractions,
      'averageUserRating': userPrefs.averageUserRating,
    };
  }

  // Reset user preferences for specific user
  Future<void> resetPreferencesForUser(String userId) async {
    final userPrefs = UserPreferences();
    await _saveUserPreferencesForUser(userId, userPrefs);
  }

  // Export preferences for backup for specific user
  Future<String> exportPreferencesForUser(String userId) async {
    final userPrefs = await _loadUserPreferencesForUser(userId);
    return jsonEncode(userPrefs.toJson());
  }

  // Import preferences from backup for specific user
  Future<void> importPreferencesForUser(
    String userId,
    String preferencesJson,
  ) async {
    try {
      final prefsMap = jsonDecode(preferencesJson);
      final userPrefs = UserPreferences.fromJson(prefsMap);
      await _saveUserPreferencesForUser(userId, userPrefs);
    } catch (e) {
      debugPrint('Error importing preferences for user $userId: $e');
      throw Exception('Invalid preferences format');
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a movie recommendation to a friend
  Future<void> sendMovieRecommendation({
    required String toUserId,
    required String movieId,
    String? message,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final recommendation = MovieRecommendation(
      id: _firestore.collection('recommendations').doc().id,
      fromUserId: currentUser.uid,
      toUserId: toUserId,
      movieId: movieId,
      timestamp: DateTime.now(),
      message: message,
    );

    await _firestore
        .collection('recommendations')
        .doc(recommendation.id)
        .set(recommendation.toJson());
  }

  // Get all recommendations sent to current user
  Stream<List<MovieRecommendation>> getReceivedRecommendations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('recommendations')
        .where('toUserId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MovieRecommendation.fromJson(doc.data()))
            .toList());
  }

  // Get all recommendations sent by current user
  Stream<List<MovieRecommendation>> getSentRecommendations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('recommendations')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MovieRecommendation.fromJson(doc.data()))
            .toList());
  }

  // Mark a recommendation as read
  Future<void> markRecommendationAsRead(String recommendationId) async {
    await _firestore
        .collection('recommendations')
        .doc(recommendationId)
        .update({'isRead': true});
  }

  // Get count of shared movies between two users
  Future<int> getSharedMovieCount(String user1Id, String user2Id) async {
    final recommendations = await _firestore
        .collection('recommendations')
        .where('fromUserId', whereIn: [user1Id, user2Id])
        .where('toUserId', whereIn: [user1Id, user2Id])
        .get();

    // Count unique movies shared between these users
    final sharedMovies = <String>{};
    for (final doc in recommendations.docs) {
      final recommendation = MovieRecommendation.fromJson(doc.data());
      if ((recommendation.fromUserId == user1Id && recommendation.toUserId == user2Id) ||
          (recommendation.fromUserId == user2Id && recommendation.toUserId == user1Id)) {
        sharedMovies.add(recommendation.movieId);
      }
    }

    return sharedMovies.length;
  }

  // Get friends with shared movie counts, sorted by interaction
  Future<List<Map<String, dynamic>>> getFriendsWithSharedCounts() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    // Get all accepted friendships
    final friendships = await _firestore
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .where('requesterUid', isEqualTo: currentUser.uid)
        .get();

    final receivedFriendships = await _firestore
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .where('receiverUid', isEqualTo: currentUser.uid)
        .get();

    final allFriendships = [...friendships.docs, ...receivedFriendships.docs];
    final friendIds = <String>{};

    for (final doc in allFriendships) {
      final friendship = Friendship.fromJson(doc.data());
      if (friendship.requesterUid == currentUser.uid) {
        friendIds.add(friendship.receiverUid);
      } else {
        friendIds.add(friendship.requesterUid);
      }
    }

    // Get user profiles and shared counts
    final friendsWithCounts = <Map<String, dynamic>>[];
    
    for (final friendId in friendIds) {
      final userDoc = await _firestore.collection('users').doc(friendId).get();
      if (userDoc.exists) {
        final userData = UserData.fromJson(userDoc.data()!);
        final sharedCount = await getSharedMovieCount(currentUser.uid, friendId);
        
        friendsWithCounts.add({
          'userId': friendId,
          'username': userData.username,
          'avatarId': userData.avatarId,
          'sharedCount': sharedCount,
        });
      }
    }

    // Sort by shared count (descending), then alphabetically
    friendsWithCounts.sort((a, b) {
      final countComparison = b['sharedCount'].compareTo(a['sharedCount']);
      if (countComparison != 0) return countComparison;
      return a['username'].compareTo(b['username']);
    });

    return friendsWithCounts;
  }

  // Delete a recommendation
  Future<void> deleteRecommendation(String recommendationId) async {
    await _firestore
        .collection('recommendations')
        .doc(recommendationId)
        .delete();
  }

  // Get unread recommendations count
  Stream<int> getUnreadRecommendationsCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('recommendations')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get a normalized match percentage for a movie using a context pool for normalization
  Future<double> getMatchPercentForCurrentUser({
    required Movie movie,
    required List<Movie> contextPool,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return 0.0;
    final userPrefs = await _loadUserPreferencesForUser(userId);

    // Score the context pool and compute distribution
    final scores = <double>[];
    for (final m in contextPool) {
      if (!m.adult) {
        scores.add(_calculatePersonalizedScoreForUser(m, userPrefs));
      }
    }
    // Include the target movie in the distribution
    final targetScore = _calculatePersonalizedScoreForUser(movie, userPrefs);
    scores.add(targetScore);

    if (scores.isEmpty) return 0.0;

    // Primary: percentile rank (higher is better). This better matches user expectations on ranking.
    final sorted = List<double>.from(scores)..sort();
    final n = sorted.length;
    // Find the position of the target score (handle duplicates by taking the upper rank)
    int idx = sorted.lastIndexOf(targetScore);
    if (idx == -1) {
      // Fallback search if floating comparisons fail
      idx = sorted.indexWhere((s) => (s - targetScore).abs() < 1e-9);
      if (idx == -1) idx = sorted.indexWhere((s) => s >= targetScore);
      if (idx == -1) idx = n - 1;
    }
    // Convert to percentile: top item → ~100, bottom → ~0
    final percentile = (idx / (n - 1).clamp(1, 1 << 30)) * 100.0;
    final pctRank = (100.0 - percentile).clamp(0.0, 100.0);

    // Degenerate distribution fallback: if almost all scores are identical, use min-max
    double minS = sorted.first;
    double maxS = sorted.last;
    if ((maxS - minS).abs() <= 1e-6) {
      return 100.0; // All scores effectively equal
    }

    // Slight smoothing to avoid showing extremely low values for close contenders
    final smoothed = (pctRank * 0.85) + 5.0; // bring up floor slightly without inflating top
    return smoothed.clamp(0.0, 100.0);
  }
}
