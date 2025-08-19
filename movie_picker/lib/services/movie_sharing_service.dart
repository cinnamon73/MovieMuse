import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie_recommendation.dart';
import '../models/friendship.dart';
import 'user_data_service.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

class MovieSharingService {
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
      id: _firestore.collection('movie_recommendations').doc().id,
      fromUserId: currentUser.uid,
      toUserId: toUserId,
      movieId: movieId,
      timestamp: DateTime.now(),
      message: message,
    );

    await _firestore
        .collection('movie_recommendations')
        .doc(recommendation.id)
        .set(recommendation.toJson());
  }

  // Get all recommendations sent to current user
  Stream<List<MovieRecommendation>> getReceivedRecommendations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('movie_recommendations')
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
        .collection('movie_recommendations')
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
        .collection('movie_recommendations')
        .doc(recommendationId)
        .update({'isRead': true});
  }

  // Get count of shared movies between two users
  Future<int> getSharedMovieCount(String user1Id, String user2Id) async {
    final recommendations = await _firestore
        .collection('movie_recommendations')
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

    debugPrint('🔍 [ShareModal] Found friendIds: ${friendIds.toList()}');

    // Get user profiles and shared counts
    final friendsWithCounts = <Map<String, dynamic>>[];
    
    for (final friendId in friendIds) {
      final userDoc = await _firestore.collection('users').doc(friendId).get();
      debugPrint('🔍 [ShareModal] userDoc for $friendId exists: ${userDoc.exists}');
      if (userDoc.exists) {
        final userData = UserData.fromJson(userDoc.data()!);
        debugPrint('🔍 [ShareModal] userData.username for $friendId: ${userData.username}');
        final sharedCount = await getSharedMovieCount(currentUser.uid, friendId);
        
        friendsWithCounts.add({
          'userId': friendId,
          'username': userData.username ?? userData.name ?? 'Unknown',
          'avatarId': userData.avatarId,
          'sharedCount': sharedCount,
        });
      } else {
        debugPrint('❌ [ShareModal] No user document found for $friendId');
      }
    }

    // Sort by shared count (descending), then alphabetically
    friendsWithCounts.sort((a, b) {
      final countComparison = b['sharedCount'].compareTo(a['sharedCount']);
      if (countComparison != 0) return countComparison;
      return a['username'].compareTo(b['username']);
    });

    debugPrint('🔍 [ShareModal] friendsWithCounts: ${friendsWithCounts.map((f) => f['username']).toList()}');
    return friendsWithCounts;
  }

  // Delete a recommendation
  Future<void> deleteRecommendation(String recommendationId) async {
    await _firestore
        .collection('movie_recommendations')
        .doc(recommendationId)
        .delete();
  }

  // Get unread recommendations count
  Stream<int> getUnreadRecommendationsCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('movie_recommendations')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
} 