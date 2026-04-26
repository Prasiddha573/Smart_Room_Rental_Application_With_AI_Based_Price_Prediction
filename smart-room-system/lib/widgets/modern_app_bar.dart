import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern color palette for consistent theming across the application
/// Follows Material Design 3 color system principles
class ModernColors {
  static const Color primary = Color(0xFF6366F1); // Primary brand color (Indigo)
  static const Color primaryDark = Color(0xFF4F46E5); // Darker shade for pressed states
  static const Color surface = Color(0xFFFFFFFF); // Surface/card background color
  static const Color background = Color(0xFFF8FAFC); // Main app background color
  static const Color onSurface = Color(0xFF1E293B); // Text/icon color on surfaces
  static const Color onSurfaceVariant = Color(0xFF64748B); // Secondary text color
  static const Color outline = Color(0xFFE2E8F0); // Border/divider color
  static const Color primaryContainer = Color(0xFFEEF2FF); // Container for primary color
}

/// Modern app bar with gradient background and decorative floating shapes
/// Provides a consistent header component with back navigation support
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; // The title text to display in the app bar
  final bool showAddButton; // Whether to show the add button
  final VoidCallback? onAddPressed; // Callback when add button is pressed

  const ModernAppBar({
    super.key,
    required this.title,
    this.showAddButton = false,
    this.onAddPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(50.0); // Fixed height for app bar

  /// Creates a circular shape decoration for the floating background elements
  Widget _buildFloatingShape(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle, // Circular shape for soft visual elements
      ),
    );
  }

  /// Builds the decorative background layer with floating shapes and gradient overlay
  /// Creates a visually appealing depth effect behind the app bar content
  Widget _buildAppBarDecoration(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ModernColors.primary.withOpacity(0.05), // Subtle gradient start
            ModernColors.primary.withOpacity(0.02), // Subtle gradient end
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12.0), // Matches app bar border radius
        ),
      ),
      child: Stack(
        children: [
          // Multiple floating circles with varying sizes, positions, and opacities
          // Creates a dynamic, layered background effect
          Positioned(top: -10, left: 20, child: _buildFloatingShape(25, ModernColors.primary.withOpacity(0.08))),
          Positioned(bottom: 10, right: 40, child: _buildFloatingShape(40, ModernColors.primary.withOpacity(0.06))),
          Positioned(top: 30, left: 100, child: _buildFloatingShape(30, ModernColors.primary.withOpacity(0.1))),
          Positioned(top: 5, right: 80, child: _buildFloatingShape(15, ModernColors.primary.withOpacity(0.12))),
          Positioned(bottom: -5, left: 120, child: _buildFloatingShape(20, ModernColors.primary.withOpacity(0.08))),
          Positioned(bottom: -15, right: 5, child: _buildFloatingShape(35, ModernColors.primary.withOpacity(0.06))),
          Positioned(top: -25, right: 15, child: _buildFloatingShape(50, ModernColors.primary.withOpacity(0.08))),
          Positioned(top: 55, left: 5, child: _buildFloatingShape(10, ModernColors.primary.withOpacity(0.1))),
          Positioned(top: -5, left: 180, child: _buildFloatingShape(22, ModernColors.primary.withOpacity(0.07))),
          Positioned(bottom: 25, left: 50, child: _buildFloatingShape(18, ModernColors.primary.withOpacity(0.09))),
          Positioned(top: 15, right: 20, child: _buildFloatingShape(14, ModernColors.primary.withOpacity(0.12))),
          Positioned(top: 5, left: 50, child: _buildFloatingShape(16, ModernColors.primary.withOpacity(0.08))),
          Positioned(top: 40, right: 100, child: _buildFloatingShape(12, ModernColors.primary.withOpacity(0.1))),
          Positioned(bottom: 0, left: 30, child: _buildFloatingShape(22, ModernColors.primary.withOpacity(0.06))),
          Positioned(bottom: 40, right: 10, child: _buildFloatingShape(18, ModernColors.primary.withOpacity(0.12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(15.0), // Outer container border radius
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Subtle shadow for depth
            blurRadius: 7,
            offset: const Offset(0, 2), // Downward shadow offset
          ),
        ],
      ),
      child: AppBar(
        toolbarHeight: 60, // Increased height for better visual presence
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, // Transparent status bar
          statusBarIconBrightness: Brightness.dark, // Dark icons for light background
          statusBarBrightness: Brightness.light, // Light status bar content
        ),
        backgroundColor: Colors.white, // Primary app bar background color
        elevation: 0, // Remove default Material elevation
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20.0), // App bar bottom border radius
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.quicksand(
            letterSpacing: 1.0, // Increased letter spacing for readability
            fontSize: 17,
            fontWeight: FontWeight.w800, // Bold weight for emphasis
            color: ModernColors.onSurface, // High contrast text color
          ),
        ),
        centerTitle: true, // Center align the title text
        actions: showAddButton
            ? [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernColors.primary,
                      ModernColors.primaryDark,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ModernColors.primary.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              onPressed: onAddPressed ?? () {},
              tooltip: 'Add New Room',
            ),
          ),
        ]
            : null, // No action items by default
        flexibleSpace: ClipRRect(
          // Clips child to rounded borders
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12.0), // Matches decoration border radius
          ),
          child: Column(
            children: [
              Expanded(
                child: _buildAppBarDecoration(context), // Background decoration layer
              ),
              // Decorative gradient border at bottom
              Container(
                height: 1.5, // Thin border height
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ModernColors.outline.withOpacity(0.8),
                      ModernColors.outline.withOpacity(0.4), // Center lighter
                      ModernColors.outline.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}