import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/friendship_service.dart';
import '../services/user_data_service.dart';
import '../services/movie_service.dart';
import '../models/movie.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';
import '../utils/animation_utils.dart';
import '../utils/avatar_helper.dart';
import '../widgets/filter_dialog.dart';
import 'movie_details_page.dart';

class FriendCatalogPage extends StatefulWidget {
  final String friendUid;
  final String friendUsername;
  final String? friendAvatarId;
  final FriendshipService friendshipService;
  final UserDataService userDataService;
  final MovieService movieService;

  const FriendCatalogPage({
    super.key,
    required this.friendUid,
    required this.friendUsername,
    this.friendAvatarId,
    required this.friendshipService,
    required this.userDataService,
    required this.movieService,
  });

  @override
  State<FriendCatalogPage> createState() => _FriendCatalogPageState();
}

class _FriendCatalogPageState extends State<FriendCatalogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Friend's data
  UserData? _friendData;
  List<Movie> _friendWatchedMovies = [];
  List<Movie> _friendBookmarkedMovies = [];
  Map<int, double> _friendRatings = {};
  
  // Current user's data for comparison
  Map<int, double> _myRatings = {};
  Set<int> _myWatchedIds = {};
  Set<int> _myBookmarkedIds = {};
  String _currentUserName = 'User'; // Add current user name field

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedGenres = {};
  String? _selectedLanguage;
  String? _selectedTimePeriod = 'All Years';
  
  // Loading states
  bool _isLoading = true;
  String? _error;
  
  // Filtered results
  List<Movie> _filteredWatchedMovies = [];
  List<Movie> _filteredBookmarkedMovies = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load friend's data
      _friendData = await widget.userDataService.getUserDataByUid(widget.friendUid);
      
      if (_friendData == null) {
        throw Exception('Could not load friend\'s data');
      }

      // Load current user's data for comparison
      final myData = await widget.userDataService.getCurrentUserData();
      if (myData != null) {
        _myRatings = myData.movieRatings;
        _myWatchedIds = myData.watchedMovieIds;
        _myBookmarkedIds = myData.bookmarkedMovieIds;
        _currentUserName = myData.name; // Store current user's name
      }

      // Fetch and cache friend's movies
      await _fetchFriendMovies();

      // Apply initial filters
      _applyFilters();

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Failed to load friend\'s catalog: $e';
        _isLoading = false;
      });
      debugPrint('❌ Error loading friend catalog: $e');
    }
  }

  Future<void> _fetchFriendMovies() async {
    if (_friendData == null) return;

    debugPrint('🔄 [FriendCatalog] Fetching specific movies for ${widget.friendUsername}...');
    debugPrint('   Watched IDs: ${_friendData!.watchedMovieIds.length}');
    debugPrint('   Bookmarked IDs: ${_friendData!.bookmarkedMovieIds.length}');

    // Get friend's ratings
    _friendRatings = _friendData!.movieRatings;

    // Get ONLY the specific movie IDs we need
    final watchedIds = _friendData!.watchedMovieIds;
    final bookmarkedIds = _friendData!.bookmarkedMovieIds;

    // Fetch ONLY the movies we need (no cache checking first)
    final allNeededIds = <int>{};
    allNeededIds.addAll(watchedIds);
    allNeededIds.addAll(bookmarkedIds);

    debugPrint('🔄 [FriendCatalog] Fetching ${allNeededIds.length} movies directly from API...');

    // Fetch all needed movies directly from API
    final futures = allNeededIds.map((movieId) => widget.movieService.fetchMovieById(movieId));
    final results = await Future.wait(futures);

    // Filter successful results
    final successfulMovies = <Movie>[];
    int successCount = 0;
    int failureCount = 0;
    
    for (int i = 0; i < results.length; i++) {
      final movie = results[i];
      if (movie != null) {
        successfulMovies.add(movie);
        successCount++;
      } else {
        failureCount++;
      }
    }

    debugPrint('✅ [FriendCatalog] Fetching completed: $successCount successful, $failureCount failed');

    // Filter into watched and bookmarked
    _friendWatchedMovies = successfulMovies
        .where((movie) => watchedIds.contains(movie.id))
        .toList();
    
    _friendBookmarkedMovies = successfulMovies
        .where((movie) => bookmarkedIds.contains(movie.id))
        .toList();

    debugPrint('✅ [FriendCatalog] Final catalog loaded:');
    debugPrint('   Watched movies: ${_friendWatchedMovies.length} / ${watchedIds.length}');
    debugPrint('   Bookmarked movies: ${_friendBookmarkedMovies.length} / ${bookmarkedIds.length}');
  }

  Future<void> _retryLoadingMovies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      await _fetchFriendMovies();
      _applyFilters();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to reload movies: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final allWatched = _friendWatchedMovies;
    final allBookmarked = _friendBookmarkedMovies;

    // Apply search filter
    List<Movie> searchFilteredWatched = allWatched;
    List<Movie> searchFilteredBookmarked = allBookmarked;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      searchFilteredWatched = allWatched.where((movie) =>
        movie.title.toLowerCase().contains(query) ||
        movie.description.toLowerCase().contains(query) ||
        movie.genre.toLowerCase().contains(query)
      ).toList();
      
      searchFilteredBookmarked = allBookmarked.where((movie) =>
        movie.title.toLowerCase().contains(query) ||
        movie.description.toLowerCase().contains(query) ||
        movie.genre.toLowerCase().contains(query)
      ).toList();
    }

    // Apply genre filter
    if (_selectedGenres.isNotEmpty) {
      searchFilteredWatched = searchFilteredWatched.where((movie) =>
        _selectedGenres.contains(movie.genre)
      ).toList();
      
      searchFilteredBookmarked = searchFilteredBookmarked.where((movie) =>
        _selectedGenres.contains(movie.genre)
      ).toList();
    }

    // Apply language filter
    if (_selectedLanguage != null) {
      searchFilteredWatched = searchFilteredWatched.where((movie) =>
        movie.language == _selectedLanguage
      ).toList();
      
      searchFilteredBookmarked = searchFilteredBookmarked.where((movie) =>
        movie.language == _selectedLanguage
      ).toList();
    }

    // Apply time period filter
    if (_selectedTimePeriod != null && _selectedTimePeriod != 'All Years') {
      final yearRanges = {
        '2020-2024': (2020, 2024),
        '2010-2019': (2010, 2019),
        '2000-2009': (2000, 2009),
        '1990-1999': (1990, 1999),
        '1980-1989': (1980, 1989),
        '1970-1979': (1970, 1979),
        'Before 1970': (0, 1969),
      };

      final range = yearRanges[_selectedTimePeriod];
      if (range != null) {
        searchFilteredWatched = searchFilteredWatched.where((movie) {
          final year = int.tryParse(movie.releaseDate) ?? 0;
          return year >= range.$1 && year <= range.$2;
        }).toList();
        
        searchFilteredBookmarked = searchFilteredBookmarked.where((movie) {
          final year = int.tryParse(movie.releaseDate) ?? 0;
          return year >= range.$1 && year <= range.$2;
        }).toList();
      }
    }

    setState(() {
      _filteredWatchedMovies = searchFilteredWatched;
      _filteredBookmarkedMovies = searchFilteredBookmarked;
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FilterDialog(
        movieService: widget.movieService,
        initialGenres: _selectedGenres,
        initialLanguage: _selectedLanguage,
        initialTimePeriod: _selectedTimePeriod,
        onApply: (genres, language, timePeriod, platform) async {
          setState(() {
            _selectedGenres = genres;
            _selectedLanguage = language;
            _selectedTimePeriod = timePeriod;
            // Note: Platform filter not used in friend catalog page
          });
          _applyFilters();
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedGenres.clear();
      _selectedLanguage = null;
      _selectedTimePeriod = 'All Years';
    });
    _searchController.clear();
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.friendUsername}\'s Movies'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _retryLoadingMovies,
            tooltip: 'Refresh catalog',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
          if (_selectedGenres.isNotEmpty || _selectedLanguage != null || 
              _selectedTimePeriod != 'All Years' || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: _clearFilters,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Text(
                'Watched (${_filteredWatchedMovies.length})',
                style: AppTypography.tabLabel,
              ),
            ),
            Tab(
              child: Text(
                'Bookmarked (${_filteredBookmarkedMovies.length})',
                style: AppTypography.tabLabel,
              ),
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search movies...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
          ),
          
          // Active filters indicator
          if (_selectedGenres.isNotEmpty || _selectedLanguage != null || 
              _selectedTimePeriod != 'All Years')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedGenres.isNotEmpty)
                    ..._selectedGenres.map((genre) => Chip(
                      label: Text(genre),
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedGenres.remove(genre);
                        });
                        _applyFilters();
                      },
                    )),
                  if (_selectedLanguage != null)
                    Chip(
                      label: Text(_selectedLanguage!),
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedLanguage = null;
                        });
                        _applyFilters();
                      },
                    ),
                  if (_selectedTimePeriod != 'All Years')
                    Chip(
                      label: Text(_selectedTimePeriod!),
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedTimePeriod = 'All Years';
                        });
                        _applyFilters();
                      },
                    ),
                ],
              ),
            ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: AppTypography.movieDescription.copyWith(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildWatchedTab(),
                          _buildBookmarkedTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchedTab() {
    if (_filteredWatchedMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _friendData?.watchedMovieIds.isEmpty == true 
                ? 'No watched movies yet'
                : 'No watched movies found',
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),
            if (_friendData?.watchedMovieIds.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text(
                'Some movies might still be loading...',
                style: TextStyle(color: Colors.white38, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryLoadingMovies,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredWatchedMovies.length,
      itemBuilder: (context, index) {
        final movie = _filteredWatchedMovies[index];
        return _buildMovieCard(movie, isWatched: true);
      },
    );
  }

  Widget _buildBookmarkedTab() {
    if (_filteredBookmarkedMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_outline, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _friendData?.bookmarkedMovieIds.isEmpty == true 
                ? 'No bookmarked movies yet'
                : 'No bookmarked movies found',
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),
            if (_friendData?.bookmarkedMovieIds.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text(
                'Some movies might still be loading...',
                style: TextStyle(color: Colors.white38, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryLoadingMovies,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredBookmarkedMovies.length,
      itemBuilder: (context, index) {
        final movie = _filteredBookmarkedMovies[index];
        return _buildMovieCard(movie, isWatched: false);
      },
    );
  }

  Widget _buildMovieCard(Movie movie, {required bool isWatched}) {
    final friendRating = _friendRatings[movie.id] ?? 0.0;
    final myRating = _myRatings[movie.id] ?? 0.0;
    final isInMyWatched = _myWatchedIds.contains(movie.id);
    final isInMyBookmarked = _myBookmarkedIds.contains(movie.id);
    
    // Determine friend's actual status for this movie
    final isInFriendWatched = _friendData?.watchedMovieIds.contains(movie.id) ?? false;
    final isInFriendBookmarked = _friendData?.bookmarkedMovieIds.contains(movie.id) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white10,
      child: InkWell(
        onTap: () => _showMovieDetails(movie),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Movie poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: movie.posterUrl,
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie, color: Colors.white54),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Movie info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: AppTypography.movieTitle.copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '${movie.releaseDate} • ${movie.genre}',
                      style: AppTypography.metadataText.copyWith(color: Colors.white70),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Movie description
                    Text(
                      movie.description,
                      style: AppTypography.metadataText.copyWith(color: Colors.white60),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Ratings comparison
                    Row(
                      children: [
                        // Friend's rating
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              friendRating > 0 ? friendRating.toStringAsFixed(1) : 'Not rated',
                              style: const TextStyle(color: Colors.amber, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${widget.friendUsername})',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Your rating (if you've rated it)
                        if (myRating > 0)
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.blue, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                myRating.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.blue, fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '(You)',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Status indicators
                    Row(
                      children: [
                        // Only show your status indicators (remove friend's status tags)
                        if (isInMyWatched)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YOU WATCHED',
                              style: TextStyle(color: Colors.blue, fontSize: 10),
                            ),
                          ),
                        
                        if (isInMyBookmarked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YOU BOOKMARKED',
                              style: TextStyle(color: Colors.purple, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // TMDB rating
              Column(
                children: [
                  const Icon(Icons.star, color: Colors.white54, size: 16),
                  Text(
                    movie.formattedScore,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMovieDetails(Movie movie) async {
    final cast = await widget.movieService.fetchCast(movie.id);
    if (!mounted) return;
    
    await Navigator.push(
      context,
      AnimationUtils.createFadeSlideRoute(
        MovieDetailsPage(
          movie: movie,
          cast: cast,
          isBookmarked: _myBookmarkedIds.contains(movie.id),
          isWatched: _myWatchedIds.contains(movie.id),
          currentRating: _myRatings[movie.id] ?? 0.0,
          showRatingSystem: false, // View-only mode - no rating system
          selectedPlatform: null, // No platform filter in friend catalog view
          onBookmark: () {
            // View-only mode - no interactions allowed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This is a view-only mode. You cannot modify your data here.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          onMarkWatched: () {
            // View-only mode - no interactions allowed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This is a view-only mode. You cannot modify your data here.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          onRatingChanged: (rating) {
            // View-only mode - no interactions allowed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This is a view-only mode. You cannot modify your data here.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          onPersonTap: (personName, personType) {
            // View-only mode - no interactions allowed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This is a view-only mode. You cannot modify your data here.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        ),
      ),
    );
  }
} 