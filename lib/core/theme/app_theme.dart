import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: isDark ? const Color(0xFF0F0B08) : AppColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.burntOrange,
      primary: AppColors.burntOrange,
      secondary: AppColors.mustardYellow,
      // Dark mode: use a deep muted orange for card surfaces so cards feel orange yet dark
      surface: isDark ? const Color(0xFF3A1F0F) : AppColors.cardBackground,
      onSurface: isDark ? const Color(0xFFFFEDE0) : AppColors.textPrimary,
      brightness: brightness,
    ),
  );

  final textTheme = GoogleFonts.nunitoSansTextTheme(base.textTheme).apply(
    bodyColor: isDark ? const Color(0xFFF5F5F5) : AppColors.textPrimary,
    displayColor: isDark ? const Color(0xFFF5F5F5) : AppColors.textPrimary,
  );

  return base.copyWith(
    dividerColor: isDark ? const Color(0xFF65412F) : AppColors.divider,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? const Color(0xFFFFEDE0) : AppColors.textPrimary,
      elevation: 0,
    ),
    cardColor: base.colorScheme.surface,
    dialogTheme: DialogThemeData(backgroundColor: base.colorScheme.surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF261710) : const Color(0xFFFFFBF6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF65412F) : AppColors.cardStroke,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF65412F) : AppColors.cardStroke,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.burntOrange, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.burntOrange,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: isDark ? const Color(0xFF8A5A40) : AppColors.cardStroke,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.progressTrack,
      selectedColor: AppColors.burntOrange,
      checkmarkColor: AppColors.white,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      secondaryLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.burntOrange,
      unselectedItemColor: AppColors.textSecondary,
      backgroundColor: AppColors.cardBackground,
      showUnselectedLabels: true,
    ),
  );
}
