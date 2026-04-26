import 'package:flutter/material.dart';

/// Utility Functions And Constants For Authentication Screens
class AuthUtils {
  /// Calculate Responsive Height Based On Screen Size
  static double getResponsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  /// Calculate Responsive Width Based On Screen Size
  static double getResponsiveWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  /// Get Bottom Inset For Keyboard Avoidance
  static double getBottomInset(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Build Background Radial Gradients For Authentication Screens
  static List<Widget> buildBackgroundGradients(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    final double width = MediaQuery.of(context).size.width;

    return [
      // Top Right Gradient
      Positioned(
        top: -height * 0.15,
        right: -width * 0.1,
        child: Container(
          width: width * 0.5,
          height: width * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [const Color(0xFF007AFF).withOpacity(0.08), Colors.transparent]),
          ),
        ),
      ),
      // Bottom Left Gradient
      Positioned(
        bottom: -height * 0.1,
        left: -width * 0.1,
        child: Container(
          width: width * 0.4,
          height: width * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [const Color(0xFFFF9500).withOpacity(0.06), Colors.transparent]),
          ),
        ),
      ),
    ];
  }
}
