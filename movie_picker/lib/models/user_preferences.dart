class UserPreferences {
  // Genre preferences (positive and negative weights)
  Map<String, double> genrePreferences = {};

  // Language preferences
  Map<String, double> languagePreferences = {};

  // Decade preferences (e.g., "2020s", "2010s", etc.)
  Map<String, double> decadePreferences = {};

  // Rating range preferences (tracks preferred rating ranges)
  Map<String, double> ratingRangePreferences = {};

  // Actor/Director preferences (can be expanded later)
  Map<String, double> personPreferences = {};

  // Tag-based preferences for keyword overlap scoring
  Map<String, double> userLikedTags = {};
  Map<String, double> userDislikedTags = {};

  // Overall statistics
  int totalWatchedMovies = 0;
  int totalSkippedMovies = 0;
  int totalRatedMovies = 0;
  double averageUserRating = 0.0;

  // Interaction history for learning
  List<MovieInteraction> interactionHistory = [];

  UserPreferences();

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'genrePreferences': genrePreferences,
      'languagePreferences': languagePreferences,
      'decadePreferences': decadePreferences,
      'ratingRangePreferences': ratingRangePreferences,
      'personPreferences': personPreferences,
      'userLikedTags': userLikedTags,
      'userDislikedTags': userDislikedTags,
      'totalWatchedMovies': totalWatchedMovies,
      'totalSkippedMovies': totalSkippedMovies,
      'totalRatedMovies': totalRatedMovies,
      'averageUserRating': averageUserRating,
      'interactionHistory': interactionHistory.map((i) => i.toJson()).toList(),
    };
  }

  // Create from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final prefs = UserPreferences();
    prefs.genrePreferences = Map<String, double>.from(
      json['genrePreferences'] ?? {},
    );
    prefs.languagePreferences = Map<String, double>.from(
      json['languagePreferences'] ?? {},
    );
    prefs.decadePreferences = Map<String, double>.from(
      json['decadePreferences'] ?? {},
    );
    prefs.ratingRangePreferences = Map<String, double>.from(
      json['ratingRangePreferences'] ?? {},
    );
    prefs.personPreferences = Map<String, double>.from(
      json['personPreferences'] ?? {},
    );
    prefs.userLikedTags = Map<String, double>.from(json['userLikedTags'] ?? {});
    prefs.userDislikedTags = Map<String, double>.from(
      json['userDislikedTags'] ?? {},
    );
    prefs.totalWatchedMovies = json['totalWatchedMovies'] ?? 0;
    prefs.totalSkippedMovies = json['totalSkippedMovies'] ?? 0;
    prefs.totalRatedMovies = json['totalRatedMovies'] ?? 0;
    prefs.averageUserRating = json['averageUserRating']?.toDouble() ?? 0.0;

    if (json['interactionHistory'] != null) {
      prefs.interactionHistory =
          (json['interactionHistory'] as List)
              .map((i) => MovieInteraction.fromJson(i))
              .toList();
    }

    return prefs;
  }

  // Get preference score for a specific attribute
  double getPreferenceScore(String category, String value) {
    switch (category) {
      case 'genre':
        return genrePreferences[value] ?? 0.0;
      case 'language':
        return languagePreferences[value] ?? 0.0;
      case 'decade':
        return decadePreferences[value] ?? 0.0;
      case 'ratingRange':
        return ratingRangePreferences[value] ?? 0.0;
      case 'person':
        return personPreferences[value] ?? 0.0;
      case 'tag':
        return (userLikedTags[value] ?? 0.0) - (userDislikedTags[value] ?? 0.0);
      default:
        return 0.0;
    }
  }

  // Update preference based on interaction
  void updatePreference(String category, String value, double weight) {
    switch (category) {
      case 'genre':
        genrePreferences[value] = (genrePreferences[value] ?? 0.0) + weight;
        break;
      case 'language':
        languagePreferences[value] =
            (languagePreferences[value] ?? 0.0) + weight;
        break;
      case 'decade':
        decadePreferences[value] = (decadePreferences[value] ?? 0.0) + weight;
        break;
      case 'ratingRange':
        ratingRangePreferences[value] =
            (ratingRangePreferences[value] ?? 0.0) + weight;
        break;
      case 'person':
        personPreferences[value] = (personPreferences[value] ?? 0.0) + weight;
        break;
      case 'tag':
        if (weight > 0) {
          userLikedTags[value] = (userLikedTags[value] ?? 0.0) + weight;
        } else {
          userDislikedTags[value] =
              (userDislikedTags[value] ?? 0.0) + weight.abs();
        }
        break;
    }
  }

  // Update tag preferences based on movie keywords and interaction weight
  void updateTagPreferences(List<String> keywords, double weight) {
    for (final keyword in keywords) {
      final normalizedKeyword = keyword.toLowerCase().trim();
      if (normalizedKeyword.isNotEmpty) {
        updatePreference('tag', normalizedKeyword, weight);
      }
    }
  }

  // Get tag overlap score between movie keywords and user preferences
  double calculateTagOverlapScore(List<String> movieKeywords) {
    if (movieKeywords.isEmpty) return 0.0;

    double totalScore = 0.0;
    int matchingTags = 0;

    for (final keyword in movieKeywords) {
      final normalizedKeyword = keyword.toLowerCase().trim();
      final likedScore = userLikedTags[normalizedKeyword] ?? 0.0;
      final dislikedScore = userDislikedTags[normalizedKeyword] ?? 0.0;
      final netScore = likedScore - dislikedScore;

      if (netScore != 0.0) {
        totalScore += netScore;
        matchingTags++;
      }
    }

    // Return average score of matching tags, or 0 if no matches
    return matchingTags > 0 ? totalScore / matchingTags : 0.0;
  }

  // Get top preferred items in a category
  List<String> getTopPreferences(String category, {int limit = 5}) {
    Map<String, double> preferences;
    switch (category) {
      case 'genre':
        preferences = genrePreferences;
        break;
      case 'language':
        preferences = languagePreferences;
        break;
      case 'decade':
        preferences = decadePreferences;
        break;
      case 'ratingRange':
        preferences = ratingRangePreferences;
        break;
      case 'person':
        preferences = personPreferences;
        break;
      case 'likedTags':
        preferences = userLikedTags;
        break;
      case 'dislikedTags':
        preferences = userDislikedTags;
        break;
      default:
        return [];
    }

    final sorted =
        preferences.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .where((entry) => entry.value > 0)
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  // Reset all preferences (for testing or user request)
  void reset() {
    genrePreferences.clear();
    languagePreferences.clear();
    decadePreferences.clear();
    ratingRangePreferences.clear();
    personPreferences.clear();
    userLikedTags.clear();
    userDislikedTags.clear();
    totalWatchedMovies = 0;
    totalSkippedMovies = 0;
    totalRatedMovies = 0;
    averageUserRating = 0.0;
    interactionHistory.clear();
  }
}

class MovieInteraction {
  final int movieId;
  final String movieTitle;
  final String interactionType; // 'watched', 'skipped', 'rated', 'bookmarked'
  final double? rating;
  final DateTime timestamp;
  final Map<String, dynamic>
  movieAttributes; // Store movie features for learning

  MovieInteraction({
    required this.movieId,
    required this.movieTitle,
    required this.interactionType,
    this.rating,
    required this.timestamp,
    required this.movieAttributes,
  });

  Map<String, dynamic> toJson() {
    return {
      'movieId': movieId,
      'movieTitle': movieTitle,
      'interactionType': interactionType,
      'rating': rating,
      'timestamp': timestamp.toIso8601String(),
      'movieAttributes': movieAttributes,
    };
  }

  factory MovieInteraction.fromJson(Map<String, dynamic> json) {
    return MovieInteraction(
      movieId: json['movieId'],
      movieTitle: json['movieTitle'],
      interactionType: json['interactionType'],
      rating: json['rating']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      movieAttributes: Map<String, dynamic>.from(json['movieAttributes'] ?? {}),
    );
  }
}
