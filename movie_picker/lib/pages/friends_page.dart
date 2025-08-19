import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/friendship_service.dart';
import '../services/user_data_service.dart';
import '../services/movie_service.dart';
import '../models/friendship.dart';
import 'friend_discovery_page.dart';
import 'friend_catalog_page.dart';
import '../utils/avatar_helper.dart';

class FriendsPage extends StatefulWidget {
  final FriendshipService friendshipService;
  final UserDataService userDataService;
  final MovieService movieService;

  const FriendsPage({
    super.key,
    required this.friendshipService,
    required this.userDataService,
    required this.movieService,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    // Change from 3 tabs to 2 tabs (remove "Sent" tab)
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Friends'),
            StreamBuilder<List<Friendship>>(
              stream: widget.friendshipService.getPendingFriendRequests(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Requests'),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            // Remove the "Sent" tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildRequestsTab(),
          // Remove _buildSentTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FriendDiscoveryPage(
                friendshipService: widget.friendshipService,
              ),
            ),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<List<Friendship>>(
      stream: widget.friendshipService.getAcceptedFriendships(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final friendships = snapshot.data ?? [];

        if (friendships.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to find friends!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendships.length,
          itemBuilder: (context, index) {
            final friendship = friendships[index];
            return _buildFriendCard(friendship);
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<List<Friendship>>(
      stream: widget.friendshipService.getPendingFriendRequests(),
      builder: (context, snapshot) {
        // Add better error handling and loading states
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_unread_outlined, 
                     size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'When someone sends you a friend request,\nit will appear here!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request);
          },
        );
      },
    );
  }

  Widget _buildFriendCard(Friendship friendship) {
    // Get the friend's UID (the other user in the friendship)
    final friendUid = friendship.requesterUid == widget.friendshipService.currentUserId
        ? friendship.receiverUid
        : friendship.requesterUid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: FutureBuilder<UserProfile?>(
        future: widget.friendshipService.getUserProfile(friendUid),
        builder: (context, snapshot) {
          final username = snapshot.data?.username ?? 'Loading...';
          final avatarId = snapshot.data?.avatarId;
          final avatarUrl = avatarId != null ? _getAvatarUrl(avatarId) : null;
          
          return ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[300],
              backgroundImage: avatarUrl != null ? AssetImage(avatarUrl) : null,
              child: avatarUrl == null 
                ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                : null,
            ),
            title: Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Friend since ${_formatDate(friendship.updatedAt ?? friendship.createdAt)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Catalog button
                IconButton(
                  icon: const Icon(Icons.movie, color: Colors.blue),
                  onPressed: () => _viewFriendCatalog(friendUid, username, avatarId),
                  tooltip: 'View Movie Catalog',
                ),
                // Remove friend menu
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') {
                      _showRemoveFriendDialog(friendUid);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Friend'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Friendship request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<UserProfile?>(
          future: widget.friendshipService.getUserProfile(request.requesterUid),
          builder: (context, snapshot) {
            final username = snapshot.data?.username ?? 'Loading...';
            final avatarId = snapshot.data?.avatarId;
            final avatarUrl = avatarId != null ? _getAvatarUrl(avatarId) : null;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: avatarUrl != null ? AssetImage(avatarUrl) : null,
                      child: avatarUrl == null 
                        ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                        : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Wants to be your friend',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptRequest(request.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _declineRequest(request.id),
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSentRequestCard(Friendship request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[300],
          child: Icon(Icons.person, size: 30, color: Colors.grey[600]),
        ),
        title: Text(
          'User ${request.receiverUid}', // Would be replaced with actual user name
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Request sent ${_formatDate(request.createdAt)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Pending',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptRequest(String friendshipId) async {
    try {
      await widget.friendshipService.acceptFriendRequest(friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(String friendshipId) async {
    try {
      await widget.friendshipService.declineFriendRequest(friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRemoveFriendDialog(String friendUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.friendshipService.removeFriend(friendUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Friend removed'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _viewFriendCatalog(String friendUid, String friendUsername, String? friendAvatarId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendCatalogPage(
          friendUid: friendUid,
          friendUsername: friendUsername,
          friendAvatarId: friendAvatarId,
          friendshipService: widget.friendshipService,
          userDataService: widget.userDataService,
          movieService: widget.movieService,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to get avatar URL from avatarId
  String _getAvatarUrl(String avatarId) {
    return AvatarHelper.getAvatarAsset(avatarId) ?? 'assets/avatars/avatar_1.png';
  }
} 