import 'package:flutter/material.dart';

/// ------------------------------------------------------
/// GLOBAL APP COLOR PALETTE
/// Keep all color constants here for easy reuse.
/// ------------------------------------------------------
class AppColors {
  /// Primary theme blue (backgrounds, buttons)
  static const Color primaryBlue = Color(0xFF2196F3);

  /// Slightly darker shade used for focused borders
  static const Color primaryBlueDark = Color(0xFF1976D2);

  /// Lighter blue for backgrounds or accents
  static const Color lightBlue = Color(0xFF64B5F6);

  /// White used inside cards and text fields
  static const Color white = Colors.white;

  /// Text color inside forms
  static const Color darkText = Color(0xFF333333);

  /// Light grey for borders & hint text
  static const Color lightGrey = Color(0xFFBDBDBD);

  /// Shadow color for card dropshadows
  static const Color shadow = Color(0x22000000); // 13% opacity black
}
