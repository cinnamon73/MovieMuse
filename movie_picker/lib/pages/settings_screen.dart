import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/privacy_service.dart';
import '../services/movie_service.dart';
import 'privacy_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final PrivacyService privacyService;
  final MovieService movieService;

  const SettingsScreen({
    super.key, 
    required this.privacyService,
    required this.movieService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, dynamic> _privacyPreferences;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    setState(() {
      _privacyPreferences = widget.privacyService.getPrivacyPreferences();
    });
  }

  Future<void> _updateAdultContentSetting(bool enabled) async {
    setState(() => _isLoading = true);

    try {
      await widget.privacyService.setAdultContentEnabled(enabled);
      _loadPreferences();

      // CRITICAL: Clear movie cache so the new setting takes effect immediately
      widget.movieService.clearCacheForPrivacyChange();
      debugPrint('🔞 Cleared movie cache after adult content setting change: $enabled');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled 
                ? 'Adult content enabled - movie cache cleared' 
                : 'Adult content disabled - movie cache cleared',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPrivacySettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrivacySettingsScreen(
          privacyService: widget.privacyService,
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'MovieMuse',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.movie, size: 48, color: Colors.deepPurple),
      children: [
        const Text(
          'A personalized movie recommendation app that helps you discover great movies based on your preferences.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Movie data provided by The Movie Database (TMDB).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Language Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Current language: English (US)'),
            const SizedBox(height: 16),
            const Text('Additional languages will be available in future updates.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Current theme: Dark'),
            const SizedBox(height: 16),
            const Text('Additional themes will be available in future updates.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications are currently disabled.'),
            const SizedBox(height: 16),
            const Text('Notification features will be available in future updates.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Settings Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings, color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'General',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ListTile(
                            leading: const Icon(Icons.language),
                            title: const Text('Language'),
                            subtitle: const Text('English (US)'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showLanguageDialog,
                          ),

                          const Divider(),

                          ListTile(
                            leading: const Icon(Icons.palette),
                            title: const Text('Theme'),
                            subtitle: const Text('Dark'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showThemeDialog,
                          ),

                          const Divider(),

                          ListTile(
                            leading: const Icon(Icons.notifications),
                            title: const Text('Notifications'),
                            subtitle: const Text('Manage notification preferences'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showNotificationDialog,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Content Settings Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.movie_filter, color: Colors.orange.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Content',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          SwitchListTile(
                            secondary: const Icon(Icons.visibility_off, color: Colors.orange),
                            title: const Text('Adult Content'),
                            subtitle: const Text(
                              'Show adult/18+ movies in search results',
                            ),
                            value: _privacyPreferences['adultContentEnabled'] ?? false,
                            onChanged: _updateAdultContentSetting,
                          ),

                          const Divider(),

                          ListTile(
                            leading: const Icon(Icons.filter_alt),
                            title: const Text('Default Filters'),
                            subtitle: const Text('Set default movie filters'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Default Filters'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Default filter settings are currently managed through the main filter dialog.'),
                                      const SizedBox(height: 16),
                                      const Text('Enhanced filter management will be available in future updates.'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Privacy & Security Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Privacy & Security',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ListTile(
                            leading: const Icon(Icons.privacy_tip),
                            title: const Text('Privacy Settings'),
                            subtitle: const Text('Data retention, analytics, and more'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showPrivacySettings,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // About Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.purple.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'About',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('About MovieMuse'),
                            subtitle: const Text('Version 1.0.0'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showAboutDialog,
                          ),

                          const Divider(),

                          ListTile(
                            leading: const Icon(Icons.rate_review),
                            title: const Text('Rate App'),
                            subtitle: const Text('Leave a review on the app store'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Rate MovieMuse'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('We hope you\'re enjoying MovieMuse!'),
                                      const SizedBox(height: 16),
                                      const Text('App store ratings will be available when the app is published to app stores.'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const Divider(),

                          ListTile(
                            leading: const Icon(Icons.help_outline),
                            title: const Text('Help & Support'),
                            subtitle: const Text('Get help using the app'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Help & Support'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        const Text('Need help with MovieMuse?', style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 16),
                                        
                                        const Text('📱 Basic Gestures:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                        const SizedBox(height: 8),
                                        const Text('• Tap movie card for detailed information'),
                                        const Text('• Swipe right to mark as watched'),
                                        const Text('• Swipe left to skip (not interested)'),
                                        const Text('• Swipe down to bookmark for later'),
                                      const SizedBox(height: 16),
                                        
                                        const Text('🎬 Movie Feeds:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                      const SizedBox(height: 8),
                                        const Text('• Trending: Popular movies everyone loves'),
                                        const Text('• For You: Personalized recommendations'),
                                        const SizedBox(height: 16),
                                        
                                        const Text('🔍 Finding Movies:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                      const SizedBox(height: 8),
                                        const Text('• Use filters to narrow down options'),
                                        const Text('• Search for specific movies or actors'),
                                        const Text('• Filter by streaming platform'),
                                        const SizedBox(height: 16),
                                        
                                        const Text('📚 Managing Your Movies:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                      const SizedBox(height: 8),
                                        const Text('• View bookmarks in the drawer menu'),
                                        const Text('• Check watched movies with ratings'),
                                        const Text('• Rate movies 1-10 stars'),
                                        const SizedBox(height: 16),
                                        
                                        const Text('⚙️ Settings & Privacy:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                                      const SizedBox(height: 8),
                                        const Text('• Manage privacy settings'),
                                        const Text('• Clear app data if needed'),
                                        const Text('• Export your movie data'),
                                        const SizedBox(height: 16),
                                        
                                        const Text('💡 Tips:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                      const SizedBox(height: 8),
                                        const Text('• The more you rate movies, the better your recommendations'),
                                        const Text('• Use filters to find specific types of movies'),
                                        const Text('• Bookmark movies you want to watch later'),
                                        const Text('• Check movie details for streaming options'),
                                    ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Got it!'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Footer
                  Center(
                    child: Text(
                      'MovieMuse v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 