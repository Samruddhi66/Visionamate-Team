import 'package:flutter/material.dart';

/// VisionMate 2.0 Design System Color Palette
/// Designed for high visual contrast, WCAG 2.1 AAA compliance, and modern aesthetics.
class AppColors {
  AppColors._();

  // Dark Theme / Brand Core Colors (Reference Image: Deep Navy & Midnight Blue)
  static const Color backgroundDark = Color(0xFF090D1A);
  static const Color surfaceDark = Color(0xFF111728);
  static const Color cardDark = Color(0xFF162036);
  static const Color cardBorderDark = Color(0xFF223152);

  // High-Energy Primary Accents
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryBlue = Color(0xFF2979FF);
  static const Color accentViolet = Color(0xFF7C4DFF);
  static const Color accentPurple = Color(0xFF9C27B0);

  // Status & Feature Identifiers
  static const Color currencyEmerald = Color(0xFF00E676);
  static const Color emergencyRed = Color(0xFFFF3B30);
  static const Color emergencyRedGlow = Color(0x66FF3B30);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color successGreen = Color(0xFF00E676);
  static const Color infoBlue = Color(0xFF00B0FF);

  // Text & Content (Dark Mode)
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0BEC5);
  static const Color textMutedDark = Color(0xFF78909C);

  // Light Theme (Clean High-Contrast)
  static const Color backgroundLight = Color(0xFFF4F7FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFEBF1FA);
  static const Color cardBorderLight = Color(0xFFCFD8DC);
  static const Color textPrimaryLight = Color(0xFF0A0F1D);
  static const Color textSecondaryLight = Color(0xFF37474F);

  // Accessible High-Contrast Theme (Pure Black, Pure White, Neon Yellow)
  static const Color hcBackground = Color(0xFF000000);
  static const Color hcSurface = Color(0xFF000000);
  static const Color hcCard = Color(0xFF000000);
  static const Color hcBorder = Color(0xFFFFFFFF);
  static const Color hcYellow = Color(0xFFFFFF00);
  static const Color hcCyan = Color(0xFF00FFFF);
  static const Color hcTextPrimary = Color(0xFFFFFFFF);
  static const Color hcTextSecondary = Color(0xFFFFFF00);
}
