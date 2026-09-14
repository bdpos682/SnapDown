import 'package:flutter/material.dart';

/// SnapDown 2026 Premium Design Tokens - Color Palette
class AppColors {
  AppColors._();

  // Dark Theme Surfaces (Cinematic Deep Obsidian)
  static const Color darkBackground = Color(0xFF090A0E);
  static const Color darkSurface = Color(0xFF12141C);
  static const Color darkElevated = Color(0xFF1A1D28);
  static const Color darkHighlight = Color(0xFF242837);
  static const Color darkBorder = Color(0xFF2C3243);
  static const Color darkBorderSubtle = Color(0xFF1E222F);

  // Light Theme Surfaces (Premium Clean Studio Slate & Crisp White)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF1F5F9);
  static const Color lightHighlight = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFEDF2F7);

  // Accent Colors
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentBlue = Color(0xFF0066FF);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentRed = Color(0xFFFF3366);
  static const Color accentGreen = Color(0xFF00C853);
  static const Color accentPurple = Color(0xFF9D4EDD);

  // Gradients
  static const LinearGradient cyanBlueGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0077FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightPrimaryGradient = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF00C2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberOrangeGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Text Colors
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFA1A8BA);
  static const Color darkTextTertiary = Color(0xFF6B7285);

  // Light Text Colors (High Contrast Slate)
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Liquid Glass iOS 27 Tokens
  static const Color liquidGlassDark = Color(0x99121624);
  static const Color liquidGlassLight = Color(0xAAFFFFFF);
  static const Color liquidGlassElevatedDark = Color(0xBB1E2235);
  static const Color liquidGlassElevatedLight = Color(0xDDFFFFFF);

  // Specular Refraction Gradients
  static const LinearGradient liquidBorderDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66FFFFFF), // Specular light reflection top
      Color(0x1A00E5FF), // Subtle cyan refraction
      Color(0x0DFFFFFF), // Bottom subtle bleed
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient liquidBorderLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF), // Pure white specular sheen
      Color(0x330066FF), // Azure refraction
      Color(0x15000000), // Shadow edge
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient liquidDropletActive = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0077FE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
