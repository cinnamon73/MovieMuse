import 'package:flutter_test/flutter_test.dart';
import 'package:movie_picker/services/movie_service.dart';

void main() {
  group('Platform Filter Tests', () {
    test('should have valid platform provider IDs', () {
      // Test that all platform provider IDs are valid
      for (final entry in MovieService.PLATFORM_PROVIDERS.entries) {
        expect(entry.value, isNotEmpty);
        expect(int.tryParse(entry.value), isNotNull, 
          reason: 'Provider ID for ${entry.key} should be a valid integer');
      }
    });

    test('should support all major platforms', () {
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

    test('should handle platform filter state correctly', () {
      // This would require a mock MovieService
      // For now, just test the platform provider mapping
      expect(MovieService.PLATFORM_PROVIDERS['netflix'], equals('8'));
      expect(MovieService.PLATFORM_PROVIDERS['amazon_prime'], equals('119'));
      expect(MovieService.PLATFORM_PROVIDERS['disney_plus'], equals('337'));
    });
  });
} 