import 'package:flutter/material.dart';
import '../services/movie_service.dart';
import '../themes/app_colors.dart';
import '../themes/typography_theme.dart';

class PlatformFilterWidget extends StatefulWidget {
  final MovieService movieService;
  final Function(String?) onPlatformChanged;
  final String? selectedPlatform;

  const PlatformFilterWidget({
    super.key,
    required this.movieService,
    required this.onPlatformChanged,
    this.selectedPlatform,
  });

  @override
  State<PlatformFilterWidget> createState() => _PlatformFilterWidgetState();
}

class _PlatformFilterWidgetState extends State<PlatformFilterWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available on:',
          style: AppTypography.sectionTitle.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Clear filter option
            FilterChip(
              label: const Text('All Platforms'),
              selected: widget.selectedPlatform == null,
              onSelected: (selected) {
                if (selected) {
                  _clearPlatformFilter();
                }
              },
              backgroundColor: Colors.grey[800],
              selectedColor: AppColors.primary,
              labelStyle: AppTypography.genreTag.copyWith(
                color: widget.selectedPlatform == null ? Colors.white : Colors.grey[400],
              ),
            ),
            // Platform options
            ...MovieService.PLATFORM_PROVIDERS.keys.map((platform) => 
              FilterChip(
                label: Text(_getPlatformDisplayName(platform)),
                selected: widget.selectedPlatform == platform,
                onSelected: (selected) {
                  if (selected) {
                    _onPlatformSelected(platform);
                  } else {
                    _clearPlatformFilter();
                  }
                },
                backgroundColor: Colors.grey[800],
                selectedColor: AppColors.primary,
                labelStyle: AppTypography.genreTag.copyWith(
                  color: widget.selectedPlatform == platform ? Colors.white : Colors.grey[400],
                ),
              )
            ).toList(),
          ],
        ),
        
        // Show loading progress if fetching
        if (widget.movieService.isPlatformFetching) ...[
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loading initial ${_getPlatformDisplayName(widget.selectedPlatform ?? '')} movies...',
                style: AppTypography.metadataText.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
          ),
        ],
        
        // Show loading more indicator
        if (widget.movieService.isLoadingMorePlatformMovies) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading more ${_getPlatformDisplayName(widget.selectedPlatform ?? '')} movies...',
                style: AppTypography.metadataText.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
        
        // Show platform info if selected
        if (widget.selectedPlatform != null && 
            !widget.movieService.isPlatformFetching && 
            !widget.movieService.isLoadingMorePlatformMovies) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.movieService.platformMovieStack.length} ${_getPlatformDisplayName(widget.selectedPlatform!)} movies loaded',
                        style: AppTypography.metadataText.copyWith(color: Colors.white70),
                      ),
                    ),
                    IconButton(
                      onPressed: _clearPlatformFilter,
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      iconSize: 20,
                    ),
                  ],
                ),
                if (widget.movieService.hasMorePlatformPages) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Scroll to load more movies',
                    style: AppTypography.metadataText.copyWith(color: Colors.white54, fontSize: 12),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'All available movies loaded',
                    style: AppTypography.metadataText.copyWith(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getPlatformDisplayName(String platform) {
    switch (platform) {
      case 'netflix':
        return 'Netflix';
      case 'amazon_prime':
        return 'Amazon Prime';
      case 'disney_plus':
        return 'Disney+';

      case 'hulu':
        return 'Hulu';
      case 'apple_tv':
        return 'Apple TV+';
      case 'paramount_plus':
        return 'Paramount+';
      case 'peacock':
        return 'Peacock';
      case 'crunchyroll':
        return 'Crunchyroll';
      default:
        return platform.replaceAll('_', ' ').toUpperCase();
    }
  }

  Future<void> _onPlatformSelected(String platform) async {
    debugPrint('🎯 PLATFORM BUTTON CLICKED: $platform');
    
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 Calling movieService.onPlatformFilterSelected($platform)');
      await widget.movieService.onPlatformFilterSelected(platform);
      
      debugPrint('✅ Platform filter applied successfully');
      
      // Populate the movie stack from platform results
      debugPrint('🔄 Calling populateMovieStackFromPlatform()');
      widget.movieService.populateMovieStackFromPlatform();
      
      // Notify parent of platform change
      debugPrint('📢 Notifying parent of platform change: $platform');
      widget.onPlatformChanged(platform);
      
      debugPrint('✅ Platform selection complete for: $platform');
      
    } catch (e) {
      debugPrint('❌ ERROR in platform selection: $e');
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error Loading ${_getPlatformDisplayName(platform)} Movies'),
            content: Text('Unable to load movies from ${_getPlatformDisplayName(platform)}. Please try again.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearPlatformFilter();
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _onPlatformSelected(platform); // Retry
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('🏁 Platform selection finished for: $platform');
      }
    }
  }

  void _clearPlatformFilter() {
    debugPrint('🗑️ CLEARING PLATFORM FILTER');
    widget.movieService.clearPlatformFilter();
    widget.onPlatformChanged(null);
    debugPrint('✅ Platform filter cleared');
  }
} 