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

  final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
    bodyColor: isDark ? const Color(0xFFF5F5F5) : AppColors.textPrimary,
    displayColor: isDark ? const Color(0xFFF5F5F5) : AppColors.textPrimary,
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    cardColor: base.colorScheme.surface,
    dialogTheme: DialogThemeData(
      backgroundColor: base.colorScheme.surface,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
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
