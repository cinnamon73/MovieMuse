import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Movie Title Styles
  static TextStyle get movieTitle => GoogleFonts.bebasNeue(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  static TextStyle get movieTitleLarge => GoogleFonts.bebasNeue(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.1,
  );
  
  // Description Styles
  static TextStyle get movieDescription => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
  );
  
  static TextStyle get movieDescriptionBold => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
  );
  
  // Genre and Secondary Text Styles
  static TextStyle get genreTag => GoogleFonts.robotoCondensed(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  static TextStyle get secondaryText => GoogleFonts.lato(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0.2,
  );
  
  static TextStyle get secondaryTextBold => GoogleFonts.lato(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
  );
  
  // UI Text Styles
  static TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  
  static TextStyle get appBarTitle => GoogleFonts.spaceGrotesk(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: Color(0xFF6C3EFF), // Dark purple
  );
  
  static TextStyle get tabLabel => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  
  // Rating and Metadata Styles
  static TextStyle get ratingText => GoogleFonts.robotoCondensed(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
  
  static TextStyle get metadataText => GoogleFonts.lato(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );
  
  // Cast and Crew Styles
  static TextStyle get sectionTitle => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );
  
  static TextStyle get castName => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  
  static TextStyle get castCharacter => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );
  
  // Shimmer placeholder styles (with reduced opacity)
  static TextStyle get shimmerTitle => GoogleFonts.bebasNeue(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
    color: Colors.white.withValues(alpha: 0.8),
  );
  
  static TextStyle get shimmerDescription => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
    color: Colors.white.withValues(alpha: 0.7),
  );
  
  static TextStyle get shimmerGenre => GoogleFonts.robotoCondensed(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.2,
    color: Colors.white.withValues(alpha: 0.6),
  );
} 
