import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/movie_service.dart';
import 'services/recommendation_service.dart';
import 'services/user_data_service.dart';
import 'services/secure_storage_service.dart';
import 'services/privacy_service.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'services/friendship_service.dart';
import 'pages/home_screen.dart';
import 'pages/privacy_policy_screen.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';

void main() async {
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
    debugPrint('Flutter Error: ${details.exception}');
    }
  };

  // Catch errors not handled by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
    debugPrint('Platform Error: $error');
    }
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $e');
    }
    // Continue with app launch even if Firebase fails
  }

  runApp(MovieMuseApp());
}

class MovieMuseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieMuse',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AuthService authService;
  bool _servicesInitialized = false;
  bool _authFallbackMode = false; // New: Track if we're in fallback mode
  bool _authStateStabilized = false; // New: Track if auth state has stabilized
  
  // Services
  late UserDataService userDataService;
  late MovieService movieService;
  late RecommendationService recommendationService;
  late PrivacyService privacyService;
  late AnalyticsService analyticsService;
  late SecureStorageService secureStorageService;
  late FriendshipService friendshipService; // New: Friendship service

  @override
  void initState() {
    super.initState();
    authService = AuthService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Auto-login functionality - handles both anonymous and email user persistence
      try {
        final user = await authService.autoLogin();
        if (kDebugMode && user != null) {
          debugPrint('Auto-login successful for user: ${user.uid}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Auto-login error: $e');
        }
        // Continue with app launch even if auto-login fails
      }

      // Load environment variables
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        // Continue with app launch - will fall back to default values
      }

      // Initialize SharedPreferences with error handling
      final prefs = await SharedPreferences.getInstance();

      // Initialize secure storage service
      secureStorageService = SecureStorageService(prefs);
      try {
        await secureStorageService.initialize();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Secure storage initialization failed: $e');
        }
        // Continue with app launch - will fall back to regular SharedPreferences
      }

      // Initialize services with error handling
      userDataService = UserDataService(prefs);
      movieService = MovieService();
      recommendationService = RecommendationService();
      friendshipService = FriendshipService();

      // Initialize privacy service
      privacyService = PrivacyService(
        prefs: prefs,
        secureStorage: secureStorageService,
        userDataService: userDataService,
        recommendationService: recommendationService,
      );
      
      // Set privacy service reference in movie service for adult content filtering
      movieService.setPrivacyService(privacyService);

      // Initialize analytics service with error handling
      analyticsService = AnalyticsService();
      try {
        await analyticsService.initialize();
      } catch (e) {
        if (kDebugMode) {
        debugPrint('Analytics initialization failed: $e');
        }
        // Continue with app launch - analytics is not critical
      }

      // Initialize other services
      await userDataService.initialize();
      await recommendationService.initialize();
      await privacyService.initialize();

      setState(() {
        _servicesInitialized = true;
      });

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Service initialization failed: $e');
      }
      // Still show the app even if some services fail
      setState(() {
        _servicesInitialized = true;
      });
    }
  }

  // Wait for auth state to stabilize
  Future<void> _waitForAuthStateStabilization() async {
    if (_authStateStabilized) return;
    
    try {
      // Wait a moment for Firebase Auth to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if we have a user
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        if (kDebugMode) {
          debugPrint('✅ Auth state stabilized with user: ${currentUser.uid}');
        }
        setState(() {
          _authStateStabilized = true;
        });
        return;
      }
      
      // If no user, try auto-login one more time
      if (kDebugMode) {
        debugPrint('🔄 No user found, attempting final auto-login...');
      }
      
      final user = await authService.autoLogin();
      if (user != null) {
        if (kDebugMode) {
          debugPrint('✅ Final auto-login successful: ${user.uid}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Final auto-login failed - proceeding with anonymous mode');
        }
      }
      
      setState(() {
        _authStateStabilized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error in auth state stabilization: $e');
      }
      setState(() {
        _authStateStabilized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesInitialized) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Initializing MovieMuse...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // Trigger auth state stabilization if not done yet
    if (!_authStateStabilized) {
      _waitForAuthStateStabilization();
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Setting up your session...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while auth state is being determined
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            debugShowCheckedModeBanner: false,
          );
        }

        // If no user and anonymous sign-in failed, show fallback or try again
        if (snapshot.data == null) {
          if (_authFallbackMode) {
            // Show error screen with instructions for user
            return MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
                        SizedBox(height: 24),
                        Text(
                          'Authentication Setup Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Anonymous authentication is disabled in your Firebase project. Please enable it in the Firebase Console under Authentication > Sign-in method > Anonymous.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            // Try to sign in anonymously again
                            setState(() {
                              _authFallbackMode = false;
                            });
                            if (authService.currentUser == null) {
                            authService.signInAnonymously().catchError((e) {
                                debugPrint('\u274c Anonymous sign-in retry failed: $e');
                              setState(() {
                                _authFallbackMode = true;
                              });
                            });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              debugShowCheckedModeBanner: false,
            );
          } else {
            // Try auto-login one more time
            debugPrint('\u26a0\ufe0f No authenticated user found, attempting auto-login...');
            Future.delayed(Duration(seconds: 2), () {
              // If still no user after 2 seconds, try auto-login
              if (mounted && snapshot.data == null) {
                authService.autoLogin().catchError((e) {
                  debugPrint('\u274c Auto-login failed: $e');
                setState(() {
                  _authFallbackMode = true;
                });
                });
              }
            });
            
            return MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Setting up your session...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This may take a moment',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              debugShowCheckedModeBanner: false,
            );
          }
        }

        // User is authenticated, show the main app
        debugPrint('✅ Auth state ready - User: ${snapshot.data?.uid}');
        
        return MaterialApp(
          title: 'MovieMuse',
          theme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          home: HomeScreen(
            userDataService: userDataService,
            movieService: movieService,
            recommendationService: recommendationService,
            secureStorageService: secureStorageService,
            privacyService: privacyService,
            authService: authService,
            friendshipService: friendshipService, // New: Pass friendship service
          ),
          routes: {
            '/privacy-policy': (context) => PrivacyPolicyScreen(
              privacyService: privacyService,
            ),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
