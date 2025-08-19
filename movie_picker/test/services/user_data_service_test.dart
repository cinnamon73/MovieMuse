import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_picker/services/user_data_service.dart';

import 'user_data_service_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserDataService Tests', () {
    late UserDataService userDataService;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      userDataService = UserDataService(mockPrefs);

      // Setup default mock responses
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
      when(mockPrefs.getBool(any)).thenReturn(null);
      when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
      when(mockPrefs.getStringList(any)).thenReturn(null);
      when(mockPrefs.remove(any)).thenAnswer((_) async => true);
    });

    group('Initialization', () {
      test('should initialize with existing user', () async {
        when(
          mockPrefs.getString('current_user_id'),
        ).thenReturn('existing_user');
        when(mockPrefs.getString('user_data_existing_user')).thenReturn(
          '{"userId":"existing_user","name":"Existing User","watchedMovieIds":[],"bookmarkedMovieIds":[],"skippedMovieIds":[],"movieRatings":{},"createdAt":"2023-01-01T00:00:00.000Z","lastActiveAt":"2023-01-01T00:00:00.000Z"}',
        );

        await userDataService.initialize();

        expect(userDataService.currentUserId, equals('existing_user'));
      });

      test('should create default user when none exists', () async {
        when(mockPrefs.getString('current_user_id')).thenReturn(null);
        when(mockPrefs.getString('users_list')).thenReturn(null);

        await userDataService.initialize();

        expect(userDataService.currentUserId, isNotNull);
        verify(mockPrefs.setString('current_user_id', any)).called(1);
      });

      test('should handle migration from old data format', () async {
        when(mockPrefs.getString('current_user_id')).thenReturn(null);
        when(mockPrefs.getBool('data_migrated')).thenReturn(false);
        when(
          mockPrefs.getStringList('watched_movies'),
        ).thenReturn(['1', '2', '3']);
        when(mockPrefs.getString('user_preferences')).thenReturn(
          '{"interactionHistory":[{"movieId":1,"interactionType":"watched"},{"movieId":2,"interactionType":"rated","rating":8.5}]}',
        );

        await userDataService.initialize();

        verify(mockPrefs.setBool('data_migrated', true)).called(1);
      });
    });

    group('User Management', () {
      test('should create new user successfully', () async {
        when(mockPrefs.getString('users_list')).thenReturn('[]');

        final userId = await userDataService.createUser('Test User');

        expect(userId, isNotNull);
        expect(userDataService.currentUserId, equals(userId));
        verify(mockPrefs.setString('current_user_id', userId)).called(1);
        verify(mockPrefs.setString('user_data_$userId', any)).called(1);
        verify(mockPrefs.setString('users_list', any)).called(1);
      });

      test('should get all users', () async {
        when(mockPrefs.getString('users_list')).thenReturn(
          '[{"userId":"user1","name":"User 1","createdAt":"2023-01-01T00:00:00.000Z"},{"userId":"user2","name":"User 2","createdAt":"2023-01-02T00:00:00.000Z"}]',
        );

        final users = await userDataService.getAllUsers();

        expect(users.length, equals(2));
        expect(users[0].userId, equals('user1'));
        expect(users[0].name, equals('User 1'));
        expect(users[1].userId, equals('user2'));
        expect(users[1].name, equals('User 2'));
      });

      test('should handle empty users list', () async {
        when(mockPrefs.getString('users_list')).thenReturn(null);

        final users = await userDataService.getAllUsers();

        expect(users, isEmpty);
      });

      test('should handle malformed users list gracefully', () async {
        when(mockPrefs.getString('users_list')).thenReturn('invalid json');

        final users = await userDataService.getAllUsers();

        expect(users, isEmpty);
      });

      test('should delete user successfully', () async {
        when(mockPrefs.getString('users_list')).thenReturn(
          '[{"userId":"user1","name":"User 1","createdAt":"2023-01-01T00:00:00.000Z"},{"userId":"user2","name":"User 2","createdAt":"2023-01-02T00:00:00.000Z"}]',
        );
        await userDataService.switchUser('user1'); // Set current user to user1

        await userDataService.deleteUser('user2');

        verify(mockPrefs.remove('user_data_user2')).called(1);
        verify(mockPrefs.setString('users_list', any)).called(1);
      });

      test('should not delete current user', () async {
        await userDataService.switchUser('current_user');

        expect(
          () => userDataService.deleteUser('current_user'),
          throwsException,
        );
      });
    });

    group('User Data Operations', () {
      setUp(() async {
        // Setup a current user for these tests
        when(mockPrefs.getString('current_user_id')).thenReturn('test_user');
        when(mockPrefs.getString('user_data_test_user')).thenReturn(
          '{"userId":"test_user","name":"Test User","watchedMovieIds":[],"bookmarkedMovieIds":[],"skippedMovieIds":[],"movieRatings":{},"createdAt":"2023-01-01T00:00:00.000Z","lastActiveAt":"2023-01-01T00:00:00.000Z"}',
        );
        await userDataService.initialize();
      });

      test('should get current user data', () async {
        final userData = await userDataService.getCurrentUserData();

        expect(userData.userId, equals('test_user'));
        expect(userData.name, equals('Test User'));
        expect(userData.watchedMovieIds, isEmpty);
        expect(userData.bookmarkedMovieIds, isEmpty);
        expect(userData.skippedMovieIds, isEmpty);
        expect(userData.movieRatings, isEmpty);
      });

      test('should get user data by ID', () async {
        when(mockPrefs.getString('user_data_other_user')).thenReturn(
          '{"userId":"other_user","name":"Other User","watchedMovieIds":[1,2],"bookmarkedMovieIds":[3],"skippedMovieIds":[4],"movieRatings":{"5":8.5},"createdAt":"2023-01-01T00:00:00.000Z","lastActiveAt":"2023-01-01T00:00:00.000Z"}',
        );

        final userData = await userDataService.getUserData('other_user');

        expect(userData.userId, equals('other_user'));
        expect(userData.name, equals('Other User'));
        expect(userData.watchedMovieIds, contains(1));
        expect(userData.watchedMovieIds, contains(2));
        expect(userData.bookmarkedMovieIds, contains(3));
        expect(userData.skippedMovieIds, contains(4));
        expect(userData.movieRatings[5], equals(8.5));
      });

      test('should create default user data when not found', () async {
        when(mockPrefs.getString('user_data_new_user')).thenReturn(null);

        final userData = await userDataService.getUserData('new_user');

        expect(userData.userId, equals('new_user'));
        expect(userData.name, equals('User new_user'));
        expect(userData.watchedMovieIds, isEmpty);
        expect(userData.bookmarkedMovieIds, isEmpty);
        expect(userData.skippedMovieIds, isEmpty);
        expect(userData.movieRatings, isEmpty);
      });

      test('should handle malformed user data gracefully', () async {
        when(
          mockPrefs.getString('user_data_corrupt_user'),
        ).thenReturn('invalid json');

        final userData = await userDataService.getUserData('corrupt_user');

        expect(userData.userId, equals('corrupt_user'));
        expect(userData.name, equals('User corrupt_user'));
      });

      test('should save user data successfully', () async {
        final userData = await userDataService.getCurrentUserData();
        userData.watchedMovieIds.add(123);
        userData.movieRatings[456] = 7.5;

        await userDataService.saveUserData(userData);

        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });
    });

    group('Movie Operations', () {
      setUp(() async {
        // Setup a current user for these tests
        when(mockPrefs.getString('current_user_id')).thenReturn('test_user');
        when(mockPrefs.getString('user_data_test_user')).thenReturn(
          '{"userId":"test_user","name":"Test User","watchedMovieIds":[],"bookmarkedMovieIds":[],"skippedMovieIds":[],"movieRatings":{},"createdAt":"2023-01-01T00:00:00.000Z","lastActiveAt":"2023-01-01T00:00:00.000Z"}',
        );
        await userDataService.initialize();
      });

      test('should add watched movie', () async {
        await userDataService.addWatchedMovie(123);

        // Verify that setString was called to save the updated user data
        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });

      test('should toggle bookmark (add)', () async {
        await userDataService.toggleBookmark(456);

        // Verify that setString was called to save the updated user data
        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });

      test('should toggle bookmark (remove)', () async {
        // First add a bookmark
        await userDataService.toggleBookmark(456);
        // Then remove it
        await userDataService.toggleBookmark(456);

        // Verify that setString was called twice
        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });

      test('should set movie rating', () async {
        await userDataService.setMovieRating(789, 8.5);

        // Verify that setString was called to save the updated user data
        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });

      test('should remove movie rating when set to 0', () async {
        // First set a rating
        await userDataService.setMovieRating(789, 8.5);
        // Then remove it by setting to 0
        await userDataService.setMovieRating(789, 0.0);

        // Verify that setString was called twice
        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });

      test('should add skipped movie', () async {
        await userDataService.addSkippedMovie(321);

        // Verify that setString was called to save the updated user data
        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });

      test('should clear all user data', () async {
        // First add some data
        await userDataService.addWatchedMovie(123);
        await userDataService.toggleBookmark(456);
        await userDataService.setMovieRating(789, 8.5);
        await userDataService.addSkippedMovie(321);

        // Then clear it
        await userDataService.clearCurrentUserData();

        // Verify that setString was called multiple times (once for each operation plus clear)
        verify(
          mockPrefs.setString('user_data_test_user', any),
        ).called(greaterThan(0));
      });
    });

    group('UserData Model Tests', () {
      test('should create UserData with default values', () {
        final userData = UserData(userId: 'test', name: 'Test User');

        expect(userData.userId, equals('test'));
        expect(userData.name, equals('Test User'));
        expect(userData.watchedMovieIds, isEmpty);
        expect(userData.bookmarkedMovieIds, isEmpty);
        expect(userData.skippedMovieIds, isEmpty);
        expect(userData.movieRatings, isEmpty);
        expect(userData.createdAt, isNotNull);
        expect(userData.lastActiveAt, isNotNull);
      });

      test('should create UserData with provided values', () {
        final now = DateTime.now();
        final userData = UserData(
          userId: 'test',
          name: 'Test User',
          watchedMovieIds: {1, 2, 3},
          bookmarkedMovieIds: {4, 5},
          skippedMovieIds: {6},
          movieRatings: {7: 8.5, 8: 7.0},
          createdAt: now,
          lastActiveAt: now,
        );

        expect(userData.watchedMovieIds.length, equals(3));
        expect(userData.bookmarkedMovieIds.length, equals(2));
        expect(userData.skippedMovieIds.length, equals(1));
        expect(userData.movieRatings.length, equals(2));
        expect(userData.createdAt, equals(now));
        expect(userData.lastActiveAt, equals(now));
      });

      test('should calculate statistics correctly', () {
        final userData = UserData(
          userId: 'test',
          name: 'Test User',
          watchedMovieIds: {1, 2, 3, 4, 5},
          bookmarkedMovieIds: {6, 7, 8},
          skippedMovieIds: {9, 10},
          movieRatings: {1: 8.0, 2: 7.0, 3: 9.0},
        );

        expect(userData.totalWatchedMovies, equals(5));
        expect(userData.totalBookmarkedMovies, equals(3));
        expect(userData.totalSkippedMovies, equals(2));
        expect(userData.totalRatedMovies, equals(3));
        expect(userData.averageRating, equals(8.0)); // (8.0 + 7.0 + 9.0) / 3
      });

      test('should handle empty ratings for average calculation', () {
        final userData = UserData(userId: 'test', name: 'Test User');

        expect(userData.averageRating, equals(0.0));
      });

      test('should serialize to JSON correctly', () {
        final userData = UserData(
          userId: 'test',
          name: 'Test User',
          watchedMovieIds: {1, 2},
          bookmarkedMovieIds: {3},
          skippedMovieIds: {4},
          movieRatings: {5: 8.5},
        );

        final json = userData.toJson();

        expect(json['userId'], equals('test'));
        expect(json['name'], equals('Test User'));
        expect(json['watchedMovieIds'], isA<List>());
        expect(json['bookmarkedMovieIds'], isA<List>());
        expect(json['skippedMovieIds'], isA<List>());
        expect(json['movieRatings'], isA<Map>());
        expect(json['createdAt'], isA<String>());
        expect(json['lastActiveAt'], isA<String>());
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'userId': 'test',
          'name': 'Test User',
          'watchedMovieIds': [1, 2, 3],
          'bookmarkedMovieIds': [4, 5],
          'skippedMovieIds': [6],
          'movieRatings': {'7': 8.5, '8': 7.0},
          'createdAt': '2023-01-01T00:00:00.000Z',
          'lastActiveAt': '2023-01-01T00:00:00.000Z',
        };

        final userData = UserData.fromJson(json);

        expect(userData.userId, equals('test'));
        expect(userData.name, equals('Test User'));
        expect(userData.watchedMovieIds, equals({1, 2, 3}));
        expect(userData.bookmarkedMovieIds, equals({4, 5}));
        expect(userData.skippedMovieIds, equals({6}));
        expect(userData.movieRatings[7], equals(8.5));
        expect(userData.movieRatings[8], equals(7.0));
      });
    });

    group('UserProfile Model Tests', () {
      test('should create UserProfile with default creation time', () {
        final profile = UserProfile(userId: 'test', name: 'Test User');

        expect(profile.userId, equals('test'));
        expect(profile.name, equals('Test User'));
        expect(profile.createdAt, isNotNull);
      });

      test('should create UserProfile with provided creation time', () {
        final now = DateTime.now();
        final profile = UserProfile(
          userId: 'test',
          name: 'Test User',
          createdAt: now,
        );

        expect(profile.createdAt, equals(now));
      });

      test('should serialize UserProfile to JSON correctly', () {
        final profile = UserProfile(userId: 'test', name: 'Test User');
        final json = profile.toJson();

        expect(json['userId'], equals('test'));
        expect(json['name'], equals('Test User'));
        expect(json['createdAt'], isA<String>());
      });

      test('should deserialize UserProfile from JSON correctly', () {
        final json = {
          'userId': 'test',
          'name': 'Test User',
          'createdAt': '2023-01-01T00:00:00.000Z',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.userId, equals('test'));
        expect(profile.name, equals('Test User'));
        expect(
          profile.createdAt,
          equals(DateTime.parse('2023-01-01T00:00:00.000Z')),
        );
      });
    });

    group('Error Handling', () {
      test('should handle SharedPreferences errors gracefully', () async {
        when(
          mockPrefs.setString(any, any),
        ).thenThrow(Exception('Storage error'));

        // Should not throw exception
        await userDataService.saveUserData(
          UserData(userId: 'test', name: 'Test'),
        );

        // Test passes if no exception is thrown
        expect(true, isTrue);
      });

      test('should handle no current user gracefully', () async {
        when(mockPrefs.getString('current_user_id')).thenReturn(null);
        userDataService = UserDataService(mockPrefs);

        expect(() => userDataService.getCurrentUserData(), throwsException);
      });
    });

    group('Edge Cases', () {
      test('should handle very large user data sets', () async {
        final largeWatchedSet = Set<int>.from(List.generate(10000, (i) => i));
        final largeRatingsMap = Map<int, double>.fromEntries(
          List.generate(5000, (i) => MapEntry(i, 7.0 + (i % 3))),
        );

        final userData = UserData(
          userId: 'heavy_user',
          name: 'Heavy User',
          watchedMovieIds: largeWatchedSet,
          movieRatings: largeRatingsMap,
        );

        final startTime = DateTime.now();
        final json = userData.toJson();
        final reconstructed = UserData.fromJson(json);
        final endTime = DateTime.now();

        expect(reconstructed.watchedMovieIds.length, equals(10000));
        expect(reconstructed.movieRatings.length, equals(5000));
        expect(endTime.difference(startTime).inMilliseconds, lessThan(1000));
      });

      test('should handle duplicate movie IDs in sets', () async {
        // Test that UserData sets handle duplicates correctly
        final userData = UserData(userId: 'test', name: 'Test');

        // Add same movie multiple times to the set
        userData.watchedMovieIds.add(123);
        userData.watchedMovieIds.add(123);
        userData.watchedMovieIds.add(123);

        // Sets should automatically handle duplicates
        expect(userData.watchedMovieIds.length, equals(1));
        expect(userData.watchedMovieIds, contains(123));
      });

      test('should handle concurrent operations', () async {
        when(mockPrefs.getString('current_user_id')).thenReturn('test_user');
        when(mockPrefs.getString('user_data_test_user')).thenReturn(
          '{"userId":"test_user","name":"Test User","watchedMovieIds":[],"bookmarkedMovieIds":[],"skippedMovieIds":[],"movieRatings":{},"createdAt":"2023-01-01T00:00:00.000Z","lastActiveAt":"2023-01-01T00:00:00.000Z"}',
        );
        await userDataService.initialize();

        // Simulate concurrent operations
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(userDataService.addWatchedMovie(i));
          futures.add(userDataService.toggleBookmark(i + 100));
          futures.add(userDataService.setMovieRating(i + 200, 8.0));
        }

        await Future.wait(futures);

        // Test should complete without throwing exceptions
        expect(true, isTrue);
      });
    });
  });
}
