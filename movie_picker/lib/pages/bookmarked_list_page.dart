import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../services/auth_service.dart';
import '../themes/app_colors.dart';
import '../themes/typography_theme.dart';
import '../widgets/bookmark_badge.dart';
import '../pages/movie_details_page.dart';

class BookmarkedListPage extends StatefulWidget {
  final List<Movie> bookmarkedMovies;
  final Function(Movie) onRemoveBookmark;
  final Function(Movie) onMovieTap;
  final VoidCallback? onBackPressed;

  const BookmarkedListPage({
    Key? key,
    required this.bookmarkedMovies,
    required this.onRemoveBookmark,
    required this.onMovieTap,
    this.onBackPressed,
  }) : super(key: key);

  @override
  State<BookmarkedListPage> createState() => _BookmarkedListPageState();
}

class _BookmarkedListPageState extends State<BookmarkedListPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<Movie> _bookmarkedMovies = [];
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
    
    _loadBookmarkedMovies();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarkedMovies() async {
    setState(() {
      _isLoading = true;
    });

    // Use the movies passed from the parent
    setState(() {
      _bookmarkedMovies = widget.bookmarkedMovies;
      _isLoading = false;
    });
    
    // Start animations after data loads
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _removeBookmark(Movie movie) async {
    // Call the parent's remove bookmark function
    widget.onRemoveBookmark(movie);
    
    setState(() {
      _bookmarkedMovies.removeWhere((m) => m.id == movie.id);
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${movie.title}" from your collection'),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _bookmarkedMovies.isEmpty
                ? _buildEmptyState()
                : _buildMovieList(),
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
            'Loading your collection...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
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
                    Icons.bookmark_border,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your Collection is Empty',
                  style: AppTypography.movieTitle.copyWith(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Start building your movie collection by bookmarking movies you love while swiping.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildMovieList() {
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
                'My Collection',
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
              // Navigate back to main view using the callback
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
                    Icons.bookmark,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_bookmarkedMovies.length}',
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
        
        // Movie grid
        SliverPadding(
                padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final movie = _bookmarkedMovies[index];
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildMovieCard(movie, index),
                  ),
                );
              },
              childCount: _bookmarkedMovies.length,
            ),
          ),
        ),
        
        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  Widget _buildMovieCard(Movie movie, int index) {
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

  void _showMovieDetails(Movie movie) async {
    // Fetch cast for the movie
    final cast = await MovieService().fetchCast(movie.id);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MovieDetailsPage(
          movie: movie,
          cast: cast,
          isBookmarked: true,
          isWatched: false, // We'll need to get this from user data
          currentRating: 0.0, // We'll need to get this from user data
          onBookmark: () {
            // This is the unbookmark action for bookmarked movies
            _removeBookmark(movie);
            Navigator.of(context).pop();
          },
          onMarkWatched: () async {
            // Mark as watched and remove from bookmarks
            widget.onRemoveBookmark(movie);
            // TODO: Add to watched list
            Navigator.of(context).pop();
          },
          onRatingChanged: (rating) async {
            // Handle rating from the dialog
            // This will be handled by the home screen
          },
          showRatingSystem: false, // No rating system for bookmarked movies
                ),
      ),
    );
  }
}
