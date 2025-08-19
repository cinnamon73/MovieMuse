import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';
import '../utils/animation_utils.dart';
import '../utils/language_utils.dart';

class WatchedListPage extends StatefulWidget {
  final List<Movie> watchedMovies;
  final Map<int, double> movieRatings;
  final Function(int, double) onRatingChanged;
  final VoidCallback? onBackPressed;

  const WatchedListPage({
    required this.watchedMovies,
    required this.movieRatings,
    required this.onRatingChanged,
    this.onBackPressed,
    Key? key,
  }) : super(key: key);

  @override
  State<WatchedListPage> createState() => _WatchedListPageState();
}

class _WatchedListPageState extends State<WatchedListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watched Movies'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back, color: AppColors.success, size: 24),
          ),
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else {
              Navigator.of(context).pop();
            }
          },
          tooltip: 'Back to Movie Picker',
        ),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child:
            widget.watchedMovies.isEmpty
                ? const Center(
                  child: Text(
                    'No watched movies yet',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: StaggeredListAnimation(
                    children: widget.watchedMovies.map((movie) {
                      final userRating = widget.movieRatings[movie.id] ?? 0.0;

                      return AnimatedButton(
                        onPressed: () {
                          // Add onPressed functionality if needed
                        },
                        child: Card(
                          color: Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Movie poster
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: movie.posterUrl,
                                    width: 80,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.error, color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Movie details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        movie.title,
                                        style: AppTypography.movieTitle.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            movie.voteAverage.toStringAsFixed(1),
                                            style: AppTypography.ratingText,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.calendar_today,
                                            color: Colors.white70,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            movie.releaseDate.split('-')[0],
                                            style: AppTypography.ratingText,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Language: ${LanguageUtils.getFullLanguageName(movie.language)}',
                                        style: AppTypography.movieDescription.copyWith(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        movie.description,
                                        style: AppTypography.movieDescription.copyWith(
                                          fontSize: 12,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      // Rating section
                                      Row(
                                        children: [
                                          Text(
                                            'Your rating: ',
                                            style: AppTypography.movieDescription.copyWith(
                                              fontSize: 12,
                                            ),
                                          ),
                                          RatingBar.builder(
                                            initialRating: userRating,
                                            minRating: 0,
                                            direction: Axis.horizontal,
                                            allowHalfRating: true,
                                            itemCount: 5,
                                            itemSize: 16,
                                            itemBuilder: (context, _) => const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                            ),
                                            onRatingUpdate: (rating) {
                                              widget.onRatingChanged(movie.id, rating);
                                            },
                                          ),
                                        ],
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Watched',
                                          style: AppTypography.movieDescription.copyWith(
                                            color: Colors.green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
      ),
    );
  }
}
