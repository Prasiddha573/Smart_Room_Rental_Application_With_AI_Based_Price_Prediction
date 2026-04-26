import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../main/main_screen.dart';

/// Splash Screen - First Screen Displayed When App Launches
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Timer For Navigation Delay
  Timer? _navigationTimer;

  // Animation Controller For Smooth Fade Effect
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Get Authentication Service Instance
  final AuthService _authService = Get.find<AuthService>();

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // 2 Second Fade Duration
      vsync: this,
    );

    // Create Smooth Fade Animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut, // Smooth Easing Curve
      ),
    );

    // Start Fade Animation
    _animationController.forward();

    // Start Navigation Timer When Screen Initializes
    _startNavigationTimer();
  }

  @override
  void dispose() {
    // Cancel Timer To Prevent Memory Leaks
    _navigationTimer?.cancel();

    // Dispose Animation Controller
    _animationController.dispose();

    super.dispose();
  }

  /// Start Timer For Automatic Navigation After Delay
  void _startNavigationTimer() {
    _navigationTimer = Timer(
      const Duration(milliseconds: 3500), // 3.5 Seconds Total Delay
      _navigateBasedOnAuthStatus,
    );
  }

  /// Navigate Based On User Authentication Status
  void _navigateBasedOnAuthStatus() {
    if (_authService.isLoggedIn) {
      // User Is Already Logged In, Navigate To Home Screen
      Get.off(() => const MainScreen());
    } else {
      // User Is Not Logged In, Navigate To Login Screen
      Get.off(() => LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Very Dark Blue Gradient Background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000814), // Almost Black Blue
              Color(0xFF001D3D), // Very Dark Blue
              Color(0xFF003566), // Dark Blue
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Thin White Outline (No Fill Color)
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 0.4, // Thin Outline
                ),
              ),
              child: Center(
                child: Lottie.asset('assets/images/smart_room.json', width: 160, height: 160, fit: BoxFit.contain, repeat: true, frameRate: FrameRate.max),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
