import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modern iOS-inspired Palette
  static const Color _primaryPropulsion = Color(0xFF5E5CE6); // Electric Indigo
  static const Color _secondaryOrbit = Color(0xFF64D2FF); // Cyan Blue

  static const Color _surfaceDark = Color(0xFF1C1C1E); // Apple-style Dark Gray
  static const Color _backgroundDark = Color(0xFF000000); // Pure Black for OLED

  static const Color _surfaceLight = Color(0xFFF2F2F7); // iOS System Gray 6
  static const Color _backgroundLight = Color(0xFFFFFFFF);

  static const Color _errorSystem = Color(0xFFFF453A); // iOS Red
  static const Color _successSystem = Color(0xFF32D74B); // iOS Green

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _backgroundDark,
      primaryColor: _primaryPropulsion,
      colorScheme: const ColorScheme.dark(
        primary: _primaryPropulsion,
        secondary: _secondaryOrbit,
        surface: _surfaceDark,
        error: _errorSystem,
        tertiary: _successSystem,
        onSurface: Colors.white,
        primaryContainer: Color(0xFF2C2C2E),
        onPrimaryContainer: Colors.white,
        surfaceContainerHighest: Color(0xFF3A3A3C),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundDark, // Pure black for OLED
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      dividerColor: Colors.white10,
      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _backgroundLight,
      primaryColor: _primaryPropulsion,
      colorScheme: const ColorScheme.light(
        primary: _primaryPropulsion,
        secondary: _secondaryOrbit,
        surface: _surfaceLight,
        error: _errorSystem,
        tertiary: _successSystem,
        onSurface: Colors.black,
        primaryContainer: Color(0xFFE5E5EA),
        onPrimaryContainer: Colors.black,
        surfaceContainerHighest: Color(0xFFE5E5EA),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
            color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      dividerColor: Colors.black12,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
