import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';
import '../utils/animation_utils.dart';
import '../utils/language_utils.dart';

/// Modern WatchedListPage with Rating Sections
class WatchedListPage extends StatefulWidget {
  final List<Movie> moviesToRate;        // Pre-filtered by parent: watched, unrated, not bookmarked
  final List<Movie> ratedMovies;         // Pre-filtered by parent: watched and rated
  final Map<int, double> movieRatings;
  final Function(int, double) onRatingChanged;
  final Function(Movie) onMovieTap;
  final VoidCallback? onBackPressed;

  const WatchedListPage({
    super.key,
    required this.moviesToRate,
    required this.ratedMovies,
    required this.movieRatings,
    required this.onRatingChanged,
    required this.onMovieTap,
    this.onBackPressed,
  });

  @override
  State<WatchedListPage> createState() => _WatchedListPageState();
}

class _WatchedListPageState extends State<WatchedListPage> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLoading = true;

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
    
    _loadWatchedMovies();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchedMovies() async {
      setState(() {
      _isLoading = true;
      });
    
    // Simulate loading time for smooth animation
    await Future.delayed(const Duration(milliseconds: 300));
    
        setState(() {
      _isLoading = false;
    });
    
    // Start animations after data loads
    _fadeController.forward();
    _slideController.forward();
  }

  // Organize movies by rating
  Map<int, List<Movie>> _getMoviesByRating() {
    final moviesByRating = <int, List<Movie>>{};
    
    // Initialize all rating sections
    for (int i = 10; i >= 1; i--) {
      moviesByRating[i] = [];
    }
    moviesByRating[0] = []; // Unrated movies
    
    // Sort rated movies into sections
    for (final movie in widget.ratedMovies) {
      final rating = widget.movieRatings[movie.id] ?? 0.0;
      if (rating > 0) {
        final ratingInt = rating.round();
        if (ratingInt >= 1 && ratingInt <= 10) {
          moviesByRating[ratingInt]!.add(movie);
        }
      }
    }
    
    // Add unrated movies
    moviesByRating[0]!.addAll(widget.moviesToRate);
    
    return moviesByRating;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _buildWatchedList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
      children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your watched movies...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchedList() {
    final moviesByRating = _getMoviesByRating();
    final totalMovies = widget.ratedMovies.length + widget.moviesToRate.length;
    
    if (totalMovies == 0) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      slivers: [
        // Modern SliverAppBar with gradient
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: Colors.black,
          flexibleSpace: FlexibleSpaceBar(
            title: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Watched Movies',
                style: AppTypography.movieTitle.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
              ),
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
            ),
            onPressed: () {
              widget.onBackPressed?.call();
            },
                  ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                    Icons.visibility,
                    color: AppColors.primary,
                    size: 16,
                      ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalMovies',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Rating sections
        ...moviesByRating.entries.map((entry) {
          final rating = entry.key;
          final movies = entry.value;
          
          if (movies.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
          
          return SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildRatingSection(rating, movies),
              ),
            ),
          );
        }).toList(),
        
        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  Widget _buildRatingSection(int rating, List<Movie> movies) {
    final isUnrated = rating == 0;
    final sectionTitle = isUnrated ? 'Unrated Movies' : '$rating-Star Movies';
    final sectionColor = isUnrated 
        ? Colors.grey[600]! 
        : Colors.amber; // Use amber for all rated movies
    
    return Container(
      margin: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sectionColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sectionColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (!isUnrated) ...[
            Icon(
                    Icons.star,
                    color: sectionColor,
                    size: 20,
            ),
                  const SizedBox(width: 8),
                ],
            Text(
                  sectionTitle,
                  style: TextStyle(
                    color: sectionColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
                const Spacer(),
            Text(
                  '${movies.length}',
                  style: TextStyle(
                    color: sectionColor.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Movie grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie, rating);
            },
            ),
          ],
        ),
      );
    }

  Widget _buildMovieCard(Movie movie, int rating) {
    return GestureDetector(
      onTap: () => widget.onMovieTap(movie),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
                  children: [
                    // Movie poster
              CachedNetworkImage(
                        imageUrl: movie.posterUrl,
                width: double.infinity,
                height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                  child: Icon(
                    Icons.movie,
                    color: Colors.grey[600],
                    size: 40,
                  ),
                ),
              ),
              
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              
              // Rating badge (for rated movies)
              if (rating > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 12,
                    ),
                        const SizedBox(width: 2),
                        Text(
                          '$rating',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                    
              // Movie info overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                        movie.displayTitle,
                            style: AppTypography.movieTitle.copyWith(
                          fontSize: 14,
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
                            size: 14,
                          ),
                              const SizedBox(width: 4),
                          Text(
                            movie.formattedScore,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                            ),
                                  ),
                                ),
                              ],
                            ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                          Container(
                  width: 120,
                  height: 120,
                            decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                            ),
                  child: Icon(
                    Icons.visibility_off,
                    size: 60,
                                color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Watched Movies Yet',
                  style: AppTypography.movieTitle.copyWith(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                            ),
                const SizedBox(height: 12),
                Text(
                  'Start swiping movies to build your watched collection and rate the films you love.',
                              style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => widget.onBackPressed?.call(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    'Start Swiping',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                              ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                          ),
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
