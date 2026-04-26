import 'package:flutter/material.dart';

/// Application Color Theme Constants
class AppColors {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color primaryPurple = Color(0xFF6366F1);
  static const Color secondaryPurple = Color(0xFF8B5CF6);

  // Icon Colors
  static const Color nameIconColor = Color(0xFF34C759);
  static const Color phoneIconColor = Color(0xFFDC241F);
  static const Color emailIconColor = Color(0xFF007AFF);
  static const Color passwordIconColor = Color(0xFFFF9500);
  static const Color confirmPasswordIconColor = Color(0xFF5856D6);

  // Status Colors
  static const Color successGreen = Color(0xFF34C759);
  static const Color errorRed = Color(0xFFFF3B30);
  static const Color warningOrange = Color(0xFFFF9500);

  // Neutral Colors
  static const Color backgroundColor = Colors.white;
  static const Color textColor = Colors.black87;
  static const Color hintTextColor = Color(0xFF666666);
  static const Color borderColor = Color(0xFFE5E5E5);

  // Gradient Colors
  static const List<Color> buttonGradient = [Color(0xFF6366F1), Color(0xFF8B5CF6)];
  static const List<Color> textGradient = [Color(0xFF6366F1), Color(0xFFFF6B95)];

  /// Get Hint Text Color With Shade Variation
  static Color getHintTextColor(BuildContext context) {
    return Colors.grey.shade700;
  }

  /// Get Border Color With Shade Variation
  static Color getBorderColor(BuildContext context) {
    return Colors.grey.shade300;
  }
}
