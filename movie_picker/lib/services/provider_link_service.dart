import 'dart:convert';
import 'affiliate_link_service.dart';

/// Builds public search URLs for streaming providers using title + optional year.
/// Amazon search includes the affiliate tag via AffiliateLinkService.
class ProviderLinkService {
  static String buildSearchUrl({
    required String platform,
    required String title,
    String? year,
    String region = 'GB',
  }) {
    final query = _encodeQuery(title, year);
    switch (platform) {
      case 'amazon_prime':
        return AffiliateLinkService.buildAmazonSearchUrl(
          title: title,
          year: year,
          countryCode: region,
        );
      case 'netflix':
        return 'https://www.netflix.com/search?q=$query';
      case 'disney_plus':
        return 'https://www.disneyplus.com/search/$query';
      case 'hulu':
        return 'https://www.hulu.com/search?q=$query';
      case 'hbo_max':
        return 'https://www.max.com/search?q=$query';
      case 'apple_tv':
        return 'https://tv.apple.com/search?term=$query';
      case 'paramount_plus':
        return 'https://www.paramountplus.com/search/?q=$query';
      case 'peacock':
        return 'https://www.peacocktv.com/search?q=$query';
      case 'crunchyroll':
        return 'https://www.crunchyroll.com/search?q=$query';
      default:
        // Generic web search fallback
        return 'https://www.google.com/search?q=${Uri.encodeComponent('$title ${year ?? ''}')}';
    }
  }

  static String _encodeQuery(String title, String? year) {
    final cleanedTitle = title
        .replaceAll(RegExp(r"\s+\(\d{4}\)$"), '') // remove trailing (YYYY)
        .replaceAll(RegExp(r"tt\d{7,}"), '') // strip IMDb IDs if present
        .trim();
    final q = [cleanedTitle, if (year != null && year.trim().isNotEmpty) year.trim()]
        .where((e) => e != null && e!.isNotEmpty)
        .map((e) => e!)
        .join(' ');
    return Uri.encodeComponent(q);
  }
}


