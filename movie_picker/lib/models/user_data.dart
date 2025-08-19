class UserData {
  final String userId;
  final String name;
  final Set<int> watchedMovieIds;
  final Set<int> bookmarkedMovieIds;
  final Set<int> skippedMovieIds;
  final Map<int, double> movieRatings;
  final DateTime createdAt;
  final DateTime lastUsed;

  UserData({
    required this.userId,
    required this.name,
    required this.watchedMovieIds,
    required this.bookmarkedMovieIds,
    required this.skippedMovieIds,
    required this.movieRatings,
    required this.createdAt,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'watchedMovieIds': watchedMovieIds.toList(),
      'bookmarkedMovieIds': bookmarkedMovieIds.toList(),
      'skippedMovieIds': skippedMovieIds.toList(),
      'movieRatings': movieRatings.map((k, v) => MapEntry(k.toString(), v)),
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['userId'] as String,
      name: json['name'] as String,
      watchedMovieIds: Set<int>.from(json['watchedMovieIds'] ?? []),
      bookmarkedMovieIds: Set<int>.from(json['bookmarkedMovieIds'] ?? []),
      skippedMovieIds: Set<int>.from(json['skippedMovieIds'] ?? []),
      movieRatings: (json['movieRatings'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(int.parse(k), (v as num).toDouble())),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsed: DateTime.parse(json['lastUsed'] as String),
    );
  }

  UserData copyWith({
    String? userId,
    String? name,
    Set<int>? watchedMovieIds,
    Set<int>? bookmarkedMovieIds,
    Set<int>? skippedMovieIds,
    Map<int, double>? movieRatings,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return UserData(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      watchedMovieIds: watchedMovieIds ?? this.watchedMovieIds,
      bookmarkedMovieIds: bookmarkedMovieIds ?? this.bookmarkedMovieIds,
      skippedMovieIds: skippedMovieIds ?? this.skippedMovieIds,
      movieRatings: movieRatings ?? this.movieRatings,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
} 