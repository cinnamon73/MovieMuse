import 'package:flutter_test/flutter_test.dart';
import 'package:movie_picker/services/movie_service.dart';

void main() {
  group('Platform Filter Integration Tests', () {
    test('should initialize platform filter state correctly', () {
      // Test that platform filter state is properly initialized
      expect(MovieService.PLATFORM_PROVIDERS.isNotEmpty, isTrue);
      expect(MovieService.PLATFORM_PROVIDERS.containsKey('netflix'), isTrue);
      expect(MovieService.PLATFORM_PROVIDERS.containsKey('amazon_prime'), isTrue);
      expect(MovieService.PLATFORM_PROVIDERS.containsKey('disney_plus'), isTrue);
    });

    test('should have valid provider IDs for all platforms', () {
      // Test that all platform provider IDs are valid integers
      for (final entry in MovieService.PLATFORM_PROVIDERS.entries) {
        final providerId = int.tryParse(entry.value);
        expect(providerId, isNotNull, 
          reason: 'Provider ID for ${entry.key} should be a valid integer');
        expect(providerId, isPositive, 
          reason: 'Provider ID for ${entry.key} should be positive');
      }
    });

    test('should support all major streaming platforms', () {
      // Test that all major platforms are supported
      final expectedPlatforms = [
        'netflix',
        'amazon_prime', 
        'disney_plus',
        'hbo_max',
        'hulu',
        'apple_tv',
        'paramount_plus',
        'peacock',
        'crunchyroll',
      ];

      for (final platform in expectedPlatforms) {
        expect(MovieService.PLATFORM_PROVIDERS.containsKey(platform), isTrue,
          reason: 'Platform $platform should be supported');
      }
    });

    test('should have correct provider IDs for major platforms', () {
      // Test specific provider IDs for major platforms
      expect(MovieService.PLATFORM_PROVIDERS['netflix'], equals('8'));
      expect(MovieService.PLATFORM_PROVIDERS['amazon_prime'], equals('119'));
      expect(MovieService.PLATFORM_PROVIDERS['disney_plus'], equals('337'));
      expect(MovieService.PLATFORM_PROVIDERS['hbo_max'], equals('384'));
      expect(MovieService.PLATFORM_PROVIDERS['hulu'], equals('15'));
    });

    test('should have unique provider IDs for all platforms', () {
      // Test that all provider IDs are unique
      final providerIds = MovieService.PLATFORM_PROVIDERS.values.toSet();
      expect(providerIds.length, equals(MovieService.PLATFORM_PROVIDERS.length),
        reason: 'All provider IDs should be unique');
    });
  });
} 