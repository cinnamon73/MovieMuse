import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import 'movie_card.dart';
import 'trailer_player_sheet.dart';
import '../services/recommendation_service.dart';

class SwipeableMovieCard extends StatefulWidget {
  final Movie movie;
  final bool isTop;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeDown;
  final VoidCallback onSwipeUp;
  final bool isBookmarked;
  final bool isWatched;
  final MovieService movieService;
  final double? rating;
  final ValueChanged<double>? onRatingChanged;
  final String? recommendedBy; // NEW: Who recommended this movie
  final RecommendationService? recommendationService; // Optional: for match/explain
  final List<Movie>? contextPool; // Optional: for match percentile normalization

  const SwipeableMovieCard({
    required this.movie,
    required this.isTop,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSwipeDown,
    required this.onSwipeUp,
    required this.isBookmarked,
    required this.isWatched,
    required this.movieService,
    this.rating,
    this.onRatingChanged,
    this.recommendedBy, // NEW: Optional recommender name
    this.recommendationService,
    this.contextPool,
    super.key,
  });

  @override
  State<SwipeableMovieCard> createState() => _SwipeableMovieCardState();
}

class _SwipeableMovieCardState extends State<SwipeableMovieCard>
    with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  double _angle = 0.0;
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _angleAnimation;
  bool? _hasTrailer; // null = unknown, true/false = determined

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _angleAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _prefetchTrailerAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SwipeableMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.id != widget.movie.id) {
      _hasTrailer = null;
      _inlineTrailerUrl = null;
      _showInlineTrailer = false;
      _prefetchTrailerAvailability();
    }
  }

  void _animateCardOffScreen(Offset targetOffset, VoidCallback onComplete) {
    _offsetAnimation = Tween<Offset>(begin: _offset, end: targetOffset).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _angleAnimation = Tween<double>(
      begin: _angle,
      end: _angle * 2, // Exaggerate the rotation as it flies off
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward(from: 0.0).then((_) {
      if (mounted) {
        onComplete();
        // Reset for next card
        setState(() {
          _offset = Offset.zero;
          _angle = 0.0;
        });
      }
    });
  }

  void _resetCard() {
    _offsetAnimation = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _angleAnimation = Tween<double>(begin: _angle, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _offset = Offset.zero;
          _angle = 0.0;
        });
      }
    });
  }

  double get _swipeProgress {
    if (_offset.dx.abs() < 30) return 0; // Lowered from 50 for earlier feedback
    return (_offset.dx / 150).clamp(-1, 1); // Lowered from 200 for more responsive feedback
  }

  String? _inlineTrailerUrl;
  bool _showInlineTrailer = false;

  Future<void> _prefetchTrailerAvailability() async {
    try {
      final url = await widget.movieService.fetchTrailerUrl(widget.movie.id);
      if (!mounted) return;
      setState(() {
        _hasTrailer = url != null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasTrailer = false;
      });
    }
  }

  Future<void> _toggleInlineTrailer() async {
    if (_showInlineTrailer) {
      setState(() { _showInlineTrailer = false; });
      return;
    }
    final url = await widget.movieService.fetchTrailerUrl(widget.movie.id);
    if (!mounted) return;
    if (url == null) return;
    setState(() {
      _inlineTrailerUrl = url;
      _showInlineTrailer = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTop) {
      return _OptimizedMovieCard(
        movie: widget.movie,
        onMarkWatched: widget.onSwipeRight,
        onBookmark: widget.onSwipeDown,
        isBookmarked: widget.isBookmarked,
        isWatched: widget.isWatched,
        movieService: widget.movieService,
        rating: widget.rating,
        onRatingChanged: widget.onRatingChanged,
        recommendedBy: widget.recommendedBy,
        recommendationService: widget.recommendationService,
        contextPool: widget.contextPool,
        hasTrailer: false,
      );
    }

    return GestureDetector(
      onDoubleTap: _toggleInlineTrailer,
      onPanUpdate: (details) {
        setState(() {
          _offset += details.delta;
          _angle = 0.25 * _offset.dx / 200; // max ~14deg
        });
        // Only hide trailer if there's significant movement (not just a light touch)
        if (_showInlineTrailer && _offset.distance > 20) {
          setState(() { _showInlineTrailer = false; });
        }
      },
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        // Improved sensitivity: lower thresholds and better velocity detection
        final shouldSwipeRight = _offset.dx > 80 || velocity.dx > 400; // Lowered from 100/600
        final shouldSwipeLeft = _offset.dx < -80 || velocity.dx < -400; // Lowered from -100/-600
        final shouldSwipeUp = _offset.dy < -80 || velocity.dy < -400; // Lowered from -100/-600
        final shouldSwipeDown = _offset.dy > 80 || velocity.dy > 400; // Lowered from 100/600

        if (shouldSwipeRight) {
          // Ensure any inline trailer is hidden before completing the swipe
          if (_showInlineTrailer) {
            setState(() { _showInlineTrailer = false; });
          }
          _animateCardOffScreen(const Offset(400, 0), widget.onSwipeRight);
        } else if (shouldSwipeLeft) {
          // Ensure any inline trailer is hidden before completing the swipe
          if (_showInlineTrailer) {
            setState(() { _showInlineTrailer = false; });
          }
          _animateCardOffScreen(const Offset(-400, 0), widget.onSwipeLeft);
        } else if (shouldSwipeUp) {
          // Ensure any inline trailer is hidden before completing the swipe
          if (_showInlineTrailer) {
            setState(() { _showInlineTrailer = false; });
          }
          _animateCardOffScreen(const Offset(0, -400), widget.onSwipeUp);
        } else if (shouldSwipeDown) {
          // Ensure any inline trailer is hidden before completing the swipe
          if (_showInlineTrailer) {
            setState(() { _showInlineTrailer = false; });
          }
          _animateCardOffScreen(const Offset(0, 400), widget.onSwipeDown);
        } else {
          _resetCard();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final currentOffset =
              _animationController.isAnimating
                  ? _offsetAnimation.value
                  : _offset;
          final currentAngle =
              _animationController.isAnimating ? _angleAnimation.value : _angle;

          return Transform(
            alignment: Alignment.bottomCenter,
            transform:
                Matrix4.identity()
                  ..translate(currentOffset.dx, currentOffset.dy)
                  ..rotateZ(currentAngle),
            child: _OptimizedMovieCard(
              movie: widget.movie,
              onMarkWatched: widget.onSwipeRight,
              onBookmark: widget.onSwipeDown,
              isBookmarked: widget.isBookmarked,
              isWatched: widget.isWatched,
              movieService: widget.movieService,
              swipeProgress: _swipeProgress,
              rating: widget.rating,
              onRatingChanged: widget.onRatingChanged,
              recommendedBy: widget.recommendedBy,
              showTrailer: _showInlineTrailer,
              trailerUrl: _inlineTrailerUrl,
              hasTrailer: _hasTrailer == true,
              recommendationService: widget.recommendationService,
              contextPool: widget.contextPool,
            ),
          );
        },
      ),
    );
  }
}

// Optimized MovieCard wrapper with const constructor
class _OptimizedMovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onMarkWatched;
  final VoidCallback onBookmark;
  final bool isBookmarked;
  final bool isWatched;
  final MovieService movieService;
  final double swipeProgress;
  final double? rating;
  final ValueChanged<double>? onRatingChanged;
  final String? recommendedBy; // NEW: Who recommended this movie
  final bool showTrailer;
  final String? trailerUrl;
  final bool hasTrailer;
  final RecommendationService? recommendationService;
  final List<Movie>? contextPool;

  const _OptimizedMovieCard({
    required this.movie,
    required this.onMarkWatched,
    required this.onBookmark,
    required this.isBookmarked,
    required this.isWatched,
    required this.movieService,
    this.swipeProgress = 0.0,
    this.rating,
    this.onRatingChanged,
    this.recommendedBy, // NEW: Optional recommender name
    this.showTrailer = false,
    this.trailerUrl,
    this.hasTrailer = false,
    this.recommendationService,
    this.contextPool,
  });

  @override
  Widget build(BuildContext context) {
    return MovieCard(
      movie: movie,
      onMarkWatched: onMarkWatched,
      onBookmark: onBookmark,
      isBookmarked: isBookmarked,
      isWatched: isWatched,
      movieService: movieService,
      swipeProgress: swipeProgress,
      rating: rating,
      onRatingChanged: onRatingChanged,
      recommendedBy: recommendedBy, // NEW: Pass recommender info
      inlineTrailerUrl: showTrailer ? trailerUrl : null,
      hasTrailer: hasTrailer,
      recommendationService: recommendationService,
      contextPool: contextPool,
    );
  }
}

// Lightweight wrapper to avoid importing the player at the top-level
class _TrailerSheetLauncher extends StatelessWidget {
  final String youtubeUrl;
  const _TrailerSheetLauncher({required this.youtubeUrl});

  @override
  Widget build(BuildContext context) {
    // Lazy import to keep initial build light
    return FutureBuilder(
      future: Future.value(true),
      builder: (context, _) {
        return Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) {
              // Defer import to this scope
              // ignore: avoid_dynamic_calls
              return _TrailerPlayer(youtubeUrl: youtubeUrl);
            },
          ),
        );
      },
    );
  }
}

class _TrailerPlayer extends StatelessWidget {
  final String youtubeUrl;
  const _TrailerPlayer({required this.youtubeUrl});

  @override
  Widget build(BuildContext context) {
    // Import player widget
    return Builder(
      builder: (context) {
        // Use the sheet widget we created
        // The sheet is already a full UI; just embed it
        // ignore: prefer_const_constructors
        return TrailerPlayerSheet(youtubeUrl: youtubeUrl);
      },
    );
  }
}
