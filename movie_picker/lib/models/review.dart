import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String userId;
  final String username;
  final int movieId;
  final String movieTitle;
  final String reviewText;
  final DateTime timestamp;
  final bool hasSpoilers;
  final int upvoteCount;
  final List<String> upvotedBy; // List of user IDs who upvoted

  Review({
    required this.id,
    required this.userId,
    required this.username,
    required this.movieId,
    required this.movieTitle,
    required this.reviewText,
    required this.timestamp,
    this.hasSpoilers = false,
    this.upvoteCount = 0,
    this.upvotedBy = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'reviewText': reviewText,
      'timestamp': Timestamp.fromDate(timestamp),
      'hasSpoilers': hasSpoilers,
      'upvoteCount': upvoteCount,
      'upvotedBy': upvotedBy,
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      movieId: json['movieId'] ?? 0,
      movieTitle: json['movieTitle'] ?? '',
      reviewText: json['reviewText'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasSpoilers: json['hasSpoilers'] ?? false,
      upvoteCount: json['upvoteCount'] ?? 0,
      upvotedBy: List<String>.from(json['upvotedBy'] ?? []),
    );
  }

  Review copyWith({
    String? id,
    String? userId,
    String? username,
    int? movieId,
    String? movieTitle,
    String? reviewText,
    DateTime? timestamp,
    bool? hasSpoilers,
    int? upvoteCount,
    List<String>? upvotedBy,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      reviewText: reviewText ?? this.reviewText,
      timestamp: timestamp ?? this.timestamp,
      hasSpoilers: hasSpoilers ?? this.hasSpoilers,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      upvotedBy: upvotedBy ?? this.upvotedBy,
    );
  }
} 