import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';
import '../services/movie_service.dart';
import '../services/streaming_service.dart';
import '../widgets/enhanced_cast_crew_section.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/affiliate_link_service.dart';
import '../services/server_streaming_service.dart';
import '../widgets/trailer_player_sheet.dart';
import '../services/firebase_platform_service.dart';
import '../widgets/friend_selection_modal.dart';
import '../utils/language_utils.dart';
import '../widgets/movie_reviews_section.dart';
import '../services/recommendation_service.dart';
import '../services/firebase_images_service.dart';
import 'dart:ui' show PointerDeviceKind;

class MovieDetailsPage extends StatefulWidget {
  final Movie movie;
  final List<String> cast;
  final bool isBookmarked;
  final bool isWatched;
  final double currentRating;
  final VoidCallback onBookmark;
  final VoidCallback onMarkWatched;
  final Function(double) onRatingChanged;
  final Function(String, String)? onPersonTap;
  final bool showRatingSystem;
  final String? selectedPlatform;
  final List<Movie>? contextPool; // optional pool for match normalization
  final double? matchPercent; // optional precomputed match percent
  final bool allowWatchedAction; // control whether Watched button is shown
  final bool allowBookmarkAction; // control whether bookmark remove is shown
  final bool showMatchBadge; // show match percentage badge on page

  const MovieDetailsPage({
    Key? key,
    required this.movie,
    required this.cast,
    required this.isBookmarked,
    required this.isWatched,
    required this.currentRating,
    required this.onBookmark,
    required this.onMarkWatched,
    required this.onRatingChanged,
    this.onPersonTap,
    this.showRatingSystem = true,
    this.selectedPlatform,
    this.contextPool,
    this.matchPercent,
    this.allowWatchedAction = true,
    this.allowBookmarkAction = false,
    this.showMatchBadge = false,
  }) : super(key: key);

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late double _currentRating;
  double? _computedMatch;
  final RecommendationService _recService = RecommendationService();
  final FirebaseImagesService _imagesService = FirebaseImagesService();
  bool _loadingPhotos = false;
  List<Map<String, dynamic>> _photos = [];
  int _currentPhotoIndex = 0;
  final PageController _photosController = PageController(viewportFraction: 0.9, initialPage: 5000);
  Future<String?>? _platformFuture;
  Future<List<String>>? _allPlatformsFuture;
  // Prefetched links to avoid slow taps
  String? _prefetchedAmazonUrl;
  String? _prefetchedProviderUrl;
  String? _prefetchedTrailerUrl;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.currentRating;
    _maybeComputeMatch();
    _loadPhotos();
    // Memoize streaming futures
    final streaming = StreamingService();
    _platformFuture = streaming.getStreamingPlatformForFilter(widget.movie.id, widget.selectedPlatform);
    _allPlatformsFuture = streaming.getAllAvailablePlatforms(widget.movie.id);
    _prefetchLinks();
  }

  Future<void> _prefetchLinks() async {
    try {
      final region = await _inferCountryCode();
      _prefetchedTrailerUrl = await MovieService().fetchTrailerUrl(widget.movie.id);

      // Decide best platform first
      final platform = await _platformFuture;
      if (platform == 'amazon_prime') {
        // Try override, PA-API, then search in parallel with timeouts
        String? imdbId;
        try {
          final external = await MovieService().fetchExternalIds(widget.movie.id);
          imdbId = external['imdb_id'];
        } catch (_) {}

        final overrideF = FirebasePlatformService().getDirectProviderUrl(
          movieId: widget.movie.id,
          provider: 'amazon_prime',
          countryCode: region,
        );
        final directF = ServerStreamingService().getAmazonDirectLink(
          title: widget.movie.title,
          year: widget.movie.releaseDate,
          imdbId: imdbId,
          country: region,
        );

        final results = await Future.wait<String?>([
          overrideF.catchError((_) => null),
          directF.catchError((_) => null),
        ]).timeout(const Duration(seconds: 6), onTimeout: () => [null, null]);

        final overrideUrl = results.isNotEmpty ? results[0] : null;
        final directUrl = results.length > 1 ? results[1] : null;

        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          _prefetchedAmazonUrl = AffiliateLinkService.ensureAmazonAffiliateTag(overrideUrl, countryCode: region);
        } else if (directUrl != null && directUrl.isNotEmpty) {
          _prefetchedAmazonUrl = AffiliateLinkService.ensureAmazonAffiliateTag(directUrl, countryCode: region);
        } else {
          _prefetchedAmazonUrl = AffiliateLinkService.buildAmazonSearchUrl(
            title: widget.movie.title,
            year: widget.movie.releaseDate,
            imdbId: imdbId,
            countryCode: region,
          );
        }
      } else if (platform != null) {
        // Non-Amazon: try provider direct, else TMDB watch
        final direct = await ServerStreamingService().getProviderDirectLink(
          title: widget.movie.title,
          year: widget.movie.releaseDate,
          provider: platform,
          country: region,
        ).timeout(const Duration(seconds: 6), onTimeout: () => null);
        _prefetchedProviderUrl = direct ?? StreamingService().buildTmdbWatchUrl(
          movieId: widget.movie.id,
          region: region,
        );
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Prefetch failures are non-fatal
    }
  }

  Future<void> _loadPhotos() async {
    setState(() => _loadingPhotos = true);
    // Use project id from .firebaserc
    const firebaseProjectId = 'moviemuse-2bc27';
    final images = await _imagesService.ensureBackdropsForMovie(
      movieId: widget.movie.id,
      firebaseProjectId: firebaseProjectId,
    );
    if (!mounted) return;
    setState(() {
      _photos = images;
      _loadingPhotos = false;
      _currentPhotoIndex = 0;
    });
  }

  // Try to infer a sensible country code for affiliate links.
  // We use the first region found from TMDB providers if available; otherwise fall back to device locale.
  Future<String> _inferCountryCode() async {
    try {
      final providers = await StreamingService().fetchWatchProviders(widget.movie.id);
      final region = providers != null ? (providers['region'] as String?) : null;
      if (region != null && region.isNotEmpty) return region;
    } catch (_) {}
    final locale = Localizations.maybeLocaleOf(context);
    final country = locale?.countryCode;
    if (country != null && country.isNotEmpty) return country;
    return 'US';
  }

  Future<void> _maybeComputeMatch() async {
    if (widget.matchPercent != null) {
      setState(() => _computedMatch = widget.matchPercent);
      return;
    }
    try {
      await _recService.initialize();
      final pool = widget.contextPool ?? <Movie>[];
      if (pool.isEmpty) {
        setState(() => _computedMatch = null);
        return;
      }
      final pct = await _recService.getMatchPercentForCurrentUser(
        movie: widget.movie,
        contextPool: pool,
      );
      if (mounted) setState(() => _computedMatch = pct);
    } catch (_) {
      if (mounted) setState(() => _computedMatch = null);
    }
  }

  void _updateRating(double newRating) {
    setState(() {
      _currentRating = newRating;
    });
    widget.onRatingChanged(newRating);
  }

  void _showRatingDialog() {
    double tempRating = 0.0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Rate "${widget.movie.title}"',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_computedMatch != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_computedMatch!.toStringAsFixed(0)}% match for you',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'How would you rate this movie?',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // 10-star rating system - make it responsive
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 8,
                  children: List.generate(10, (index) {
                    final starNumber = index + 1;
                    final isGold = starNumber <= tempRating;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          tempRating = starNumber.toDouble();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        child: Column(
                          children: [
                            Icon(
                              Icons.star,
                              size: 24,
                              color: isGold ? Colors.amber : Colors.grey[600],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$starNumber',
                              style: TextStyle(
                                color: isGold ? Colors.amber : Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                if (tempRating > 0)
                  Text(
                    'Rating: ${tempRating.toStringAsFixed(0)}/10',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: tempRating > 0 ? () {
                Navigator.of(context).pop();
                _updateRating(tempRating);
                widget.onMarkWatched();
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rate & Mark Watched'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isSmallScreen = width < 400;
    
    final genres = <String>{};
    if (widget.movie.genre.isNotEmpty) genres.add(widget.movie.genre);
    if (widget.movie.subgenre.isNotEmpty && widget.movie.subgenre != widget.movie.genre) genres.add(widget.movie.subgenre);
    final genresString = genres.isNotEmpty ? genres.join(", ") : null;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.movie.displayTitle,
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 24),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: widget.movie.posterUrl,
                      width: isSmallScreen ? width * 0.6 : (width < 400 ? width * 0.7 : 250),
                      height: isSmallScreen ? width * 0.9 : (width < 400 ? width * 1.05 : 375),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.movie.displayTitle,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.showMatchBadge)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.psychology, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _computedMatch != null
                            ? '${_computedMatch!.toStringAsFixed(0)}% match for you'
                            : 'Calculating match…',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                      '⭐ ${widget.movie.formattedScore}',
                        style: TextStyle(
                          color: Colors.amber, 
                          fontSize: isSmallScreen ? 16 : 18
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                      'Language: ${LanguageUtils.getFullLanguageName(widget.movie.language)}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (genresString != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Genres: $genresString',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Release Date: ${widget.movie.releaseDate}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'Overview:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.movie.description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (widget.allowBookmarkAction && widget.isBookmarked)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: ElevatedButton.icon(
                            onPressed: widget.onBookmark,
                            icon: Icon(
                              Icons.bookmark_remove,
                              color: Colors.white,
                              size: isSmallScreen ? 16 : 18,
                            ),
                            label: Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 10 : 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 8 : 10, 
                                horizontal: isSmallScreen ? 4 : 6
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),
                    
                    // Watched Button (optional)
                    if (widget.allowWatchedAction)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton.icon(
                          onPressed: widget.isWatched ? null : _showRatingDialog,
                          icon: Icon(
                            widget.isWatched ? Icons.check_circle : Icons.check_circle_outline,
                            color: Colors.white,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          label: Text(
                            widget.isWatched ? 'Watched' : 'Watched',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isWatched ? Colors.green[700] : AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 8 : 10, 
                              horizontal: isSmallScreen ? 4 : 6
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                    
                    // Share Button
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => FriendSelectionModal(
                                movieId: widget.movie.id.toString(),
                                movieTitle: widget.movie.title,
                                onMovieShared: () {
                                  // Optional: Add any callback when movie is shared
                                },
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.share, 
                            color: Colors.white, 
                            size: isSmallScreen ? 16 : 18
                          ),
                          label: Text(
                            'Share',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 8 : 10, 
                              horizontal: isSmallScreen ? 4 : 6
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                    // Trailer Button (in-app playback only)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final trailerUrl = await MovieService().fetchTrailerUrl(widget.movie.id);
                            if (!mounted) return;
                            if (trailerUrl == null) {
                              _showComingSoonDialog('Trailer');
                              return;
                            }
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.black,
                              builder: (_) => SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: TrailerPlayerSheet(youtubeUrl: trailerUrl),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          label: Text(
                            'Trailer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 8 : 10,
                              horizontal: isSmallScreen ? 4 : 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Clean Single Streaming Button
                FutureBuilder<String?>(
                  future: _platformFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(width: 16),
                            Text(
                              'Checking availability...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    }

                    final platform = snapshot.data;
                    if (platform == null) {
                      // Show more helpful message when platform filter is active
                      if (widget.selectedPlatform != null) {
                        final platformInfo = StreamingService().getPlatformInfo(widget.selectedPlatform!);
                        return FutureBuilder<List<String>>(
                          future: _allPlatformsFuture,
                          builder: (context, platformsSnapshot) {
                            final availablePlatforms = platformsSnapshot.data ?? [];
                            final platformNames = availablePlatforms
                                .map((p) => StreamingService().getPlatformInfo(p)['name'] as String)
                                .join(', ');
                            
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Not available on ${platformInfo['name']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This movie is not currently streaming on ${platformInfo['name']}.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (availablePlatforms.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Available on: $platformNames',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try removing the platform filter to see all available options.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      } else {
                        // Generic message when no platform filter is active
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white70),
                            SizedBox(width: 12),
                            Text(
                              'Not available on streaming platforms',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                      }
                    }

                    final platformInfo = StreamingService().getPlatformInfo(platform);
                    final gradientColors = platformInfo['gradient'] as List<int>;
                    
                    return Container(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            // If Amazon is selected/best platform, open affiliate search link
                            if (platform == 'amazon_prime') {
                              final countryCode = await _inferCountryCode();
                              // Use prefetched if available for instant open
                              if (_prefetchedAmazonUrl != null) {
                                final uri = Uri.parse(_prefetchedAmazonUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  return;
                                }
                              }
                              // Try to enrich search with IMDb ID for better precision
                              String? imdbId;
                              try {
                                final external = await MovieService().fetchExternalIds(widget.movie.id);
                                imdbId = external['imdb_id'];
                              } catch (_) {}
                              // 0) Firestore overrides (manual deep links without PA-API)
                              try {
                                final overrideUrl = await FirebasePlatformService().getDirectProviderUrl(
                                  movieId: widget.movie.id,
                                  provider: 'amazon_prime',
                                  countryCode: countryCode,
                                );
                                if (overrideUrl != null && overrideUrl.isNotEmpty) {
                                  final uri = Uri.parse(AffiliateLinkService.ensureAmazonAffiliateTag(overrideUrl, countryCode: countryCode));
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    return;
                                  }
                                }
                              } catch (_) {}
                              // First, try direct detail link via server PA-API
                              try {
                                final directUrl = await ServerStreamingService().getAmazonDirectLink(
                                  title: widget.movie.title,
                                  year: widget.movie.releaseDate,
                                  imdbId: imdbId,
                                  country: countryCode,
                                );
                                if (directUrl != null && directUrl.isNotEmpty) {
                                  final uri = Uri.parse(AffiliateLinkService.ensureAmazonAffiliateTag(directUrl, countryCode: countryCode));
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    return;
                                  }
                                }
                              } catch (_) {}
                              final searchUrl = AffiliateLinkService.buildAmazonSearchUrl(
                                title: widget.movie.title,
                                year: widget.movie.releaseDate,
                                imdbId: imdbId,
                                countryCode: countryCode,
                              );
                              final uri = Uri.parse(searchUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                return;
                              }
                            }
                            // Non-Amazon providers: try direct provider link via server (JustWatch), else TMDB watch page
                            try {
                              final region = await _inferCountryCode();
                              // Use prefetched if available for instant open
                              if (_prefetchedProviderUrl != null) {
                                final uri = Uri.parse(_prefetchedProviderUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  return;
                                }
                              }
                              // Attempt direct link
                              final direct = await ServerStreamingService().getProviderDirectLink(
                                title: widget.movie.title,
                                year: widget.movie.releaseDate,
                                provider: platform, // our platform key (e.g., netflix, disney_plus)
                                country: region,
                              );
                              final urlToOpen = direct ?? StreamingService().buildTmdbWatchUrl(
                                movieId: widget.movie.id,
                                region: region,
                              );
                              final uri = Uri.parse(urlToOpen);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                return;
                              }
                            } catch (_) {}
                            _showComingSoonDialog(platformInfo['name']);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(gradientColors[0]).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Color(gradientColors[0]).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  platformInfo['icon'],
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        platformInfo['displayName'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Tap to watch',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(gradientColors[0]).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    platform == 'amazon_prime' ? 'Watch Now' : 'Coming Soon',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Photos (auto-loaded)
                if (_loadingPhotos)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                        SizedBox(width: 12),
                        Text('Loading photos...', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                if (!_loadingPhotos && _photos.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        height: 180,
                        child: ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.stylus,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: PageView.builder(
                            controller: _photosController,
                            padEnds: true,
                            pageSnapping: true,
                            physics: const BouncingScrollPhysics(),
                            onPageChanged: (i) {
                              setState(() => _currentPhotoIndex = i % _photos.length);
                            },
                            itemBuilder: (context, rawIndex) {
                              // Loop by mapping index
                              final index = rawIndex % _photos.length;
                              final p = _photos[index];
                              final url = p['url_w780'] as String? ?? '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                            itemCount: _photos.isEmpty ? 0 : 10000, // large number to simulate infinite loop
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_photos.length, (i) {
                          final isActive = i == _currentPhotoIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 10 : 6,
                            height: isActive ? 10 : 6,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Enhanced Cast and Crew Section
                EnhancedCastCrewSection(movie: widget.movie, onPersonTap: widget.onPersonTap),

                const SizedBox(height: 24),
                // Rating Section
                if (widget.showRatingSystem && _currentRating > 0) ...[
                    Text(
                    'Your Rating: ${_currentRating.toStringAsFixed(0)}/10',
                    style: AppTypography.movieTitle.copyWith(color: Colors.amber),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 10-star rating system for changing rating
                if (widget.showRatingSystem) ...[
                Text(
                  'Your Rating:',
                  style: AppTypography.movieTitle.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(10, (index) {
                    final starNumber = index + 1;
                      final isGold = starNumber <= _currentRating;
                    return GestureDetector(
                        onTap: () => _updateRating(starNumber.toDouble()),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        child: Column(
                          children: [
                            Icon(
                              Icons.star,
                              size: 22,
                              color: isGold ? Colors.amber : Colors.grey[600],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$starNumber',
                              style: TextStyle(
                                color: isGold ? Colors.amber : Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                        ),
                      ),
                    );
                  }),
                ),
                ],

                const SizedBox(height: 24),
                // Reviews Section
                MovieReviewsSection(
                  movieId: widget.movie.id,
                  movieTitle: widget.movie.title,
                  currentUsername: '',
                  canReview: widget.isWatched,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog(String platform) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Watch on $platform',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'This feature is coming soon! Users will be able to watch "${widget.movie.title}" directly on $platform with one tap.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

