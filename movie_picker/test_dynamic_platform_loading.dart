import 'package:flutter_test/flutter_test.dart';
import 'package:movie_picker/services/movie_service.dart';

void main() {
  group('Dynamic Platform Loading Tests', () {
    test('should support all major platforms', () {
      final platforms = [
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
      
      for (final platform in platforms) {
        expect(MovieService.PLATFORM_PROVIDERS.containsKey(platform), true,
          reason: 'Platform $platform should be supported');
      }
    });

    test('should have valid provider IDs', () {
      for (final entry in MovieService.PLATFORM_PROVIDERS.entries) {
        final providerId = int.tryParse(entry.value);
        expect(providerId, isNotNull,
          reason: 'Provider ID for ${entry.key} should be a valid integer');
        expect(providerId, isPositive,
          reason: 'Provider ID for ${entry.key} should be positive');
      }
    });

    test('should have correct Netflix provider ID', () {
      expect(MovieService.PLATFORM_PROVIDERS['netflix'], '8');
    });

    test('should have correct Amazon Prime provider ID', () {
      expect(MovieService.PLATFORM_PROVIDERS['amazon_prime'], '119');
    });

    test('should have correct Disney+ provider ID', () {
      expect(MovieService.PLATFORM_PROVIDERS['disney_plus'], '337');
    });

    test('should have correct HBO Max provider ID', () {
      expect(MovieService.PLATFORM_PROVIDERS['hbo_max'], '384');
    });

    test('should have correct Hulu provider ID', () {
      expect(MovieService.PLATFORM_PROVIDERS['hulu'], '15');
    });
  });
} 