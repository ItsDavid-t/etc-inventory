import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFF073B66);
  static const secondary = Color(0xFF168BC2);
  static const lightBlue = Color(0xFFE5F3FA);
  static const lightBackground = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF263746);
  static const textSecondary = Color(0xFF82909D);
  static const border = Color(0xFFE9EEF2);
  static const darkBackground = Color(0xFF162B3A);

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: primary,
      secondary: secondary,
      tertiary: Color(0xFFE38A22),
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border,
      primaryContainer: lightBlue,
      onPrimaryContainer: primary,
      secondaryContainer: lightBlue,
      onSecondaryContainer: primary,
    );
    return _build(scheme, lightBackground);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: Color(0xFF65B9E4),
      secondary: Color(0xFF65B9E4),
      tertiary: Color(0xFFFFB45C),
      surface: Color(0xFF203D50),
      onSurface: Color(0xFFF2F7FA),
      onSurfaceVariant: Color(0xFFB7C7D2),
      outline: Color(0xFF496679),
      outlineVariant: Color(0xFF496679),
      primaryContainer: Color(0xFF285A78),
      onPrimaryContainer: Color(0xFFDDF2FA),
      secondaryContainer: Color(0xFF285A78),
      onSecondaryContainer: Color(0xFFDDF2FA),
    );
    return _build(scheme, darkBackground);
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      fontFamily: GoogleFonts.poppins().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(128)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
