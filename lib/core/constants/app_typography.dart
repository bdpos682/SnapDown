import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// BDSNAP Typography System - 100% Google Roboto
class AppTypography {
  AppTypography._();

  static String get fontFamily => GoogleFonts.roboto().fontFamily ?? 'Roboto';

  // Display
  static TextStyle get display => GoogleFonts.roboto(
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.2,
  );

  // Headings
  static TextStyle get h1 => GoogleFonts.roboto(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static TextStyle get h2 => GoogleFonts.roboto(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static TextStyle get h3 => GoogleFonts.roboto(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  // Body
  static TextStyle get body => GoogleFonts.roboto(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.45,
  );

  static TextStyle get bodyMedium => GoogleFonts.roboto(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.45,
  );

  static TextStyle get bodySmall => GoogleFonts.roboto(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  // Label & Caption
  static TextStyle get label => GoogleFonts.roboto(
    fontSize: 11.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static TextStyle get caption => GoogleFonts.roboto(
    fontSize: 10.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.2,
  );
}
