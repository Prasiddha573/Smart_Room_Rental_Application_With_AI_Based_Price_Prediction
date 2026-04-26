import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import '../../chat/screens/chat_home_screen.dart' as chat;
import '../home/home_screen.dart';
import '../owner/owner_screen.dart';
import '../user/profile_screen.dart';

/// Main Screen Container With Persistent Bottom Navigation Bar
/// Houses Primary Application Tabs: Home, Pending, History, And Profile
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PersistentTabController _controller = PersistentTabController(initialIndex: 0);

  /// Build Screen Widgets For Each Navigation Tab
  List<Widget> _buildScreens() {
    return [
      const HomeScreen(), // Home Tab - Product Management
      OwnerScreen(), // Pending Tab - Credit Sales Management
      chat.ChatHomeScreen(), // History Tab - Completed Sales Records
      const ProfileScreen(), // Profile Tab - User Account Management
    ];
  }

  /// Build Navigation Bar Items With Consistent Styling
  List<PersistentBottomNavBarItem> _navBarsItems() {
    const activeColor = Colors.pink; // Active Tab Color
    const inactiveColor = Color(0xFF6B7280); // Inactive Tab Color

    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.home_rounded, size: 24),
        title: "Home",
        activeColorPrimary: activeColor,
        inactiveColorPrimary: inactiveColor,
        textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.dashboard_customize_rounded, size: 24),
        title: "Dashboard",
        activeColorPrimary: activeColor,
        inactiveColorPrimary: inactiveColor,
        textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.wechat_outlined, size: 24),
        title: "Chat",
        activeColorPrimary: activeColor,
        inactiveColorPrimary: inactiveColor,
        textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person_rounded, size: 24),
        title: "Profile",
        activeColorPrimary: activeColor,
        inactiveColorPrimary: inactiveColor,
        textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ];
  }


  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      context,
      controller: _controller,
      screens: _buildScreens(),
      items: _navBarsItems(),
      navBarStyle: NavBarStyle.style1, // Classic Bottom Navigation Style
      backgroundColor: Colors.white, // White Navigation Bar Background
      resizeToAvoidBottomInset: true, // Adjust For On-Screen Keyboard
      stateManagement: true, // Maintain Tab State
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // Compact Padding
      decoration: NavBarDecoration(
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)), // Top Border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, -3), // Top Shadow For Depth
          ),
        ],
      ),
    );
  }
}


/// Temporary Chat Tab Screen - Will be replaced with actual chat
class ChatTabScreen extends StatelessWidget {
  ChatTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Chats',
          style: GoogleFonts.quicksand(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              'Chat Feature',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Message room owners from room details',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}