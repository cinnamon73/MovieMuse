import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onShowWatched;
  final VoidCallback onShowBookmarked;
  final VoidCallback onShowSearch;
  final VoidCallback? onShowHelp;
  final VoidCallback? onShowPrivacySettings;
  final VoidCallback? onShowSettings;
  final VoidCallback? onShowFriends; // New: Friends callback
  final VoidCallback? onShowSemanticSearch; // New: Semantic search callback
  final bool isAnonymousUser;

  const AppDrawer({
    required this.onShowWatched,
    required this.onShowBookmarked,
    required this.onShowSearch,
    this.onShowHelp,
    this.onShowPrivacySettings,
    this.onShowSettings,
    this.onShowFriends, // New parameter
    this.onShowSemanticSearch,
    this.isAnonymousUser = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawerHeader(
              child: Row(
                children: [
                  Icon(Icons.movie, color: Colors.deepPurple, size: 36),
                  const SizedBox(width: 12),
                  const Text(
                    'MovieMuse',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Main Navigation
            ListTile(
              leading: const Icon(Icons.search, color: Colors.blue),
              title: const Text(
                'Search Movies',
                style: TextStyle(color: Colors.white),
              ),
              onTap: onShowSearch,
            ),
            if (onShowSemanticSearch != null)
              ListTile(
                leading: isAnonymousUser
                    ? const Icon(Icons.lock, color: Colors.white38)
                    : const Icon(Icons.auto_awesome, color: Colors.lightBlueAccent),
                title: const Text(
                  'AI Semantic Search',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: isAnonymousUser ? null : onShowSemanticSearch!,
                enabled: !isAnonymousUser,
            ),
            ListTile(
              leading: isAnonymousUser
                  ? const Icon(Icons.lock, color: Colors.white38)
                  : const Icon(Icons.check_circle, color: Colors.green),
              title: const Text(
                'Watched List',
                style: TextStyle(color: Colors.white),
              ),
              onTap: isAnonymousUser ? null : onShowWatched,
              enabled: !isAnonymousUser,
            ),
            ListTile(
              leading: isAnonymousUser
                  ? const Icon(Icons.lock, color: Colors.white38)
                  : const Icon(
                      Icons.bookmark,
                      color: Colors.amber,
                      size: 24,
                    ),
              title: const Text(
                'Bookmarks',
                style: TextStyle(color: Colors.white),
              ),
              onTap: isAnonymousUser ? null : onShowBookmarked,
              enabled: !isAnonymousUser,
            ),
            // New: Friends Section
            ListTile(
              leading: isAnonymousUser
                  ? const Icon(Icons.lock, color: Colors.white38)
                  : const Icon(Icons.people, color: Colors.purple),
              title: const Text(
                'Friends',
                style: TextStyle(color: Colors.white),
              ),
              onTap: isAnonymousUser ? null : onShowFriends,
              enabled: !isAnonymousUser,
            ),
            const Divider(color: Colors.white24),
            // Settings & Support
            if (onShowSettings != null)
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.grey),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: onShowSettings,
              ),
            if (onShowPrivacySettings != null)
              ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.orange),
                title: const Text(
                  'Privacy & Security',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: onShowPrivacySettings,
              ),
            if (onShowHelp != null) ...[
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.purple),
                title: const Text(
                  'Help & Feedback',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: onShowHelp,
              ),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.white70),
                title: const Text(
                  'Website',
                  style: TextStyle(color: Colors.white),
                                ),
                onTap: () async {
                  final url = Uri.parse('https://moviemuse.app');
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                      }
                                    },
              ),
            ]
          ],
        ),
      ),
    );
  }
}
