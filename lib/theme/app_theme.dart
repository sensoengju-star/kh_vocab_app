import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const scaffold = Color(0xFFF6F9FF);
  static const navy = Color(0xFF0A1F4A);
  static const royal = Color(0xFF1F4FD8);
  static const ice = Color(0xFFE7F0FF);
  static const border = Color(0xFFD7E3FA);
  static const muted = Color(0xFF6B7A99);
  static const danger = Color(0xFFD7263D);
  static const success = Color(0xFF1B8A5A);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.royal,
        primary: AppColors.royal,
        secondary: AppColors.navy,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.scaffold,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.navy,
      displayColor: AppColors.navy,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.navy,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.inter(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.royal, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerColor: AppColors.border,
    );
  }

  /// Khmer-aware display text style. Noto Sans Khmer has different vertical
  /// metrics, so we use a slightly taller line-height.
  static TextStyle khmerDisplay({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.navy,
  }) {
    return GoogleFonts.notoSansKhmer(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.45,
    );
  }
}
