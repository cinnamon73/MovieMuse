import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDataService {
  static const String _migrationKey = 'firestore_migrated';

  final SharedPreferences _prefs;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserDataService(this._prefs, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // Get current Firebase user UID
  String? get currentUserId {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // Initialize and migrate existing data if needed
  Future<void> initialize() async {
    await _migrateToFirestoreIfNeeded();
  }

  // Migrate data from SharedPreferences to Firestore (one-time)
  Future<void> _migrateToFirestoreIfNeeded() async {
    final migrated = _prefs.getBool(_migrationKey) ?? false;
    if (migrated) return; // Already migrated

    try {
      final currentUid = currentUserId;
      if (currentUid == null) return; // No user signed in

      // Check if user data already exists in Firestore
      final firestoreDoc = await _firestore.collection('users').doc(currentUid).get();
      if (firestoreDoc.exists) {
        // Data already in Firestore, mark as migrated
        await _prefs.setBool(_migrationKey, true);
        return;
      }

      // Check if user data exists in SharedPreferences
      final localData = _prefs.getString('user_data_$currentUid');
      if (localData != null) {
        try {
          final userDataMap = jsonDecode(localData);
          final userData = UserData.fromJson(userDataMap);
          
          // Upload to Firestore
          await _firestore.collection('users').doc(currentUid).set(userData.toJson());
          
          if (kDebugMode) {
            debugPrint('✅ Migrated user data to Firestore for UID: $currentUid');
            debugPrint('   Name: ${userData.name}');
            debugPrint('   Watched: ${userData.watchedMovieIds.length}');
            debugPrint('   Bookmarked: ${userData.bookmarkedMovieIds.length}');
            debugPrint('   Ratings: ${userData.movieRatings.length}');
          }
        } catch (e) {
          debugPrint('❌ Error migrating user data: $e');
        }
      }

      // Mark migration as complete
      await _prefs.setBool(_migrationKey, true);
    } catch (e) {
      debugPrint('❌ Error during Firestore migration: $e');
    }
  }

  // Get user data from Firestore by UID
  Future<UserData> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        final userData = UserData.fromJson(doc.data()!);
      
      if (kDebugMode) {
          debugPrint('📂 Loading user data from Firestore for UID: $userId');
        debugPrint('   Name: ${userData.name}');
        debugPrint('   Watched: ${userData.watchedMovieIds.length}');
        debugPrint('   Bookmarked: ${userData.bookmarkedMovieIds.length}');
        debugPrint('   Ratings: ${userData.movieRatings.length}');
      }
      
      return userData;
      } else {
        // Create new user data if doesn't exist
        final user = _auth.currentUser;
        final isAnonymous = user?.isAnonymous ?? false;
        final name = user?.email ?? user?.displayName ?? (isAnonymous ? 'Anonymous User' : 'User');
        final username = user?.displayName ?? name; // Use display name as username
        
        final newUserData = UserData(
          userId: userId, 
          name: name,
          username: isAnonymous ? null : username, // Only set username for non-anonymous users
          isAnonymous: isAnonymous,
        );
        await saveUserData(newUserData);
        
        if (kDebugMode) {
          debugPrint('📝 Created new user data in Firestore for UID: $userId');
          debugPrint('   Name: $name');
          debugPrint('   Anonymous: $isAnonymous');
        }
        
        return newUserData;
      }
    } catch (e) {
      debugPrint('❌ Error loading user data from Firestore: $e');
      
      // Fallback: create fresh user data
      final user = _auth.currentUser;
      final isAnonymous = user?.isAnonymous ?? false;
      final name = user?.email ?? user?.displayName ?? (isAnonymous ? 'Anonymous User' : 'User');
      
      return UserData(userId: userId, name: name);
    }
  }

  // Save user data to Firestore
  Future<void> saveUserData(UserData userData) async {
    try {
      // Update last active time
      userData.lastActiveAt = DateTime.now();
      
      await _firestore.collection('users').doc(userData.userId).set(userData.toJson());
      
    } catch (e) {
      debugPrint('❌ Error saving user data to Firestore: $e');
      rethrow;
    }
  }

  // Reload user data from Firestore (for auth state changes)
  Future<UserData?> reloadUserData() async {
    try {
      final uid = currentUserId;
      if (uid == null) return null;
      
      return await getUserData(uid);
    } catch (e) {
      debugPrint('❌ Error reloading user data from Firestore: $e');
      return null;
    }
  }

  // Enhanced getCurrentUserData with comprehensive retry logic
  Future<UserData> getCurrentUserData() async {
    const maxRetries = 5;
    const baseDelay = 200; // milliseconds
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
    final uid = currentUserId;
        if (uid == null) {
          debugPrint('⚠️ No authenticated user found (attempt $attempt/$maxRetries)');
    
          if (attempt < maxRetries) {
            await Future.delayed(Duration(milliseconds: baseDelay * attempt));
            continue;
          } else {
            throw Exception('No authenticated user found after $maxRetries attempts');
          }
        }
        
        final userData = await getUserData(uid);
        
        // Verify data integrity
        if (userData.userId != uid) {
          throw Exception('Data mismatch: expected $uid, got ${userData.userId}');
  }
        
        return userData;
        
      } catch (e) {
        debugPrint('❌ Error loading user data (attempt $attempt/$maxRetries): $e');
        
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: baseDelay * attempt));
        } else {
          debugPrint('❌ Failed to load user data after $maxRetries attempts');
          rethrow;
        }
      }
    }
    
    throw Exception('Unexpected error in getCurrentUserData');
  }

  // Add data integrity check method
  Future<bool> verifyDataIntegrity(String userId) async {
    try {
      final userData = await getUserData(userId);
      
      // Check for data consistency
      bool isConsistent = true;
      String issues = '';
      
      // Check if user ID matches
      if (userData.userId != userId) {
        isConsistent = false;
        issues += 'User ID mismatch; ';
      }
      
      // Check for negative ratings
      for (final entry in userData.movieRatings.entries) {
        if (entry.value < 0 || entry.value > 10) {
          isConsistent = false;
          issues += 'Invalid rating ${entry.value} for movie ${entry.key}; ';
        }
      }
      
      // Check for duplicate entries
      final allMovieIds = <int>{};
      allMovieIds.addAll(userData.watchedMovieIds);
      allMovieIds.addAll(userData.bookmarkedMovieIds);
      allMovieIds.addAll(userData.skippedMovieIds);
      
      if (allMovieIds.length != (userData.watchedMovieIds.length + 
                                userData.bookmarkedMovieIds.length + 
                                userData.skippedMovieIds.length)) {
        isConsistent = false;
        issues += 'Duplicate movie IDs detected; ';
      }
      
      if (!isConsistent) {
        debugPrint('⚠️ Data integrity issues found for user $userId: $issues');
      } else {
        debugPrint('✅ Data integrity check passed for user $userId');
      }
      
      return isConsistent;
    } catch (e) {
      debugPrint('❌ Error during data integrity check: $e');
      return false;
    }
  }

  // Create completely fresh user data in Firestore
  Future<UserData> createFreshUserData(String userId, {String? name}) async {
    final user = _auth.currentUser;
    final isAnonymous = user?.isAnonymous ?? false;
    final userName = name ?? (user?.email ?? user?.displayName ?? (isAnonymous ? 'Anonymous User' : 'User'));
    
    // Create completely fresh data
    final freshData = UserData(
      userId: userId,
      name: userName,
    );
    
    // Save to Firestore
    await saveUserData(freshData);
    
    if (kDebugMode) {
      debugPrint('✨ Created completely fresh user data in Firestore for UID: $userId');
      debugPrint('   Name: $userName');
      debugPrint('   Anonymous: $isAnonymous');
    }
    
    return freshData;
  }

  // Update current user's watched movies
  Future<void> addWatchedMovie(int movieId) async {
    try {
    final userData = await getCurrentUserData();
    userData.watchedMovieIds.add(movieId);
    await saveUserData(userData);
    } catch (e) {
      debugPrint('❌ Error adding watched movie: $e');
    }
  }

  // Update current user's bookmarked movies
  Future<void> toggleBookmark(int movieId) async {
    try {
    final userData = await getCurrentUserData();
    if (userData.bookmarkedMovieIds.contains(movieId)) {
      userData.bookmarkedMovieIds.remove(movieId);
    } else {
      userData.bookmarkedMovieIds.add(movieId);
    }
    await saveUserData(userData);
    } catch (e) {
      debugPrint('❌ Error toggling bookmark: $e');
    }
  }

  // Update current user's movie rating
  Future<void> setMovieRating(int movieId, double rating) async {
    try {
    final userData = await getCurrentUserData();
    if (rating > 0) {
      userData.movieRatings[movieId] = rating;
    } else {
      userData.movieRatings.remove(movieId);
    }
    await saveUserData(userData);
    } catch (e) {
      debugPrint('❌ Error setting movie rating: $e');
    }
  }

  // Update movie rating with existing UserData object (avoids reload)
  Future<void> setMovieRatingWithUserData(UserData userData, int movieId, double rating) async {
    try {
      if (rating > 0) {
        userData.movieRatings[movieId] = rating;
      } else {
        userData.movieRatings.remove(movieId);
      }
      await saveUserData(userData);
    } catch (e) {
      debugPrint('❌ Error setting movie rating with user data: $e');
    }
  }

  // Update current user's skipped movies
  Future<void> addSkippedMovie(int movieId) async {
    try {
    final userData = await getCurrentUserData();
    userData.skippedMovieIds.add(movieId);
    await saveUserData(userData);
    } catch (e) {
      debugPrint('❌ Error adding skipped movie: $e');
  }
}

  // NEW: Update avatar ID with proper verification
  Future<void> updateAvatarId(String avatarId) async {
    try {
      if (kDebugMode) {
        debugPrint('🖼️ Updating avatar ID: $avatarId');
      }
      
      final userData = await getCurrentUserData();
      userData.avatarId = avatarId;
      
      // Save to Firestore
      await saveUserData(userData);
      
      // Verify the save was successful
      final verificationData = await getCurrentUserData();
      if (verificationData.avatarId != avatarId) {
        throw Exception('Avatar ID verification failed: expected $avatarId, got ${verificationData.avatarId}');
      }
      
      if (kDebugMode) {
        debugPrint('✅ Avatar ID updated and verified successfully: $avatarId');
      }
    } catch (e) {
      debugPrint('❌ Error updating avatar ID: $e');
      rethrow;
    }
  }

  // NEW: Update username with proper verification
  Future<void> updateUsername(String username) async {
    try {
      if (kDebugMode) {
        debugPrint('👤 Updating username: $username');
      }
      
      final userData = await getCurrentUserData();
      userData.username = username;
      
      // Save to Firestore
      await saveUserData(userData);
      
      // Verify the save was successful
      final verificationData = await getCurrentUserData();
      if (verificationData.username != username) {
        throw Exception('Username verification failed: expected $username, got ${verificationData.username}');
      }
      
      if (kDebugMode) {
        debugPrint('✅ Username updated and verified successfully: $username');
      }
    } catch (e) {
      debugPrint('❌ Error updating username: $e');
      rethrow;
    }
  }

  // NEW: Get avatar ID with fallback
  Future<String?> getAvatarId() async {
    try {
      final userData = await getCurrentUserData();
      return userData.avatarId;
    } catch (e) {
      debugPrint('❌ Error getting avatar ID: $e');
      return null;
    }
  }

  // NEW: Get username with fallback
  Future<String?> getUsername() async {
    try {
      final userData = await getCurrentUserData();
      return userData.username;
    } catch (e) {
      debugPrint('❌ Error getting username: $e');
      return null;
    }
  }

  // NEW: Get user data by UID (for friend catalogs)
  Future<UserData?> getUserDataByUid(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (doc.exists && doc.data() != null) {
        final userData = UserData.fromJson(doc.data()!);
        
        if (kDebugMode) {
          debugPrint('📂 Loading friend data from Firestore for UID: $uid');
          debugPrint('   Name: ${userData.name}');
          debugPrint('   Watched: ${userData.watchedMovieIds.length}');
          debugPrint('   Bookmarked: ${userData.bookmarkedMovieIds.length}');
          debugPrint('   Ratings: ${userData.movieRatings.length}');
        }
        
        return userData;
      } else {
        if (kDebugMode) {
          debugPrint('❌ No user data found for UID: $uid');
        }
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error loading friend data from Firestore: $e');
      return null;
    }
  }

  // NEW: Update specific fields of user data
  Future<void> updateUserData({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Updating user data for UID: $userId');
        debugPrint('   Updates: $updates');
      }
      
      // Get current user data
      final userData = await getUserData(userId);
      
      // Apply updates
      if (updates.containsKey('forYouMovieIds')) {
        final forYouList = updates['forYouMovieIds'] as List;
        userData.forYouMovieIds.clear();
        userData.forYouMovieIds.addAll(forYouList.cast<int>());
      }
      
      // Save updated data
      await saveUserData(userData);
      
      if (kDebugMode) {
        debugPrint('✅ User data updated successfully for UID: $userId');
      }
    } catch (e) {
      debugPrint('❌ Error updating user data: $e');
      rethrow;
    }
  }
}

// Simplified user data model - just username and profile pic for social features
class UserData {
  final String userId;
  String name;
  final Set<int> watchedMovieIds;
  final Set<int> bookmarkedMovieIds;
  final Set<int> skippedMovieIds;
  final Set<int> forYouMovieIds; // Added for movie sharing
  final Map<int, double> movieRatings;
  final DateTime createdAt;
  DateTime lastActiveAt;
  
  // Simplified profile fields for friend system
  String? username;
  String? avatarId; // Changed from profilePicUrl to avatarId
  bool isAnonymous;

  UserData({
    required this.userId,
    required this.name,
    Set<int>? watchedMovieIds,
    Set<int>? bookmarkedMovieIds,
    Set<int>? skippedMovieIds,
    Set<int>? forYouMovieIds, // Added for movie sharing
    Map<int, double>? movieRatings,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    this.username,
    this.avatarId, // Changed from profilePicUrl
    bool? isAnonymous,
  }) : watchedMovieIds = watchedMovieIds ?? {},
       bookmarkedMovieIds = bookmarkedMovieIds ?? {},
       skippedMovieIds = skippedMovieIds ?? {},
       forYouMovieIds = forYouMovieIds ?? {}, // Added for movie sharing
       movieRatings = movieRatings ?? {},
       createdAt = createdAt ?? DateTime.now(),
       lastActiveAt = lastActiveAt ?? DateTime.now(),
       isAnonymous = isAnonymous ?? false;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'watchedMovieIds': watchedMovieIds.toList(),
      'bookmarkedMovieIds': bookmarkedMovieIds.toList(),
      'skippedMovieIds': skippedMovieIds.toList(),
      'forYouMovieIds': forYouMovieIds.toList(), // Added for movie sharing
      'movieRatings': movieRatings.map((k, v) => MapEntry(k.toString(), v)),
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'username': username,
      'avatarId': avatarId, // Changed from profilePicUrl
      'isAnonymous': isAnonymous,
    };
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    try {
      // Robust parsing for watchedMovieIds
      Set<int> watchedMovieIds = {};
      if (json['watchedMovieIds'] != null) {
        final watchedList = json['watchedMovieIds'] as List?;
        if (watchedList != null) {
          for (final item in watchedList) {
            try {
              final id = int.parse(item.toString());
              watchedMovieIds.add(id);
            } catch (e) {
              debugPrint('⚠️ Skipping invalid watched movie ID: $item');
            }
          }
        }
      }

      // Robust parsing for bookmarkedMovieIds
      Set<int> bookmarkedMovieIds = {};
      if (json['bookmarkedMovieIds'] != null) {
        final bookmarkedList = json['bookmarkedMovieIds'] as List?;
        if (bookmarkedList != null) {
          for (final item in bookmarkedList) {
            try {
              final id = int.parse(item.toString());
              bookmarkedMovieIds.add(id);
            } catch (e) {
              debugPrint('⚠️ Skipping invalid bookmarked movie ID: $item');
            }
          }
        }
      }

      // Robust parsing for skippedMovieIds
      Set<int> skippedMovieIds = {};
      if (json['skippedMovieIds'] != null) {
        final skippedList = json['skippedMovieIds'] as List?;
        if (skippedList != null) {
          for (final item in skippedList) {
            try {
              final id = int.parse(item.toString());
              skippedMovieIds.add(id);
            } catch (e) {
              debugPrint('⚠️ Skipping invalid skipped movie ID: $item');
            }
          }
        }
      }

      // Robust parsing for forYouMovieIds
      Set<int> forYouMovieIds = {};
      if (json['forYouMovieIds'] != null) {
        final forYouList = json['forYouMovieIds'] as List?;
        if (forYouList != null) {
          for (final item in forYouList) {
            try {
              final id = int.parse(item.toString());
              forYouMovieIds.add(id);
            } catch (e) {
              debugPrint('⚠️ Skipping invalid forYou movie ID: $item');
            }
          }
        }
      }

      // Robust parsing for movieRatings
      Map<int, double> movieRatings = {};
      if (json['movieRatings'] != null) {
        final ratingsMap = json['movieRatings'] as Map?;
        if (ratingsMap != null) {
          ratingsMap.forEach((key, value) {
            try {
              final movieId = int.parse(key.toString());
              final rating = double.parse(value.toString());
              movieRatings[movieId] = rating;
            } catch (e) {
              debugPrint('⚠️ Skipping invalid movie rating: $key -> $value');
            }
          });
        }
      }

      return UserData(
        userId: json['userId'] ?? '',
        name: json['name'] ?? 'User',
        watchedMovieIds: watchedMovieIds,
        bookmarkedMovieIds: bookmarkedMovieIds,
        skippedMovieIds: skippedMovieIds,
        forYouMovieIds: forYouMovieIds, // Added for movie sharing
        movieRatings: movieRatings,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] ?? '') ?? DateTime.now(),
        username: json['username'],
        avatarId: json['avatarId'],
        isAnonymous: json['isAnonymous'] ?? false,
      );
    } catch (e) {
      debugPrint('❌ Critical error parsing UserData: $e');
      debugPrint('   JSON data: $json');
      
      // Return a safe fallback
    return UserData(
        userId: json['userId'] ?? 'unknown',
        name: json['name'] ?? 'User',
    );
    }
  }
}

