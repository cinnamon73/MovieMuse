import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/friendship.dart';

class FriendshipService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FriendshipService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // Get current user UID
  String? get currentUserId => _auth.currentUser?.uid;

  // Send friend request
  Future<Friendship> sendFriendRequest({
    required String receiverUid,
  }) async {
    try {
      final requesterUid = currentUserId;
      if (requesterUid == null) {
        throw Exception('User not authenticated');
      }

      if (requesterUid == receiverUid) {
        throw Exception('Cannot send friend request to yourself');
      }

      // Check if friendship already exists
      final existingFriendship = await _getFriendshipBetweenUsers(
        requesterUid, 
        receiverUid,
      );

      if (existingFriendship != null) {
        throw Exception('Friendship request already exists');
      }

      // Create new friendship document
      final friendshipDoc = _firestore.collection('friendships').doc();
      final friendship = Friendship(
        id: friendshipDoc.id,
        requesterUid: requesterUid,
        receiverUid: receiverUid,
        status: FriendshipStatus.pending,
        createdAt: DateTime.now(),
      );

      await friendshipDoc.set(friendship.toJson());

      if (kDebugMode) {
        debugPrint('✅ Friend request sent: ${friendship.id}');
        debugPrint('   From: $requesterUid');
        debugPrint('   To: $receiverUid');
      }

      return friendship;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error sending friend request: $e');
      }
      rethrow;
    }
  }

  // Accept friend request
  Future<Friendship> acceptFriendRequest(String friendshipId) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null) {
        throw Exception('User not authenticated');
      }

      final friendshipDoc = await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .get();

      if (!friendshipDoc.exists) {
        throw Exception('Friendship request not found');
      }

      final friendship = Friendship.fromJson(friendshipDoc.data()!);

      // Verify current user is the receiver
      if (friendship.receiverUid != currentUid) {
        throw Exception('Not authorized to accept this request');
      }

      if (friendship.status != FriendshipStatus.pending) {
        throw Exception('Request is not pending');
      }

      // Update friendship status
      final updatedFriendship = friendship.copyWith(
        status: FriendshipStatus.accepted,
        updatedAt: DateTime.now(),
      );

      await friendshipDoc.reference.update(updatedFriendship.toJson());

      if (kDebugMode) {
        debugPrint('✅ Friend request accepted: ${friendship.id}');
        debugPrint('   Requester: ${friendship.requesterUid}');
        debugPrint('   Receiver: ${friendship.receiverUid}');
      }

      return updatedFriendship;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error accepting friend request: $e');
      }
      rethrow;
    }
  }

  // Decline friend request
  Future<Friendship> declineFriendRequest(String friendshipId) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null) {
        throw Exception('User not authenticated');
      }

      final friendshipDoc = await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .get();

      if (!friendshipDoc.exists) {
        throw Exception('Friendship request not found');
      }

      final friendship = Friendship.fromJson(friendshipDoc.data()!);

      // Verify current user is the receiver
      if (friendship.receiverUid != currentUid) {
        throw Exception('Not authorized to decline this request');
      }

      if (friendship.status != FriendshipStatus.pending) {
        throw Exception('Request is not pending');
      }

      // Update friendship status
      final updatedFriendship = friendship.copyWith(
        status: FriendshipStatus.declined,
        updatedAt: DateTime.now(),
      );

      await friendshipDoc.reference.update(updatedFriendship.toJson());

      if (kDebugMode) {
        debugPrint('❌ Friend request declined: ${friendship.id}');
      }

      return updatedFriendship;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error declining friend request: $e');
      }
      rethrow;
    }
  }

  // Remove friend (unfriend)
  Future<void> removeFriend(String friendUid) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null) {
        throw Exception('User not authenticated');
      }

      // Find the friendship
      final friendship = await _getFriendshipBetweenUsers(currentUid, friendUid);
      if (friendship == null) {
        throw Exception('Friendship not found');
      }

      if (friendship.status != FriendshipStatus.accepted) {
        throw Exception('Users are not friends');
      }

      // Delete the friendship
      await _firestore
          .collection('friendships')
          .doc(friendship.id)
          .delete();

      if (kDebugMode) {
        debugPrint('🗑️ Friend removed: ${friendship.id}');
        debugPrint('   User: $currentUid');
        debugPrint('   Friend: $friendUid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error removing friend: $e');
      }
      rethrow;
    }
  }

  // Get pending friend requests (received)
  Stream<List<Friendship>> getPendingFriendRequests() {
    final currentUid = currentUserId;
    if (currentUid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('friendships')
        .where('receiverUid', isEqualTo: currentUid)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friendship.fromJson(doc.data()))
            .toList());
  }

  // Get sent friend requests (pending)
  Stream<List<Friendship>> getSentFriendRequests() {
    final currentUid = currentUserId;
    if (currentUid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('friendships')
        .where('requesterUid', isEqualTo: currentUid)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friendship.fromJson(doc.data()))
            .toList());
  }

  // Get accepted friends
  Stream<List<Friendship>> getAcceptedFriendships() {
    final currentUid = currentUserId;
    if (currentUid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('friendships')
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .where('requesterUid', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)  // Changed from 'updatedAt' to 'createdAt'
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friendship.fromJson(doc.data()))
            .toList())
        .asyncMap((requesterFriendships) async {
          // Also get friendships where current user is the receiver
          final receiverSnapshot = await _firestore
              .collection('friendships')
              .where('status', isEqualTo: FriendshipStatus.accepted.name)
              .where('receiverUid', isEqualTo: currentUid)
              .orderBy('createdAt', descending: true)  // Changed from 'updatedAt' to 'createdAt'
              .get();
          
          final receiverFriendships = receiverSnapshot.docs
              .map((doc) => Friendship.fromJson(doc.data()))
              .toList();
          
          // Combine both lists
          final allFriendships = [...requesterFriendships, ...receiverFriendships];
          // Sort by createdAt instead of updatedAt
          allFriendships.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return allFriendships;
        });
  }

  // Get friend UIDs (for easy querying)
  Stream<List<String>> getFriendUids() {
    return getAcceptedFriendships().map((friendships) {
      final currentUid = currentUserId;
      if (currentUid == null) return [];

      return friendships.map((friendship) {
        return friendship.requesterUid == currentUid
            ? friendship.receiverUid
            : friendship.requesterUid;
      }).toList();
    });
  }

  // Search users by username
  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null) {
        throw Exception('User not authenticated');
      }

      if (query.length < 2) {
        return [];
      }

      // Search by username (case-insensitive)
      final usernameQuery = query.toLowerCase();
      
      final usersSnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: usernameQuery)
          .where('username', isLessThan: usernameQuery + '\uf8ff')
          .limit(20)
          .get();

      final users = <UserProfile>[];
      
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final uid = doc.id;
        
        // Skip current user and anonymous users
        if (uid == currentUid || (userData['isAnonymous'] == true)) {
          continue;
        }

        users.add(UserProfile(
          uid: uid,
          username: userData['username'] ?? 'Unknown User',
          avatarId: userData['avatarId'], // Changed from profilePicUrl
          isAnonymous: userData['isAnonymous'] ?? false,
        ));
      }

      if (kDebugMode) {
        debugPrint('🔍 Found ${users.length} users matching: $query');
      }

      return users;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error searching users: $e');
      }
      return [];
    }
  }

  // Get user profile by UID
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data()!;
      return UserProfile(
        uid: uid,
        username: userData['username'] ?? 'Unknown User',
        avatarId: userData['avatarId'], // Changed from profilePicUrl
        isAnonymous: userData['isAnonymous'] ?? false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting user profile: $e');
      }
      return null;
    }
  }

  // Get multiple user profiles by UIDs
  Future<List<UserProfile>> getUserProfiles(List<String> uids) async {
    try {
      if (uids.isEmpty) return [];

      final userDocs = await Future.wait(
        uids.map((uid) => _firestore.collection('users').doc(uid).get())
      );

      final profiles = <UserProfile>[];
      for (int i = 0; i < userDocs.length; i++) {
        final doc = userDocs[i];
        if (doc.exists) {
          final userData = doc.data()!;
          profiles.add(UserProfile(
            uid: uids[i],
            username: userData['username'] ?? 'Unknown User',
            avatarId: userData['avatarId'], // Changed from profilePicUrl
            isAnonymous: userData['isAnonymous'] ?? false,
          ));
        }
      }

      return profiles;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting user profiles: $e');
      }
      return [];
    }
  }

  // Get friendship between two users
  Future<Friendship?> _getFriendshipBetweenUsers(
    String user1Uid, 
    String user2Uid,
  ) async {
    try {
      // Check if user1 is requester and user2 is receiver
      final snapshot1 = await _firestore
          .collection('friendships')
          .where('requesterUid', isEqualTo: user1Uid)
          .where('receiverUid', isEqualTo: user2Uid)
          .limit(1)
          .get();

      if (snapshot1.docs.isNotEmpty) {
        return Friendship.fromJson(snapshot1.docs.first.data());
      }

      // Check if user2 is requester and user1 is receiver
      final snapshot2 = await _firestore
          .collection('friendships')
          .where('requesterUid', isEqualTo: user2Uid)
          .where('receiverUid', isEqualTo: user1Uid)
          .limit(1)
          .get();

      if (snapshot2.docs.isNotEmpty) {
        return Friendship.fromJson(snapshot2.docs.first.data());
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting friendship: $e');
      }
      return null;
    }
  }

  // Check if two users are friends
  Future<bool> areFriends(String user1Uid, String user2Uid) async {
    final friendship = await _getFriendshipBetweenUsers(user1Uid, user2Uid);
    return friendship?.status == FriendshipStatus.accepted;
  }

  // Get friendship status between current user and another user
  Future<FriendshipStatus?> getFriendshipStatus(String otherUserUid) async {
    final currentUid = currentUserId;
    if (currentUid == null) return null;

    final friendship = await _getFriendshipBetweenUsers(currentUid, otherUserUid);
    return friendship?.status;
  }
} 