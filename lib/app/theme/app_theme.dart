import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'accessibility_tokens.dart';

enum AppThemeMode {
  dark,
  light,
  highContrast,
}

/// VisionMate 2.0 Theme Configuration
class AppTheme {
  AppTheme._();

  /// Default Midnight Blue / Cyber Dark Mode (Matches Reference UI Mockup)
  static ThemeData get darkTheme {
    final textTheme = AppTypography.createTextTheme(
      AppColors.textPrimaryDark,
      AppColors.textSecondaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryCyan,
        onPrimary: AppColors.backgroundDark,
        secondary: AppColors.accentViolet,
        onSecondary: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        error: AppColors.emergencyRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
          side: const BorderSide(color: AppColors.cardBorderDark, width: 1.2),
        ),
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(AccessibilityTokens.minTouchTarget, AccessibilityTokens.primaryActionMinSize),
          backgroundColor: AppColors.primaryCyan,
          foregroundColor: AppColors.backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
        size: 26,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryCyan,
        unselectedItemColor: AppColors.textMutedDark,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }

  /// High-Contrast Accessible Mode (Pure Black, Pure White, Vibrant Yellow)
  static ThemeData get highContrastTheme {
    final textTheme = AppTypography.createTextTheme(
      AppColors.hcTextPrimary,
      AppColors.hcTextSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.hcBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.hcYellow,
        onPrimary: AppColors.hcBackground,
        secondary: AppColors.hcCyan,
        onSecondary: AppColors.hcBackground,
        surface: AppColors.hcSurface,
        onSurface: AppColors.hcTextPrimary,
        error: AppColors.emergencyRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.hcCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
          side: const BorderSide(color: AppColors.hcBorder, width: AccessibilityTokens.focusBorderWidth),
        ),
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(AccessibilityTokens.minTouchTarget, AccessibilityTokens.primaryActionMinSize),
          backgroundColor: AppColors.hcYellow,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.hcYellow,
        size: 30,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.hcYellow,
        unselectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  /// Light Theme
  static ThemeData get lightTheme {
    final textTheme = AppTypography.createTextTheme(
      AppColors.textPrimaryLight,
      AppColors.textSecondaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        secondary: AppColors.accentViolet,
        onSecondary: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.emergencyRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
          side: const BorderSide(color: AppColors.cardBorderLight, width: 1.2),
        ),
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(AccessibilityTokens.minTouchTarget, AccessibilityTokens.primaryActionMinSize),
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
          ),
        ),
      ),
    );
  }
}
