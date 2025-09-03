import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movie.dart';

class StreamingService {
  final Dio _dio;
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  
  // Cache for watch providers to avoid repeated API calls
  final Map<int, Map<String, dynamic>> _watchProvidersCache = {};
  // Memoization caches
  final Map<int, String?> _bestPlatformCache = {};
  final Map<String, String?> _platformForFilterCache = {}; // key: movieId|platform
  final Map<int, List<String>> _allPlatformsCache = {};

  StreamingService() : _dio = Dio() {
    _dio.options.queryParameters = {'api_key': _apiKey};
  }

  // Build a TMDB watch link for a movie (non-affiliate). Opens TMDB's "Watch" page.
  // Example: https://www.themoviedb.org/movie/<id>/watch?region=GB
  String buildTmdbWatchUrl({required int movieId, String region = 'GB'}) {
    final regionCode = region.isNotEmpty ? region : 'GB';
    return 'https://www.themoviedb.org/movie/$movieId/watch?region=$regionCode';
  }

  // Fetch watch providers for a movie from TMDB
  Future<Map<String, dynamic>?> fetchWatchProviders(int movieId) async {
    // Check cache first
    if (_watchProvidersCache.containsKey(movieId)) {
      return _watchProvidersCache[movieId];
    }

    try {
      final response = await _dio.get('$_baseUrl/movie/$movieId/watch/providers');
      
      if (response.statusCode == 200) {
        final data = response.data;
        final results = data['results'] as Map<String, dynamic>?;
        
        if (results != null) {
          debugPrint('🌍 Available regions for movie $movieId: ${results.keys.toList()}');
          
          // Try multiple regions in order of preference
          final regions = ['US', 'GB', 'CA', 'AU', 'DE', 'FR', 'ES', 'IT', 'SE', 'PL'];
          
          for (final region in regions) {
            final regionProviders = results[region] as Map<String, dynamic>?;
            if (regionProviders != null) {
              debugPrint('✅ Found providers for region $region');
              debugPrint('📺 Flatrate providers: ${regionProviders['flatrate'] ?? []}');
              debugPrint('🆓 Free providers: ${regionProviders['free'] ?? []}');
              debugPrint('📢 Ad providers: ${regionProviders['ads'] ?? []}');
              debugPrint('💰 Rent providers: ${regionProviders['rent'] ?? []}');
              debugPrint('💳 Buy providers: ${regionProviders['buy'] ?? []}');
              
              final flatrate = regionProviders['flatrate'] as List<dynamic>?;
              final free = regionProviders['free'] as List<dynamic>?;
              final ads = regionProviders['ads'] as List<dynamic>?;
              final rent = regionProviders['rent'] as List<dynamic>?;
              final buy = regionProviders['buy'] as List<dynamic>?;
              
              final providers = {
                'flatrate': flatrate ?? [],
                'free': free ?? [],
                'ads': ads ?? [],
                'rent': rent ?? [],
                'buy': buy ?? [],
                'region': region,
              };
              
              // Cache the result
              _watchProvidersCache[movieId] = providers;
              return providers;
            }
          }
          
          debugPrint('❌ No providers found for any region');
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching watch providers: $e');
    }
    return null;
  }

  // Get the best streaming platform for a movie
  Future<String?> getBestStreamingPlatform(int movieId) async {
    if (_bestPlatformCache.containsKey(movieId)) return _bestPlatformCache[movieId];
    final providers = await fetchWatchProviders(movieId);
    if (providers == null) {
      debugPrint('❌ No TMDB streaming data available for movie $movieId');
      return null;
    }

    final region = providers['region'] as String?;
    debugPrint('🌍 Checking streaming availability for movie $movieId in region: $region');

    // Collect all available providers
    final allProviders = <Map<String, dynamic>>[];
    
    // Add flatrate providers (subscription - highest priority)
    final flatrate = providers['flatrate'] as List<dynamic>;
    for (final provider in flatrate) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'flatrate',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add free providers
    final free = providers['free'] as List<dynamic>;
    for (final provider in free) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'free',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add ad-supported providers
    final ads = providers['ads'] as List<dynamic>;
    for (final provider in ads) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'ads',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add rent providers (lower priority)
    final rent = providers['rent'] as List<dynamic>;
    for (final provider in rent) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'rent',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add buy providers (lowest priority)
    final buy = providers['buy'] as List<dynamic>;
    for (final provider in buy) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'buy',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    if (allProviders.isEmpty) {
      debugPrint('❌ No streaming providers found for movie $movieId');
      return null;
    }

    // Sort by type priority first, then by affiliate revenue potential
    allProviders.sort((a, b) {
      // First sort by type priority: flatrate > free > ads > rent > buy
      final typePriority = {
        'flatrate': 5,
        'free': 4,
        'ads': 3,
        'rent': 2,
        'buy': 1,
      };
      
      final aTypePriority = typePriority[a['type']] ?? 0;
      final bTypePriority = typePriority[b['type']] ?? 0;
      
      if (aTypePriority != bTypePriority) {
        return bTypePriority.compareTo(aTypePriority);
      }
      
      // Then sort by affiliate revenue potential
      return (b['priority'] as double).compareTo(a['priority'] as double);
    });

    final bestProvider = allProviders.first;
    final providerName = bestProvider['provider'] as String;
    final providerType = bestProvider['type'] as String;
    final priority = bestProvider['priority'] as double;
    
    debugPrint('✅ Selected provider: $providerName ($providerType) with priority: $priority');
    
    final mappedPlatform = _mapProviderToPlatform(providerName);
    debugPrint('🔄 Mapped "$providerName" to "$mappedPlatform"');
    _bestPlatformCache[movieId] = mappedPlatform;
    return _bestPlatformCache[movieId];
  }

  // Get streaming platform based on user's selected filter
  Future<String?> getStreamingPlatformForFilter(int movieId, String? selectedPlatform) async {
    final cacheKey = '$movieId|${selectedPlatform ?? '_auto'}';
    if (_platformForFilterCache.containsKey(cacheKey)) return _platformForFilterCache[cacheKey];
    final providers = await fetchWatchProviders(movieId);
    if (providers == null) {
      debugPrint('❌ No TMDB streaming data available for movie $movieId');
      return null;
    }

    final region = providers['region'] as String?;
    debugPrint('🌍 Checking streaming availability for movie $movieId in region: $region');

    // If no platform filter is selected, use the best available platform
    if (selectedPlatform == null) {
      return getBestStreamingPlatform(movieId);
    }

    // Collect all available providers
    final allProviders = <Map<String, dynamic>>[];
    
    // Add flatrate providers (subscription - highest priority)
    final flatrate = providers['flatrate'] as List<dynamic>;
    for (final provider in flatrate) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'flatrate',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add free providers
    final free = providers['free'] as List<dynamic>;
    for (final provider in free) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'free',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add ad-supported providers
    final ads = providers['ads'] as List<dynamic>;
    for (final provider in ads) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'ads',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add rent providers (lower priority)
    final rent = providers['rent'] as List<dynamic>;
    for (final provider in rent) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'rent',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add buy providers (lowest priority)
    final buy = providers['buy'] as List<dynamic>;
    for (final provider in buy) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'buy',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    if (allProviders.isEmpty) {
      debugPrint('❌ No streaming providers found for movie $movieId');
      return null;
    }

    // FIRST: Try to find the selected platform
    for (final provider in allProviders) {
      final providerName = provider['provider'] as String;
      final mappedPlatform = _mapProviderToPlatform(providerName);
      
      if (mappedPlatform == selectedPlatform) {
        debugPrint('✅ Found selected platform: $selectedPlatform ($providerName)');
        _platformForFilterCache[cacheKey] = selectedPlatform;
        return _platformForFilterCache[cacheKey];
      }
    }

    // SECOND: If selected platform not found, show "not available" instead of falling back
    debugPrint('❌ Selected platform $selectedPlatform not available for this movie');
    debugPrint('📊 Available platforms: ${allProviders.map((p) => _mapProviderToPlatform(p['provider'] as String)).where((p) => p != null).toList()}');
    
    // Return null to indicate the selected platform is not available
    _platformForFilterCache[cacheKey] = null;
    return _platformForFilterCache[cacheKey];
  }

  // Get all available platforms for a movie
  Future<List<String>> getAllAvailablePlatforms(int movieId) async {
    if (_allPlatformsCache.containsKey(movieId)) return _allPlatformsCache[movieId]!;
    final providers = await fetchWatchProviders(movieId);
    if (providers == null) {
      return [];
    }

    final allProviders = <Map<String, dynamic>>[];
    
    // Add flatrate providers (subscription - highest priority)
    final flatrate = providers['flatrate'] as List<dynamic>;
    for (final provider in flatrate) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'flatrate',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add free providers
    final free = providers['free'] as List<dynamic>;
    for (final provider in free) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'free',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add ad-supported providers
    final ads = providers['ads'] as List<dynamic>;
    for (final provider in ads) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'ads',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add rent providers (lower priority)
    final rent = providers['rent'] as List<dynamic>;
    for (final provider in rent) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'rent',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Add buy providers (lowest priority)
    final buy = providers['buy'] as List<dynamic>;
    for (final provider in buy) {
      allProviders.add({
        'provider': provider['provider_name'] as String,
        'type': 'buy',
        'priority': _getAffiliatePriority(provider['provider_name'] as String),
      });
    }

    // Get unique platforms
    final platforms = allProviders
        .map((p) => _mapProviderToPlatform(p['provider'] as String))
        .where((p) => p != null)
        .cast<String>()
        .toSet()
        .toList();

    _allPlatformsCache[movieId] = platforms;
    return _allPlatformsCache[movieId]!;
  }

  // Get affiliate revenue priority for a provider (higher = more revenue)
  double _getAffiliatePriority(String providerName) {
    final affiliatePriorities = {
      'Amazon Video': 10.0,      // Highest affiliate potential
      'Amazon Prime Video': 10.0, // Highest affiliate potential
      'Prime Video': 10.0,        // Highest affiliate potential
      'Apple TV': 8.0,           // High affiliate potential
      'Apple TV Plus': 8.0,      // High affiliate potential
      'HBO Max': 6.0,            // Good affiliate potential
      'HBO': 6.0,                // Good affiliate potential
      'Hulu': 5.0,               // Moderate affiliate potential
      'Netflix': 4.0,            // Lower affiliate potential
      'Disney Plus': 3.0,        // Lower affiliate potential
      'Disney+': 3.0,            // Lower affiliate potential
      'Paramount Plus': 2.0,     // Lower affiliate potential
      'Peacock': 1.0,            // Lower affiliate potential
      'Crunchyroll': 4.0,        // Good affiliate potential for anime
    };
    
    return affiliatePriorities[providerName] ?? 0.0;
  }

  // Test method to check streaming availability for debugging
  Future<void> testStreamingAvailability(int movieId) async {
    debugPrint('🧪 Testing streaming availability for movie $movieId');
    
    try {
      final response = await _dio.get('$_baseUrl/movie/$movieId/watch/providers');
      
      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('📊 Raw TMDB response: $data');
        
        final results = data['results'] as Map<String, dynamic>?;
        if (results != null) {
          debugPrint('🌍 Available regions: ${results.keys.toList()}');
          
          for (final region in results.keys) {
            final regionData = results[region] as Map<String, dynamic>?;
            if (regionData != null) {
              debugPrint('📺 Region $region providers:');
              debugPrint('  Flatrate: ${regionData['flatrate'] ?? []}');
              debugPrint('  Free: ${regionData['free'] ?? []}');
              debugPrint('  Ads: ${regionData['ads'] ?? []}');
              debugPrint('  Rent: ${regionData['rent'] ?? []}');
              debugPrint('  Buy: ${regionData['buy'] ?? []}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error testing streaming availability: $e');
    }
  }

  // Map TMDB provider names to our platform names
  String? _mapProviderToPlatform(String providerName) {
    final providerMap = {
      'Netflix': 'netflix',
      'Amazon Prime Video': 'amazon_prime',
      'Disney Plus': 'disney_plus',

      'Hulu': 'hulu',
      'Apple TV Plus': 'apple_tv',
      'Paramount Plus': 'paramount_plus',
      'Peacock Premium': 'peacock',
      'Peacock': 'peacock',

      'Prime Video': 'amazon_prime',
      'Disney+': 'disney_plus',
      // Add Amazon Video mapping
      'Amazon Video': 'amazon_prime',
      // UK-specific providers
      'Amazon Prime': 'amazon_prime',
      'BBC iPlayer': 'bbc_iplayer',
      'ITV Hub': 'itv_hub',
      'All 4': 'all4',
      'My5': 'my5',
      'BritBox': 'britbox',
      'NOW': 'now_tv',
      'NOW TV': 'now_tv',
      'Sky Go': 'sky_go',
      'BT TV': 'bt_tv',
      'Virgin TV Go': 'virgin_tv',
      // International providers
      'Canal+': 'canal_plus',
      'M6': 'm6',
      'TF1': 'tf1',
      'Arte': 'arte',
      'RTL+': 'rtl_plus',
      'ProSieben': 'prosieben',
      'ZDF': 'zdf',
      'Mediaset': 'mediaset',
      'RAI Play': 'rai_play',
      'Movistar+': 'movistar_plus',
      'Atresplayer': 'atresplayer',

      // Anime and international platforms
      'Crunchyroll': 'crunchyroll',
      'Funimation': 'funimation',
      'HIDIVE': 'hidive',
      'VRV': 'vrv',
      // Note: Crunchyroll has good affiliate opportunities for anime content
    };

    return providerMap[providerName];
  }

  // Get platform display name and styling with softer colors
  Map<String, dynamic> getPlatformInfo(String platform) {
    final platformData = {
      'netflix': {
        'name': 'Netflix',
        'displayName': 'Watch on Netflix',
        'icon': '🎬',
        'color': 0xFFE50914,
        'gradient': [0xFFE50914, 0xFFB20710],
      },
      'amazon_prime': {
        'name': 'Amazon Prime',
        'displayName': 'Watch on Amazon Prime',
        'icon': '📦',
        'color': 0xFF00A8E1,
        'gradient': [0xFF00A8E1, 0xFF0077BE],
      },
      'disney_plus': {
        'name': 'Disney+',
        'displayName': 'Watch on Disney+',
        'icon': '🏰',
        'color': 0xFF113CCF,
        'gradient': [0xFF113CCF, 0xFF0A1F8F],
      },

      'hulu': {
        'name': 'Hulu',
        'displayName': 'Watch on Hulu',
        'icon': '🟢',
        'color': 0xFF1CE783,
        'gradient': [0xFF1CE783, 0xFF0FAF6B],
      },
      'apple_tv': {
        'name': 'Apple TV+',
        'displayName': 'Watch on Apple TV+',
        'icon': '🍎',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
      'paramount_plus': {
        'name': 'Paramount+',
        'displayName': 'Watch on Paramount+',
        'icon': '🔵',
        'color': 0xFF0066CC,
        'gradient': [0xFF0066CC, 0xFF004499],
      },
      'peacock': {
        'name': 'Peacock',
        'displayName': 'Watch on Peacock',
        'icon': '🦚',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
      // UK-specific platforms
      'bbc_iplayer': {
        'name': 'BBC iPlayer',
        'displayName': 'Watch on BBC iPlayer',
        'icon': '📺',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
      'itv_hub': {
        'name': 'ITV Hub',
        'displayName': 'Watch on ITV Hub',
        'icon': '📺',
        'color': 0xFFE50914,
        'gradient': [0xFFE50914, 0xFFB20710],
      },
      'all4': {
        'name': 'All 4',
        'displayName': 'Watch on All 4',
        'icon': '📺',
        'color': 0xFF00A8E1,
        'gradient': [0xFF00A8E1, 0xFF0077BE],
      },
      'my5': {
        'name': 'My5',
        'displayName': 'Watch on My5',
        'icon': '📺',
        'color': 0xFF113CCF,
        'gradient': [0xFF113CCF, 0xFF0A1F8F],
      },
      'britbox': {
        'name': 'BritBox',
        'displayName': 'Watch on BritBox',
        'icon': '🇬🇧',
        'color': 0xFF5F2EEA,
        'gradient': [0xFF5F2EEA, 0xFF3F1F9A],
      },
      'now_tv': {
        'name': 'NOW TV',
        'displayName': 'Watch on NOW TV',
        'icon': '📺',
        'color': 0xFF1CE783,
        'gradient': [0xFF1CE783, 0xFF0FAF6B],
      },
      'sky_go': {
        'name': 'Sky Go',
        'displayName': 'Watch on Sky Go',
        'icon': '☁️',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
      'bt_tv': {
        'name': 'BT TV',
        'displayName': 'Watch on BT TV',
        'icon': '📺',
        'color': 0xFF0066CC,
        'gradient': [0xFF0066CC, 0xFF004499],
      },
      'virgin_tv': {
        'name': 'Virgin TV',
        'displayName': 'Watch on Virgin TV',
        'icon': '📺',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
      // Anime and international platforms
      'crunchyroll': {
        'name': 'Crunchyroll',
        'displayName': 'Watch on Crunchyroll',
        'icon': '🍊',
        'color': 0xFFF47521,
        'gradient': [0xFFF47521, 0xFFE65A00],
      },
      'funimation': {
        'name': 'Funimation',
        'displayName': 'Watch on Funimation',
        'icon': '🎬',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
      'hidive': {
        'name': 'HIDIVE',
        'displayName': 'Watch on HIDIVE',
        'icon': '🎬',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
      'vrv': {
        'name': 'VRV',
        'displayName': 'Watch on VRV',
        'icon': '🎬',
        'color': 0xFF000000,
        'gradient': [0xFF000000, 0xFF333333],
      },
    };

    return platformData[platform] ?? {
      'name': 'Unknown',
      'displayName': 'Watch Now',
      'icon': '❓',
      'color': 0xFF666666,
      'gradient': [0xFF666666, 0xFF444444],
    };
  }

  // Get list of platforms with affiliate opportunities
  List<String> getAffiliatePlatforms() {
    return [
      'amazon_prime', 'netflix', 'disney_plus', 'hbo_max', 
      'hulu', 'apple_tv', 'paramount_plus', 'peacock', 'crunchyroll'
    ];
  }

  // Get affiliate priority score for a platform
  double getAffiliatePriorityScore(String platform) {
    final affiliateScores = {
      'amazon_prime': 10.0,  // High affiliate potential
      'netflix': 8.0,        // Good affiliate potential
      'disney_plus': 7.0,    // Good affiliate potential
      'hbo_max': 6.0,        // Moderate affiliate potential
      'hulu': 5.0,           // Moderate affiliate potential
      'crunchyroll': 4.0,    // Good affiliate potential for anime
      'apple_tv': 3.0,       // Lower affiliate potential
      'paramount_plus': 2.0, // Lower affiliate potential
      'peacock': 1.0,        // Lower affiliate potential
    };
    
    return affiliateScores[platform] ?? 0.0;
  }
} 