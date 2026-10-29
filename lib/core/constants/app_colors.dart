import 'package:flutter/material.dart';

/// Centralized colors for consistent UI across the application.
abstract final class AppColors {
  // Brand colours, taken from the NPL Community logo.
  static const Color primary = Color(0xFF0D2B73);   // navy
  static const Color accent = Color(0xFFE5294B);    // logo red
  static const Color highlight = Color(0xFF1E6FF0); // mountain blue

  // Neutrals, with a slight blue tint to suit the navy.
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF14213D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE1E6F0);

  // Login screen gradient (same navy as the app icon).
  static const Color gradientTop = Color(0xFF002678);
  static const Color gradientBottom = Color(0xFF00113C);
}