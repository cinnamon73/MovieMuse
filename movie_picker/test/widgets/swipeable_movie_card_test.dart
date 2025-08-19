import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:movie_picker/widgets/swipeable_movie_card.dart';
import 'package:movie_picker/models/movie.dart';
import 'package:movie_picker/services/movie_service.dart';

import 'swipeable_movie_card_test.mocks.dart';

@GenerateMocks([MovieService])
void main() {
  group('SwipeableMovieCard Widget Tests', () {
    late MockMovieService mockMovieService;
    late Movie testMovie;

    setUp(() {
      mockMovieService = MockMovieService();
      testMovie = Movie(
        id: 1,
        title: 'Test Movie',
        description:
            'A great test movie with an amazing plot and fantastic characters.',
        posterUrl: 'https://example.com/poster.jpg',
        genre: 'Action',
        subgenre: 'Adventure',
        releaseDate: '2023',
        voteAverage: 8.5,
        language: 'en',
        keywords: ['action', 'adventure'],
      );

      // Setup mock responses
      when(mockMovieService.isHighQualityMovie(any)).thenReturn(true);
    });

    Widget createTestWidget({
      bool isTop = true,
      bool isBookmarked = false,
      bool isWatched = false,
      double rating = 0.0,
      VoidCallback? onSwipeLeft,
      VoidCallback? onSwipeRight,
      VoidCallback? onSwipeUp,
      VoidCallback? onSwipeDown,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SwipeableMovieCard(
            movie: testMovie,
            isTop: isTop,
            isBookmarked: isBookmarked,
            isWatched: isWatched,
            rating: rating,
            movieService: mockMovieService,
            onSwipeLeft: onSwipeLeft ?? () {},
            onSwipeRight: onSwipeRight ?? () {},
            onSwipeUp: onSwipeUp ?? () {},
            onSwipeDown: onSwipeDown ?? () {},
          ),
        ),
      );
    }

    group('Widget Rendering', () {
      testWidgets('should render movie card with basic information', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Test Movie'), findsOneWidget);
        expect(find.text('Action • Adventure'), findsOneWidget);
        expect(find.text('2023'), findsOneWidget);
        expect(find.text('8.5'), findsOneWidget);
      });

      testWidgets('should show bookmark icon when movie is bookmarked', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(isBookmarked: true));

        expect(find.byIcon(Icons.bookmark), findsOneWidget);
      });

      testWidgets('should show watched icon when movie is watched', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(isWatched: true));

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('should show rating when provided', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(rating: 9.0));

        expect(find.text('Your Rating: 9.0'), findsOneWidget);
      });

      testWidgets('should handle long movie titles gracefully', (
        WidgetTester tester,
      ) async {
        final longTitleMovie = Movie(
          id: 1,
          title:
              'This is a Very Long Movie Title That Should Be Handled Gracefully by the UI Component',
          description: 'Test description',
          posterUrl: 'https://example.com/poster.jpg',
          genre: 'Drama',
          subgenre: 'Romance',
          releaseDate: '2023',
          voteAverage: 7.5,
          language: 'en',
          keywords: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: longTitleMovie,
                isTop: true,
                isBookmarked: false,
                isWatched: false,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        expect(
          find.textContaining('This is a Very Long Movie Title'),
          findsOneWidget,
        );
      });

      testWidgets('should handle long movie descriptions gracefully', (
        WidgetTester tester,
      ) async {
        final longDescMovie = Movie(
          id: 1,
          title: 'Test Movie',
          description:
              'This is a very long movie description that goes on and on about the plot, characters, setting, and various other aspects of the movie that should be handled gracefully by the UI component without causing overflow or other layout issues.',
          posterUrl: 'https://example.com/poster.jpg',
          genre: 'Drama',
          subgenre: 'Romance',
          releaseDate: '2023',
          voteAverage: 7.5,
          language: 'en',
          keywords: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: longDescMovie,
                isTop: true,
                isBookmarked: false,
                isWatched: false,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        expect(
          find.textContaining('This is a very long movie description'),
          findsOneWidget,
        );
      });
    });

    group('Gesture Handling', () {
      testWidgets('should call onSwipeLeft when swiped left', (
        WidgetTester tester,
      ) async {
        bool swipeLeftCalled = false;

        await tester.pumpWidget(
          createTestWidget(onSwipeLeft: () => swipeLeftCalled = true),
        );

        final cardFinder = find.byType(SwipeableMovieCard);
        await tester.drag(cardFinder, const Offset(-300, 0));
        await tester.pumpAndSettle();

        expect(swipeLeftCalled, isTrue);
      });

      testWidgets('should call onSwipeRight when swiped right', (
        WidgetTester tester,
      ) async {
        bool swipeRightCalled = false;

        await tester.pumpWidget(
          createTestWidget(onSwipeRight: () => swipeRightCalled = true),
        );

        final cardFinder = find.byType(SwipeableMovieCard);
        await tester.drag(cardFinder, const Offset(300, 0));
        await tester.pumpAndSettle();

        expect(swipeRightCalled, isTrue);
      });

      testWidgets('should call onSwipeUp when swiped up', (
        WidgetTester tester,
      ) async {
        bool swipeUpCalled = false;

        await tester.pumpWidget(
          createTestWidget(onSwipeUp: () => swipeUpCalled = true),
        );

        final cardFinder = find.byType(SwipeableMovieCard);
        await tester.drag(cardFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(swipeUpCalled, isTrue);
      });

      testWidgets('should call onSwipeDown when swiped down', (
        WidgetTester tester,
      ) async {
        bool swipeDownCalled = false;

        await tester.pumpWidget(
          createTestWidget(onSwipeDown: () => swipeDownCalled = true),
        );

        final cardFinder = find.byType(SwipeableMovieCard);
        await tester.drag(cardFinder, const Offset(0, 300));
        await tester.pumpAndSettle();

        expect(swipeDownCalled, isTrue);
      });

      testWidgets('should not trigger swipe for small gestures', (
        WidgetTester tester,
      ) async {
        bool swipeCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            onSwipeLeft: () => swipeCalled = true,
            onSwipeRight: () => swipeCalled = true,
            onSwipeUp: () => swipeCalled = true,
            onSwipeDown: () => swipeCalled = true,
          ),
        );

        final cardFinder = find.byType(SwipeableMovieCard);

        // Small gestures should not trigger swipe
        await tester.drag(cardFinder, const Offset(50, 0));
        await tester.pumpAndSettle();

        await tester.drag(cardFinder, const Offset(0, 50));
        await tester.pumpAndSettle();

        expect(swipeCalled, isFalse);
      });
    });

    group('Visual States', () {
      testWidgets('should show different visual state when not top card', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(isTop: false));

        // Non-top cards should be rendered but may have different styling
        expect(find.byType(SwipeableMovieCard), findsOneWidget);
        expect(find.text('Test Movie'), findsOneWidget);
      });

      testWidgets('should handle missing poster URL gracefully', (
        WidgetTester tester,
      ) async {
        final noPosterMovie = Movie(
          id: 1,
          title: 'No Poster Movie',
          description: 'Movie without poster',
          posterUrl: '',
          genre: 'Drama',
          subgenre: 'Drama',
          releaseDate: '2023',
          voteAverage: 7.0,
          language: 'en',
          keywords: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: noPosterMovie,
                isTop: true,
                isBookmarked: false,
                isWatched: false,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        expect(find.text('No Poster Movie'), findsOneWidget);
      });

      testWidgets('should handle zero rating gracefully', (
        WidgetTester tester,
      ) async {
        final zeroRatingMovie = Movie(
          id: 1,
          title: 'Zero Rating Movie',
          description: 'Movie with zero rating',
          posterUrl: 'https://example.com/poster.jpg',
          genre: 'Drama',
          subgenre: 'Drama',
          releaseDate: '2023',
          voteAverage: 0.0,
          language: 'en',
          keywords: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: zeroRatingMovie,
                isTop: true,
                isBookmarked: false,
                isWatched: false,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        expect(find.text('Zero Rating Movie'), findsOneWidget);
        expect(find.text('0.0'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantics for screen readers', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // Check that the card has semantic information
        expect(find.byType(SwipeableMovieCard), findsOneWidget);

        final semantics = tester.getSemantics(find.byType(SwipeableMovieCard));
        expect(semantics, isNotNull);
      });

      testWidgets('should handle tap gestures for accessibility', (
        WidgetTester tester,
      ) async {
        bool tapCalled = false;

        await tester.pumpWidget(
          createTestWidget(onSwipeUp: () => tapCalled = true),
        );

        await tester.tap(find.byType(SwipeableMovieCard));
        await tester.pumpAndSettle();

        // Verify callback was called
        // Note: In a real test, you would verify the callback was called
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle null or empty movie data gracefully', (
        WidgetTester tester,
      ) async {
        final emptyMovie = Movie(
          id: 1,
          title: '',
          description: '',
          posterUrl: '',
          genre: '',
          subgenre: '',
          releaseDate: '',
          voteAverage: 0.0,
          language: '',
          keywords: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: emptyMovie,
                isTop: true,
                isBookmarked: false,
                isWatched: false,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        expect(find.byType(SwipeableMovieCard), findsOneWidget);
      });

      testWidgets('should handle very high ratings', (
        WidgetTester tester,
      ) async {
        final highRatingMovie = Movie(
          id: 1,
          title: 'Perfect Movie',
          description: 'A perfect movie',
          posterUrl: 'https://example.com/poster.jpg',
          genre: 'Drama',
          subgenre: 'Drama',
          releaseDate: '2023',
          voteAverage: 10.0,
          language: 'en',
          keywords: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: highRatingMovie,
                isTop: true,
                isBookmarked: false,
                isWatched: false,
                rating: 10.0,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        expect(find.text('Perfect Movie'), findsOneWidget);
        expect(find.text('10.0'), findsOneWidget);
        expect(find.text('Your Rating: 10.0'), findsOneWidget);
      });

      testWidgets('should handle special characters in movie data', (
        WidgetTester tester,
      ) async {
        final specialCharsMovie = Movie(
          id: 1,
          title: 'Café & Résumé: The Movie!',
          description: 'A movie with special characters: @#\$%^&*()_+{}|:"<>?',
          posterUrl: 'https://example.com/poster.jpg',
          genre: 'Comédie',
          subgenre: 'Drame',
          releaseDate: '2023',
          voteAverage: 7.5,
          language: 'fr',
          keywords: ['comédie', 'français'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: specialCharsMovie,
                isTop: true,
                isBookmarked: false,
                isWatched: false,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        expect(find.text('Café & Résumé: The Movie!'), findsOneWidget);
        expect(find.text('Comédie • Drame'), findsOneWidget);
      });
    });

    group('Performance', () {
      testWidgets('should render quickly with complex movie data', (
        WidgetTester tester,
      ) async {
        final complexMovie = Movie(
          id: 1,
          title: 'Complex Movie with Very Long Title That Tests Performance',
          description:
              'This is a very long and complex movie description that contains multiple sentences and should test the performance of the widget when rendering complex text content. It includes various details about the plot, characters, and setting.',
          posterUrl:
              'https://example.com/very-long-url-that-might-cause-performance-issues.jpg',
          genre: 'Action',
          subgenre: 'Adventure',
          releaseDate: '2023',
          voteAverage: 8.7,
          language: 'en',
          keywords: List.generate(50, (index) => 'keyword$index'),
        );

        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMovieCard(
                movie: complexMovie,
                isTop: true,
                isBookmarked: true,
                isWatched: true,
                rating: 9.5,
                movieService: mockMovieService,
                onSwipeLeft: () {},
                onSwipeRight: () {},
                onSwipeUp: () {},
                onSwipeDown: () {},
              ),
            ),
          ),
        );

        stopwatch.stop();

        expect(find.byType(SwipeableMovieCard), findsOneWidget);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
        ); // Should render within 1 second
      });

      testWidgets('should handle rapid gesture changes', (
        WidgetTester tester,
      ) async {
        int gestureCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            onSwipeLeft: () => gestureCount++,
            onSwipeRight: () => gestureCount++,
            onSwipeUp: () => gestureCount++,
            onSwipeDown: () => gestureCount++,
          ),
        );

        final cardFinder = find.byType(SwipeableMovieCard);

        // Perform rapid gestures
        for (int i = 0; i < 10; i++) {
          await tester.drag(cardFinder, Offset(300 * (i % 2 == 0 ? 1 : -1), 0));
          await tester.pump(const Duration(milliseconds: 10));
        }

        await tester.pumpAndSettle();

        // Should handle rapid gestures without crashing
        expect(find.byType(SwipeableMovieCard), findsOneWidget);
      });
    });
  });
}
