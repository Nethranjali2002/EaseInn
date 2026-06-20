import 'package:flutter/material.dart';

/// ==========================================
/// APP THEME - Centralized Styling Configuration
/// ==========================================
/// This class defines the visual styling for the entire EaseInn app.
/// Instead of hardcoding colors, border radiuses, and text styles
/// throughout the app, we define them here once and apply them globally.
///
/// Uses Flutter's Material 3 design system with a green color scheme
/// that matches the hospitality/resort branding of EaseInn.
///
/// Two themes are provided:
/// - Light theme (default) for daytime use
/// - Dark theme for low-light environments
/// ==========================================
class AppTheme {
  // Private constructor prevents instantiation - this is a static utility class
  AppTheme._();

  /// ==========================================
  /// COLOR PALETTE
  /// ==========================================
  /// Primary: Dark green (#1B5E20) - represents trust, nature, hospitality
  /// Secondary: Medium green (#4CAF50) - used for accents and highlights
  /// Surface: Light grey (#F5F5F5) - background color for cards and content areas
  /// ==========================================
  static const _primaryColor = Color(0xFF1B5E20);
  static const _secondaryColor = Color(0xFF4CAF50);
  static const _surfaceColor = Color(0xFFF5F5F5);

  /// ==========================================
  /// LIGHT THEME
  /// ==========================================
  /// The default theme for the app. Configures Material 3 components
  /// with consistent styling: rounded corners (12px), green accents,
  /// white input fields, and centered app bar titles.
  /// ==========================================
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: _primaryColor,
    scaffoldBackgroundColor: _surfaceColor,

    // App bar: centered title, no elevation by default, slight shadow when scrolled
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),

    // Cards: slight elevation with rounded corners for a modern look
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Input fields: white filled background, rounded borders, green focus state
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Elevated buttons: full-width, rounded, consistent with the design system
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  /// ==========================================
  /// DARK THEME
  /// ==========================================
  /// Alternative theme for dark mode. Uses a dark background (#121212),
  /// slightly elevated cards, and green accents for consistency.
  /// Input fields use a dark grey fill (#1E1E1E) to blend with the background.
  /// ==========================================
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: _secondaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _secondaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
