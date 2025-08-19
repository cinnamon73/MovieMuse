import 'package:cloud_firestore/cloud_firestore.dart';

class MovieRecommendation {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String movieId;
  final DateTime timestamp;
  final bool isRead;
  final String? message; // Optional message from sender

  MovieRecommendation({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.movieId,
    required this.timestamp,
    this.isRead = false,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'movieId': movieId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'message': message,
    };
  }

  factory MovieRecommendation.fromJson(Map<String, dynamic> json) {
    return MovieRecommendation(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      movieId: json['movieId'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isRead: json['isRead'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  MovieRecommendation copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? movieId,
    DateTime? timestamp,
    bool? isRead,
    String? message,
  }) {
    return MovieRecommendation(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      movieId: movieId ?? this.movieId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MovieRecommendation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MovieRecommendation(id: $id, fromUserId: $fromUserId, toUserId: $toUserId, movieId: $movieId, isRead: $isRead)';
  }
} 