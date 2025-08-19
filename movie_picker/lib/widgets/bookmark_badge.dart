import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/typography_theme.dart';

class BookmarkBadge extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;
  final double size;
  final bool showLabel;
  final String? customLabel;

  const BookmarkBadge({
    super.key,
    required this.isBookmarked,
    required this.onToggle,
    this.size = 24.0,
    this.showLabel = false,
    this.customLabel,
  });

  @override
  State<BookmarkBadge> createState() => _BookmarkBadgeState();
}

class _BookmarkBadgeState extends State<BookmarkBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isBookmarked 
                      ? AppColors.primary.withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isBookmarked 
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: widget.isBookmarked ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isBookmarked 
                          ? Icons.bookmark 
                          : Icons.bookmark_border,
                      color: widget.isBookmarked 
                          ? Colors.white 
                          : Colors.white70,
                      size: widget.size,
                    ),
                    if (widget.showLabel) ...[
                      const SizedBox(width: 6),
                      Text(
                        widget.customLabel ?? 
                        (widget.isBookmarked ? 'Saved' : 'Save'),
                        style: AppTypography.metadataText.copyWith(
                          color: widget.isBookmarked 
                              ? Colors.white 
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 