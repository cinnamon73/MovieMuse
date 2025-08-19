import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/friendship_service.dart';
import '../services/user_data_service.dart';
import '../services/movie_service.dart';
import '../themes/app_colors.dart';
import '../themes/typography_theme.dart';
import '../widgets/avatar_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendSelectionModal extends StatefulWidget {
  final String movieId;
  final String movieTitle;
  final VoidCallback? onMovieShared;

  const FriendSelectionModal({
    required this.movieId,
    required this.movieTitle,
    this.onMovieShared,
    Key? key,
  }) : super(key: key);

  @override
  State<FriendSelectionModal> createState() => _FriendSelectionModalState();
}

class _FriendSelectionModalState extends State<FriendSelectionModal> {
  final FriendshipService _friendshipService = FriendshipService();
  late final UserDataService _userDataService;
  final MovieService _movieService = MovieService();
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _userDataService = UserDataService(prefs);
    await _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      // Use the EXACT same logic as the Friends page
      final friendships = await _friendshipService.getAcceptedFriendships().first;
      final friendsWithProfiles = <Map<String, dynamic>>[];
      
      for (final friendship in friendships) {
        // Get the friend's UID (the other user in the friendship)
        final friendUid = friendship.requesterUid == _friendshipService.currentUserId
            ? friendship.receiverUid
            : friendship.requesterUid;
            
        final userProfile = await _friendshipService.getUserProfile(friendUid);
        if (userProfile != null) {
          friendsWithProfiles.add({
            'userId': friendUid,
            'username': userProfile.username,
            'avatarId': userProfile.avatarId,
          });
        }
      }
      
      setState(() {
        _friends = friendsWithProfiles;
        _filteredFriends = friendsWithProfiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Remove the problematic SnackBar - just log the error
      debugPrint('Error loading friends: $e');
    }
  }

  void _filterFriends(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends
            .where((friend) => friend['username']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _shareWithFriend(Map<String, dynamic> friend) async {
    try {
      final friendUserId = friend['userId'] as String;
      final friendUsername = friend['username'] as String;
      
      // 1. Fetch the movie details
      final movie = await _movieService.fetchMovieById(int.parse(widget.movieId));
      if (movie == null) {
        debugPrint('Error: Could not fetch movie details for ID ${widget.movieId}');
        return;
      }
      
      // 2. Create a recommendation document that the friend can read
      final currentUser = _friendshipService.currentUserId;
      if (currentUser == null) {
        debugPrint('Error: Current user not authenticated');
        return;
      }
      
      // 3. Get current user's profile to get username
      final currentUserProfile = await _friendshipService.getUserProfile(currentUser);
      final currentUsername = currentUserProfile?.username ?? 'Friend';
      
      // 4. Add to recommendations collection (both users can access this)
      final recommendationData = {
        'fromUserId': currentUser,
        'toUserId': friendUserId,
        'movieId': movie.id,
        'movieTitle': movie.title,
        'fromUsername': currentUsername, // Add sender's username
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      };
      
      // Use Firestore directly to avoid permissions issues
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('recommendations').add(recommendationData);
      
      debugPrint('✅ Shared "${widget.movieTitle}" with $friendUsername - added to recommendations');
      
      widget.onMovieShared?.call();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error sharing movie: $e');
      // Don't show SnackBar - just log the error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.share,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SHARE WITH FRIENDS',
                      style: AppTypography.appBarTitle.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Share "${widget.movieTitle}"',
              style: AppTypography.secondaryText.copyWith(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // Search Bar
            TextField(
              onChanged: _filterFriends,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),

            const SizedBox(height: 20),

            // Friends List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _filteredFriends.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No friends found'
                                    : 'No friends match your search',
                                style: AppTypography.secondaryText.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, index) {
                            final friend = _filteredFriends[index];
                            return ListTile(
                              leading: AvatarWidget(
                                avatarId: friend['avatarId'],
                                size: 40,
                              ),
                              title: Text(
                                friend['username'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () => _shareWithFriend(friend),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
} 