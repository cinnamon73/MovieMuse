import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';
import '../utils/animation_utils.dart';
import '../widgets/swipeable_movie_card.dart';
import '../services/movie_service.dart';

class RatingScreen extends StatefulWidget {
  final List<Movie> moviesToRate;
  final Map<int, double> movieRatings;
  final Function(int, double) onRatingChanged;
  final Function(Movie) onMovieTap;
  final VoidCallback onComplete;
  final VoidCallback? onBackPressed;
  final VoidCallback? onGoToWatched; // New callback for going to watched catalog

  const RatingScreen({
    super.key,
    required this.moviesToRate,
    required this.movieRatings,
    required this.onRatingChanged,
    required this.onMovieTap,
    required this.onComplete,
    this.onBackPressed,
    this.onGoToWatched, // New parameter
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Movie> ratingQueue = [];
  int currentIndex = 0;
  bool isRating = false;
  double? selectedRating; // Track the selected rating for star animation

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _initializeRatingQueue();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeRatingQueue() {
    setState(() {
      ratingQueue = List.from(widget.moviesToRate);
      currentIndex = 0;
      selectedRating = null;
    });
    _fadeController.forward();
    _slideController.forward();
  }

  void _onRateMovie(double rating) {
    if (ratingQueue.isEmpty || currentIndex >= ratingQueue.length) return;
    setState(() {
      isRating = true;
      selectedRating = rating;
    });
    final movie = ratingQueue[currentIndex];
    widget.onRatingChanged(movie.id, rating);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        isRating = false;
        selectedRating = null;
        currentIndex++;
      });
      if (currentIndex >= ratingQueue.length) {
        _onComplete();
      }
    });
  }

  void _onSkipMovie() {
    if (ratingQueue.isEmpty || currentIndex >= ratingQueue.length) return;
    setState(() => currentIndex++);
    if (currentIndex >= ratingQueue.length) {
      _onComplete();
    }
  }

  void _onSkipAll() {
    if (widget.onGoToWatched != null) {
      widget.onGoToWatched!();
    } else {
      _onComplete();
    }
  }

  void _onComplete() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (ratingQueue.isEmpty || currentIndex >= ratingQueue.length) {
      return _buildCompletionScreen();
    }

    final currentMovie = ratingQueue[currentIndex];
    final total = ratingQueue.length;
    final progress = (currentIndex + 1) / total;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Rate Movies',
              style: AppTypography.appBarTitle.copyWith(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background poster image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: currentMovie.posterUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.black),
              errorWidget: (context, url, error) => Container(color: Colors.black),
            ),
          ),
          // Dark gradient overlay for readability
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(180, 0, 0, 0),
                    Color.fromARGB(210, 0, 0, 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Foreground content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Spacer(),

                    // Movie title + meta on top of poster
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            currentMovie.title,
                            style: AppTypography.movieTitle.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              shadows: const [Shadow(blurRadius: 12, color: Colors.black)],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star, color: AppColors.warning, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${currentMovie.voteAverage}  •  ${currentMovie.genre}',
                                style: AppTypography.metadataText.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Stars overlay (interactive)
                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          if (!isRating) ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final maxWidth = constraints.maxWidth;
                                // Star size chosen so 10 stars fit with spaceBetween without overflow
                                final starSize = math.min(36.0, (maxWidth - 2) / 10);
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(10, (index) {
                                    final rating = (index + 1).toDouble();
                                    final active = selectedRating != null && rating <= selectedRating!;
                                    return GestureDetector(
                                      onTap: () => _onRateMovie(rating),
                                      child: Icon(
                                        Icons.star,
                                        size: starSize,
                                        color: active ? AppColors.warning : Colors.white70,
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap a star (1–10)',
                              style: AppTypography.metadataText.copyWith(color: Colors.white70),
                            ),
                          ] else ...[
                            Text(
                              'Rating saved!',
                              style: AppTypography.movieTitle.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final maxWidth = constraints.maxWidth;
                                final starSize = math.min(36.0, (maxWidth - 2) / 10);
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(10, (index) {
                                    final rating = (index + 1).toDouble();
                                    final active = rating <= (selectedRating ?? 0);
                                    return Icon(
                                      Icons.star,
                                      size: starSize,
                                      color: active ? AppColors.warning : Colors.white70,
                                    );
                                  }),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons on the poster
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _onSkipMovie,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.white.withOpacity(0.06),
                            ),
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _onSkipAll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.fast_forward),
                            label: const Text('Skip All'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Rating complete',
                  style: AppTypography.movieTitle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You\'ve rated ${ratingQueue.length} movies. Ready to view your watched collection?',
                  style: AppTypography.movieDescription.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('View Watched Movies'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 