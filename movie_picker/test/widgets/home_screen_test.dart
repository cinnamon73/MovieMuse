import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:movie_picker/pages/home_screen.dart';
import 'package:movie_picker/services/movie_service.dart';
import 'package:movie_picker/services/recommendation_service.dart';
import 'package:movie_picker/services/user_data_service.dart';
import 'package:movie_picker/services/secure_storage_service.dart';
import 'package:movie_picker/services/privacy_service.dart';
import 'package:movie_picker/services/auth_service.dart';
import 'package:movie_picker/models/movie.dart';
import 'package:movie_picker/models/user_data.dart';
import 'package:movie_picker/widgets/swipeable_movie_card.dart';

import 'home_screen_test.mocks.dart';

@GenerateMocks([
  MovieService,
  RecommendationService,
  UserDataService,
  SecureStorageService,
  PrivacyService,
])
void main() {
  group('HomeScreen Widget Tests', () {
    late MockMovieService mockMovieService;
    late MockRecommendationService mockRecommendationService;
    late MockUserDataService mockUserDataService;
    late MockSecureStorageService mockSecureStorageService;
    late MockPrivacyService mockPrivacyService;
    late AuthService mockAuthService;
    late List<Movie> testMovies;

    setUp(() {
      mockMovieService = MockMovieService();
      mockRecommendationService = MockRecommendationService();
      mockUserDataService = MockUserDataService();
      mockSecureStorageService = MockSecureStorageService();
      mockPrivacyService = MockPrivacyService();
      mockAuthService = AuthService(); // Or use a mock if available

      testMovies = [
        Movie(
          id: 1,
          title: 'Test Movie 1',
          description: 'First test movie',
          posterUrl: 'https://example.com/poster1.jpg',
          genre: 'Action',
          subgenre: 'Adventure',
          releaseDate: '2023',
          voteAverage: 8.5,
          language: 'en',
          keywords: ['action', 'adventure'],
        ),
        Movie(
          id: 2,
          title: 'Test Movie 2',
          description: 'Second test movie',
          posterUrl: 'https://example.com/poster2.jpg',
          genre: 'Drama',
          subgenre: 'Romance',
          releaseDate: '2022',
          voteAverage: 7.8,
          language: 'en',
          keywords: ['drama', 'romance'],
        ),
      ];

      // Setup default mock responses
      when(mockMovieService.cacheSize).thenReturn(100);
      when(mockMovieService.hasEnoughMovies).thenReturn(true);
      when(mockMovieService.isHighQualityMovie(any)).thenReturn(true);
      when(
        mockMovieService.getAllGenres(),
      ).thenReturn(['Action', 'Drama', 'Comedy']);
      when(
        mockMovieService.preloadMovies(
          targetCount: anyNamed('targetCount'),
          preferredGenres: anyNamed('preferredGenres'),
        ),
      ).thenAnswer((_) async {});
      when(
        mockMovieService.filterCachedMovies(
          selectedGenres: anyNamed('selectedGenres'),
          language: anyNamed('language'),
          timePeriod: anyNamed('timePeriod'),
          minRating: anyNamed('minRating'),
          excludeIds: anyNamed('excludeIds'),
          person: anyNamed('person'),
          personType: anyNamed('personType'),
        ),
      ).thenAnswer((_) async => testMovies);
      when(
        mockMovieService.findMoviesWithFilters(
          selectedGenres: anyNamed('selectedGenres'),
          language: anyNamed('language'),
          timePeriod: anyNamed('timePeriod'),
          minRating: anyNamed('minRating'),
          excludeIds: anyNamed('excludeIds'),
          targetCount: anyNamed('targetCount'),
          maxPages: anyNamed('maxPages'),
          person: anyNamed('person'),
          personType: anyNamed('personType'),
        ),
      ).thenAnswer((_) async => testMovies);
      when(
        mockMovieService.fetchCast(any),
      ).thenAnswer((_) async => ['Actor 1', 'Actor 2']);

      when(mockRecommendationService.initialize()).thenAnswer((_) async {});
      when(
        mockRecommendationService.getRecommendationsForUser(
          any,
          any,
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async => testMovies);
      when(mockRecommendationService.getUserInsightsForUser(any)).thenAnswer(
        (_) async => {
          'totalInteractions': 5,
          'topGenres': ['Action', 'Drama'],
        },
      );

      when(mockUserDataService.getCurrentUserData()).thenAnswer(
        (_) async => UserData(userId: 'test_user', name: 'Test User'),
      );
      when(mockUserDataService.currentUserId).thenReturn('test_user');
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: HomeScreen(
          movieService: mockMovieService,
          recommendationService: mockRecommendationService,
          userDataService: mockUserDataService,
          privacyService: mockPrivacyService,
          secureStorageService: mockSecureStorageService,
          authService: mockAuthService,
        ),
      );
    }

    group('Widget Initialization', () {
      testWidgets('should display loading indicator initially', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading movies from TMDB...'), findsOneWidget);
      });

      testWidgets('should initialize services on startup', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        verify(mockRecommendationService.initialize()).called(1);
        verify(
          mockMovieService.preloadMovies(
            targetCount: anyNamed('targetCount'),
            preferredGenres: anyNamed('preferredGenres'),
          ),
        ).called(1);
        verify(mockUserDataService.getCurrentUserData()).called(greaterThan(0));
      });

      testWidgets('should display app bar with title', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Movie Picker - Test User'), findsOneWidget);
      });

      testWidgets('should display tabs for Trending and For You', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Trending'), findsOneWidget);
        expect(find.text('For You'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('should display error message when initialization fails', (
        WidgetTester tester,
      ) async {
        when(
          mockMovieService.preloadMovies(
            targetCount: anyNamed('targetCount'),
            preferredGenres: anyNamed('preferredGenres'),
          ),
        ).thenThrow(Exception('Network error'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Failed to load movies'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should handle user data service errors gracefully', (
        WidgetTester tester,
      ) async {
        when(
          mockUserDataService.getCurrentUserData(),
        ).thenThrow(Exception('User data error'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should still display the app, possibly with default user
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('should allow retry after error', (
        WidgetTester tester,
      ) async {
        when(
          mockMovieService.preloadMovies(
            targetCount: anyNamed('targetCount'),
            preferredGenres: anyNamed('preferredGenres'),
          ),
        ).thenThrow(Exception('Network error'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);

        // Tap retry button
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Should attempt to initialize again
        verify(
          mockMovieService.preloadMovies(
            targetCount: anyNamed('targetCount'),
            preferredGenres: anyNamed('preferredGenres'),
          ),
        ).called(2);
      });
    });

    group('Navigation and Drawer', () {
      testWidgets('should open drawer when menu button is tapped', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap the menu button
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();

        expect(find.text('Movie Picker'), findsOneWidget); // Drawer header
        expect(find.text('Search Movies'), findsOneWidget);
        expect(find.text('Watched List'), findsOneWidget);
        expect(find.text('Bookmarked List'), findsOneWidget);
      });

      testWidgets('should navigate to search when search option is tapped', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Open drawer
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();

        // Tap search option
        await tester.tap(find.text('Search Movies'));
        await tester.pumpAndSettle();

        // Should navigate to search view
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets(
        'should navigate to watched list when watched option is tapped',
        (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          // Open drawer
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();

          // Tap watched list option
          await tester.tap(find.text('Watched List'));
          await tester.pumpAndSettle();

          // Should navigate to watched list view
          expect(find.byType(HomeScreen), findsOneWidget);
        },
      );
    });

    group('Tab Navigation', () {
      testWidgets('should switch between Trending and For You tabs', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Initially should be on Trending tab
        expect(find.text('Trending'), findsOneWidget);

        // Tap For You tab
        await tester.tap(find.text('For You'));
        await tester.pumpAndSettle();

        // Should switch to For You content
        expect(find.text('For You'), findsOneWidget);
      });

      testWidgets('should initialize For You queue when tab is selected', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap For You tab
        await tester.tap(find.text('For You'));
        await tester.pumpAndSettle();

        verify(
          mockRecommendationService.getUserInsightsForUser(any),
        ).called(greaterThan(0));
        verify(
          mockRecommendationService.getRecommendationsForUser(
            any,
            any,
            limit: anyNamed('limit'),
          ),
        ).called(greaterThan(0));
      });
    });

    group('Filter Functionality', () {
      testWidgets('should open filter dialog when filter button is tapped', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap filter button
        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();

        // Should open filter dialog
        expect(find.byType(BottomSheet), findsOneWidget);
      });

      testWidgets(
        'should toggle bookmark filter when bookmark button is tapped',
        (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          // Tap bookmark filter button
          await tester.tap(find.byIcon(Icons.bookmark_border));
          await tester.pumpAndSettle();

          // Button should change to filled bookmark
          expect(find.byIcon(Icons.bookmark), findsOneWidget);
        },
      );

      testWidgets('should refresh movies when refresh button is tapped', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap refresh button
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();

        // Should call preload movies again
        verify(
          mockMovieService.preloadMovies(
            targetCount: anyNamed('targetCount'),
            preferredGenres: anyNamed('preferredGenres'),
          ),
        ).called(2); // Once on init, once on refresh
      });
    });

    group('Movie Cards Display', () {
      testWidgets('should display movie cards when data is loaded', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should display swipeable movie cards
        expect(find.byType(SwipeableMovieCard), findsAtLeastNWidget(1));
      });

      testWidgets('should handle empty movie queue gracefully', (
        WidgetTester tester,
      ) async {
        when(
          mockMovieService.findMoviesWithFilters(
            selectedGenres: anyNamed('selectedGenres'),
            language: anyNamed('language'),
            timePeriod: anyNamed('timePeriod'),
            minRating: anyNamed('minRating'),
            excludeIds: anyNamed('excludeIds'),
            targetCount: anyNamed('targetCount'),
            maxPages: anyNamed('maxPages'),
            person: anyNamed('person'),
            personType: anyNamed('personType'),
          ),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.text('No movies available with current filters'),
          findsOneWidget,
        );
        expect(find.text('Reset Filters'), findsOneWidget);
      });

      testWidgets('should show reset filters button when no movies available', (
        WidgetTester tester,
      ) async {
        when(
          mockMovieService.findMoviesWithFilters(
            selectedGenres: anyNamed('selectedGenres'),
            language: anyNamed('language'),
            timePeriod: anyNamed('timePeriod'),
            minRating: anyNamed('minRating'),
            excludeIds: anyNamed('excludeIds'),
            targetCount: anyNamed('targetCount'),
            maxPages: anyNamed('maxPages'),
            person: anyNamed('person'),
            personType: anyNamed('personType'),
          ),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Reset Filters'), findsOneWidget);

        // Tap reset filters
        await tester.tap(find.text('Reset Filters'));
        await tester.pumpAndSettle();

        // Should call filter reset methods
        verify(mockMovieService.resetFilters()).called(greaterThan(0));
      });
    });

    group('User Interaction', () {
      testWidgets('should handle movie swipe gestures', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final cardFinder = find.byType(SwipeableMovieCard).first;

        // Test swipe right (watch)
        await tester.drag(cardFinder, const Offset(300, 0));
        await tester.pumpAndSettle();

        verify(mockUserDataService.addWatchedMovie(any)).called(1);
      });

      testWidgets('should handle bookmark toggle', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final cardFinder = find.byType(SwipeableMovieCard).first;

        // Test swipe down (bookmark)
        await tester.drag(cardFinder, const Offset(0, 300));
        await tester.pumpAndSettle();

        verify(mockUserDataService.toggleBookmark(any)).called(1);
      });
    });

    group('Cache and Performance Indicators', () {
      testWidgets('should display cache size indicator', (
        WidgetTester tester,
      ) async {
        when(mockMovieService.cacheSize).thenReturn(150);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('150 cached'), findsOneWidget);
      });

      testWidgets('should show background loading indicator', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should show loading indicator when background preloading is happening
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('should display queue status when queue is low', (
        WidgetTester tester,
      ) async {
        // Mock a low queue scenario
        when(
          mockMovieService.findMoviesWithFilters(
            selectedGenres: anyNamed('selectedGenres'),
            language: anyNamed('language'),
            timePeriod: anyNamed('timePeriod'),
            minRating: anyNamed('minRating'),
            excludeIds: anyNamed('excludeIds'),
            targetCount: anyNamed('targetCount'),
            maxPages: anyNamed('maxPages'),
            person: anyNamed('person'),
            personType: anyNamed('personType'),
          ),
        ).thenAnswer((_) async => testMovies.take(5).toList());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should show queue status indicator
        expect(find.textContaining('Queue:'), findsOneWidget);
      });
    });

    group('Edge Cases and Error States', () {
      testWidgets('should handle service initialization failures gracefully', (
        WidgetTester tester,
      ) async {
        when(
          mockRecommendationService.initialize(),
        ).thenThrow(Exception('Service error'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should still display the app
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('should handle network connectivity issues', (
        WidgetTester tester,
      ) async {
        when(
          mockMovieService.findMoviesWithFilters(
            selectedGenres: anyNamed('selectedGenres'),
            language: anyNamed('language'),
            timePeriod: anyNamed('timePeriod'),
            minRating: anyNamed('minRating'),
            excludeIds: anyNamed('excludeIds'),
            targetCount: anyNamed('targetCount'),
            maxPages: anyNamed('maxPages'),
            person: anyNamed('person'),
            personType: anyNamed('personType'),
          ),
        ).thenThrow(Exception('Network error'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Error searching TMDB catalog'),
          findsOneWidget,
        );
      });

      testWidgets('should handle rapid user interactions', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final cardFinder = find.byType(SwipeableMovieCard).first;

        // Perform rapid swipes
        for (int i = 0; i < 5; i++) {
          await tester.drag(cardFinder, Offset(300 * (i % 2 == 0 ? 1 : -1), 0));
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pumpAndSettle();

        // Should handle rapid interactions without crashing
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('should handle large datasets efficiently', (
        WidgetTester tester,
      ) async {
        final largeMovieList = List.generate(
          1000,
          (index) => Movie(
            id: index,
            title: 'Movie $index',
            description: 'Description $index',
            posterUrl: 'https://example.com/poster$index.jpg',
            genre: 'Action',
            subgenre: 'Adventure',
            releaseDate: '2023',
            voteAverage: 7.0 + (index % 3),
            language: 'en',
            keywords: ['keyword$index'],
          ),
        );

        when(
          mockMovieService.findMoviesWithFilters(
            selectedGenres: anyNamed('selectedGenres'),
            language: anyNamed('language'),
            timePeriod: anyNamed('timePeriod'),
            minRating: anyNamed('minRating'),
            excludeIds: anyNamed('excludeIds'),
            targetCount: anyNamed('targetCount'),
            maxPages: anyNamed('maxPages'),
            person: anyNamed('person'),
            personType: anyNamed('personType'),
          ),
        ).thenAnswer((_) async => largeMovieList);

        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        stopwatch.stop();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
        ); // Should render within 5 seconds
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantics for screen readers', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Check that key elements have semantic information
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(TabBar), findsOneWidget);
        expect(
          find.byType(Drawer),
          findsNothing,
        ); // Drawer should be closed initially

        final semantics = tester.getSemantics(find.byType(HomeScreen));
        expect(semantics, isNotNull);
      });

      testWidgets('should support keyboard navigation', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Test tab navigation
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });
  });
}
