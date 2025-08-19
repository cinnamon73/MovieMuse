import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';

class EnhancedCastCrewSection extends StatefulWidget {
  final Movie movie;
  final Function(String, String)? onPersonTap;

  const EnhancedCastCrewSection({
    required this.movie,
    this.onPersonTap,
    Key? key,
  }) : super(key: key);

  @override
  State<EnhancedCastCrewSection> createState() => _EnhancedCastCrewSectionState();
}

class _EnhancedCastCrewSectionState extends State<EnhancedCastCrewSection> {
  Map<String, dynamic>? castAndCrew;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCastAndCrew();
  }

  Future<void> _loadCastAndCrew() async {
    try {
      final movieService = MovieService();
      final data = await movieService.fetchCastAndCrew(widget.movie.id);
      setState(() {
        castAndCrew = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    if (castAndCrew == null || 
        (castAndCrew!['cast'].isEmpty && castAndCrew!['crew'].isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cast Section
        if (castAndCrew!['cast'].isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Cast:',
            style: AppTypography.sectionTitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (castAndCrew!['cast'] as List).map<Widget>((actor) {
              final name = actor['name'] as String;
              final character = actor['character'] as String;

              return InkWell(
                onTap: widget.onPersonTap != null 
                    ? () => widget.onPersonTap!(name, 'actor')
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.onPersonTap != null
                          ? AppColors.primary.withOpacity(0.6)
                          : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: AppTypography.castName.copyWith(
                              color: widget.onPersonTap != null
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.onPersonTap != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.filter_list,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      if (character.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          character,
                          style: AppTypography.castCharacter.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // Crew Section
        if (castAndCrew!['crew'].isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Crew:',
            style: AppTypography.sectionTitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (castAndCrew!['crew'] as List).map<Widget>((member) {
              final name = member['name'] as String;
              final job = member['job'] as String;

              return InkWell(
                onTap: widget.onPersonTap != null 
                    ? () => widget.onPersonTap!(name, job.toLowerCase())
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.onPersonTap != null
                          ? AppColors.secondary.withOpacity(0.6)
                          : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: AppTypography.castName.copyWith(
                              color: widget.onPersonTap != null
                                  ? AppColors.secondary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.onPersonTap != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.filter_list,
                              color: AppColors.secondary,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job,
                        style: AppTypography.castCharacter.copyWith(
                          color: widget.onPersonTap != null
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
} 