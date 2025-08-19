import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/privacy_service.dart';
import 'privacy_policy_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  final PrivacyService privacyService;

  const PrivacySettingsScreen({super.key, required this.privacyService});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  late Map<String, dynamic> _privacyPreferences;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPreferences();
  }

  void _loadPrivacyPreferences() {
    setState(() {
      _privacyPreferences = widget.privacyService.getPrivacyPreferences();
    });
  }

  Future<void> _updatePrivacyPreferences({
    int? dataRetentionDays,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? adultContentEnabled,
  }) async {
    setState(() => _isLoading = true);

    try {
      await widget.privacyService.updatePrivacyPreferences(
        dataRetentionDays: dataRetentionDays,
        analyticsEnabled: analyticsEnabled,
        crashReportingEnabled: crashReportingEnabled,
        adultContentEnabled: adultContentEnabled,
      );

      _loadPrivacyPreferences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy preferences updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportUserData() async {
    setState(() => _isLoading = true);

    try {
      final filePath = await widget.privacyService.saveExportedDataToFile();

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Data Export Successful'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your data has been exported successfully!'),
                    const SizedBox(height: 12),
                    const Text(
                      'File saved to:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        filePath,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This file contains all your personal data in JSON format. '
                      'You can import this data into other apps or keep it as a backup.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: filePath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('File path copied to clipboard'),
                        ),
                      );
                    },
                    child: const Text('Copy Path'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAllUserData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete All Data'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete all your data?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text('This action will permanently delete:'),
                SizedBox(height: 8),
                Text('• All your movie preferences and ratings'),
                Text('• Your watch history and bookmarks'),
                Text('• All user profiles and settings'),
                Text('• Privacy preferences'),
                SizedBox(height: 12),
                Text(
                  'This action cannot be undone!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete All Data'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        await widget.privacyService.deleteAllUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All user data deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to main screen or restart app
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => PrivacyPolicyScreen(
              privacyService: widget.privacyService,
              isFirstTime: false,
            ),
      ),
    );
  }

  void _showDataRetentionDialog() {
    final currentRetention = _privacyPreferences['dataRetentionDays'] as int;
    int selectedRetention = currentRetention;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Data Retention Period'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('How long should we keep your data?'),
                      const SizedBox(height: 16),
                      RadioListTile<int>(
                        title: const Text('30 days'),
                        subtitle: const Text('Short-term storage'),
                        value: 30,
                        groupValue: selectedRetention,
                        onChanged:
                            (value) => setDialogState(
                              () => selectedRetention = value!,
                            ),
                      ),
                      RadioListTile<int>(
                        title: const Text('90 days'),
                        subtitle: const Text('Medium-term storage'),
                        value: 90,
                        groupValue: selectedRetention,
                        onChanged:
                            (value) => setDialogState(
                              () => selectedRetention = value!,
                            ),
                      ),
                      RadioListTile<int>(
                        title: const Text('365 days (1 year)'),
                        subtitle: const Text('Long-term storage (recommended)'),
                        value: 365,
                        groupValue: selectedRetention,
                        onChanged:
                            (value) => setDialogState(
                              () => selectedRetention = value!,
                            ),
                      ),
                      RadioListTile<int>(
                        title: const Text('730 days (2 years)'),
                        subtitle: const Text('Extended storage'),
                        value: 730,
                        groupValue: selectedRetention,
                        onChanged:
                            (value) => setDialogState(
                              () => selectedRetention = value!,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Data older than this period will be automatically deleted.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updatePrivacyPreferences(
                          dataRetentionDays: selectedRetention,
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Privacy Policy Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.policy, color: Colors.blue.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'Privacy Policy',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Version: ${_privacyPreferences['privacyPolicyVersion']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _privacyPreferences['privacyPolicyAccepted']
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color:
                                      _privacyPreferences['privacyPolicyAccepted']
                                          ? Colors.green
                                          : Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _privacyPreferences['privacyPolicyAccepted']
                                      ? 'Accepted'
                                      : 'Not Accepted',
                                  style: TextStyle(
                                    color:
                                        _privacyPreferences['privacyPolicyAccepted']
                                            ? Colors.green
                                            : Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _showPrivacyPolicy,
                              child: const Text('View Privacy Policy'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Data Management Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.storage,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Data Management',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            ListTile(
                              leading: const Icon(Icons.schedule),
                              title: const Text('Data Retention Period'),
                              subtitle: Text(
                                '${_privacyPreferences['dataRetentionDays']} days',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: _showDataRetentionDialog,
                            ),

                            const Divider(),

                            ListTile(
                              leading: const Icon(
                                Icons.download,
                                color: Colors.blue,
                              ),
                              title: const Text('Export My Data'),
                              subtitle: const Text(
                                'Download all your data in portable format',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: _exportUserData,
                            ),

                            const Divider(),

                            ListTile(
                              leading: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              title: const Text('Delete All Data'),
                              subtitle: const Text(
                                'Permanently remove all your data',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: _deleteAllUserData,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Analytics & Reporting Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics,
                                  color: Colors.purple.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Analytics & Reporting',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            SwitchListTile(
                              secondary: const Icon(Icons.bar_chart),
                              title: const Text('Usage Analytics'),
                              subtitle: const Text(
                                'Help improve the app with anonymous usage data',
                              ),
                              value:
                                  _privacyPreferences['analyticsEnabled'] ??
                                  false,
                              onChanged:
                                  (value) => _updatePrivacyPreferences(
                                    analyticsEnabled: value,
                                  ),
                            ),

                            SwitchListTile(
                              secondary: const Icon(Icons.bug_report),
                              title: const Text('Crash Reporting'),
                              subtitle: const Text(
                                'Send crash reports to help fix bugs',
                              ),
                              value:
                                  _privacyPreferences['crashReportingEnabled'] ??
                                  false,
                              onChanged:
                                  (value) => _updatePrivacyPreferences(
                                    crashReportingEnabled: value,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Security Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.security,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Security Information',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _buildSecurityItem(
                              Icons.lock,
                              'Data Encryption',
                              'All sensitive data is encrypted with AES-256',
                              Colors.green,
                            ),
                            _buildSecurityItem(
                              Icons.phone_android,
                              'Local-First',
                              'Preferences and most data stay on your device',
                              Colors.blue,
                            ),
                            _buildSecurityItem(
                              Icons.cloud,
                              'Selective Cloud',
                              'Reviews you post are stored securely in Firestore and tied to your account',
                              Colors.orange,
                            ),
                            _buildSecurityItem(
                              Icons.verified_user,
                              'GDPR Compliant',
                              'Full compliance with data protection regulations',
                              Colors.purple,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer
                    Center(
                      child: Text(
                        'Your privacy is important to us. Most processing happens locally; posted reviews sync securely to the cloud.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSecurityItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
