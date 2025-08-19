import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  FirebaseAuth? _auth;

  // Lazy initialization of FirebaseAuth
  FirebaseAuth? get _firebaseAuth {
    try {
      _auth ??= FirebaseAuth.instance;
      return _auth!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get FirebaseAuth instance: $e');
      }
      return null;
    }
  }

  // Stream of auth state changes
  Stream<User?> get authStateChanges {
    try {
      return _firebaseAuth?.authStateChanges() ?? Stream.value(null);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Auth state changes error: $e');
      }
      return Stream.value(null);
    }
  }

  // Check if Firebase Auth is ready
  Future<bool> isAuthReady() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) return false;
      
      // Wait for auth to be ready
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Auth not ready: $e');
      }
      return false;
    }
  }

  // Current user with better error handling
  User? get currentUser {
    try {
      final auth = _firebaseAuth;
      if (auth == null) return null;
      
      final user = auth.currentUser;
      if (kDebugMode && user != null) {
        debugPrint('👤 Current user: ${user.uid} (${user.isAnonymous ? 'anonymous' : 'email'})');
      }
      return user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting current user: $e');
      }
      return null;
    }
  }

  // Anonymous sign-in (industry standard: only if no user)
  Future<UserCredential?> signInAnonymously() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      if (auth.currentUser != null) {
        // Already signed in (anonymous or not)
        if (kDebugMode) debugPrint('Already signed in, skipping anonymous sign-in. UID: ${auth.currentUser?.uid}');
        return null;
      }
      return await auth.signInAnonymously();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Anonymous sign-in error: $e');
      }
      rethrow;
    }
  }

  // Email/password sign-up
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      return await auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Email sign-up error: $e');
      }
      rethrow;
    }
  }

  // Email/password sign-in
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      return await auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Email sign-in error: $e');
      }
      rethrow;
    }
  }

  // Link anonymous account to email/password
  Future<UserCredential?> linkAnonymousWithEmail(String email, String password) async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      final credential = EmailAuthProvider.credential(email: email, password: password);
      return await auth.currentUser?.linkWithCredential(credential);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Link anonymous error: $e');
      }
      rethrow;
    }
  }

  // Sign out and immediately sign in anonymously (for data isolation)
  Future<void> signOutAndSignInAnonymously() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      
      // Get the old UID for debugging
      final oldUid = auth.currentUser?.uid;
      final wasAnonymous = auth.currentUser?.isAnonymous ?? false;
      
      if (kDebugMode) {
        debugPrint('🔄 Starting sign-out process...');
        debugPrint('   Old UID: $oldUid (anonymous: $wasAnonymous)');
      }
      
      // Sign out current user
      await auth.signOut();
      
      if (kDebugMode) {
        debugPrint('✅ Signed out successfully');
      }
      
      // Wait a longer moment to ensure the auth state is fully cleared
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try multiple times to get a different UID if needed
      String? newUid;
      int attempts = 0;
      const maxAttempts = 3;
      
      while (attempts < maxAttempts) {
        attempts++;
        
        if (kDebugMode) {
          debugPrint('🔄 Anonymous sign-in attempt $attempts...');
        }
        
        // Sign in anonymously
        final result = await auth.signInAnonymously();
        newUid = result.user?.uid;
        
        if (kDebugMode) {
          debugPrint('   Got UID: $newUid');
        }
        
        // If we got a different UID, we're good
        if (oldUid == null || newUid != oldUid) {
          break;
        }
        
        // If we got the same UID, try again after a brief delay
        if (attempts < maxAttempts) {
          if (kDebugMode) {
            debugPrint('⚠️ Got same UID, trying again...');
          }
          await auth.signOut();
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      if (kDebugMode) {
        debugPrint('✅ Created new anonymous session');
        debugPrint('   New UID: $newUid');
        debugPrint('   UIDs different: ${oldUid != newUid}');
        debugPrint('   Attempts needed: $attempts');
      }
      
      // If we still got the same UID after all attempts, we'll need to force-clear data
      if (oldUid != null && oldUid == newUid) {
        debugPrint('⚠️ WARNING: New anonymous UID is the same as old UID after $maxAttempts attempts!');
        debugPrint('   This means Firebase reused the anonymous UID. Data will be force-cleared.');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Sign out and anonymous sign-in error: $e');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      await auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Sign out error: $e');
      }
      rethrow;
    }
  }

  // Check if user is anonymous
  bool get isAnonymous {
    try {
      return _firebaseAuth?.currentUser?.isAnonymous ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Check anonymous error: $e');
      }
      return false;
    }
  }

  // Get user-friendly error message from FirebaseAuthException
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'invalid-credential':
        return 'The provided credentials are invalid.';
      default:
        return 'Authentication error: ${e.message ?? 'Unknown error'}';
    }
  }

  // Delete anonymous account and its data (for ephemeral behavior)
  Future<void> deleteAnonymousAccountAndData() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) debugPrint('⚠️ No current user to delete');
        return;
      }
      
      if (!currentUser.isAnonymous) {
        if (kDebugMode) debugPrint('⚠️ Not deleting non-anonymous user: ${currentUser.uid}');
        return; // Only delete anonymous users
      }
      
      final anonymousUid = currentUser.uid;
      if (kDebugMode) {
        debugPrint('🗑️ Starting deletion of anonymous account: $anonymousUid');
        debugPrint('   User email: ${currentUser.email}');
        debugPrint('   User display name: ${currentUser.displayName}');
        debugPrint('   User creation time: ${currentUser.metadata.creationTime}');
        debugPrint('   User last sign in: ${currentUser.metadata.lastSignInTime}');
      }
      
      // STEP 1: Delete Firestore data first
      try {
        if (kDebugMode) debugPrint('📂 Attempting to delete Firestore data...');
        await FirebaseFirestore.instance.collection('users').doc(anonymousUid).delete();
        if (kDebugMode) debugPrint('✅ Firestore data deleted successfully for UID: $anonymousUid');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to delete Firestore data: $e');
          debugPrint('   Error type: ${e.runtimeType}');
          if (e is FirebaseException) {
            debugPrint('   Firebase error code: ${e.code}');
            debugPrint('   Firebase error message: ${e.message}');
          }
        }
        // Continue anyway - we'll try to delete the auth user
      }
      
      // STEP 2: Delete the anonymous user account
      try {
        if (kDebugMode) debugPrint('👤 Attempting to delete anonymous user account...');
        await currentUser.delete();
        if (kDebugMode) debugPrint('✅ Anonymous user account deleted successfully: $anonymousUid');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to delete anonymous user account: $e');
          debugPrint('   Error type: ${e.runtimeType}');
          if (e is FirebaseAuthException) {
            debugPrint('   Firebase Auth error code: ${e.code}');
            debugPrint('   Firebase Auth error message: ${e.message}');
            debugPrint('   Firebase Auth error email: ${e.email}');
            debugPrint('   Firebase Auth error credential: ${e.credential}');
          }
        }
        // CRITICAL FIX: Re-throw the error to ensure we know when deletion fails
        rethrow; // This was the main issue - errors were being silently ignored
      }
      
      if (kDebugMode) {
        debugPrint('🧹 Anonymous account and data cleanup complete for: $anonymousUid');
        debugPrint('   Verification: Checking if user still exists...');
        
        // Verify deletion
        final verifyUser = auth.currentUser;
        if (verifyUser == null) {
          debugPrint('✅ Verification: User successfully deleted (currentUser is null)');
        } else {
          debugPrint('⚠️ Verification: User still exists after deletion attempt');
          debugPrint('   Current UID: ${verifyUser.uid}');
          debugPrint('   Is anonymous: ${verifyUser.isAnonymous}');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error in deleteAnonymousAccountAndData: $e');
        debugPrint('   Error type: ${e.runtimeType}');
        debugPrint('   Stack trace: ${StackTrace.current}');
      }
      // CRITICAL FIX: Re-throw the error so calling methods can handle it properly
      rethrow; // This ensures we don't silently ignore deletion failures
    }
  }

  // NEW: Clean up orphaned anonymous accounts in Firestore
  Future<void> cleanupOrphanedAnonymousAccounts() async {
    try {
      if (kDebugMode) debugPrint('🧹 Starting orphaned anonymous account cleanup...');
      
      // Get all users from Firestore
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final isAnonymous = userData['isAnonymous'] ?? false;
        
        if (isAnonymous) {
          try {
            // Try to get the user from Firebase Auth
            // Note: We can't directly check if a user exists by UID, so we'll use a different approach
            // We'll check if the user has been inactive for too long (24 hours for anonymous users)
            final lastActiveAt = userData['lastActiveAt'];
            if (lastActiveAt != null) {
              final lastActive = DateTime.tryParse(lastActiveAt);
              if (lastActive != null) {
                final hoursSinceActive = DateTime.now().difference(lastActive).inHours;
                
                if (hoursSinceActive > 24) {
                  if (kDebugMode) {
                    debugPrint('🗑️ Deleting orphaned anonymous account: ${doc.id}');
                    debugPrint('   Last active: $lastActive (${hoursSinceActive} hours ago)');
                  }
                  
                  // Delete the Firestore document
                  await doc.reference.delete();
                  
                  if (kDebugMode) {
                    debugPrint('✅ Deleted orphaned anonymous account: ${doc.id}');
                  }
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ Error cleaning up orphaned account ${doc.id}: $e');
            }
          }
        }
      }
      
      if (kDebugMode) debugPrint('✅ Orphaned anonymous account cleanup complete');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error during orphaned account cleanup: $e');
      }
    }
  }

  // Ephemeral email sign-up (deletes anonymous account first)
  Future<User> signUpWithEmailEphemeral(
    String email, 
    String password, 
    {String? username} // Add username parameter
  ) async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      
      // Create the new user account
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final newUser = userCredential.user;
      if (newUser == null) throw Exception('Failed to create user account');
      
      // Update display name with username if provided
      if (username != null && username.isNotEmpty) {
        await newUser.updateDisplayName(username);
      }
      
      return newUser;
    } catch (e) {
      debugPrint('❌ Error in signUpWithEmailEphemeral: $e');
      rethrow;
    }
  }

  // Ephemeral email sign-in (deletes anonymous account first)
  Future<UserCredential?> signInWithEmailEphemeral(String email, String password) async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      
      if (kDebugMode) {
        debugPrint('🚀 Starting ephemeral email sign-in...');
        debugPrint('   Email: $email');
        debugPrint('   Current user: ${auth.currentUser?.uid} (anonymous: ${auth.currentUser?.isAnonymous})');
      }
      
      // STEP 1: Delete anonymous account and data if exists
      if (auth.currentUser?.isAnonymous == true) {
        if (kDebugMode) debugPrint('🗑️ Anonymous user detected - starting deletion process...');
        await deleteAnonymousAccountAndData();
        
        // Verify deletion was successful
        final userAfterDeletion = auth.currentUser;
        if (userAfterDeletion != null) {
          if (kDebugMode) {
            debugPrint('⚠️ WARNING: User still exists after deletion attempt!');
            debugPrint('   UID: ${userAfterDeletion.uid}');
            debugPrint('   Is anonymous: ${userAfterDeletion.isAnonymous}');
          }
        } else {
          if (kDebugMode) debugPrint('✅ User successfully deleted - proceeding with sign-in');
        }
      } else {
        if (kDebugMode) debugPrint('ℹ️ No anonymous user to delete - proceeding with sign-in');
      }
      
      // STEP 2: Sign in with email
      if (kDebugMode) debugPrint('🔑 Signing in with email...');
      final result = await auth.signInWithEmailAndPassword(email: email, password: password);
      
      if (kDebugMode) {
        debugPrint('✅ Ephemeral email sign-in successful');
        debugPrint('   UID: ${result.user?.uid}');
        debugPrint('   Email: ${result.user?.email}');
        debugPrint('   Is anonymous: ${result.user?.isAnonymous}');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Ephemeral email sign-in error: $e');
        debugPrint('   Error type: ${e.runtimeType}');
        if (e is FirebaseAuthException) {
          debugPrint('   Firebase Auth error code: ${e.code}');
          debugPrint('   Firebase Auth error message: ${e.message}');
        }
      }
      rethrow;
    }
  }

  // Auto-login functionality - handles both anonymous and email user persistence
  Future<User?> autoLogin() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      
      // Wait for Firebase Auth to be ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Check if there's already a current user (Firebase handles persistence automatically)
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        if (kDebugMode) {
          debugPrint('🔄 Auto-login: User already signed in');
          debugPrint('   UID: ${currentUser.uid}');
          debugPrint('   Email: ${currentUser.email}');
          debugPrint('   Anonymous: ${currentUser.isAnonymous}');
          debugPrint('   Email verified: ${currentUser.emailVerified}');
        }
        return currentUser;
      }
      
      // Wait a bit more for Firebase Auth to fully initialize
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Check again after waiting
      final retryUser = auth.currentUser;
      if (retryUser != null) {
        if (kDebugMode) {
          debugPrint('🔄 Auto-login: User found after waiting');
          debugPrint('   UID: ${retryUser.uid}');
          debugPrint('   Email: ${retryUser.email}');
          debugPrint('   Anonymous: ${retryUser.isAnonymous}');
        }
        return retryUser;
      }
      
      // No current user, check if we should create anonymous user
      if (kDebugMode) {
        debugPrint('🔄 Auto-login: No current user, creating anonymous session');
      }
      
      // Create anonymous user for data isolation
      final result = await auth.signInAnonymously();
      if (result.user != null) {
        if (kDebugMode) {
          debugPrint('✅ Auto-login: Anonymous user created');
          debugPrint('   UID: ${result.user!.uid}');
        }
        return result.user;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Auto-login error: $e');
      }
      return null;
    }
  }

  // Check if user should be automatically logged in
  Future<bool> shouldAutoLogin() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) return false;
      
      // If there's already a user, we should auto-login
      if (auth.currentUser != null) {
        return true;
      }
      
      // For now, we always want to auto-login (either with existing user or new anonymous)
      // In the future, you could add logic here to check user preferences
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking auto-login: $e');
      }
      return false;
    }
  }

  // Get current session info for debugging
  Map<String, dynamic> getCurrentSessionInfo() {
    try {
      final auth = _firebaseAuth;
      if (auth == null) return {'error': 'Firebase Auth not available'};
      
      final user = auth.currentUser;
      if (user == null) return {'status': 'no_user'};
      
      return {
        'uid': user.uid,
        'email': user.email,
        'isAnonymous': user.isAnonymous,
        'emailVerified': user.emailVerified,
        'creationTime': user.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
        'displayName': user.displayName,
        'photoURL': user.photoURL,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Enhanced sign out that creates new anonymous session
  Future<void> signOutAndCreateAnonymous() async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Auth not available');
      
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        if (kDebugMode) {
          debugPrint('🚪 Signing out user: ${currentUser.uid}');
          debugPrint('   Email: ${currentUser.email}');
          debugPrint('   Anonymous: ${currentUser.isAnonymous}');
        }
      }
      
      await auth.signOut();
      
      if (kDebugMode) {
        debugPrint('✅ User signed out successfully');
      }
      
      // Create a new anonymous session for data isolation
      if (kDebugMode) {
        debugPrint('🔄 Creating new anonymous session after sign-out...');
      }
      
      await auth.signInAnonymously();
      
      if (kDebugMode) {
        debugPrint('✅ New anonymous session created');
        final newUser = auth.currentUser;
        if (newUser != null) {
          debugPrint('   New UID: ${newUser.uid}');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error in signOutAndCreateAnonymous: $e');
      }
      rethrow;
    }
  }

  // NEW: Periodic cleanup of orphaned accounts
  Future<void> performPeriodicCleanup() async {
    try {
      if (kDebugMode) {
        debugPrint('🧹 Starting periodic cleanup...');
      }
      
      // Clean up orphaned anonymous accounts
      await cleanupOrphanedAnonymousAccounts();
      
      if (kDebugMode) {
        debugPrint('✅ Periodic cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error during periodic cleanup: $e');
      }
    }
  }

  // NEW: Force cleanup of specific anonymous account
  Future<void> forceCleanupAnonymousAccount(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ Force cleaning up anonymous account: $uid');
      }
      
      // Delete Firestore data
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      
      if (kDebugMode) {
        debugPrint('✅ Force cleanup completed for UID: $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error during force cleanup: $e');
      }
      rethrow;
    }
  }

  // NEW: Delete full account with password confirmation (non-anonymous users)
  Future<void> deleteUserAccountAndCloudData({
    required String email,
    required String password,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) throw Exception('Firebase Auth not available');
    final user = auth.currentUser;
    if (user == null) throw Exception('No signed-in user');
    if (user.isAnonymous) throw Exception('Anonymous session cannot delete account');

    try {
      // Reauthenticate with password for security
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;

      // Best-effort Firestore cleanup for user-owned data
      final fs = FirebaseFirestore.instance;
      final futures = <Future<void>>[
        // Users document
        fs.collection('users').doc(uid).delete().catchError((_) {}),
        // Reviews written by user
        _deleteCollectionByQuery(fs.collection('reviews').where('userId', isEqualTo: uid)),
        // Bookmarks
        _deleteCollectionByQuery(fs.collection('bookmarks').where('userId', isEqualTo: uid)),
        // Watched
        _deleteCollectionByQuery(fs.collection('watched').where('userId', isEqualTo: uid)),
        // Friendships (either side)
        _deleteCollectionByQuery(fs.collection('friendships').where('requesterUid', isEqualTo: uid)),
        _deleteCollectionByQuery(fs.collection('friendships').where('receiverUid', isEqualTo: uid)),
        // Recommendations (from/to)
        _deleteCollectionByQuery(fs.collection('recommendations').where('fromUserId', isEqualTo: uid)),
        _deleteCollectionByQuery(fs.collection('recommendations').where('toUserId', isEqualTo: uid)),
      ];
      await Future.wait(futures);

      // Finally delete the auth user
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(getErrorMessage(e));
    }
  }

  // Helper: delete docs returned by a query in small batches
  Future<void> _deleteCollectionByQuery(Query query) async {
    const int batchSize = 200;
    Query q = query.limit(batchSize);
    bool done = false;
    while (!done) {
      final snap = await q.get();
      if (snap.docs.isEmpty) {
        done = true;
        break;
      }
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) done = true;
    }
  }
} 