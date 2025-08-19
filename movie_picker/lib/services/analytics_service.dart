import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;

  // Initialize Firebase Analytics
  Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _isInitialized = true;
      
      // Enable analytics collection
      await _analytics?.setAnalyticsCollectionEnabled(true);
      
      // Set basic app properties only
      await _analytics?.setUserProperty(name: 'app_version', value: '1.0.0');
      
      if (kDebugMode) {
        debugPrint('✅ Firebase Analytics initialized');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Analytics initialization failed: $e');
      }
    }
  }

  // Track only essential app events
  Future<void> trackAppEvent(String eventName) async {
    if (!_isInitialized || _analytics == null) return;

    try {
      // Only track critical app events
      if (!['app_start', 'onboarding_complete'].contains(eventName)) return;
      
      await _analytics!.logEvent(
        name: eventName,
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Silently handle analytics errors
    }
  }

  // Track app session start only
  Future<void> trackAppSession() async {
    if (!_isInitialized || _analytics == null) return;

    try {
      await _analytics!.logEvent(
        name: 'app_session_start',
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Silently handle analytics errors
    }
  }

  // Get analytics instance for direct access
  FirebaseAnalytics? get analytics => _analytics;

  // Check if analytics is initialized
  bool get isInitialized => _isInitialized;
} 