import 'package:flutter/material.dart';

/// BDSNAP 2026 Neo-Glass & Dynamic Depth Color System
class AppColors {
  AppColors._();

  // Bề mặt Chế độ Tối (Obsidian Thẳm)
  static const Color darkBackground = Color(0xFF0A0C13);
  static const Color darkSurface = Color(0xFF121520);
  static const Color darkCard = Color(0xFF191E2D);
  static const Color darkElevated = Color(0xFF21283B);
  static const Color darkHighlight = Color(0xFF2B334C);
  static const Color darkBorder = Color(0xFF2B334C);
  static const Color darkBorderSubtle = Color(0xFF1D2335);

  // Bề mặt Chế độ Sáng (Tinh Khôi & Ngọc Trai)
  static const Color lightBackground = Color(0xFFF5F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFEDF2F8);
  static const Color lightHighlight = Color(0xFFE1E7F0);
  static const Color lightBorder = Color(0xFFE1E7F0);
  static const Color lightBorderSubtle = Color(0xFFEEF2F7);

  // Màu điểm nhấn rực rỡ (Vibrant Accents)
  static const Color accentCyan = Color(0xFF00F2FE);
  static const Color accentBlue = Color(0xFF0070F3);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);

  // Dải màu chuyển sắc nghệ thuật (Gradients)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00F2FE), Color(0xFF0070F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Chữ & Biểu tượng Chế độ Tối
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Chữ & Biểu tượng Chế độ Sáng (Tương phản cao)
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Kính mờ cao cấp (Neo-Glass)
  static const Color liquidGlassDark = Color(0xCC111420);
  static const Color liquidGlassLight = Color(0xE6FFFFFF);
  static const Color liquidGlassElevatedDark = Color(0xD9181D2D);
  static const Color liquidGlassElevatedLight = Color(0xF2FFFFFF);
}
