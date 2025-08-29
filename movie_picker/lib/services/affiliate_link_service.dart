import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utility functions for building and appending affiliate parameters
/// to outbound links. Initial focus: Amazon/Prime Video.
class AffiliateLinkService {
  /// Returns an amazon.{tld} search URL for the given title/year with the proper
  /// affiliate tag for the provided [countryCode] (ISO-2 like US, GB, DE...).
  /// Falls back to amazon.com and the US tag if no match is found.
  static String buildAmazonSearchUrl({
    required String title,
    String? year,
    String? imdbId,
    String countryCode = 'GB',
  }) {
    final domain = _amazonDomainForCountry(countryCode);
    final tag = _amazonTagForCountry(countryCode);

    // Build a user-friendly search query: Title + Year only (exclude IMDb IDs like tt7181546)
    final query = [
      title,
      if (year != null && year.trim().isNotEmpty) year.trim(),
    ]
        .where((v) => v != null && v!.isNotEmpty)
        .map((v) => v!)
        .join(' ');

    final uri = Uri.https(domain, '/s', {
      'k': query,
      'i': 'instant-video',
      if (tag != null && tag.isNotEmpty) 'tag': tag,
    });

    return uri.toString();
  }

  /// Returns an amazon.{tld} detail page URL for an ASIN with the affiliate tag applied.
  /// Note: For Prime Video, ASIN-style IDs are used internally by Amazon; only use this
  /// if you have a reliable ASIN for the title in the target marketplace.
  static String buildAmazonDetailUrlFromAsin({
    required String asin,
    String countryCode = 'GB',
  }) {
    final domain = _amazonDomainForCountry(countryCode);
    final tag = _amazonTagForCountry(countryCode);

    final uri = Uri.https(
      domain,
      '/gp/video/detail/$asin',
      {
        if (tag != null && tag.isNotEmpty) 'tag': tag,
      },
    );
    return uri.toString();
  }

  /// Append or replace the Amazon Associates tag for URLs pointing to amazon.{tld}.
  /// - Leaves amzn.to shortlinks unchanged (they cannot be modified reliably).
  /// - Preserves all other existing query parameters.
  /// - If [countryCode] is provided, the tag for that country is enforced; otherwise
  ///   tries to infer from domain and falls back to US.
  static String ensureAmazonAffiliateTag(String url, {String? countryCode}) {
    Uri? parsed;
    try {
      parsed = Uri.parse(url);
    } catch (_) {
      return url;
    }

    if (parsed.host.isEmpty) return url;

    // Do not attempt to modify Amazon shortlinks.
    if (parsed.host == 'amzn.to') return url;

    final isAmazon = _isAmazonDomain(parsed.host);
    if (!isAmazon) return url;

    final inferredCountry = countryCode ?? _inferCountryFromAmazonHost(parsed.host) ?? 'GB';
    final tag = _amazonTagForCountry(inferredCountry);
    if (tag == null || tag.isEmpty) return url; // No tag configured; return as-is

    // Merge/replace 'tag' query param
    final newQuery = Map<String, dynamic>.from(parsed.queryParameters);
    newQuery['tag'] = tag;

    final rebuilt = parsed.replace(queryParameters: newQuery);
    return rebuilt.toString();
  }

  /// True if host looks like an Amazon retail domain (not PrimeVideo).
  static bool _isAmazonDomain(String host) {
    return host == 'amazon.com' ||
        host.endsWith('.amazon.com') ||
        host.endsWith('.amazon.co.uk') ||
        host.endsWith('.amazon.de') ||
        host.endsWith('.amazon.fr') ||
        host.endsWith('.amazon.it') ||
        host.endsWith('.amazon.es') ||
        host.endsWith('.amazon.ca') ||
        host.endsWith('.amazon.com.au') ||
        host.endsWith('.amazon.co.jp') ||
        host.endsWith('.amazon.in') ||
        host.endsWith('.amazon.com.br') ||
        host.endsWith('.amazon.nl') ||
        host.endsWith('.amazon.se') ||
        host.endsWith('.amazon.pl') ||
        host.endsWith('.amazon.com.mx');
  }

  /// Map ISO-2 country code to the closest Amazon retail domain.
  static String _amazonDomainForCountry(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'GB':
      case 'UK':
        return 'www.amazon.co.uk';
      case 'DE':
        return 'www.amazon.de';
      case 'FR':
        return 'www.amazon.fr';
      case 'IT':
        return 'www.amazon.it';
      case 'ES':
        return 'www.amazon.es';
      case 'CA':
        return 'www.amazon.ca';
      case 'AU':
        return 'www.amazon.com.au';
      case 'JP':
        return 'www.amazon.co.jp';
      case 'IN':
        return 'www.amazon.in';
      case 'BR':
        return 'www.amazon.com.br';
      case 'NL':
        return 'www.amazon.nl';
      case 'SE':
        return 'www.amazon.se';
      case 'PL':
        return 'www.amazon.pl';
      case 'MX':
        return 'www.amazon.com.mx';
      case 'US':
      default:
        return 'www.amazon.com';
    }
  }

  /// Attempt to infer country from the Amazon host.
  static String? _inferCountryFromAmazonHost(String host) {
    if (host.endsWith('.amazon.com')) return 'US';
    if (host.endsWith('.amazon.co.uk')) return 'GB';
    if (host.endsWith('.amazon.de')) return 'DE';
    if (host.endsWith('.amazon.fr')) return 'FR';
    if (host.endsWith('.amazon.it')) return 'IT';
    if (host.endsWith('.amazon.es')) return 'ES';
    if (host.endsWith('.amazon.ca')) return 'CA';
    if (host.endsWith('.amazon.com.au')) return 'AU';
    if (host.endsWith('.amazon.co.jp')) return 'JP';
    if (host.endsWith('.amazon.in')) return 'IN';
    if (host.endsWith('.amazon.com.br')) return 'BR';
    if (host.endsWith('.amazon.nl')) return 'NL';
    if (host.endsWith('.amazon.se')) return 'SE';
    if (host.endsWith('.amazon.pl')) return 'PL';
    if (host.endsWith('.amazon.com.mx')) return 'MX';
    return null;
  }

  /// Look up the Associate tag for a given marketplace. Configure these in .env
  /// without checking secrets into source control.
  /// Example keys:
  ///  - AMZN_ASSOC_TAG_US
  ///  - AMZN_ASSOC_TAG_GB
  ///  - AMZN_ASSOC_TAG_DE ... etc
  static String? _amazonTagForCountry(String countryCode) {
    final code = countryCode.toUpperCase();
    final keys = [
      'AMZN_ASSOC_TAG_$code', // region-specific Associates tag
      'AMZN_ASSOC_TAG',       // global fallback Associates tag
      'AMZN_PARTNER_TAG',     // PA-API partner tag fallback if provided
    ];
    for (final k in keys) {
      final v = dotenv.env[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}


