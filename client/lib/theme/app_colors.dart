import 'package:flutter/material.dart';

/// A central class to hold all color constants for the app.
///
/// Add your exact hex color codes here.
/// To keep the theme uniform, always reference [AppColors] instead of hardcoding colors.
class AppColors {
  // --- Replace these with your actual color codes ---

  /// Primary brand color. Used for prominent active elements like buttons.
  static const Color primary = Color(0xFFC2A892);

  /// Secondary brand color. Used for less prominent elements.
  static const Color secondary = Color(0xFFA67C52);

  static const Color tertiary = Color(0xFF8E7F71);

  /// A background color used for the main screens of the app.
  static const Color background = Color(0xFFECEBE7);

  /// Default text color.
  static const Color textPrimary = Color(0xFF000000);

  /// Lighter text color for subtitles or less important text.
  static const Color textSecondary = Color(0xFF49454F);

  // --- Example Contextual Colors ---

  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFB3261E);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  // --- Weather Widget Specific Colors ---

  static const Color weatherSun = Color(0xFFFFA726); // Orange for the sun icon
}
