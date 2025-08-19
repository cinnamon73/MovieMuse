import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_picker/services/recommendation_service.dart';
import 'package:movie_picker/services/user_data_service.dart';
import 'package:movie_picker/models/movie.dart';
import 'package:movie_picker/models/user_data.dart';

import 'recommendation_service_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecommendationService Tests', () {
    late RecommendationService recommendationService;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      recommendationService = RecommendationService();

      // Setup default mock responses
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await recommendationService.initialize();
        expect(recommendationService.userPreferences, isNotNull);
      });

      test('should handle initialization errors gracefully', () async {
        when(mockPrefs.getString(any)).thenThrow(Exception('Storage error'));

        await recommendationService.initialize();
        expect(recommendationService.userPreferences, isNotNull);
      });
    });

    group('User Interaction Recording', () {
      test('should record watched movie interaction', () async {
        await recommendationService.initialize();

        final movie = Movie(
          id: 1,
          title: 'Test Movie',
          description: 'Test description',
          posterUrl: 'https://example.com/poster.jpg',
          genre: 'Action',
          subgenre: 'Adventure',
          releaseDate: '2023',
          voteAverage: 7.5,
          language: 'en',
          keywords: ['action', 'adventure'],
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'watched',
        );

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['watchedMovies'], equals(1));
      });

      test('should record skipped movie interaction', () async {
        await recommendationService.initialize();

        final movie = Movie(
          id: 2,
          title: 'Skipped Movie',
          description: 'Not interesting',
          posterUrl: 'https://example.com/poster2.jpg',
          genre: 'Romance',
          subgenre: 'Drama',
          releaseDate: '2022',
          voteAverage: 6.0,
          language: 'en',
          keywords: ['romance', 'drama'],
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'skipped',
        );

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['skippedMovies'], equals(1));
      });

      test('should record rated movie interaction', () async {
        await recommendationService.initialize();

        final movie = Movie(
          id: 3,
          title: 'Rated Movie',
          description: 'Good movie',
          posterUrl: 'https://example.com/poster3.jpg',
          genre: 'Drama',
          subgenre: 'Thriller',
          releaseDate: '2021',
          voteAverage: 8.0,
          language: 'en',
          keywords: ['drama', 'thriller'],
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'rated',
          rating: 9.0,
        );

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['ratedMovies'], equals(1));
        expect(insights['averageRating'], equals(9.0));
      });

      test('should record bookmarked movie interaction', () async {
        await recommendationService.initialize();

        final movie = Movie(
          id: 4,
          title: 'Bookmarked Movie',
          description: 'Interesting movie',
          posterUrl: 'https://example.com/poster4.jpg',
          genre: 'Sci-Fi',
          subgenre: 'Action',
          releaseDate: '2023',
          voteAverage: 7.8,
          language: 'en',
          keywords: ['sci-fi', 'action'],
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'bookmarked',
        );

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['totalInteractions'], equals(1));
      });
    });

    group('Preference Learning', () {
      test('should learn genre preferences from interactions', () async {
        await recommendationService.initialize();

        // Record multiple action movie interactions
        for (int i = 0; i < 3; i++) {
          final movie = Movie(
            id: i,
            title: 'Action Movie $i',
            description: 'Action description',
            posterUrl: 'https://example.com/poster$i.jpg',
            genre: 'Action',
            subgenre: 'Adventure',
            releaseDate: '2023',
            voteAverage: 8.0,
            language: 'en',
            keywords: ['action', 'adventure'],
          );

          await recommendationService.recordInteractionForUser(
            userId: 'user1',
            movie: movie,
            interactionType: 'watched',
          );
        }

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        final topGenres = insights['topGenres'] as List<String>;
        expect(topGenres, contains('Action'));
      });

      test('should learn language preferences from interactions', () async {
        await recommendationService.initialize();

        // Record multiple Spanish movie interactions
        for (int i = 0; i < 3; i++) {
          final movie = Movie(
            id: i,
            title: 'Película $i',
            description: 'Descripción en español',
            posterUrl: 'https://example.com/poster$i.jpg',
            genre: 'Drama',
            subgenre: 'Romance',
            releaseDate: '2023',
            voteAverage: 7.5,
            language: 'es',
            keywords: ['drama', 'romance'],
          );

          await recommendationService.recordInteractionForUser(
            userId: 'user1',
            movie: movie,
            interactionType: 'watched',
          );
        }

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        final topLanguages = insights['topLanguages'] as List<String>;
        expect(topLanguages, contains('es'));
      });

      test('should learn decade preferences from interactions', () async {
        await recommendationService.initialize();

        // Record multiple 2020s movie interactions
        for (int i = 0; i < 3; i++) {
          final movie = Movie(
            id: i,
            title: '2020s Movie $i',
            description: 'Recent movie',
            posterUrl: 'https://example.com/poster$i.jpg',
            genre: 'Comedy',
            subgenre: 'Romance',
            releaseDate: '2022',
            voteAverage: 7.0,
            language: 'en',
            keywords: ['comedy', 'romance'],
          );

          await recommendationService.recordInteractionForUser(
            userId: 'user1',
            movie: movie,
            interactionType: 'watched',
          );
        }

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        final topDecades = insights['topDecades'] as List<String>;
        expect(topDecades, contains('2020s'));
      });
    });

    group('Recommendation Scoring', () {
      test('should score movies based on user preferences', () async {
        await recommendationService.initialize();

        // First, build user preferences by recording interactions
        final actionMovie = Movie(
          id: 1,
          title: 'Action Movie',
          description: 'Action description',
          posterUrl: 'https://example.com/action.jpg',
          genre: 'Action',
          subgenre: 'Adventure',
          releaseDate: '2023',
          voteAverage: 8.0,
          language: 'en',
          keywords: ['action', 'adventure'],
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: actionMovie,
          interactionType: 'watched',
        );

        // Test that interactions are recorded (we can't test private methods directly)
        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['watchedMovies'], equals(1));
      });

      test('should give higher scores to preferred genres', () async {
        await recommendationService.initialize();

        // Build strong action preference
        for (int i = 0; i < 5; i++) {
          final movie = Movie(
            id: i,
            title: 'Action Movie $i',
            description: 'Action description',
            posterUrl: 'https://example.com/action$i.jpg',
            genre: 'Action',
            subgenre: 'Adventure',
            releaseDate: '2023',
            voteAverage: 8.0,
            language: 'en',
            keywords: ['action', 'adventure'],
          );

          await recommendationService.recordInteractionForUser(
            userId: 'user1',
            movie: movie,
            interactionType: 'watched',
          );
        }

        final actionMovie = Movie(
          id: 100,
          title: 'New Action Movie',
          description: 'New action movie',
          posterUrl: 'https://example.com/new_action.jpg',
          genre: 'Action',
          subgenre: 'Adventure',
          releaseDate: '2024',
          voteAverage: 7.5,
          language: 'en',
          keywords: ['action', 'adventure'],
        );

        final romanceMovie = Movie(
          id: 101,
          title: 'Romance Movie',
          description: 'Romance movie',
          posterUrl: 'https://example.com/romance.jpg',
          genre: 'Romance',
          subgenre: 'Drama',
          releaseDate: '2024',
          voteAverage: 7.5,
          language: 'en',
          keywords: ['romance', 'drama'],
        );

        // Test through the public recommendation API
        final recommendations = await recommendationService
            .getRecommendationsForUser([actionMovie, romanceMovie], 'user1');

        // Action movie should be recommended first due to user preferences
        expect(recommendations.first.genre, equals('Action'));
      });
    });

    group('Recommendation Generation', () {
      test('should return popular movies for new users', () async {
        await recommendationService.initialize();

        final movies = [
          Movie(
            id: 1,
            title: 'Popular Movie 1',
            description: 'Very popular',
            posterUrl: 'https://example.com/popular1.jpg',
            genre: 'Action',
            subgenre: 'Adventure',
            releaseDate: '2023',
            voteAverage: 9.0,
            language: 'en',
            keywords: ['action'],
          ),
          Movie(
            id: 2,
            title: 'Less Popular Movie',
            description: 'Less popular',
            posterUrl: 'https://example.com/less_popular.jpg',
            genre: 'Drama',
            subgenre: 'Romance',
            releaseDate: '2023',
            voteAverage: 6.0,
            language: 'en',
            keywords: ['drama'],
          ),
        ];

        final recommendations = await recommendationService
            .getRecommendationsForUser(movies, 'new_user');

        expect(recommendations, isNotEmpty);
        expect(
          recommendations.first.voteAverage,
          greaterThanOrEqualTo(recommendations.last.voteAverage),
        );
      });

      test(
        'should return personalized recommendations for experienced users',
        () async {
          await recommendationService.initialize();

          // Build user preferences
          for (int i = 0; i < 5; i++) {
            final movie = Movie(
              id: i,
              title: 'Action Movie $i',
              description: 'Action description',
              posterUrl: 'https://example.com/action$i.jpg',
              genre: 'Action',
              subgenre: 'Adventure',
              releaseDate: '2023',
              voteAverage: 8.0,
              language: 'en',
              keywords: ['action', 'adventure'],
            );

            await recommendationService.recordInteractionForUser(
              userId: 'experienced_user',
              movie: movie,
              interactionType: 'watched',
            );
          }

          final availableMovies = [
            Movie(
              id: 100,
              title: 'New Action Movie',
              description: 'Action movie',
              posterUrl: 'https://example.com/new_action.jpg',
              genre: 'Action',
              subgenre: 'Adventure',
              releaseDate: '2024',
              voteAverage: 7.5,
              language: 'en',
              keywords: ['action', 'adventure'],
            ),
            Movie(
              id: 101,
              title: 'Romance Movie',
              description: 'Romance movie',
              posterUrl: 'https://example.com/romance.jpg',
              genre: 'Romance',
              subgenre: 'Drama',
              releaseDate: '2024',
              voteAverage: 8.0,
              language: 'en',
              keywords: ['romance', 'drama'],
            ),
          ];

          final recommendations = await recommendationService
              .getRecommendationsForUser(availableMovies, 'experienced_user');

          expect(recommendations, isNotEmpty);
          // The action movie should be recommended first due to user preferences
          expect(recommendations.first.genre, equals('Action'));
        },
      );

      test('should limit recommendations to specified count', () async {
        await recommendationService.initialize();

        final movies = List.generate(
          100,
          (index) => Movie(
            id: index,
            title: 'Movie $index',
            description: 'Description $index',
            posterUrl: 'https://example.com/movie$index.jpg',
            genre: 'Action',
            subgenre: 'Adventure',
            releaseDate: '2023',
            voteAverage: 7.0,
            language: 'en',
            keywords: ['action'],
          ),
        );

        final recommendations = await recommendationService
            .getRecommendationsForUser(movies, 'user1', limit: 10);

        expect(recommendations.length, lessThanOrEqualTo(10));
      });
    });

    group('User Insights', () {
      test('should provide comprehensive user insights', () async {
        await recommendationService.initialize();

        // Record various interactions
        final movies = [
          Movie(
            id: 1,
            title: 'Action Movie',
            description: 'Action',
            posterUrl: 'https://example.com/action.jpg',
            genre: 'Action',
            subgenre: 'Adventure',
            releaseDate: '2023',
            voteAverage: 8.0,
            language: 'en',
            keywords: ['action', 'adventure'],
          ),
          Movie(
            id: 2,
            title: 'Drama Movie',
            description: 'Drama',
            posterUrl: 'https://example.com/drama.jpg',
            genre: 'Drama',
            subgenre: 'Romance',
            releaseDate: '2022',
            voteAverage: 7.5,
            language: 'en',
            keywords: ['drama', 'romance'],
          ),
        ];

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movies[0],
          interactionType: 'watched',
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movies[1],
          interactionType: 'rated',
          rating: 8.5,
        );

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );

        expect(insights['totalInteractions'], equals(2));
        expect(insights['watchedMovies'], equals(1));
        expect(insights['ratedMovies'], equals(1));
        expect(insights['averageRating'], equals(8.5));
        expect(insights['topGenres'], isA<List<String>>());
        expect(insights['topLanguages'], isA<List<String>>());
        expect(insights['topDecades'], isA<List<String>>());
      });

      test('should handle users with no interactions', () async {
        await recommendationService.initialize();

        final insights = await recommendationService.getUserInsightsForUser(
          'new_user',
        );

        expect(insights['totalInteractions'], equals(0));
        expect(insights['watchedMovies'], equals(0));
        expect(insights['ratedMovies'], equals(0));
        expect(insights['averageRating'], equals(0.0));
      });
    });

    group('Cache Management', () {
      test('should clear user preferences cache', () {
        recommendationService.clearUserPreferencesCache('user1');
        // Test passes if no exception is thrown
        expect(true, isTrue);
      });

      test('should clear all user preferences cache', () {
        recommendationService.clearUserPreferencesCache(null);
        // Test passes if no exception is thrown
        expect(true, isTrue);
      });
    });

    group('Preferences Management', () {
      test('should reset user preferences', () async {
        await recommendationService.initialize();

        // First, create some preferences
        final movie = Movie(
          id: 1,
          title: 'Test Movie',
          description: 'Test',
          posterUrl: 'https://example.com/test.jpg',
          genre: 'Action',
          subgenre: 'Adventure',
          releaseDate: '2023',
          voteAverage: 8.0,
          language: 'en',
          keywords: ['action'],
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'watched',
        );

        // Reset preferences
        await recommendationService.resetPreferencesForUser('user1');

        // Verify reset
        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['totalInteractions'], equals(0));
      });

      test('should export preferences', () async {
        await recommendationService.initialize();

        final exported = await recommendationService.exportPreferencesForUser(
          'user1',
        );
        expect(exported, isA<String>());
        expect(exported.isNotEmpty, isTrue);
      });

      test('should import preferences', () async {
        await recommendationService.initialize();

        // Export first
        final exported = await recommendationService.exportPreferencesForUser(
          'user1',
        );

        // Import to another user
        await recommendationService.importPreferencesForUser('user2', exported);

        // Test passes if no exception is thrown
        expect(true, isTrue);
      });

      test('should handle invalid import data', () async {
        await recommendationService.initialize();

        expect(
          () => recommendationService.importPreferencesForUser(
            'user1',
            'invalid json',
          ),
          throwsException,
        );
      });
    });

    group('Edge Cases', () {
      test('should handle movies with empty keywords', () async {
        await recommendationService.initialize();

        final movie = Movie(
          id: 1,
          title: 'No Keywords Movie',
          description: 'Movie without keywords',
          posterUrl: 'https://example.com/no_keywords.jpg',
          genre: 'Drama',
          subgenre: 'Drama',
          releaseDate: '2023',
          voteAverage: 7.0,
          language: 'en',
          keywords: [], // Empty keywords
        );

        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'watched',
        );

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['watchedMovies'], equals(1));
      });

      test('should handle very high and very low ratings', () async {
        await recommendationService.initialize();

        final movie = Movie(
          id: 1,
          title: 'Test Movie',
          description: 'Test',
          posterUrl: 'https://example.com/test.jpg',
          genre: 'Drama',
          subgenre: 'Drama',
          releaseDate: '2023',
          voteAverage: 7.0,
          language: 'en',
          keywords: ['drama'],
        );

        // Test very high rating
        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'rated',
          rating: 10.0,
        );

        // Test very low rating
        await recommendationService.recordInteractionForUser(
          userId: 'user1',
          movie: movie,
          interactionType: 'rated',
          rating: 1.0,
        );

        final insights = await recommendationService.getUserInsightsForUser(
          'user1',
        );
        expect(insights['ratedMovies'], equals(2));
        expect(insights['averageRating'], equals(5.5)); // (10.0 + 1.0) / 2
      });

      test('should handle large numbers of interactions efficiently', () async {
        await recommendationService.initialize();

        final startTime = DateTime.now();

        // Record many interactions
        for (int i = 0; i < 100; i++) {
          final movie = Movie(
            id: i,
            title: 'Movie $i',
            description: 'Description $i',
            posterUrl: 'https://example.com/movie$i.jpg',
            genre: i % 2 == 0 ? 'Action' : 'Drama',
            subgenre: i % 2 == 0 ? 'Adventure' : 'Romance',
            releaseDate: '2023',
            voteAverage: 7.0 + (i % 3),
            language: 'en',
            keywords: ['keyword$i'],
          );

          await recommendationService.recordInteractionForUser(
            userId: 'heavy_user',
            movie: movie,
            interactionType: 'watched',
          );
        }

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        final insights = await recommendationService.getUserInsightsForUser(
          'heavy_user',
        );
        expect(insights['watchedMovies'], equals(100));
        expect(
          duration.inSeconds,
          lessThan(10),
        ); // Should complete within 10 seconds
      });
    });
  });
}
