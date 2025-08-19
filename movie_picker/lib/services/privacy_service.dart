import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';
import 'user_data_service.dart';
import 'recommendation_service.dart';

class PrivacyService {
  static const String _privacyPolicyAcceptedKey = 'privacy_policy_accepted';
  static const String _privacyPolicyVersionKey = 'privacy_policy_version';
  static const String _dataRetentionDaysKey = 'data_retention_days';
  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const String _crashReportingEnabledKey = 'crash_reporting_enabled';
  static const String _adultContentEnabledKey = 'adult_content_enabled'; // New key for adult content

  static const String currentPrivacyPolicyVersion = '1.0.0';
  static const int defaultDataRetentionDays = 365; // 1 year

  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;
  final UserDataService _userDataService;
  final RecommendationService _recommendationService;

  PrivacyService({
    required SharedPreferences prefs,
    required SecureStorageService secureStorage,
    required UserDataService userDataService,
    required RecommendationService recommendationService,
  }) : _prefs = prefs,
       _secureStorage = secureStorage,
       _userDataService = userDataService,
       _recommendationService = recommendationService;

  /// Initialize privacy service
  Future<void> initialize() async {
    try {
      // Check if privacy policy needs to be accepted
      await _checkPrivacyPolicyVersion();

      // Clean up old data based on retention policy
      await _cleanupOldData();
    } catch (e) {
      debugPrint('❌ Error initializing privacy service: $e');
    }
  }

  /// Check if user has accepted current privacy policy version
  bool hasAcceptedPrivacyPolicy() {
    final accepted = _prefs.getBool(_privacyPolicyAcceptedKey) ?? false;
    final acceptedVersion = _prefs.getString(_privacyPolicyVersionKey) ?? '';
    return accepted && acceptedVersion == currentPrivacyPolicyVersion;
  }

  /// Record privacy policy acceptance
  Future<void> acceptPrivacyPolicy() async {
    await _prefs.setBool(_privacyPolicyAcceptedKey, true);
    await _prefs.setString(
      _privacyPolicyVersionKey,
      currentPrivacyPolicyVersion,
    );
  }

  /// Get privacy policy text
  String getPrivacyPolicyText() {
    return '''
MOVIE PICKER - PRIVACY POLICY

Last Updated: ${DateTime.now().toString().split(' ')[0]}
Version: $currentPrivacyPolicyVersion

1. INFORMATION WE COLLECT
Movie Picker collects the following information to provide our service:
• Account Information: Username, email address (if provided)
• Movie Preferences: Your ratings, watch history, and movie interactions
• App Usage: How you interact with the app to improve recommendations
• Device Information: App version, device type, and basic analytics

2. HOW WE USE YOUR INFORMATION
• Generate personalized movie recommendations
• Improve our AI algorithm and app features
• Enable social features and friend connections
• Provide customer support and technical assistance
• Analyze app performance and usage patterns (anonymized)

3. DATA STORAGE AND SECURITY
Your data is stored securely using industry-standard encryption. We use Firebase services for data storage and authentication. We do not sell your personal information to third parties.

4. THIRD-PARTY SERVICES
We use the following third-party services:
• The Movie Database (TMDB): For movie information and images
• Firebase: For data storage, authentication, and analytics
These services have their own privacy policies which we encourage you to review.

5. YOUR RIGHTS
You have the right to:
• Access your personal data
• Correct inaccurate information
• Delete your account and associated data
• Export your data in a portable format
• Opt out of certain data collection

6. DATA RETENTION
We retain your data for as long as your account is active or as needed to provide our services. You can request deletion of your data at any time.

7. CHILDREN'S PRIVACY
This app is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.

8. CHANGES TO THIS POLICY
We may update this privacy policy from time to time. We will notify you of any material changes through the app or email.

9. CONTACT
If you have questions about this privacy policy or would like to exercise your rights, please contact us at privacy@moviepicker.app

By using this app, you consent to this privacy policy.
''';
  }

  /// Check if privacy policy version has been updated
  Future<void> _checkPrivacyPolicyVersion() async {
    final acceptedVersion = _prefs.getString(_privacyPolicyVersionKey) ?? '';
    if (acceptedVersion != currentPrivacyPolicyVersion) {
      // Reset acceptance flag for new version
      await _prefs.setBool(_privacyPolicyAcceptedKey, false);
    }
  }

  /// Get user's privacy preferences
  Map<String, dynamic> getPrivacyPreferences() {
    return {
      'privacyPolicyAccepted': hasAcceptedPrivacyPolicy(),
      'privacyPolicyVersion': _prefs.getString(_privacyPolicyVersionKey) ?? '',
      'dataRetentionDays':
          _prefs.getInt(_dataRetentionDaysKey) ?? defaultDataRetentionDays,
      'analyticsEnabled': _prefs.getBool(_analyticsEnabledKey) ?? false,
      'crashReportingEnabled':
          _prefs.getBool(_crashReportingEnabledKey) ?? false,
      'adultContentEnabled': _prefs.getBool(_adultContentEnabledKey) ?? false,
    };
  }

  /// Update privacy preferences
  Future<void> updatePrivacyPreferences({
    int? dataRetentionDays,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? adultContentEnabled,
  }) async {
    if (dataRetentionDays != null) {
      await _prefs.setInt(_dataRetentionDaysKey, dataRetentionDays);
    }
    if (analyticsEnabled != null) {
      await _prefs.setBool(_analyticsEnabledKey, analyticsEnabled);
    }
    if (crashReportingEnabled != null) {
      await _prefs.setBool(_crashReportingEnabledKey, crashReportingEnabled);
    }
    if (adultContentEnabled != null) {
      await _prefs.setBool(_adultContentEnabledKey, adultContentEnabled);
    }
  }

  /// Get adult content preference (default: false for safety)
  bool isAdultContentEnabled() {
    return _prefs.getBool(_adultContentEnabledKey) ?? false;
  }

  /// Set adult content preference
  Future<void> setAdultContentEnabled(bool enabled) async {
    await _prefs.setBool(_adultContentEnabledKey, enabled);
  }

  /// Export all user data (GDPR Article 20 - Right to Data Portability)
  Future<String> exportUserData() async {
    try {
      final currentUserId = _userDataService.currentUserId;
      if (currentUserId == null) {
        throw Exception('No current user to export data for');
      }

      final exportData = <String, dynamic>{};

      // Export user data
      final userData = await _userDataService.getCurrentUserData();
      exportData['userData'] = userData.toJson();

      // Export user preferences
      final userPrefs = await _recommendationService.exportPreferencesForUser(
        currentUserId,
      );
      exportData['userPreferences'] = jsonDecode(userPrefs);

      // Export secure storage data
      final secureData = await _secureStorage.exportUserData(currentUserId);
      exportData['secureData'] = secureData;

      // Add metadata
      exportData['exportMetadata'] = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': 'MovieMuse App',
        'version': currentPrivacyPolicyVersion,
        'userId': currentUserId,
        'dataTypes': ['userData', 'userPreferences', 'secureData'],
      };

      // Generate data integrity hash
      final dataString = jsonEncode(exportData);
      exportData['dataIntegrityHash'] = _secureStorage.generateDataHash(
        dataString,
      );

      return jsonEncode(exportData);
    } catch (e) {
      debugPrint('❌ Error exporting user data: $e');
      rethrow;
    }
  }

  /// Save exported data to file
  Future<String> saveExportedDataToFile() async {
    try {
      final exportData = await exportUserData();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'movie_picker_data_export_$timestamp.json';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(exportData);
      debugPrint('💾 Exported data saved to: ${file.path}');

      return file.path;
    } catch (e) {
      debugPrint('❌ Error saving exported data: $e');
      rethrow;
    }
  }

  /// Delete all user data (GDPR Article 17 - Right to Erasure)
  Future<void> deleteAllUserData() async {
    try {
      final currentUserId = _userDataService.currentUserId;
      if (currentUserId == null) {
        throw Exception('No current user to delete data for');
      }

      // Delete from secure storage
      await _secureStorage.deleteUserData(currentUserId);

      // No longer possible to delete user data from UserDataService for other users
      // Only clear current user's data
      // await _userDataService.clearCurrentUserData();

      // Reset user preferences
      await _recommendationService.resetPreferencesForUser(currentUserId);

      // Clear privacy preferences
      await _prefs.remove(_privacyPolicyAcceptedKey);
      await _prefs.remove(_privacyPolicyVersionKey);
      await _prefs.remove(_dataRetentionDaysKey);
      await _prefs.remove(_analyticsEnabledKey);
      await _prefs.remove(_crashReportingEnabledKey);
      await _prefs.remove(_adultContentEnabledKey);

      debugPrint('🗑️ All user data deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting user data: $e');
      rethrow;
    }
  }

  /// Clean up old data based on retention policy
  Future<void> _cleanupOldData() async {
    try {
      final retentionDays =
          _prefs.getInt(_dataRetentionDaysKey) ?? defaultDataRetentionDays;
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));

      // No longer possible to get all users; only clean up current user
      final currentUserId = _userDataService.currentUserId;
      if (currentUserId != null) {
        final userData = await _userDataService.getCurrentUserData();
        if (userData.lastActiveAt.isBefore(cutoffDate)) {
          debugPrint('🧹 Cleaning up old data for user $currentUserId');
          await _secureStorage.deleteUserData(currentUserId);
          // await _userDataService.clearCurrentUserData();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error during data cleanup: $e');
    }
  }

  /// Get data usage statistics (anonymized)
  Map<String, dynamic> getDataUsageStats() {
    return {
      // No longer possible to get all users; just return 1 if current user exists
      'totalUsers': Future.value(_userDataService.currentUserId != null ? 1 : 0),
      'privacyPolicyVersion': currentPrivacyPolicyVersion,
      'dataRetentionDays':
          _prefs.getInt(_dataRetentionDaysKey) ?? defaultDataRetentionDays,
      'analyticsEnabled': _prefs.getBool(_analyticsEnabledKey) ?? false,
      'lastCleanup': DateTime.now().toIso8601String(),
    };
  }

  /// Verify data integrity
  Future<bool> verifyDataIntegrity(String exportedData) async {
    try {
      final data = jsonDecode(exportedData) as Map<String, dynamic>;
      final storedHash = data['dataIntegrityHash'] as String?;

      if (storedHash == null) return false;

      // Remove hash from data for verification
      data.remove('dataIntegrityHash');
      final dataString = jsonEncode(data);

      return _secureStorage.verifyDataIntegrity(dataString, storedHash);
    } catch (e) {
      debugPrint('❌ Error verifying data integrity: $e');
      return false;
    }
  }

  /// Check if user has been inactive for too long
  Future<bool> shouldPromptForDataRetention() async {
    try {
      final currentUserId = _userDataService.currentUserId;
      if (currentUserId == null) return false;

      final userData = await _userDataService.getCurrentUserData();
      final retentionDays =
          _prefs.getInt(_dataRetentionDaysKey) ?? defaultDataRetentionDays;
      final warningDays =
          (retentionDays * 0.9).round(); // Warn at 90% of retention period

      final daysSinceLastActive =
          DateTime.now().difference(userData.lastActiveAt).inDays;

      return daysSinceLastActive >= warningDays;
    } catch (e) {
      debugPrint('❌ Error checking data retention: $e');
      return false;
    }
  }
}
