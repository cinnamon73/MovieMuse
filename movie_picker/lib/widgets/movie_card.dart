import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';
import '../utils/language_utils.dart';
import '../widgets/friend_selection_modal.dart';
import '../widgets/bookmark_badge.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onMarkWatched;
  final VoidCallback onBookmark;
  final bool isBookmarked;
  final bool isWatched;
  final double? rating;
  final double swipeProgress; // -1 to 1, negative for left, positive for right
  final MovieService? movieService; // Optional for quality checking
  final ValueChanged<double>? onRatingChanged;
  final String? recommendedBy; // NEW: Who recommended this movie

  const MovieCard({
    super.key,
    required this.movie,
    required this.onMarkWatched,
    required this.onBookmark,
    this.isBookmarked = false,
    this.isWatched = false,
    this.rating,
    this.swipeProgress = 0,
    this.movieService,
    this.onRatingChanged,
    this.recommendedBy, // NEW: Optional recommender name
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Poster or inline trailer placeholder (double-tap handled in parent)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildOptimizedImage(),
          ),
          // Swipe Feedback Overlay
          if (swipeProgress != 0)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color:
                      swipeProgress < 0
                          ? Colors.red.withValues(
                            alpha: swipeProgress.abs() * 0.3,
                          )
                          : Colors.green.withValues(
                            alpha: swipeProgress.abs() * 0.3,
                          ),
                ),
                child: Center(
                  child: Text(
                    swipeProgress < 0 ? 'Not Interested' : 'Watched',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.displayTitle,
                  style: AppTypography.movieTitle.copyWith(color: Colors.white),
                ),
                // NEW: Recommended by tag
                if (recommendedBy != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.8),
                          AppColors.secondary.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Recommended by $recommendedBy',
                          style: AppTypography.metadataText.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '⭐ ${movie.formattedScore}',
                      style: AppTypography.ratingText.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Language: ${LanguageUtils.getFullLanguageName(movie.language)}',
                      style: AppTypography.secondaryText.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Genres: ${movie.genre}${movie.uniqueSubgenre.isNotEmpty ? ", ${movie.uniqueSubgenre}" : ""}',
                  style: AppTypography.secondaryText.copyWith(
                    color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                        ),
                const SizedBox(height: 8),
                            Text(
                  'Release: ${movie.releaseDate}',
                  style: AppTypography.secondaryText.copyWith(
                    color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                ),
                const SizedBox(height: 12),
                Text(
                  movie.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.movieDescription.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (onRatingChanged != null) ...[
                  Row(
                    children: [
                      Text(
                        'Your Rating:',
                        style: AppTypography.secondaryText.copyWith(color: Colors.white70),
                      ),
                      Expanded(
                        child: Slider(
                          value: rating ?? 0.0,
                          min: 0.0,
                          max: 10.0,
                          divisions: 20,
                          label: (rating ?? 0.0).toStringAsFixed(1),
                          onChanged: onRatingChanged,
                        ),
                      ),
                      Text(
                        rating != null ? rating!.toStringAsFixed(1) : '-',
                        style: AppTypography.ratingText.copyWith(color: Colors.amber),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Quality indicator badge
          if (movieService != null && !movieService!.isHighQualityMovie(movie))
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getQualityBadgeColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getQualityBadgeIcon(), color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _getQualityBadgeText(),
                      style: AppTypography.metadataText.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bookmark badge overlay
          if (isBookmarked)
            Positioned(
              top: 16,
              left: 16,
              child: BookmarkBadge(
                isBookmarked: isBookmarked,
                onToggle: onBookmark,
                size: 20,
                showLabel: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptimizedImage() {
    // Check if URL is valid
    if (movie.posterUrl.isEmpty ||
        movie.posterUrl.contains('placeholder') ||
        movie.posterUrl == 'null') {
      return _buildFallbackImage('Invalid poster URL');
    }

    // Ensure URL is properly formatted
    String imageUrl = movie.posterUrl;
    if (!imageUrl.startsWith('http')) {
      if (imageUrl.startsWith('/')) {
        imageUrl = 'https://image.tmdb.org/t/p/w500$imageUrl';
      } else {
        return _buildFallbackImage('Invalid URL format');
      }
    }

    // Simple approach - just use CachedNetworkImage with minimal configuration
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder:
          (context, url) => Container(
            color: Colors.grey[800],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white54),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    style: AppTypography.movieDescription.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      errorWidget: (context, url, error) {
        return _buildFallbackImage('Image failed to load');
      },
    );
  }

  Widget _buildFallbackImage(String message) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.movie, color: Colors.white54, size: 60),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(
                movie.title,
                style: AppTypography.movieTitleLarge.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.metadataText.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to retry',
                    style: AppTypography.genreTag.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getQualityBadgeColor() {
    if (movieService == null) return Colors.grey;

    final score = movieService!.getMovieScore(movie);

    if (score < 30) {
      return Colors.red.withValues(alpha: 0.9);
    } else if (score < 50) {
      return Colors.orange.withValues(alpha: 0.9);
    } else {
      return Colors.yellow.withValues(alpha: 0.9);
    }
  }

  IconData _getQualityBadgeIcon() {
    if (movieService == null) return Icons.help_outline;

    final score = movieService!.getMovieScore(movie);

    if (score < 30) {
      return Icons.warning;
    } else if (score < 50) {
      return Icons.info_outline;
    } else {
      return Icons.star_border;
    }
  }

  String _getQualityBadgeText() {
    if (movieService == null) return 'Unknown';

    final score = movieService!.getMovieScore(movie);

    if (score < 30) {
      return 'Low Quality';
    } else if (score < 50) {
      return 'Fair Quality';
    } else {
      return 'OK Quality';
    }
  }

  // Helper method to get genre-specific colors
  Color _getGenreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'action':
        return AppColors.genreAction.withValues(alpha: 0.8);
      case 'comedy':
        return AppColors.genreComedy.withValues(alpha: 0.8);
      case 'drama':
        return AppColors.genreDrama.withValues(alpha: 0.8);
      case 'horror':
        return AppColors.genreHorror.withValues(alpha: 0.8);
      case 'romance':
        return AppColors.genreRomance.withValues(alpha: 0.8);
      case 'science fiction':
      case 'sci-fi':
        return AppColors.genreSciFi.withValues(alpha: 0.8);
      default:
        return AppColors.genreDefault.withValues(alpha: 0.8);
    }
  }
}
