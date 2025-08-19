import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF7B68EE);
  static const Color secondary = Color(0xFF00BCD4);
  static const Color accent = Color(0xFFFF6B6B);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFFF5252);
  
  // Background colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color cardBackground = Color(0xFF2C2C2C);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFBBBBBB);
  static const Color textTertiary = Color(0xFF888888);
  
  // Utility colors
  static const Color divider = Color(0xFF333333);
  static const Color shimmer = Color(0xFF444444);
  
  // Genre colors
  static const Color genreAction = Color(0xFFFF5722);
  static const Color genreComedy = Color(0xFFFFEB3B);
  static const Color genreDrama = Color(0xFF9C27B0);
  static const Color genreHorror = Color(0xFF424242);
  static const Color genreRomance = Color(0xFFE91E63);
  static const Color genreSciFi = Color(0xFF03DAC6);
  static const Color genreDefault = Color(0xFF607D8B);
  
  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [background, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
} 