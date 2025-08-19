import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review.dart';
import '../themes/app_colors.dart';
import '../themes/typography_theme.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';

class MovieReviewsSection extends StatefulWidget {
  final int movieId;
  final String movieTitle;
  final String currentUsername;
  final bool canReview; // true if user has this movie in watched list

  const MovieReviewsSection({
    required this.movieId,
    required this.movieTitle,
    required this.currentUsername,
    required this.canReview,
    Key? key,
  }) : super(key: key);

  @override
  State<MovieReviewsSection> createState() => _MovieReviewsSectionState();
}

class _MovieReviewsSectionState extends State<MovieReviewsSection> {
  final TextEditingController _reviewController = TextEditingController();
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();

  bool _hasSpoilers = false;
  bool _isSubmitting = false;
  Review? _userReview;
  Set<String> _upvotingReviews = {}; // Track which reviews are being upvoted
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn().then((_) => _loadUserReview());
  }

  Future<void> _ensureSignedIn() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } catch (_) {}
    if (mounted) setState(() => _authReady = true);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadUserReview() async {
    final review = await _reviewService.getUserReviewForMovie(widget.movieId);
    if (!mounted) return;
    setState(() {
      _userReview = review;
      _reviewController.text = review?.reviewText ?? '';
      _hasSpoilers = review?.hasSpoilers ?? false;
    });
  }

  Future<void> _submitReview() async {
    if (!widget.canReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mark this movie as watched to post a review.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final text = _reviewController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      if (_userReview == null) {
        await _reviewService.submitReview(
          movieId: widget.movieId,
          movieTitle: widget.movieTitle,
          reviewText: text,
          hasSpoilers: _hasSpoilers,
        );
      } else {
        await _reviewService.updateReview(
          reviewId: _userReview!.id,
          reviewText: text,
          hasSpoilers: _hasSpoilers,
        );
      }

      await _loadUserReview();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_userReview == null ? 'Review submitted!' : 'Review updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'Reviews',
          style: AppTypography.sectionTitle.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),

        // Write Review Section (show only if watched)
        if (widget.canReview) _buildWriteBox(),

        if (widget.canReview) const SizedBox(height: 24),

        // Reviews List
        if (!_authReady)
          const Center(child: CircularProgressIndicator())
        else
          StreamBuilder<List<Review>>(
            stream: _reviewService.streamReviewsForMovie(widget.movieId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final msg = snapshot.error.toString();
                final friendly = msg.contains('permission-denied')
                    ? 'Please make sure Firestore rules are published and you are signed in.'
                    : msg;
                return Text(
                  'Error loading reviews: $friendly',
                  style: AppTypography.secondaryText.copyWith(color: Colors.red),
                );
              }

              final reviews = snapshot.data ?? [];

              if (reviews.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No reviews yet. Be the first to review!',
                      style: AppTypography.secondaryText.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: reviews.map((review) => _buildReviewCard(review, currentUserId)).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildWriteBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _userReview == null ? 'Write a Review' : 'Edit Your Review',
            style: AppTypography.movieTitle.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reviewController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Share your thoughts about this movie...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _hasSpoilers,
                onChanged: (value) {
                  setState(() {
                    _hasSpoilers = value ?? false;
                  });
                },
                activeColor: AppColors.primary,
              ),
              Text(
                'Contains spoilers',
                style: AppTypography.secondaryText.copyWith(color: Colors.white),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_userReview == null ? 'Submit' : 'Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review, String? currentUserId) {
    final isCurrentUser = review.userId == currentUserId;
    final hasUpvoted = review.upvotedBy.contains(currentUserId);
    final isUpvoting = _upvotingReviews.contains(review.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                review.username,
                style: AppTypography.movieTitle.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'You',
                    style: AppTypography.metadataText.copyWith(
                      color: AppColors.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                _formatTimestamp(review.timestamp),
                style: AppTypography.metadataText.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          if (review.hasSpoilers) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Contains Spoilers',
                    style: AppTypography.metadataText.copyWith(
                      color: Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Review Text
          Text(
            review.reviewText,
            style: AppTypography.movieDescription.copyWith(color: Colors.white),
          ),

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              // Upvote Button
              InkWell(
                onTap: () async {
                  setState(() => _upvotingReviews.add(review.id));
                  try {
                    await _reviewService.toggleUpvote(review.id);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error upvoting review: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _upvotingReviews.remove(review.id));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasUpvoted
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasUpvoted ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUpvoting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      else
                        Icon(
                          hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 16,
                          color: hasUpvoted ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        '${review.upvoteCount}',
                        style: AppTypography.metadataText.copyWith(
                          color: hasUpvoted ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Delete Button (only for current user)
              if (isCurrentUser) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _showDeleteDialog(review),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: AppTypography.metadataText.copyWith(
                            color: Colors.red.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showDeleteDialog(Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Delete Review',
          style: AppTypography.movieTitle.copyWith(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this review?',
          style: AppTypography.movieDescription.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.buttonText.copyWith(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _reviewService.deleteReview(review.id);
                await _loadUserReview(); // Refresh user review state
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Review deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting review: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.buttonText.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
} 