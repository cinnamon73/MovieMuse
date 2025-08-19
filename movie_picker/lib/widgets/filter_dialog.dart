import 'package:flutter/material.dart';
import '../services/movie_service.dart';
import '../themes/typography_theme.dart';
import '../themes/app_colors.dart';
import '../utils/animation_utils.dart';
import 'platform_filter_widget.dart';

class FilterDialog extends StatefulWidget {
  final MovieService movieService;
  final Set<String> initialGenres;
  final String? initialLanguage;
  final String? initialTimePeriod;
  final String? initialPlatform;
  final Future<void> Function(Set<String>, String?, String?, String?) onApply;

  const FilterDialog({
    required this.movieService,
    required this.initialGenres,
    required this.initialLanguage,
    required this.initialTimePeriod,
    this.initialPlatform,
    required this.onApply,
    Key? key,
  }) : super(key: key);

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Set<String> selectedGenres;
  String? selectedLanguage;
  String? selectedTimePeriod;
  String? selectedPlatform;

  @override
  void initState() {
    super.initState();
    selectedGenres = Set<String>.from(widget.initialGenres);
    selectedLanguage = widget.initialLanguage;
    selectedTimePeriod = widget.initialTimePeriod ?? 'All Years';
    selectedPlatform = widget.initialPlatform;
  }

  void _handleGenreChange(String? genre) {
    setState(() {
      if (genre == null) {
        selectedGenres.clear();
      } else {
        if (selectedGenres.contains(genre)) {
          selectedGenres.remove(genre);
        } else {
          selectedGenres.add(genre);
        }
      }
    });
  }

  void _handleTimePeriodChange(String? value) {
    setState(() {
      selectedTimePeriod = value;
    });
  }

  void _handleLanguageChange(String? value) {
    setState(() {
      selectedLanguage = value;
    });
  }

  void _handlePlatformChange(String? value) {
    debugPrint('🎯 FILTER DIALOG: Platform changed to: $value');
    setState(() {
      selectedPlatform = value;
    });
    debugPrint('✅ FILTER DIALOG: Platform state updated to: $selectedPlatform');
  }

  void _handleReset() {
    setState(() {
      selectedGenres.clear();
      selectedLanguage = null;
      selectedTimePeriod = 'All Years';
      selectedPlatform = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> timePeriods = [
      {'label': 'All Years', 'start': null, 'end': null},
      {'label': '2020-2024', 'start': 2020, 'end': 2024},
      {'label': '2010-2019', 'start': 2010, 'end': 2019},
      {'label': '2000-2009', 'start': 2000, 'end': 2009},
      {'label': '1990-1999', 'start': 1990, 'end': 1999},
      {'label': '1980-1989', 'start': 1980, 'end': 1989},
      {'label': '1970-1979', 'start': 1970, 'end': 1979},
      {'label': '1960-1969', 'start': 1960, 'end': 1969},
      {'label': '1950-1959', 'start': 1950, 'end': 1959},
      {'label': 'Before 1950', 'start': 0, 'end': 1949},
    ];
    final List<String> languages = [
      'en',
      'es',
      'fr',
      'de',
      'it',
      'ja',
      'ko',
      'zh',
    ];
    final List<String> languageNames = [
      'English',
      'Spanish',
      'French',
      'German',
      'Italian',
      'Japanese',
      'Korean',
      'Chinese',
    ];
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Genre Filter Section
            Text(
              'Genres',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Wrap layout for genres - shows all genres without needing to scroll
            Container(
              constraints: BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AnimatedButton(
                      onPressed: () => _handleGenreChange(null),
                      child: FilterChip(
                      label: const Text('All Genres'),
                      selected: selectedGenres.isEmpty,
                      onSelected: (selected) => _handleGenreChange(null),
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color:
                            selectedGenres.isEmpty
                                ? Colors.white
                                  : AppColors.textSecondary,
                        fontWeight:
                            selectedGenres.isEmpty
                                ? FontWeight.bold
                                  : FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      showCheckmark: false,
                      avatar:
                          selectedGenres.isEmpty
                              ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                              : null,
                      ),
                    ),
                    ...widget.movieService.getAllGenres().map(
                      (genre) => AnimatedButton(
                        onPressed: () => _handleGenreChange(genre),
                        child: FilterChip(
                        label: Text(genre),
                        selected: selectedGenres.contains(genre),
                        onSelected: (selected) => _handleGenreChange(genre),
                          backgroundColor: AppColors.surface,
                          selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              selectedGenres.contains(genre)
                                  ? Colors.white
                                    : AppColors.textSecondary,
                          fontWeight:
                              selectedGenres.contains(genre)
                                  ? FontWeight.bold
                                    : FontWeight.w500,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        showCheckmark: false,
                        avatar:
                            selectedGenres.contains(genre)
                                ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                                : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time Period Filter
            Text(
              'Time Period',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedTimePeriod,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  hint: Text(
                    'Select Time Period',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  items:
                      timePeriods
                          .map(
                            (period) => DropdownMenuItem<String>(
                              value: period['label'] as String,
                              child: Text(period['label'] as String),
                            ),
                          )
                          .toList(),
                  onChanged: _handleTimePeriodChange,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Language Filter
            Text(
              'Language',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedLanguage,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  hint: Text(
                    'Select Language',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any Language'),
                    ),
                    ...List.generate(
                      languages.length,
                      (index) => DropdownMenuItem(
                        value: languages[index],
                        child: Text(languageNames[index]),
                      ),
                    ),
                  ],
                  onChanged: _handleLanguageChange,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Platform Filter
            Text(
              'Platform',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            PlatformFilterWidget(
              movieService: widget.movieService,
              selectedPlatform: selectedPlatform,
              onPlatformChanged: _handlePlatformChange,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedButton(
                  onPressed: _handleReset,
                  child: TextButton(
                    onPressed: _handleReset,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(
                      selectedGenres,
                      selectedLanguage,
                      selectedTimePeriod,
                      selectedPlatform,
                    );
                  },
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApply(
                        selectedGenres,
                        selectedLanguage,
                        selectedTimePeriod,
                        selectedPlatform,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
