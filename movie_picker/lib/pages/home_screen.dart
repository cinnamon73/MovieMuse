import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../services/recommendation_service.dart';
import '../services/user_data_service.dart';
import '../services/secure_storage_service.dart';
import '../services/privacy_service.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/friendship_service.dart';
import '../widgets/swipeable_movie_card.dart';
import '../widgets/movie_card.dart';
import '../widgets/shimmer_movie_card.dart';
import '../themes/typography_theme.dart';
import '../pages/movie_details_page.dart';
import '../pages/onboarding_screen.dart';
import '../pages/privacy_settings_screen.dart';
import '../pages/settings_screen.dart';
import '../pages/friends_page.dart';
import '../widgets/app_drawer.dart';
import '../widgets/filter_dialog.dart';
import '../pages/search_page.dart';
import '../pages/watched_list_page.dart';
import '../pages/bookmarked_list_page.dart';
import '../pages/rating_screen.dart';
import '../themes/app_colors.dart';
import '../utils/animation_utils.dart';
import 'auth_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/semantic_search_page.dart';
import '../pages/taste_warmup_page.dart';

enum HomePageView { main, watched, bookmarked, search }

class HomeScreen extends StatefulWidget {
  final MovieService movieService;
  final RecommendationService recommendationService;
  final UserDataService userDataService;
  final SecureStorageService secureStorageService;
  final PrivacyService privacyService;
  final AuthService authService;
  final FriendshipService friendshipService; // New: Friendship service

  const HomeScreen({
    super.key,
    required this.movieService,
    required this.recommendationService,
    required this.userDataService,
    required this.secureStorageService,
    required this.privacyService,
    required this.authService,
    required this.friendshipService, // New parameter
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String? selectedGenre;
  List<Movie> movies = [];
  bool isLoading = true;
  String? error;
  final Set<int> watchedMovieIds = {};
  final Set<int> notInterestedMovieIds = {};
  final Set<int> bookmarkedMovieIds = {};
  final Map<int, double> movieRatings = {};
  List<Movie> trendingCardQueue = [];
  List<Movie> forYouCardQueue = [];
  Map<int, String> movieRecommenders = {}; // NEW: Track who recommended each movie
  bool showBookmarkedOnly = false;
  final Set<String> selectedGenres = {};
  late TabController _tabController;

  // New caching system variables
  List<Movie> filteredQueue = [];
  bool isPreloadingInBackground = false;

  String? selectedLanguage;
  String? selectedTimePeriod = 'All Years';
  String? selectedPerson;
  String? selectedPersonType;

  HomePageView currentView = HomePageView.main;

  // Current user data
  UserData? currentUserData;
  String? currentUserName;
  
  // Cached watched movie lists to prevent unnecessary re-filtering
  List<Movie> _cachedMoviesToRate = [];
  List<Movie> _cachedRatedMovies = [];
  int _lastWatchedCacheUpdate = 0;
  
  // Add a timestamp to force UI rebuilds when needed
  int _userDataTimestamp = DateTime.now().millisecondsSinceEpoch;

  // Add to _HomeScreenState:
  bool _watchedCacheLoaded = false;

  // Add periodic data sync
  Timer? _dataSyncTimer;
  Timer? _cleanupTimer;

  // Platform filter state
  String? selectedPlatform;
  bool isPlatformLoading = false;
  bool _skipAllPressed = false; // Track when Skip All is pressed to force showing watched list

  // Platform filter handler
  void _onPlatformChanged(String? platform) {
    debugPrint('🎯 HOME SCREEN: Platform changed to: $platform');
    setState(() {
      selectedPlatform = platform;
    });
    
    debugPrint('✅ HOME SCREEN: Platform state updated, calling _applyFiltersInstantly()');
    // Reapply filters with new platform
    _applyFiltersInstantly();
  }

  // Check if we should load more platform movies
  void _checkForMorePlatformMovies(int currentIndex) {
    if (selectedPlatform != null) {
      widget.movieService.maybeLoadMorePlatformMovies(currentIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initializeServices();
    _startPeriodicDataSync();
    _startPeriodicCleanup();
  }

  @override
  void dispose() {
    _dataSyncTimer?.cancel();
    _cleanupTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startPeriodicDataSync() {
    _dataSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && currentUserData != null) {
        _syncUserDataToFirebase();
        _syncCacheWithUserData(); // Add cache sync
      }
    });
  }

  // NEW: Sync cache with user data to ensure all referenced movies are cached
  Future<void> _syncCacheWithUserData() async {
    try {
      if (currentUserData == null) return;
      
      // Gather all unique movie IDs referenced in user data
      final idsToFetch = <int>{};
      idsToFetch.addAll(currentUserData!.watchedMovieIds);
      idsToFetch.addAll(currentUserData!.bookmarkedMovieIds);
      idsToFetch.addAll(currentUserData!.skippedMovieIds);

      // Check which movies are missing from cache
      final allCachedMovies = await widget.movieService.filterCachedMovies();
      final cachedIds = allCachedMovies.map((m) => m.id).toSet();
      final missingIds = idsToFetch.difference(cachedIds);
      
      if (missingIds.isNotEmpty) {
        debugPrint('🔄 Periodic cache sync: Fetching ${missingIds.length} missing movies...');
        
        // PARALLEL FETCHING: Fetch all missing movies simultaneously
        final futures = missingIds.map((movieId) => widget.movieService.fetchMovieById(movieId));
        final results = await Future.wait(futures);
        
        // Process results and add successful fetches to cache
        int successCount = 0;
        for (int i = 0; i < results.length; i++) {
          final movie = results[i];
          if (movie != null) {
            widget.movieService.addMovieToCache(movie);
            successCount++;
          }
        }
        
        debugPrint('✅ Periodic cache sync completed: $successCount out of ${missingIds.length} movies fetched in parallel');
      }
    } catch (e) {
      debugPrint('❌ Error during periodic cache sync: $e');
    }
  }

  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (mounted) {
        _performPeriodicCleanup();
      }
    });
  }

  Future<void> _performPeriodicCleanup() async {
    try {
      debugPrint('🧹 Starting periodic cleanup...');
      await widget.authService.performPeriodicCleanup();
      debugPrint('✅ Periodic cleanup completed');
    } catch (e) {
      debugPrint('❌ Error during periodic cleanup: $e');
    }
  }
  
  Future<void> _syncUserDataToFirebase() async {
    try {
      if (currentUserData == null) return;
      
      // Update local user data with current state
      currentUserData!.watchedMovieIds.clear();
      currentUserData!.watchedMovieIds.addAll(watchedMovieIds);
      currentUserData!.bookmarkedMovieIds.clear();
      currentUserData!.bookmarkedMovieIds.addAll(bookmarkedMovieIds);
      currentUserData!.skippedMovieIds.clear();
      currentUserData!.skippedMovieIds.addAll(notInterestedMovieIds);
      currentUserData!.movieRatings.clear();
      currentUserData!.movieRatings.addAll(movieRatings);
      
      // Save to Firebase
      await widget.userDataService.saveUserData(currentUserData!);
      
      debugPrint('✅ Periodic data sync completed');
    } catch (e) {
      debugPrint('❌ Error during periodic data sync: $e');
    }
  }

  // Initialize services and load user data
  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();

    // CRITICAL: Ensure MovieService has PrivacyService reference for adult content filtering
    widget.movieService.setPrivacyService(widget.privacyService);

    await _loadCurrentUserData();
    await _initializeApp();
  }

  // Load current user data from UserDataService
  Future<void> _loadCurrentUserData() async {
    try {
      final previousUserId = currentUserData?.userId;
      currentUserData = await widget.userDataService.getCurrentUserData();

      setState(() {
        currentUserName = currentUserData?.name;
        watchedMovieIds.clear();
        watchedMovieIds.addAll(currentUserData?.watchedMovieIds ?? {});
        bookmarkedMovieIds.clear();
        bookmarkedMovieIds.addAll(currentUserData?.bookmarkedMovieIds ?? {});
        notInterestedMovieIds.clear();
        notInterestedMovieIds.addAll(currentUserData?.skippedMovieIds ?? {});
        movieRatings.clear();
        movieRatings.addAll(currentUserData?.movieRatings ?? {});

        // Clear For You queue if user has changed to ensure personalized recommendations
        if (previousUserId != null &&
            previousUserId != currentUserData?.userId) {
          forYouCardQueue.clear();
          filteredQueue.clear();
        }
      });

      // Clear recommendation service cache for the previous user
      if (previousUserId != null && previousUserId != currentUserData?.userId) {
        widget.recommendationService.clearUserPreferencesCache(previousUserId);
      }
      
      // Load shared movies from recommendations collection
      if (currentUserData != null) {
        await _loadSharedMoviesFromRecommendations();
      }
      
      // Debug logging to verify data is loaded
      debugPrint('✅ User data loaded for ${currentUserData?.userId}:');
      debugPrint('   Watched: ${watchedMovieIds.length}');
      debugPrint('   Skipped: ${notInterestedMovieIds.length}');
      debugPrint('   Bookmarked: ${bookmarkedMovieIds.length}');
      debugPrint('   Ratings: ${movieRatings.length}');
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  // Load shared movies from recommendations collection
  Future<void> _loadSharedMoviesFromRecommendations() async {
    if (currentUserData == null) return;
    
    try {
      debugPrint('🎬 Loading shared movies from recommendations for user: ${currentUserData!.userId}');
      
      // Query recommendations sent to current user
      final firestore = FirebaseFirestore.instance;
      final recommendationsSnapshot = await firestore
          .collection('recommendations')
          .where('toUserId', isEqualTo: currentUserData!.userId)
          .where('isRead', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();
      
      final recommendations = recommendationsSnapshot.docs;
      debugPrint('📨 Found ${recommendations.length} unread recommendations');
      
      if (recommendations.isNotEmpty) {
        // Fetch movie details and store recommender info
        final movieFutures = recommendations.map((doc) {
          final data = doc.data();
          final movieId = data['movieId'] as int;
          return widget.movieService.fetchMovieById(movieId);
        });
        
        final movies = await Future.wait(movieFutures);
        final validMovies = <Movie>[];
        
        // Store recommender info for each valid movie
        for (int i = 0; i < movies.length; i++) {
          final movie = movies[i];
          if (movie != null) {
            validMovies.add(movie);
            final data = recommendations[i].data();
            final fromUsername = data['fromUsername'] as String? ?? 'Friend';
            movieRecommenders[movie.id] = fromUsername;
          }
        }
        
        if (validMovies.isNotEmpty) {
          setState(() {
            // Add shared movies to the TOP of the For You queue (seamlessly integrated)
            forYouCardQueue.insertAll(0, validMovies);
            debugPrint('✅ Added ${validMovies.length} shared movies to top of For You queue');
          });
          
          // Mark recommendations as read
          final batch = firestore.batch();
          for (final doc in recommendations) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
          debugPrint('✅ Marked ${recommendations.length} recommendations as read');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading shared movies from recommendations: $e');
    }
  }

  // Initialize the app with background preloading
  Future<void> _initializeApp() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Initialize recommendation service
      await widget.recommendationService.initialize();

      // Start preloading movies in the background
      await widget.movieService.preloadMovies(
        targetCount: 300,
        preferredGenres:
            selectedGenres.isNotEmpty ? selectedGenres.toList() : null,
      );

      // Apply initial filters to create the queue
      await _applyFiltersInstantly();

      // Only set loading to false after everything is ready
      setState(() {
        isLoading = false;
      });
      
      debugPrint('✅ App initialization complete');
    } catch (e) {
      setState(() {
        error = 'Failed to load movies: $e';
        isLoading = false;
      });
      debugPrint('❌ Error during app initialization: $e');
    }
  }

  // Apply filters using enhanced search system with immediate TMDB API queries
  Future<void> _applyFiltersInstantly() async {
    debugPrint('🔄 _applyFiltersInstantly called');
    debugPrint('📊 Current filters - Genres: $selectedGenres, Language: $selectedLanguage, TimePeriod: $selectedTimePeriod, Platform: $selectedPlatform');
    
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // If platform filter is active, use platform movies directly
      if (selectedPlatform != null) {
        debugPrint('🎯 Platform filter active: $selectedPlatform');
        
        // Get platform movies from the service
        final platformMovies = await widget.movieService.filterCachedMovies();
        
        debugPrint('📊 Found ${platformMovies.length} platform movies');
        
        setState(() {
          filteredQueue = List<Movie>.from(platformMovies);
          trendingCardQueue = filteredQueue.take(10).toList();
          isLoading = false;
        });
        
        if (filteredQueue.isEmpty) {
          setState(() {
            error = 'No movies found for $selectedPlatform';
          });
        } else {
          setState(() {
            error = null;
          });
          _showFilterSuccessMessage(filteredQueue.length);
        }
        
        debugPrint('✅ Platform filter applied successfully');
        return;
      }

      // Get current user data for personalization
      final currentUser = await widget.userDataService.getCurrentUserData();
      final excludeIds = <int>{};
      if (currentUser != null) {
        excludeIds.addAll(currentUser.watchedMovieIds);
        excludeIds.addAll(currentUser.skippedMovieIds);
        excludeIds.addAll(currentUser.bookmarkedMovieIds); // BLACKLIST bookmarked movies
      }

      // Use direct TMDB API search for immediate results
      final filtered = await widget.movieService.findMoviesWithFilters(
        selectedGenres:
            selectedGenres.isNotEmpty ? selectedGenres.toList() : null,
        language: selectedLanguage,
        timePeriod: selectedTimePeriod,
        excludeIds: excludeIds,
        targetCount: 100,
        maxPages: 500,
        person: selectedPerson,
        personType: selectedPersonType,
      );

      // Trending is non-personalized: use TMDB-based sorting only
      final List<Movie> finalMovies = widget.movieService.sortMoviesByQuality(filtered);

      // CRITICAL: If no movies found and no filters are applied, get popular movies as fallback
      if (finalMovies.isEmpty && 
          selectedGenres.isEmpty &&
          selectedLanguage == null &&
          selectedTimePeriod == 'All Years' &&
          selectedPerson == null) {
        debugPrint('🔄 No movies found with no filters - using popular movies fallback');
        // TODO: Implement dynamic movie loading
      }

      setState(() {
        filteredQueue = List<Movie>.from(finalMovies);
        trendingCardQueue =
            filteredQueue.take(10).toList(); // Show first 10 in card stack
        isLoading = false;
      });

      // Show appropriate messages based on results
      if (filteredQueue.isEmpty) {
        setState(() {
          error = _getNoResultsMessage();
        });
      } else {
        setState(() {
          error = null;
        });

        // Show success message for specific filters
        if (selectedPerson != null ||
            selectedGenres.isNotEmpty ||
            selectedLanguage != null) {
          _showFilterSuccessMessage(filteredQueue.length);
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _applyFiltersInstantly: $e');
      setState(() {
        error = 'Error searching TMDB catalog: $e';
        isLoading = false;
      });
    }

    // Check if we need to preload more movies in the background (secondary priority)
    _maybePreloadMoreInBackground();
  }

  // Get contextual no results message
  String _getNoResultsMessage() {
    if (selectedPerson != null) {
      return 'No movies found with $selectedPersonType "$selectedPerson" in TMDB catalog.\nTry a different spelling or check if the person exists.';
    } else if (selectedGenres.isNotEmpty && selectedLanguage != null) {
      return 'No ${selectedGenres.join(', ')} movies in $selectedLanguage found in TMDB.\nTry different filter combinations.';
    } else if (selectedGenres.isNotEmpty) {
      return 'No ${selectedGenres.join(', ')} movies found with current filters.\nTry different time periods or languages.';
    } else if (selectedLanguage != null) {
      return 'No movies in $selectedLanguage found with current filters.\nTry different genres or time periods.';
    } else {
      return 'No movies found with current filters in TMDB catalog.\nTry different filter combinations.';
    }
  }

  // Show success message for specific filters
  void _showFilterSuccessMessage(int resultCount) {
    if (!mounted) return;

    String message = '';
    Color backgroundColor = Colors.green.withValues(alpha: 0.8);

    if (selectedPerson != null) {
      message =
          '✅ Found $resultCount movies with $selectedPersonType "$selectedPerson"';
      backgroundColor = Colors.blue.withValues(alpha: 0.8);
    } else if (selectedGenres.isNotEmpty && selectedLanguage != null) {
      message =
          'Found $resultCount ${selectedGenres.join(', ')} movies in $selectedLanguage';
    } else if (selectedGenres.isNotEmpty) {
      message = 'Found $resultCount ${selectedGenres.join(', ')} movies';
    } else if (selectedLanguage != null) {
      message = 'Found $resultCount movies in $selectedLanguage';
    }

    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  // Background preloading when queue gets low
  Future<void> _maybePreloadMoreInBackground() async {
    if (isPreloadingInBackground) return;

    // Check for platform dynamic loading first
    if (selectedPlatform != null) {
      // For platform mode, check if we need more platform movies
      final currentIndex = filteredQueue.length - 1;
      if (currentIndex >= 0) {
        _checkForMorePlatformMovies(currentIndex);
      }
      return;
    }

    // If we have fewer than 10 movies in the filtered queue, preload more
    if (filteredQueue.length < 10) {
      setState(() {
        isPreloadingInBackground = true;
      });

      try {
        debugPrint('🔄 Queue low (${filteredQueue.length} movies), fetching more...');
        
        await widget.movieService.maybePreloadMore(
          threshold: 20, // Lower threshold for more aggressive loading
          preferredGenres: selectedGenres.isNotEmpty ? selectedGenres.toList() : null,
        );

        // Reapply filters with the new movies
        await _applyFiltersInstantly();
        
        debugPrint('✅ Refilled queue, now have ${filteredQueue.length} movies');
      } catch (e) {
        // Log error but don't crash
        debugPrint('❌ Error during background preload: $e');
      } finally {
        setState(() {
          isPreloadingInBackground = false;
        });
      }
    }
  }

  // Completely rewrite swipe handlers to ensure immediate state updates
  void _onSwipeLeft() {
    if (trendingCardQueue.isNotEmpty) {
      final movie = trendingCardQueue.last;
      
      // IMMEDIATE state update - this must happen synchronously
      setState(() {
        notInterestedMovieIds.add(movie.id);
        trendingCardQueue.removeLast();
      });

      // Update currentUserData immediately for consistency
      if (currentUserData != null) {
        currentUserData!.skippedMovieIds.add(movie.id);
      }
      
      // Ensure movie is cached immediately
      widget.movieService.addMovieToCache(movie);
      
      // Async storage update (fire and forget)
      widget.userDataService.addSkippedMovie(movie.id);

      // Other async operations
      _recordUserInteraction(movie, 'skipped');
      // Analytics tracking removed for production

      // Rebuild queue immediately
      _ensureCardQueueHasCards();
      _maybePreloadMoreInBackground();
    }
  }

  void _onSwipeRight() {
    if (trendingCardQueue.isNotEmpty) {
      final movie = trendingCardQueue.last;
      
      // IMMEDIATE state update - this must happen synchronously
      setState(() {
        watchedMovieIds.add(movie.id);
        trendingCardQueue.removeLast();
      });
      
      // Update currentUserData immediately for consistency
      if (currentUserData != null) {
        currentUserData!.watchedMovieIds.add(movie.id);
      }
      
      // Ensure movie is cached immediately so it shows up in watched list
      widget.movieService.addMovieToCache(movie);
      
      // Async storage updates (fire and forget)
      widget.userDataService.addWatchedMovie(movie.id);
      widget.userDataService.addWatchedMovie(movie.id);

      // Other async operations
      _recordUserInteraction(movie, 'watched');
      // Analytics tracking removed for production

      // Immediately update watched movies cache
      widget.movieService.filterCachedMovies().then((allCachedMovies) {
        if (mounted) {
          _updateWatchedMoviesCache(allCachedMovies);
        }
      });

      // Rebuild queue immediately
      _ensureCardQueueHasCards();
      _maybePreloadMoreInBackground();
    }
  }

  void _onSwipeUp() async {
    if (trendingCardQueue.isNotEmpty) {
      final movie = trendingCardQueue.last;
      
      // Analytics tracking removed for production
      
      final cast = await widget.movieService.fetchCast(movie.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        AnimationUtils.createFadeSlideRoute(
          MovieDetailsPage(
                movie: movie,
                cast: cast,
                isBookmarked: bookmarkedMovieIds.contains(movie.id),
                isWatched: watchedMovieIds.contains(movie.id),
                currentRating: movieRatings[movie.id] ?? 0.0,
                showRatingSystem: false, // No rating system for trending/for you movies
                selectedPlatform: selectedPlatform, // NEW: Pass the selected platform filter
                contextPool: forYouCardQueue.isNotEmpty ? List<Movie>.from(forYouCardQueue) : List<Movie>.from(filteredQueue),
                allowWatchedAction: false,
                showMatchBadge: false,
                onBookmark: () {
                  _toggleBookmark(movie.id);
                  Navigator.pop(context);
                },
                onMarkWatched: () {
                  _markWatched(movie.id);
                  Navigator.pop(context);
                },
                onRatingChanged: (rating) {
                  _updateMovieRating(movie.id, rating);
                },
                onPersonTap: (personName, personType) {
                  Navigator.pop(context); // Close details first
                  _filterByPerson(personName, personType);
                },
              ),
        ),
      );
      // Don't remove the card when returning from details - user can still swipe on it
    }
  }

  void _onSwipeDown() {
    if (trendingCardQueue.isNotEmpty) {
      final movie = trendingCardQueue.last;
      _toggleBookmark(movie.id);

      // Record bookmark interaction for recommendation learning with user ID
      if (bookmarkedMovieIds.contains(movie.id)) {
        _recordUserInteraction(movie, 'bookmarked');
      }

      // Analytics tracking removed for production

      setState(() {
        trendingCardQueue.removeLast();
      });
      _ensureCardQueueHasCards();
      _maybePreloadMoreInBackground();
    }
  }

  // Helper methods for data persistence
  void _toggleBookmark(int movieId) {
    setState(() {
      if (bookmarkedMovieIds.contains(movieId)) {
        bookmarkedMovieIds.remove(movieId);
      } else {
        bookmarkedMovieIds.add(movieId);
      }
    });
    
    // Ensure the movie is cached if it's being bookmarked
    if (bookmarkedMovieIds.contains(movieId)) {
      // Find the movie in the current queues and cache it
      final allMovies = [...trendingCardQueue, ...forYouCardQueue];
      final movie = allMovies.firstWhere(
        (m) => m.id == movieId,
        orElse: () => Movie(
          id: movieId,
          title: 'Unknown Movie',
          description: '',
          posterUrl: '',
          genre: 'Unknown',
          subgenre: 'Unknown',
          releaseDate: '0',
          voteAverage: 0.0,
          language: 'en',
        ),
      );
      widget.movieService.addMovieToCache(movie);
    }
    
    widget.userDataService.toggleBookmark(movieId);
  }

  void _markWatched(int movieId) {
    setState(() {
      watchedMovieIds.add(movieId);
      bookmarkedMovieIds.remove(movieId);
    });

    // Ensure the movie is cached if it's being marked as watched
    final allMovies = [...trendingCardQueue, ...forYouCardQueue, ...filteredQueue];
    final movie = allMovies.firstWhere(
      (m) => m.id == movieId,
      orElse: () => Movie(
        id: movieId,
        title: 'Unknown Movie',
        description: '',
        posterUrl: '',
        genre: 'Unknown',
        subgenre: 'Unknown',
        releaseDate: '0',
        voteAverage: 0.0,
        language: 'en',
      ),
    );
    widget.movieService.addMovieToCache(movie);

    // Save to persistent storage (both services for backward compatibility)
    widget.userDataService.addWatchedMovie(movieId);
    widget.userDataService.toggleBookmark(movieId); // Remove from bookmarks

    // Immediately update watched movies cache
    widget.movieService.filterCachedMovies().then((allCachedMovies) {
      if (mounted) {
        _updateWatchedMoviesCache(allCachedMovies);
      }
    });
  }

  void _markWatchedWithRating(int movieId, double rating) {
    setState(() {
      watchedMovieIds.add(movieId);
      bookmarkedMovieIds.remove(movieId);
      movieRatings[movieId] = rating; // Set the rating
      _lastWatchedCacheUpdate = 0;
    });

    // Ensure the movie is cached if it's being marked as watched
    final allMovies = [...trendingCardQueue, ...forYouCardQueue, ...filteredQueue];
    final movie = allMovies.firstWhere(
      (m) => m.id == movieId,
      orElse: () => Movie(
        id: movieId,
        title: 'Unknown Movie',
        description: '',
        posterUrl: '',
        genre: 'Unknown',
        subgenre: 'Unknown',
        releaseDate: '0',
        voteAverage: 0.0,
        language: 'en',
      ),
    );
    widget.movieService.addMovieToCache(movie);

    // Save to persistent storage
    widget.userDataService.addWatchedMovie(movieId);
    widget.userDataService.toggleBookmark(movieId); // Remove from bookmarks
    
    // Save rating
    if (currentUserData != null) {
      currentUserData!.movieRatings[movieId] = rating;
      widget.userDataService.setMovieRatingWithUserData(currentUserData!, movieId, rating);
    }

    // Record analytics
    // Analytics tracking removed for production

    // Immediately update watched movies cache
    widget.movieService.filterCachedMovies().then((allCachedMovies) {
      if (mounted) {
        _updateWatchedMoviesCache(allCachedMovies);
      }
    });
  }

  void _updateMovieRating(int movieId, double rating) {
    setState(() {
      movieRatings[movieId] = rating;
      if (rating > 0) watchedMovieIds.add(movieId); // Ensure rated movies are counted as watched
      _lastWatchedCacheUpdate = 0;
    });
    if (currentUserData != null) {
      if (rating > 0) {
        currentUserData!.movieRatings[movieId] = rating;
      } else {
        currentUserData!.movieRatings.remove(movieId);
      }
      widget.userDataService.setMovieRatingWithUserData(currentUserData!, movieId, rating);
    }
    widget.movieService.filterCachedMovies().then((allCachedMovies) {
      if (mounted) {
        _updateWatchedMoviesCache(allCachedMovies);
      }
    });
    // Analytics tracking removed for production
  }

  // Helper method to record user interactions with proper user ID
  Future<void> _recordUserInteraction(
    Movie movie,
    String interactionType, {
    double? rating,
  }) async {
    try {
      final currentUser = await widget.userDataService.getCurrentUserData();
      if (currentUser != null) {
        await widget.recommendationService.recordInteractionForUser(
          userId: currentUser.userId,
          movie: movie,
          interactionType: interactionType,
          rating: rating,
        );
      }
    } catch (e) {
      debugPrint('Error recording user interaction: $e');
    }
  }

  // Helper method to record rating interaction asynchronously with user ID
  Future<void> _recordRatingInteractionForUser(
    int movieId,
    double rating,
  ) async {
    try {
      // Find the movie in cache to record interaction
      final allCachedMovies = await widget.movieService.filterCachedMovies();
      final movie = allCachedMovies.firstWhere(
        (m) => m.id == movieId,
        orElse:
            () => Movie(
              id: movieId,
              title: 'Unknown Movie',
              description: '',
              posterUrl: '',
              genre: 'Unknown',
              subgenre: 'Unknown',
              releaseDate: '0',
              voteAverage: 0.0,
              language: 'en',
            ),
      );

      // Record rating interaction for recommendation learning with user ID
      await _recordUserInteraction(movie, 'rated', rating: rating);
    } catch (e) {
      debugPrint('Error recording rating interaction: $e');
    }
  }

  // Ensure the card queue has enough cards by adding more from the filtered queue
  void _ensureCardQueueHasCards() {
    setState(() {
      // Populate For You first (if unlocked) then Trending from remaining pool
      final Set<int> interacted = {
        ...watchedMovieIds,
        ...notInterestedMovieIds,
        ...bookmarkedMovieIds,
      };

      // Base pool: filteredQueue excluding interacted
      final basePool = filteredQueue.where((m) => !interacted.contains(m.id)).toList();

      // Fill For You up to 10 first (only if user has >= 50 interactions or anonymous lock lifted)
      final canUseForYou = !widget.authService.isAnonymous && (interacted.length >= 50);
      if (canUseForYou) {
        final needFY = 10 - forYouCardQueue.length;
        if (needFY > 0) {
          final excludedIds = forYouCardQueue.map((m) => m.id).toSet();
          final candidateFY = basePool.where((m) => !excludedIds.contains(m.id)).take(needFY).toList();
          forYouCardQueue.insertAll(0, candidateFY);
        }
      }

      // Fill Trending with movies not used in For You and not already in Trending
      final usedIds = {
        ...forYouCardQueue.map((m) => m.id),
        ...trendingCardQueue.map((m) => m.id),
      };
      final needTrending = 10 - trendingCardQueue.length;
      if (needTrending > 0) {
        final candidateTrending = basePool.where((m) => !usedIds.contains(m.id)).take(needTrending).toList();
        trendingCardQueue.insertAll(0, candidateTrending);
      }
    });
  }

  void _showWatchedList() {
    setState(() {
      currentView = HomePageView.watched;
    });
    Navigator.pop(context); // Close drawer
  }

  void _showBookmarkedList() {
    setState(() {
      currentView = HomePageView.bookmarked;
    });
    Navigator.pop(context); // Close drawer
  }

  void _showSearchPage() {
    setState(() {
      currentView = HomePageView.search;
    });
    Navigator.pop(context); // Close drawer
  }

  // New: Show friends page
  void _showFriendsPage() {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendsPage(
          friendshipService: widget.friendshipService,
          userDataService: widget.userDataService,
          movieService: widget.movieService,
        ),
      ),
    );
  }

  void _showHelp() {
    Navigator.pop(context); // Close drawer first
    Navigator.push(
      context,
      AnimationUtils.createSlideRoute(
        OnboardingScreen(
              onComplete: () {
                Navigator.pop(context); // Return to main app
              },
              authService: widget.authService,
            ),
      ),
    );
  }

  void _showPrivacySettings() {
    Navigator.pop(context); // Close drawer first
    Navigator.push(
      context,
      AnimationUtils.createSlideRoute(
                PrivacySettingsScreen(privacyService: widget.privacyService),
      ),
    );
  }

  void _showSettings() {
    Navigator.pop(context); // Close drawer first
    Navigator.push(
      context,
      AnimationUtils.createSlideRoute(
        SettingsScreen(
          privacyService: widget.privacyService,
          movieService: widget.movieService, // Pass MovieService for cache clearing
        ),
      ),
    );
  }

  void _showMainView() {
    setState(() {
      currentView = HomePageView.main;
    });
  }

  // Handle user switching
  Future<void> _onUserChanged() async {
    // Clear recommendation cache for user switching
    widget.recommendationService.clearUserPreferencesCache(null);

    // Clear For You queue to avoid showing old recommendations
    setState(() {
      forYouCardQueue.clear();
      filteredQueue.clear();
    });

    await _loadCurrentUserData();
    await _applyFiltersInstantly();

    // Rebuild For You queue with new user's preferences
    if (_tabController.index == 1) {
      await _initializeForYouQueue();
    }
  }

  // Helper method to update movie rating by ID (when we only have the ID)
  void _updateMovieRatingById(int movieId, double rating) {
    _updateMovieRating(movieId, rating);
  }

  // Quality indicator helper methods
  bool _shouldShowQualityInfo() {
    if (filteredQueue.isEmpty) return false;

    // Show quality info if we have a mix of quality levels or mostly low-quality movies
    final highQualityCount =
        filteredQueue
            .where((movie) => widget.movieService.isHighQualityMovie(movie))
            .length;
    final qualityRatio = highQualityCount / filteredQueue.length;

    // Show if less than 70% are high quality (indicating mixed or low quality)
    return qualityRatio < 0.7;
  }

  Color _getQualityColor() {
    if (filteredQueue.isEmpty) return Colors.grey;

    final highQualityCount =
        filteredQueue
            .where((movie) => widget.movieService.isHighQualityMovie(movie))
            .length;
    final qualityRatio = highQualityCount / filteredQueue.length;

    if (qualityRatio >= 0.7) {
      return AppColors.success; // Green for high quality
    } else if (qualityRatio >= 0.4) {
      return AppColors.warning; // Orange for mixed quality
    } else {
      return AppColors.error; // Red for low quality
    }
  }

  IconData _getQualityIcon() {
    if (filteredQueue.isEmpty) return Icons.help_outline;

    final highQualityCount =
        filteredQueue
            .where((movie) => widget.movieService.isHighQualityMovie(movie))
            .length;
    final qualityRatio = highQualityCount / filteredQueue.length;

    if (qualityRatio >= 0.7) {
      return Icons.star; // High quality
    } else if (qualityRatio >= 0.4) {
      return Icons.star_half; // Mixed quality
    } else {
      return Icons.star_border; // Low quality
    }
  }

  String _getQualityText() {
    if (filteredQueue.isEmpty) return 'No movies';

    final highQualityCount =
        filteredQueue
            .where((movie) => widget.movieService.isHighQualityMovie(movie))
            .length;
    final qualityRatio = highQualityCount / filteredQueue.length;

    if (qualityRatio >= 0.7) {
      return 'High Quality';
    } else if (qualityRatio >= 0.4) {
      return 'Mixed Quality';
    } else {
      return 'Lower Quality';
    }
  }

  Future<Widget> _buildBookmarkedMoviesList() async {
    // Get bookmarked movies from the cache
    final allCachedMovies = await widget.movieService.filterCachedMovies();
    final bookmarkedMovies =
        allCachedMovies
            .where((m) => bookmarkedMovieIds.contains(m.id))
            .toList();

    if (bookmarkedMovies.isEmpty) {
      return const Center(
        child: Text(
          'No bookmarked movies',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarkedMovies.length,
      itemBuilder: (context, index) {
        final movie = bookmarkedMovies[index];
        final userRating = movieRatings[movie.id] ?? 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white10,
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: movie.posterUrl,
                width: 60,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              movie.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Released: ${movie.releaseDate}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'TMDB: ',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      movie.formattedScore,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (userRating > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Your rating: ',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        userRating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.amber),
                      ),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                    ],
                  ],
                ),
              ],
            ),
            onTap: () async {
              final cast = await widget.movieService.fetchCast(movie.id);
              if (!mounted) return;
              await Navigator.push(
                context,
                AnimationUtils.createFadeSlideRoute(
                  MovieDetailsPage(
                        movie: movie,
                        cast: cast,
                        isBookmarked: bookmarkedMovieIds.contains(movie.id),
                        isWatched: watchedMovieIds.contains(movie.id),
                        currentRating: movieRatings[movie.id] ?? 0.0,
                        showRatingSystem: true, // Keep rating system for bookmarked movies
                        selectedPlatform: selectedPlatform, // NEW: Pass the selected platform filter
                        contextPool: forYouCardQueue.isNotEmpty ? List<Movie>.from(forYouCardQueue) : List<Movie>.from(filteredQueue),
                        allowWatchedAction: true,
                        allowBookmarkAction: true,
                        onBookmark: () {
                          _toggleBookmark(movie.id);
                          Navigator.pop(context);
                        },
                        onMarkWatched: () {
                          // Mark as watched, remove from bookmarks, and add rating
                          // This will be called from the rating dialog
                          _markWatchedWithRating(movie.id, movieRatings[movie.id] ?? 0.0);
                          Navigator.pop(context);
                        },
                        onRatingChanged: (rating) {
                          // Handle rating from the dialog - this will be called before onMarkWatched
                          _updateMovieRating(movie.id, rating);
                        },
                        onPersonTap: (personName, personType) {
                          Navigator.pop(context); // Close details first
                          _filterByPerson(personName, personType);
                        },
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // New method to handle person filtering
  Future<void> _filterByPerson(String personName, String personType) async {
    setState(() {
      selectedPerson = personName;
      selectedPersonType = personType;
      // Clear other filters to focus on the person
      selectedGenres.clear();
      selectedLanguage = null;
      selectedTimePeriod = 'All Years';
    });

    // Reset movie service filters
    widget.movieService.resetFilters();
    widget.movieService.setPerson(personName, personType);

    // Show immediate feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔍 Searching TMDB for $personType "$personName"...'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.blue.withValues(alpha: 0.8),
        ),
      );
    }

    // Apply the new filters (this will be much faster now)
    await _applyFiltersInstantly();
  }

  // Handle tab changes
  void _handleTabChange() {
    if (_tabController.index == 1 && forYouCardQueue.isEmpty) {
      _initializeForYouQueue();
    }
  }

  // Initialize the For You queue
  Future<void> _initializeForYouQueue() async {
    if (forYouCardQueue.isNotEmpty) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Add timeout to prevent infinite loading
      await Future.any([
        _performForYouQueueInitialization(),
        Future.delayed(const Duration(seconds: 15), () {
          throw TimeoutException('For You queue initialization timed out');
        }),
      ]);
    } catch (e) {
      setState(() {
        error = 'Failed to load recommendations: $e';
        isLoading = false;
      });
      debugPrint('Error initializing For You queue: $e');
    }
  }

  // Separated initialization logic with better auth handling
  Future<void> _performForYouQueueInitialization() async {
    try {
      // Check auth state first
      final currentUser = widget.authService.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('⚠️ No authenticated user, attempting auto-login...');
        }
        
        // Try auto-login
        final autoLoginUser = await widget.authService.autoLogin();
        if (autoLoginUser == null) {
          throw Exception('Failed to authenticate user');
        }
        
        if (kDebugMode) {
          debugPrint('✅ Auto-login successful: ${autoLoginUser.uid}');
        }
      }
      
      // Now get user data with retry logic
      UserData? currentUserData;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          currentUserData = await widget.userDataService.getCurrentUserData();
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            debugPrint('⚠️ Failed to get user data (attempt $retryCount): $e');
          }
          
          if (retryCount >= maxRetries) {
            throw Exception('Failed to get user data after $maxRetries attempts: $e');
          }
          
          // Wait before retry
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
      
      // Ensure we have user data
      if (currentUserData == null) {
        throw Exception('Failed to get user data after all retry attempts');
      }
      
      print('🎬 Initializing For You queue for user: ${currentUserData.userId}');
      print('   Name: ${currentUserData.name}');
      print('   Anonymous: ${widget.authService.isAnonymous}');

      // Get excluded movie IDs (watched, skipped, bookmarked, and currently in trending queue)
      final excludeIds = <int>{};
      excludeIds.addAll(currentUserData.watchedMovieIds);
      excludeIds.addAll(currentUserData.skippedMovieIds);
      excludeIds.addAll(currentUserData.bookmarkedMovieIds); // BLACKLIST bookmarked movies
      // Exclude movies currently in trending queue to prevent duplicates
      excludeIds.addAll(trendingCardQueue.map((m) => m.id));

      // Check if user is new (has few interactions)
      final userInsights = await widget.recommendationService
          .getUserInsightsForUser(currentUserData.userId);
      final totalInteractions =
          userInsights['totalInteractions'] as int? ?? 0;

      print('   Total interactions: $totalInteractions');

      List<Movie> recommendations;

      if (totalInteractions < 10) {
        // For new users (including fresh anonymous): Use cached movies and show popular, high-quality ones
        print('   → Showing popular movies for new user');

        // First try to use cached movies
        final cachedMovies = await widget.movieService.filterCachedMovies(
          excludeIds: excludeIds,
          minRating: 6.0, // Only show well-rated movies for new users
        );

        if (cachedMovies.length >= 20) {
          // We have enough cached movies
          recommendations = widget.movieService.sortMoviesByQuality(
            cachedMovies.take(100).toList(),
          );
          print('   → Using ${recommendations.length} cached movies for new user');
        } else {
          // Fall back to API if not enough cached movies
          print('   → Not enough cached movies, fetching from API...');
          final availableMovies = await widget.movieService.findMoviesWithFilters(
            excludeIds: excludeIds,
            minRating: 6.0,
            targetCount: 200,
            maxPages: 50,
          );

          recommendations = widget.movieService.sortMoviesByQuality(
            availableMovies.take(100).toList(),
          );
        }
      } else {
        // For experienced users: Show personalized recommendations
        print('   → Showing personalized recommendations for experienced user');

        final topGenres = userInsights['topGenres'] as List<String>? ?? [];

        // First try to use cached movies
        final cachedMovies = await widget.movieService.filterCachedMovies(
          selectedGenres:
              topGenres.isNotEmpty
                  ? topGenres.take(3).toList()
                  : null,
          excludeIds: excludeIds,
        );

        if (cachedMovies.length >= 20) {
          // We have enough cached movies - use personalized recommendations
          recommendations = await widget.recommendationService
              .getRecommendationsForUser(
                cachedMovies,
                currentUserData.userId,
                limit: 100,
              );
          print('   → Using ${recommendations.length} cached movies for personalized recommendations');
        } else {
          // Fall back to API if not enough cached movies
          print('   → Not enough cached movies, fetching from API...');
          final availableMovies = await widget.movieService.findMoviesWithFilters(
            selectedGenres:
                topGenres.isNotEmpty
                    ? topGenres.take(3).toList()
                    : null,
            excludeIds: excludeIds,
            targetCount: 200,
            maxPages: 500,
          );

          recommendations = await widget.recommendationService
            .getRecommendationsForUser(
              availableMovies,
              currentUserData.userId,
              limit: 100,
            );
        }

        if (topGenres.isNotEmpty) {
          print('   → Prioritized genres: ${topGenres.take(3).join(', ')}');
        }
      }

      setState(() {
        filteredQueue = recommendations; // Store all in filteredQueue
        forYouCardQueue = recommendations.take(10).toList(); // Show first 10
        isLoading = false;
      });

      print('✅ Initialized For You queue with ${recommendations.length} movies for user: ${currentUserData.name}');
      
    } catch (e) {
      print('❌ Error in For You queue initialization: $e');
      setState(() {
        error = 'Failed to load recommendations: $e';
        isLoading = false;
      });
    }
  }

  // Update For You queue when user interacts with movies
  Future<void> _updateForYouQueue() async {
    if (forYouCardQueue.isEmpty) {
      await _initializeForYouQueue();
      return;
    }

    try {
      // Get current user data
      final currentUser = await widget.userDataService.getCurrentUserData();
      if (currentUser == null) {
        debugPrint('No active user found when updating For You queue');
        return;
      }

      // Get excluded movie IDs (watched, skipped, bookmarked, and currently in trending queue)
      final excludeIds = <int>{};
      excludeIds.addAll(currentUser.watchedMovieIds);
      excludeIds.addAll(currentUser.skippedMovieIds);
      excludeIds.addAll(currentUser.bookmarkedMovieIds); // BLACKLIST bookmarked movies
      // Exclude movies currently in trending queue to prevent duplicates
      excludeIds.addAll(trendingCardQueue.map((m) => m.id));

      // Check if user is new or experienced for appropriate recommendations
      final userInsights = await widget.recommendationService
          .getUserInsightsForUser(currentUser.userId);
      final totalInteractions =
          userInsights['totalInteractions'] as int? ?? 0;

      List<Movie> recommendations;

      if (totalInteractions < 10) {
        // For new users: Use cached movies first
        final cachedMovies = await widget.movieService.filterCachedMovies(
          excludeIds: excludeIds,
          minRating: 6.0,
        );

        if (cachedMovies.length >= 20) {
          recommendations = widget.movieService.sortMoviesByQuality(
            cachedMovies.take(100).toList(),
          );
          debugPrint('Updated For You with ${recommendations.length} cached movies for new user');
        } else {
          // Fall back to API if not enough cached movies
          final availableMovies = await widget.movieService.findMoviesWithFilters(
            excludeIds: excludeIds,
            minRating: 6.0,
            targetCount: 200,
            maxPages: 50,
          );

          recommendations = widget.movieService.sortMoviesByQuality(
            availableMovies.take(100).toList(),
          );
        }
      } else {
        // For experienced users: Use cached movies first
      final topGenres = userInsights['topGenres'] as List<String>? ?? [];

        final cachedMovies = await widget.movieService.filterCachedMovies(
          selectedGenres:
              topGenres.isNotEmpty
                  ? topGenres.take(3).toList()
                  : null,
          excludeIds: excludeIds,
        );

        if (cachedMovies.length >= 20) {
          recommendations = await widget.recommendationService
              .getRecommendationsForUser(
                cachedMovies,
                currentUser.userId,
                limit: 100,
              );
          debugPrint('Updated For You with ${recommendations.length} cached movies for experienced user');
        } else {
          // Fall back to API if not enough cached movies
      final availableMovies = await widget.movieService.findMoviesWithFilters(
        selectedGenres:
            topGenres.isNotEmpty
                ? topGenres.take(3).toList()
                    : null,
        excludeIds: excludeIds,
            targetCount: 200,
            maxPages: 500,
      );

          recommendations = await widget.recommendationService
          .getRecommendationsForUser(
            availableMovies,
            currentUser.userId,
            limit: 100,
          );
        }
      }

      setState(() {
        filteredQueue = recommendations; // Update filteredQueue with new recommendations
      });

      debugPrint(
        'Updated For You queue with ${recommendations.length} movies for user: ${currentUser.name} (${totalInteractions < 10 ? 'popular' : 'personalized'})',
      );
    } catch (e) {
      debugPrint('Error updating For You queue: $e');
    }
  }

  // Fix the For You queue method to use in-memory state consistently
  void _ensureForYouQueueHasCards() {
    setState(() {
      // Use the same BLACKLIST logic as the trending queue for consistency
      final availableMovies = filteredQueue.where((movie) {
        // CRITICAL: Check against current in-memory state first
        final isWatched = watchedMovieIds.contains(movie.id);
        final isSkipped = notInterestedMovieIds.contains(movie.id);
        final isBookmarked = bookmarkedMovieIds.contains(movie.id);
        
        // Check if already in any queue
        final isInTrending = trendingCardQueue.any((queueMovie) => queueMovie.id == movie.id);
        final isInForYou = forYouCardQueue.any((queueMovie) => queueMovie.id == movie.id);
        
        // FIRST: Exclude movies already in either queue to prevent duplicates
        if (isInTrending || isInForYou) {
          debugPrint('🚫 [ForYou] Excluding movie already in queue: ${movie.title}');
          return false;
        }
        
        // SECOND: BLACKLIST ALL INTERACTED MOVIES - once you interact, it's gone forever
        if (isWatched) {
          debugPrint('🚫 [ForYou] BLACKLISTED watched movie: ${movie.title}');
          return false;
        }
        if (isSkipped) {
          debugPrint('🚫 [ForYou] BLACKLISTED skipped movie: ${movie.title}');
          return false;
        }
        if (isBookmarked) {
          debugPrint('🚫 [ForYou] BLACKLISTED bookmarked movie: ${movie.title}');
          return false;
        }
        
        // THIRD: Only show movies with NO interactions
        debugPrint('✅ [ForYou] Including fresh movie in queue: ${movie.title}');
        return true;
      }).toList();

      // Add movies to fill the queue up to 10 cards
        final neededCards = 10 - forYouCardQueue.length;
      if (neededCards > 0 && availableMovies.isNotEmpty) {
          final cardsToAdd = availableMovies.take(neededCards).toList();
        debugPrint('🎬 [ForYou] Adding ${cardsToAdd.length} cards to For You queue');
          forYouCardQueue.insertAll(0, cardsToAdd); // Insert at the beginning (bottom of stack)
      } else if (neededCards > 0) {
        debugPrint('⚠️ [ForYou] No available movies to add to queue. Watched: ${watchedMovieIds.length}, Skipped: ${notInterestedMovieIds.length}, Bookmarked: ${bookmarkedMovieIds.length}, Total filtered: ${filteredQueue.length}');
    }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    // Check if user is anonymous to limit features
    final isAnonymousUser = widget.authService.isAnonymous;
    // Determine For You lock state
    final int totalInteractionsCount = watchedMovieIds.length + notInterestedMovieIds.length + bookmarkedMovieIds.length;
    final bool forYouLocked = isAnonymousUser || totalInteractionsCount < 50;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: currentView == HomePageView.main
          ? AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.secondary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                'MovieMuse',
                style: AppTypography.appBarTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.8),
                          AppColors.secondary.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                    labelStyle: AppTypography.tabLabel.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    unselectedLabelStyle: AppTypography.tabLabel.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                tabs: [
                  Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_up, size: 18),
                            const SizedBox(width: 6),
                            Text('Trending'),
                          ],
                ),
              ),
                  Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              forYouLocked ? Icons.lock : Icons.psychology,
                              size: 18,
                              color: forYouLocked ? Colors.white.withValues(alpha: 0.4) : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                      'For You',
                              style: TextStyle(
                                color: forYouLocked ? Colors.white.withValues(alpha: 0.4) : null,
                ),
              ),
            ],
                        ),
                      ),
                    ],
                    onTap: (index) {
                      if (index == 1 && forYouLocked) return;
                    },
                  ),
                ),
              ),
        leading: Builder(
                builder: (context) => Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: AppColors.primary,
                      size: 24,
                    ),
                onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                  ),
              ),
        ),
        actions: [
                // Person filter clear button
            if (selectedPerson != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.warning,
                        size: 20,
              ),
                    onPressed: () {
                setState(() {
                        selectedPerson = null;
                        selectedPersonType = null;
                });
                      widget.movieService.setPerson(null, null);
                      _applyFiltersInstantly();
              },
                    tooltip: 'Clear person filter',
            ),
                  ),
                
                // Filter button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: ((selectedGenres.isNotEmpty && !(selectedGenres.length == 1 && selectedGenres.first == 'All Genres')) || selectedLanguage != null || (selectedTimePeriod != null && selectedTimePeriod != 'All Years'))
                            ? AppColors.secondary.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ((selectedGenres.isNotEmpty && !(selectedGenres.length == 1 && selectedGenres.first == 'All Genres')) || selectedLanguage != null || (selectedTimePeriod != null && selectedTimePeriod != 'All Years'))
                          ? AppColors.secondary.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.black87,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (context) => FilterDialog(
                              movieService: widget.movieService,
                              initialGenres: selectedGenres,
                              initialLanguage: selectedLanguage,
                              initialTimePeriod: selectedTimePeriod,
                              initialPlatform: selectedPlatform,
                              onApply: (genres, language, timePeriod, platform) async {
                                setState(() {
                                  selectedGenres
                                    ..clear()
                                    ..addAll(genres);
                                  selectedLanguage = language;
                                  selectedTimePeriod = timePeriod;
                                  selectedPlatform = platform;
                                });
                                
                                // Track filter usage analytics
                                // Analytics tracking removed for production
                                
                                // Set filters in movieService
                            widget.movieService.resetFilters();
                                widget.movieService.setLanguage(language);
                                if (timePeriod != null) {
                                  final timePeriods = [
                                    {
                                      'label': 'All Years',
                                      'start': null,
                                      'end': null,
                                    },
                                    {
                                      'label': '2020-2024',
                                      'start': 2020,
                                      'end': 2024,
                                    },
                                    {
                                      'label': '2010-2019',
                                      'start': 2010,
                                      'end': 2019,
                                    },
                                    {
                                      'label': '2000-2009',
                                      'start': 2000,
                                      'end': 2009,
                                    },
                                    {
                                      'label': '1990-1999',
                                      'start': 1990,
                                      'end': 1999,
                              },
                                    {
                                      'label': '1980-1989',
                                      'start': 1980,
                                      'end': 1989,
                                    },
                                    {
                                      'label': '1970-1979',
                                      'start': 1970,
                                      'end': 1979,
                                    },
                                    {
                                      'label': 'Before 1970',
                                      'start': null,
                                      'end': 1969,
                                    },
                            ];
                                  final period = timePeriods.firstWhere(
                              (p) => p['label'] == timePeriod,
                                    orElse: () => timePeriods[0],
                            );
                                  if (period['start'] != null) {
                                    widget.movieService.setReleaseYear(period['start'] as int);
                          }
                            }
                          await _applyFiltersInstantly();
                        },
                      ),
                );
              },
                tooltip: 'Filter movies',
              ),
            ),
                
                // Refresh button removed
                
                // Account button
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.secondary.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.account_circle,
                      color: AppColors.primary,
                      size: 24,
                    ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthPage(
                      authService: widget.authService,
                            userDataService: widget.userDataService,
                      onAuthChanged: _handleAuthChanged,
                    ),
                  ),
                      ).then((_) => setState(() {}));
              },
              tooltip: 'Account',
                  ),
            ),
          ],
        )
          : null,
      drawer: AppDrawer(
        onShowWatched: isAnonymousUser ? () => _showSignUpPrompt('Watched movies are only available for registered users. Sign up to track your movie history!') : _showWatchedList,
        onShowBookmarked: isAnonymousUser ? () => _showSignUpPrompt('Bookmarks are only available for registered users. Sign up to save your favorite movies!') : _showBookmarkedList,
        onShowSearch: _showSearchPage,
        onShowFriends: isAnonymousUser ? () => _showSignUpPrompt('Social features are only available for registered users. Sign up to connect with friends!') : _showFriendsPage, // New: Friends callback
        onShowHelp: _showHelp,
        onShowPrivacySettings: _showPrivacySettings,
        onShowSettings: _showSettings, // New callback
        onShowSemanticSearch: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SemanticSearchPage()),
          );
        },
        isAnonymousUser: isAnonymousUser,
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (currentView == HomePageView.watched) {
              if (isAnonymousUser) {
                return _buildSignUpPromptScreen('Watched Movies', 'Track your movie history and rate the films you\'ve seen. Sign up to unlock this feature!');
              }
              return FutureBuilder<List<Movie>>(
                future: _fetchMyWatchedMovies(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: \\${snapshot.error}'));
                  }
                  final watchedMovies = snapshot.data ?? [];
                  if (watchedMovies.isEmpty) {
                    return Center(child: Text('No watched movies found', style: TextStyle(color: Colors.white70)));
                  }
                  
                  // Check if there are unrated movies (excluding skipped movies with rating = -1)
                  final unratedMovies = watchedMovies.where((m) => (movieRatings[m.id] ?? 0.0) == 0.0).toList();
                  
                  if (unratedMovies.isNotEmpty && !_skipAllPressed) {
                    // Show rating screen first
                    return RatingScreen(
                      moviesToRate: unratedMovies,
                      movieRatings: movieRatings,
                      onRatingChanged: (movieId, rating) {
                        // Update the rating without rebuilding the entire screen
                        movieRatings[movieId] = rating;
                        if (rating > 0) watchedMovieIds.add(movieId);
                        _lastWatchedCacheUpdate = 0;
                        
                        if (currentUserData != null) {
                          if (rating > 0) {
                            currentUserData!.movieRatings[movieId] = rating;
                          } else {
                            currentUserData!.movieRatings.remove(movieId);
                          }
                          widget.userDataService.setMovieRatingWithUserData(currentUserData!, movieId, rating);
                        }
                      },
                      onMovieTap: (movie) async {
                        final cast = await widget.movieService.fetchCast(movie.id);
                        if (!mounted) return;
                        await Navigator.push(
                          context,
                          AnimationUtils.createFadeSlideRoute(
                            MovieDetailsPage(
                              movie: movie,
                              cast: cast,
                              isBookmarked: bookmarkedMovieIds.contains(movie.id),
                              isWatched: watchedMovieIds.contains(movie.id),
                              currentRating: movieRatings[movie.id] ?? 0.0,
                              showRatingSystem: false,
                              selectedPlatform: selectedPlatform,
                              contextPool: forYouCardQueue.isNotEmpty ? List<Movie>.from(forYouCardQueue) : List<Movie>.from(filteredQueue),
                              allowWatchedAction: false,
                              onBookmark: () {
                                _toggleBookmark(movie.id);
                                Navigator.pop(context);
                              },
                              onMarkWatched: () {
                                _showRatingDialog(movie.id);
                                Navigator.pop(context);
                              },
                              onRatingChanged: (rating) {
                                _updateMovieRating(movie.id, rating);
                              },
                              onPersonTap: (personName, personType) {
                                Navigator.pop(context);
                                _filterByPerson(personName, personType);
                              },
                            ),
                          ),
                        );
                      },
                      onComplete: () {
                        // After rating is complete, show the watched list
                        setState(() {
                          // Force rebuild to show watched list
                          _userDataTimestamp = DateTime.now().millisecondsSinceEpoch;
                        });
                      },
                      onBackPressed: _showMainView,
                      onGoToWatched: () {
                        // Mark all unrated movies as needing rating again (do not set -1)
                        final unratedMovies = watchedMovies.where((m) => (movieRatings[m.id] ?? 0.0) == 0.0).toList();
                        for (final movie in unratedMovies) {
                          // Mark as skipped by setting a special rating value (e.g., -1)
                          movieRatings[movie.id] = -1.0;
                          if (currentUserData != null) {
                            currentUserData!.movieRatings[movie.id] = -1.0;
                            widget.userDataService.setMovieRatingWithUserData(currentUserData!, movie.id, -1.0);
                          }
                        }
                        
                        // Navigate directly to watched catalog by showing the watched list
                        setState(() {
                          // Force rebuild to show watched list immediately
                          _userDataTimestamp = DateTime.now().millisecondsSinceEpoch;
                          // Clear any unrated movies to force showing the watched catalog
                          // Keep movies to rate so they will re-prompt next visit
                          // Force the UI to show watched catalog instead of rating screen
                          currentView = HomePageView.watched;
                          // Force immediate rebuild to show watched list
                          _lastWatchedCacheUpdate = 0;
                          // Set flag to force showing watched list
                          _skipAllPressed = true;
                        });
                      },
                    );
                  }
                  
                  // Reset the skip all flag when showing watched list
                  if (_skipAllPressed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _skipAllPressed = false;
                      });
                    });
                  }
                  
                  // Show watched list if no unrated movies or after rating is complete
                  return WatchedListPage(
                    moviesToRate: watchedMovies.where((m) => (movieRatings[m.id] ?? 0.0) == 0.0).toList(),
                    ratedMovies: watchedMovies.where((m) => (movieRatings[m.id] ?? 0.0) > 0.0).toList(),
                    movieRatings: movieRatings,
                    onRatingChanged: (movieId, rating) {
                      // Update the rating without rebuilding the entire screen
                      movieRatings[movieId] = rating;
                      if (rating > 0) watchedMovieIds.add(movieId);
                      _lastWatchedCacheUpdate = 0;
                      
                      if (currentUserData != null) {
                        if (rating > 0) {
                          currentUserData!.movieRatings[movieId] = rating;
                        } else {
                          currentUserData!.movieRatings.remove(movieId);
                        }
                        widget.userDataService.setMovieRatingWithUserData(currentUserData!, movieId, rating);
                      }
                    },
                    onMovieTap: (movie) async {
                      final cast = await widget.movieService.fetchCast(movie.id);
                      if (!mounted) return;
                      await Navigator.push(
                        context,
                        AnimationUtils.createFadeSlideRoute(
                          MovieDetailsPage(
                            movie: movie,
                            cast: cast,
                            isBookmarked: bookmarkedMovieIds.contains(movie.id),
                            isWatched: watchedMovieIds.contains(movie.id),
                            currentRating: movieRatings[movie.id] ?? 0.0,
                            showRatingSystem: false,
                            selectedPlatform: selectedPlatform,
                            contextPool: forYouCardQueue.isNotEmpty ? List<Movie>.from(forYouCardQueue) : List<Movie>.from(filteredQueue),
                            allowWatchedAction: false,
                            onBookmark: () {
                              _toggleBookmark(movie.id);
                              Navigator.pop(context);
                            },
                            onMarkWatched: () {
                              _showRatingDialog(movie.id);
                              Navigator.pop(context);
                            },
                            onRatingChanged: (rating) {
                              _updateMovieRating(movie.id, rating);
                            },
                            onPersonTap: (personName, personType) {
                              Navigator.pop(context);
                              _filterByPerson(personName, personType);
                            },
                          ),
                        ),
                      );
                    },
                    onBackPressed: _showMainView,
                  );
                },
              );
            } else if (currentView == HomePageView.bookmarked) {
              if (isAnonymousUser) {
                return _buildSignUpPromptScreen('Bookmarked Movies', 'Save your favorite movies for later viewing. Sign up to unlock this feature!');
              }
              return FutureBuilder<List<Movie>>(
                future: _fetchMyBookmarkedMovies(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: \\${snapshot.error}'));
                  }
                  final bookmarkedMovies = snapshot.data ?? [];
                  if (bookmarkedMovies.isEmpty) {
                    return Center(child: Text('No bookmarked movies found', style: TextStyle(color: Colors.white70)));
                  }
                  return BookmarkedListPage(
                    bookmarkedMovies: bookmarkedMovies,
                    onRemoveBookmark: (movie) async {
                      _toggleBookmark(movie.id);
                    },
                    onMovieTap: (movie) async {
                      final cast = await widget.movieService.fetchCast(movie.id);
                      if (!mounted) return;
                      await Navigator.push(
                        context,
                        AnimationUtils.createFadeSlideRoute(
                          MovieDetailsPage(
                                movie: movie,
                                cast: cast,
                            isBookmarked: bookmarkedMovieIds.contains(movie.id),
                                isWatched: watchedMovieIds.contains(movie.id),
                                currentRating: movieRatings[movie.id] ?? 0.0,
                            showRatingSystem: false,
                            selectedPlatform: selectedPlatform,
                                contextPool: forYouCardQueue.isNotEmpty ? List<Movie>.from(forYouCardQueue) : List<Movie>.from(filteredQueue),
                                allowWatchedAction: true,
                                allowBookmarkAction: true,
                                onBookmark: () {
                                  _toggleBookmark(movie.id);
                                  Navigator.pop(context);
                                },
                                onMarkWatched: () {
                              _showRatingDialog(movie.id);
                                  Navigator.pop(context);
                                },
                                onRatingChanged: (rating) {
                                  _updateMovieRating(movie.id, rating);
                                },
                                onPersonTap: (personName, personType) {
                              Navigator.pop(context);
                                  _filterByPerson(personName, personType);
                                },
                              ),
                        ),
                      );
                    },
                    onBackPressed: _showMainView,
                  );
                },
              );
            } else if (currentView == HomePageView.search) {
              return SearchPage(
                movieService: widget.movieService,
                bookmarkedMovieIds: bookmarkedMovieIds,
                watchedMovieIds: watchedMovieIds,
                movieRatings: movieRatings,
                onMovieTap: (movie) async {
                  final cast = await widget.movieService.fetchCast(movie.id);
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    AnimationUtils.createFadeSlideRoute(
                      MovieDetailsPage(
                            movie: movie,
                            cast: cast,
                            isBookmarked: bookmarkedMovieIds.contains(movie.id),
                            isWatched: watchedMovieIds.contains(movie.id),
                            currentRating: movieRatings[movie.id] ?? 0.0,
                            showRatingSystem: true, // Keep rating system for search results
                            selectedPlatform: selectedPlatform, // NEW: Pass the selected platform filter
                            contextPool: forYouCardQueue.isNotEmpty ? List<Movie>.from(forYouCardQueue) : List<Movie>.from(filteredQueue),
                            allowWatchedAction: false,
                            onBookmark: () {
                              _toggleBookmark(movie.id);
                              Navigator.pop(context);
                            },
                            onMarkWatched: () {
                              _markWatched(movie.id);
                              Navigator.pop(context);
                            },
                            onRatingChanged: (rating) {
                              _updateMovieRating(movie.id, rating);
                            },
                            onPersonTap: (personName, personType) {
                              Navigator.pop(context); // Close details first
                              _filterByPerson(personName, personType);
                            },
                          ),
                    ),
                  );
                },
                onBookmark: (movieId) {
                  if (isAnonymousUser) {
                    _showSignUpPrompt('Bookmarks are only available for registered users. Sign up to save your favorite movies!');
                    return;
                  }
                  _toggleBookmark(movieId);
                },
                onMarkWatched: (movieId) {
                  if (isAnonymousUser) {
                    _showSignUpPrompt('Watched movies are only available for registered users. Sign up to track your movie history!');
                    return;
                  }
                  // Always show the rating dialog before marking as watched
                  _showRatingDialog(movieId);
                },
                onBackPressed: _showMainView,
              );
            } else {
              // Main movie picker view with tabs
              return TabBarView(
                key: ValueKey('tabbar-user-${currentUserData?.userId ?? ''}-$_userDataTimestamp'),
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Disable swiping between tabs
                children: [
                  // Trending Tab
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child:
                          isLoading
                              ? AnimatedLoadingIndicator(
                                message: selectedPerson != null
                                        ? 'Finding $selectedPersonType "$selectedPerson" in TMDB...'
                                        : selectedGenres.isNotEmpty ||
                                            selectedLanguage != null
                                        ? 'Searching TMDB catalog with filters...'
                                        : 'Loading movies from TMDB...',
                                subMessage: 'Direct API search in progress',
                                color: Colors.deepPurple,
                              )
                              : error != null
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      error!,
                                      style: AppTypography.movieDescription.copyWith(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _initializeApp,
                                      child: Text('Retry', style: AppTypography.buttonText),
                                    ),
                                  ],
                                ),
                              )
                              : showBookmarkedOnly
                              ? FutureBuilder<Widget>(
                                future: _buildBookmarkedMoviesList(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return snapshot.data ??
                                      Center(
                                        child: Text(
                                          'Error loading bookmarked movies',
                                          style: AppTypography.movieDescription.copyWith(color: Colors.red),
                                        ),
                                      );
                                },
                              )
                              : trendingCardQueue.isEmpty
                              ? isLoading
                                  ? const ShimmerCardStack() // Show shimmer when loading
                                  : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                        Text(
                                      'No movies available with current filters',
                                          style: AppTypography.movieDescription.copyWith(color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Filtered queue: ${filteredQueue.length} movies',
                                          style: AppTypography.metadataText.copyWith(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          selectedGenres.clear();
                                          selectedLanguage = null;
                                          selectedTimePeriod = 'All Years';
                                          selectedPerson = null;
                                          selectedPersonType = null;
                                        });
                                        widget.movieService.resetFilters();
                                        _applyFiltersInstantly();
                                      },
                                          child: Text('Reset Filters', style: AppTypography.buttonText),
                                    ),
                                  ],
                                ),
                              )
                              : Stack(
                                children: [
                                  ...List.generate(
                                    trendingCardQueue.length > 1
                                        ? trendingCardQueue.length - 1
                                        : 0,
                                    (index) {
                                      final movie = trendingCardQueue[index];
                                      return Positioned.fill(
                                        child: MovieCard(
                                          movie: movie,
                                          onMarkWatched: () {},
                                          onBookmark: () {},
                                          isBookmarked: bookmarkedMovieIds
                                              .contains(movie.id),
                                          isWatched: watchedMovieIds.contains(
                                            movie.id,
                                          ),
                                          movieService: widget.movieService,
                                        ),
                                      );
                                    },
                                  ),
                                  if (trendingCardQueue.isNotEmpty)
                                    Positioned.fill(
                                      child: SwipeableMovieCard(
                                        movie: trendingCardQueue.last,
                                        isTop: true,
                                        onSwipeLeft: _onSwipeLeft,
                                        onSwipeRight: _onSwipeRight,
                                        onSwipeDown: isAnonymousUser ? () => _showSignUpPrompt('Bookmarks are only available for registered users. Sign up to save your favorite movies!') : _onSwipeDown,
                                        onSwipeUp: _onSwipeUp,
                                        isBookmarked: bookmarkedMovieIds
                                            .contains(
                                              trendingCardQueue.last.id,
                                            ),
                                        isWatched: watchedMovieIds.contains(
                                          trendingCardQueue.last.id,
                                        ),
                                        movieService: widget.movieService,
                                      ),
                                    ),
                                  // Quality info indicator only (queue counter removed)
                                  if (_shouldShowQualityInfo())
                                    Positioned(
                                      bottom: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.black.withValues(alpha: 0.8),
                                              Colors.black.withValues(alpha: 0.6),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: _getQualityColor().withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                    _getQualityIcon(),
                                                color: _getQualityColor(),
                                                size: 14,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                                  Text(
                                                    _getQualityText(),
                                              style: AppTypography.metadataText.copyWith(
                                                      color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                    ),
                  ),
                  // For You Tab (disabled for anonymous users)
                  forYouLocked
                    ? _buildForYouLockedPlaceholder()
                    : _buildForYouStack(),
                ],
              );
            }
          },
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildForYouLockedPlaceholder() {
    return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(16),
                                child: Column(
          mainAxisSize: MainAxisSize.min,
                                  children: [
            Icon(Icons.lock, color: AppColors.secondary, size: 36),
            const SizedBox(height: 12),
                                    Text(
              'Unlock For You',
              style: AppTypography.movieTitle.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
                                        Text(
              'Swipe on 50 movies to personalize your recommendations.',
              style: AppTypography.movieDescription.copyWith(color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
          ],
        ),
      ),
    );
  }

  // Update the For You swipe handlers to record user-specific interactions
  void _onForYouSwipeLeft() {
    if (forYouCardQueue.isNotEmpty) {
      final movie = forYouCardQueue.last;
      debugPrint('👈 [ForYou] Swiping LEFT on: ${movie.title} (ID: ${movie.id})');
      
      setState(() {
        notInterestedMovieIds.add(movie.id);
        forYouCardQueue.removeLast();
        debugPrint('👈 [ForYou] Movie removed from queue. Queue size now: ${forYouCardQueue.length}');
        debugPrint('👈 [ForYou] Added to skipped list. Total skipped: ${notInterestedMovieIds.length}');
      });

      if (currentUserData != null) {
        currentUserData!.skippedMovieIds.add(movie.id);
      }

      // Ensure movie is cached immediately
      widget.movieService.addMovieToCache(movie);

      widget.userDataService.addSkippedMovie(movie.id);
      _recordUserInteraction(movie, 'skipped');
      // Analytics tracking removed for production

      _ensureForYouQueueHasCards();
      _updateForYouQueue();
    }
  }

  void _onForYouSwipeRight() {
    if (forYouCardQueue.isNotEmpty) {
      final movie = forYouCardQueue.last;
      debugPrint('👉 [ForYou] Swiping RIGHT on: ${movie.title} (ID: ${movie.id})');
      
      setState(() {
        watchedMovieIds.add(movie.id);
        forYouCardQueue.removeLast();
        debugPrint('👉 [ForYou] Movie removed from queue. Queue size now: ${forYouCardQueue.length}');
        debugPrint('👉 [ForYou] Added to watched list. Total watched: ${watchedMovieIds.length}');
      });
      
      if (currentUserData != null) {
        currentUserData!.watchedMovieIds.add(movie.id);
      }
      
      // Ensure movie is cached immediately so it shows up in watched list
      widget.movieService.addMovieToCache(movie);
      
      widget.userDataService.addWatchedMovie(movie.id);
      widget.userDataService.addWatchedMovie(movie.id);
      _recordUserInteraction(movie, 'watched');
      // Analytics tracking removed for production

      // Immediately update watched movies cache
      widget.movieService.filterCachedMovies().then((allCachedMovies) {
        if (mounted) {
          _updateWatchedMoviesCache(allCachedMovies);
        }
      });

      _ensureForYouQueueHasCards();
      _updateForYouQueue();
    }
  }

  void _onForYouSwipeUp() async {
    if (forYouCardQueue.isNotEmpty) {
      final movie = forYouCardQueue.last;
      final cast = await widget.movieService.fetchCast(movie.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        AnimationUtils.createFadeSlideRoute(
          MovieDetailsPage(
                movie: movie,
                cast: cast,
                isBookmarked: bookmarkedMovieIds.contains(movie.id),
                isWatched: watchedMovieIds.contains(movie.id),
                currentRating: movieRatings[movie.id] ?? 0.0,
                showRatingSystem: false, // No rating system for trending/for you movies
                selectedPlatform: selectedPlatform, // NEW: Pass the selected platform filter
                contextPool: forYouCardQueue.isNotEmpty ? List<Movie>.from(forYouCardQueue) : List<Movie>.from(filteredQueue),
                allowWatchedAction: false,
                showMatchBadge: true,
                onBookmark: () {
                  _toggleBookmark(movie.id);
                  Navigator.pop(context);
                },
                onMarkWatched: () {
                  _markWatched(movie.id);
                  Navigator.pop(context);
                },
                onRatingChanged: (rating) {
                  _updateMovieRating(movie.id, rating);
                },
                onPersonTap: (personName, personType) {
                  Navigator.pop(context);
                  _filterByPerson(personName, personType);
                },
              ),
        ),
      );
    }
  }

  void _onForYouSwipeDown() {
    if (forYouCardQueue.isNotEmpty) {
      final movie = forYouCardQueue.last;
      _toggleBookmark(movie.id);

      // Record bookmark interaction for recommendation learning with user ID
      if (bookmarkedMovieIds.contains(movie.id)) {
        _recordUserInteraction(movie, 'bookmarked');
      }

      // Analytics tracking removed for production

      setState(() {
        forYouCardQueue.removeLast();
      });
      _ensureForYouQueueHasCards();
      _updateForYouQueue();
    }
  }

  // Completely rewrite auth change handler with better data loading
  Future<void> _handleAuthChanged() async {
    debugPrint('🔄 Auth changed - starting comprehensive user data sync');
    
    // STEP 1: Clear everything immediately and show loading
      setState(() {
        watchedMovieIds.clear();
        bookmarkedMovieIds.clear();
        notInterestedMovieIds.clear();
        movieRatings.clear();
        trendingCardQueue.clear();
        forYouCardQueue.clear();
        filteredQueue.clear();
        currentUserData = null;
        currentUserName = null;
        isLoading = true;
      error = null;
      _watchedCacheLoaded = false; // Reset watched cache
      _lastWatchedCacheUpdate = 0; // Force cache refresh
      });

    // STEP 2: Clear all caches
      widget.recommendationService.clearUserPreferencesCache(null);
    widget.movieService.clearCacheForPrivacyChange();
    
    try {
      // STEP 3: Wait for auth state to stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      
      // STEP 4: Get current user and verify authentication
      final currentUser = widget.authService.currentUser;
      if (currentUser?.uid != null) {
        debugPrint('🔄 Loading data for authenticated user: ${currentUser?.uid}');
        debugPrint('   Email: ${currentUser?.email ?? "Anonymous"}');
        debugPrint('   Anonymous: ${currentUser?.isAnonymous ?? false}');
        
        // STEP 5: Force reload user data with retry mechanism
        UserData? loadedUserData;
        int attempts = 0;
        const maxAttempts = 5;
        
        while (attempts < maxAttempts && loadedUserData == null) {
          attempts++;
          debugPrint('🔄 Data loading attempt $attempts/$maxAttempts...');
          
          try {
            // Force re-initialization of the service
            await widget.userDataService.initialize();
            
            loadedUserData = await widget.userDataService.getCurrentUserData();
            
            // Verify the data is for the correct user
            if (loadedUserData.userId != currentUser!.uid) {
              debugPrint('⚠️ Data mismatch: expected ${currentUser.uid}, got ${loadedUserData.userId}');
              loadedUserData = null; // Force retry
              continue;
            }
            
            // Verify data integrity
            final isIntegrityValid = await widget.userDataService.verifyDataIntegrity(loadedUserData.userId);
            if (!isIntegrityValid) {
              debugPrint('⚠️ Data integrity check failed, but continuing with available data');
            }
            
          } catch (e) {
            debugPrint('⚠️ Data loading attempt $attempts failed: $e');
            if (attempts < maxAttempts) {
              await Future.delayed(Duration(milliseconds: 300 * attempts));
            }
          }
        }
        
        // STEP 6: Handle successful data loading
        if (loadedUserData != null) {
          debugPrint('✅ User data loaded successfully after $attempts attempts:');
          debugPrint('   User ID: ${loadedUserData.userId}');
          debugPrint('   Name: ${loadedUserData.name}');
          debugPrint('   Watched: ${loadedUserData.watchedMovieIds.length}');
          debugPrint('   Skipped: ${loadedUserData.skippedMovieIds.length}');
          debugPrint('   Bookmarked: ${loadedUserData.bookmarkedMovieIds.length}');
          debugPrint('   Ratings: ${loadedUserData.movieRatings.length}');
          
          // Use the proper _loadCurrentUserData method to ensure movies are fetched and cached
          await _loadCurrentUserData();
          } else {
          // STEP 7: Create fresh data as fallback
          debugPrint('❌ Failed to load user data after $maxAttempts attempts');
          debugPrint('🔄 Creating fresh user data as fallback...');
          
          final freshData = await widget.userDataService.createFreshUserData(
            currentUser!.uid, 
            name: currentUser.email ?? currentUser.displayName ?? 'User'
          );
          
            setState(() {
            currentUserData = freshData;
            currentUserName = freshData.name;
            _userDataTimestamp = DateTime.now().millisecondsSinceEpoch;
          });
        }
      } else {
        debugPrint('🔄 No authenticated user - using anonymous mode');
      }
      
      // STEP 8: Initialize app with clean state
      debugPrint('🔄 Initializing app with new user data');
      await _initializeApp();
      
      debugPrint('✅ Auth change handling complete');
      
    } catch (e) {
      debugPrint('❌ Critical error in _handleAuthChanged: $e');
              setState(() {
        isLoading = false;
        error = 'Failed to load user data: $e';
              });
            }
          }

  // Helper method to show a sign-up prompt
  void _showSignUpPrompt(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        action: SnackBarAction(
          label: 'Sign Up',
          onPressed: () {
            Navigator.pop(context); // Close the snackbar
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AuthPage(
                  authService: widget.authService,
                  userDataService: widget.userDataService,
                  onAuthChanged: _handleAuthChanged,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method to build a sign-up prompt screen
  Widget _buildSignUpPromptScreen(String title, String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_open_outlined,
              size: 80,
              color: Colors.white54,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.movieTitle.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                message,
                style: AppTypography.movieDescription.copyWith(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthPage(
                      authService: widget.authService,
                      userDataService: widget.userDataService,
                      onAuthChanged: _handleAuthChanged,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Sign Up Now'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Return to main app
              },
              child: const Text(
                'Maybe Later',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build a sign-up prompt tab
  Widget _buildSignUpPromptTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_open_outlined,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          Text(
            'For You',
            style: AppTypography.tabLabel.copyWith(color: Colors.white38),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommendations are only available for registered users.',
            style: AppTypography.movieDescription.copyWith(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AuthPage(
                    authService: widget.authService,
                    userDataService: widget.userDataService,
                    onAuthChanged: _handleAuthChanged,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Sign Up Now'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Return to main app
            },
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced watched movies cache update with better filtering
  Future<void> _updateWatchedMoviesCache(List<Movie> allCachedMovies) async {
    debugPrint('🔄 Updating watched movies cache...');
    debugPrint('   Total cached movies: ${allCachedMovies.length}');
    debugPrint('   Watched movie IDs: ${watchedMovieIds.length}');
    debugPrint('   Movie ratings: ${movieRatings.length}');
    
    // Find all watched movies (regardless of rating or bookmark status)
    final allWatchedMovies = allCachedMovies
        .where((movie) => watchedMovieIds.contains(movie.id))
        .toList();
    
    debugPrint('   Found ${allWatchedMovies.length} watched movies in cache');
    
    // Check if we're missing any watched movies from the cache
    final foundIds = allWatchedMovies.map((m) => m.id).toSet();
    final missingIds = watchedMovieIds.difference(foundIds);
    
    if (missingIds.isNotEmpty) {
      debugPrint('⚠️ Missing ${missingIds.length} watched movies from cache');
      debugPrint('   Missing movie IDs: ${missingIds.take(10).toList()}${missingIds.length > 10 ? '...' : ''}');
      
      // Fetch missing movies from API and wait for completion
      await _fetchMissingWatchedMovies(missingIds);
      
      // Get updated cache after fetching missing movies
      final updatedCachedMovies = await widget.movieService.filterCachedMovies();
      final updatedWatchedMovies = updatedCachedMovies
          .where((movie) => watchedMovieIds.contains(movie.id))
          .toList();
      
      debugPrint('   After fetching: Found ${updatedWatchedMovies.length} watched movies in cache');
      
      // Update the cache with the complete list
      _cachedMoviesToRate = updatedWatchedMovies
          .where((movie) => (movieRatings[movie.id] ?? 0.0) == 0.0)
          .toList();
      
      _cachedRatedMovies = updatedWatchedMovies
          .where((movie) => (movieRatings[movie.id] ?? 0.0) > 0.0)
          .toList();
      
      debugPrint('   Updated cache after fetching:');
      debugPrint('     Movies to rate: ${_cachedMoviesToRate.length}');
      debugPrint('     Rated movies: ${_cachedRatedMovies.length}');
        } else {
      // No missing movies, use the current cache
      _cachedMoviesToRate = allWatchedMovies
          .where((movie) => (movieRatings[movie.id] ?? 0.0) == 0.0)
          .toList();
      
      _cachedRatedMovies = allWatchedMovies
          .where((movie) => (movieRatings[movie.id] ?? 0.0) > 0.0)
          .toList();
    }
    
    _lastWatchedCacheUpdate = DateTime.now().millisecondsSinceEpoch;
    
    debugPrint('📊 [Cache] Updated watched movies cache:');
    debugPrint('   Movies to rate: ${_cachedMoviesToRate.length}');
    debugPrint('   Rated movies: ${_cachedRatedMovies.length}');
    debugPrint('   Total watched movies: ${_cachedMoviesToRate.length + _cachedRatedMovies.length}');
    
    // Verify data integrity
    if (watchedMovieIds.length != (_cachedMoviesToRate.length + _cachedRatedMovies.length)) {
      debugPrint('⚠️ Data mismatch detected:');
      debugPrint('   Expected watched movies: ${watchedMovieIds.length}');
      debugPrint('   Found in cache: ${_cachedMoviesToRate.length + _cachedRatedMovies.length}');
      debugPrint('   Missing movies: ${watchedMovieIds.length - (_cachedMoviesToRate.length + _cachedRatedMovies.length)}');
    }
    
    // Force UI rebuild
    if (mounted) {
          setState(() {
        // Force rebuild by updating timestamp
        _userDataTimestamp = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  /// Fetch missing watched movies from API
  Future<void> _fetchMissingWatchedMovies(Set<int> missingIds) async {
    try {
      debugPrint('🔄 Fetching ${missingIds.length} missing watched movies from API...');
      
      // PARALLEL FETCHING: Fetch all movies simultaneously instead of sequentially
      final futures = missingIds.map((movieId) => widget.movieService.fetchMovieById(movieId));
      final results = await Future.wait(futures);
      
      // Process results and add successful fetches to cache
      final fetchedMovies = <Movie>[];
      int successCount = 0;
      
      for (int i = 0; i < results.length; i++) {
        final movie = results[i];
        if (movie != null) {
          fetchedMovies.add(movie);
          successCount++;
          debugPrint('✅ Fetched movie: ${movie.title} (ID: ${missingIds.elementAt(i)})');
      } else {
          debugPrint('❌ Failed to fetch movie ${missingIds.elementAt(i)}');
        }
      }
      
      debugPrint('✅ Successfully fetched $successCount out of ${missingIds.length} missing movies in parallel');
      
      // Add fetched movies to cache
      if (fetchedMovies.isNotEmpty) {
        debugPrint('🔄 Adding ${fetchedMovies.length} movies to cache...');
        for (final movie in fetchedMovies) {
          widget.movieService.addMovieToCache(movie);
        }
        debugPrint('✅ Movies added to cache successfully');
      }
      
    } catch (e) {
      debugPrint('❌ Error fetching missing watched movies: $e');
    }
  }

  Future<List<Movie>> _fetchMyWatchedMovies() async {
    // 1. Get current user data from Firestore
    final myData = await widget.userDataService.getCurrentUserData();
    if (myData == null) return [];
    final watchedIds = myData.watchedMovieIds;
    // 2. Fetch all watched movies directly from API (not just cache)
    final futures = watchedIds.map((movieId) => widget.movieService.fetchMovieById(movieId));
    final results = await Future.wait(futures);
    // 3. Filter successful results
    final watchedMovies = <Movie>[];
    for (final movie in results) {
      if (movie != null) watchedMovies.add(movie);
    }
    return watchedMovies;
  }

  Future<List<Movie>> _fetchMyBookmarkedMovies() async {
    // 1. Get current user data from Firestore
    final myData = await widget.userDataService.getCurrentUserData();
    if (myData == null) return [];
    final bookmarkedIds = myData.bookmarkedMovieIds;
    // 2. Fetch all bookmarked movies directly from API (not just cache)
    final futures = bookmarkedIds.map((movieId) => widget.movieService.fetchMovieById(movieId));
    final results = await Future.wait(futures);
    // 3. Filter successful results
    final bookmarkedMovies = <Movie>[];
    for (final movie in results) {
      if (movie != null) bookmarkedMovies.add(movie);
    }
    return bookmarkedMovies;
  }

  // Add the _showRatingDialog method if not present:
  void _showRatingDialog(int movieId) {
    showDialog(
      context: context,
      builder: (context) {
        double selectedRating = 0.0;
        return AlertDialog(
          title: const Text('Rate this movie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you rate this movie?'),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) {
                  return Slider(
                    value: selectedRating,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: selectedRating == 0 ? 'Unrated' : selectedRating.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        selectedRating = value;
                      });
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _markWatchedWithRating(movieId, selectedRating);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildForYouStack() {
    return Stack(
      children: [
        ...List.generate(
          forYouCardQueue.length > 1 ? forYouCardQueue.length - 1 : 0,
          (index) {
            final movie = forYouCardQueue[index];
            return Positioned.fill(
              child: MovieCard(
                movie: movie,
                onMarkWatched: () {},
                onBookmark: () {},
                isBookmarked: bookmarkedMovieIds.contains(movie.id),
                isWatched: watchedMovieIds.contains(movie.id),
                movieService: widget.movieService,
                rating: movieRatings[movie.id] ?? 0.0,
                recommendedBy: movieRecommenders[movie.id],
              ),
            );
          },
        ),
        if (forYouCardQueue.isNotEmpty)
          Positioned.fill(
            child: SwipeableMovieCard(
              movie: forYouCardQueue.last,
              isTop: true,
              onSwipeLeft: _onForYouSwipeLeft,
              onSwipeRight: _onForYouSwipeRight,
              onSwipeDown: _onForYouSwipeDown,
              onSwipeUp: _onForYouSwipeUp,
              isBookmarked: bookmarkedMovieIds.contains(forYouCardQueue.last.id),
              isWatched: watchedMovieIds.contains(forYouCardQueue.last.id),
              movieService: widget.movieService,
              rating: movieRatings[forYouCardQueue.last.id] ?? 0.0,
              recommendedBy: movieRecommenders[forYouCardQueue.last.id],
            ),
          ),
      ],
    );
  }
}
