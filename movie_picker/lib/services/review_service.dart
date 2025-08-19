import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ReviewService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  String get currentUsername => _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'Anonymous';

  CollectionReference<Map<String, dynamic>> get _reviewsCol => _firestore.collection('reviews');

  // Stream all reviews for a movie (ordered to match existing composite index)
  Stream<List<Review>> streamReviewsForMovie(int movieId) {
    try {
      return _reviewsCol
          .where('movieId', isEqualTo: movieId)
          .orderBy('upvoteCount', descending: true)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => Review.fromJson(d.data())).toList());
    } catch (e) {
      if (kDebugMode) debugPrint('❌ streamReviewsForMovie error: $e');
      return const Stream.empty();
    }
  }

  // Get the current user's review for a movie
  Future<Review?> getUserReviewForMovie(int movieId) async {
    try {
      final uid = currentUserId;
      if (uid == null) return null;

      final query = await _reviewsCol
          .where('movieId', isEqualTo: movieId)
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return Review.fromJson(query.docs.first.data());
    } catch (e) {
      if (kDebugMode) debugPrint('❌ getUserReviewForMovie error: $e');
      return null;
    }
  }

  // Create a new review
  Future<Review> submitReview({
    required int movieId,
    required String movieTitle,
    required String reviewText,
    required bool hasSpoilers,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');

    // If user already has a review for this movie, update instead
    final existing = await getUserReviewForMovie(movieId);
    if (existing != null) {
      return await updateReview(
        reviewId: existing.id,
        reviewText: reviewText,
        hasSpoilers: hasSpoilers,
      );
    }

    final docRef = _reviewsCol.doc();
    final review = Review(
      id: docRef.id,
      userId: uid,
      username: currentUsername,
      movieId: movieId,
      movieTitle: movieTitle,
      reviewText: reviewText,
      timestamp: DateTime.now(),
      hasSpoilers: hasSpoilers,
      upvoteCount: 0,
      upvotedBy: const [],
    );

    await docRef.set(review.toJson());
    return review;
  }

  // Update an existing review
  Future<Review> updateReview({
    required String reviewId,
    required String reviewText,
    required bool hasSpoilers,
  }) async {
    final data = {
      'reviewText': reviewText,
      'hasSpoilers': hasSpoilers,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    };

    await _reviewsCol.doc(reviewId).update(data);

    final updated = await _reviewsCol.doc(reviewId).get();
    return Review.fromJson(updated.data()!);
  }

  // Delete a review
  Future<void> deleteReview(String reviewId) async {
    await _reviewsCol.doc(reviewId).delete();
  }

  // Toggle upvote by the current user using a transaction
  Future<void> toggleUpvote(String reviewId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');

    await _firestore.runTransaction((txn) async {
      final docRef = _reviewsCol.doc(reviewId);
      final snapshot = await txn.get(docRef);
      if (!snapshot.exists) throw Exception('Review not found');

      final data = snapshot.data() as Map<String, dynamic>;
      final upvotedBy = List<String>.from(data['upvotedBy'] ?? []);
      final hasUpvoted = upvotedBy.contains(uid);

      if (hasUpvoted) {
        upvotedBy.remove(uid);
      } else {
        upvotedBy.add(uid);
      }

      final newCount = upvotedBy.length;
      txn.update(docRef, {
        'upvotedBy': upvotedBy,
        'upvoteCount': newCount,
      });
    });
  }
} 