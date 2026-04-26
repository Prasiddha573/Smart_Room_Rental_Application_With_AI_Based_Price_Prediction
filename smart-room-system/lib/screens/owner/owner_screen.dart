import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/toast_service.dart';
import '../../widgets/modern_app_bar.dart';
import 'owner_room_details_dialog.dart';

/// Owner Screen For Viewing User Requests And Order Status
class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  int _currentTabIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ToastService _toastService = ToastService();

  void _changeTab(int index) {
    setState(() {
      _currentTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 350;
    final double horizontalPadding = isSmallScreen ? 12 : 14;
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ModernAppBar(title: "User Dashboard"),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),

              // Static Toggle Container - Never refreshes during loading
              Container(
                margin: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildToggleButton(
                            icon: Icons.event_available_rounded,
                            label: 'Active',
                            isSelected: _currentTabIndex == 0,
                            onTap: () => _changeTab(0),
                          ),
                        ),
                        Expanded(
                          child: _buildToggleButton(
                            icon: Icons.history_rounded,
                            label: 'History',
                            isSelected: _currentTabIndex == 1,
                            onTap: () => _changeTab(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content Section with AnimatedSwitcher for smooth transitions
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.05),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: currentUserId == null
                    ? _buildLoginRequired(key: const ValueKey('login'))
                    : _currentTabIndex == 0
                    ? _buildActiveSection(isSmallScreen, currentUserId, key: const ValueKey('active'))
                    : _buildHistorySection(isSmallScreen, currentUserId, key: const ValueKey('history')),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequired({Key? key}) {
    return FadeInWidget(
      key: key,
      delay: Duration.zero,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.login_rounded, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Please Login',
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to login to view your rooms',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSection(bool isSmallScreen, String currentUserId, {Key? key}) {
    return StreamBuilder<QuerySnapshot>(
      key: key,
      stream: _firestore
          .collection('bookings')
          .where('ownerId', isEqualTo: currentUserId)
          .where('bookingStatus', isEqualTo: 'requested')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSimpleLoading();
        }

        final bookings = snapshot.data!.docs;
        final bookingCount = bookings.length;

        if (bookingCount == 0) {
          // CENTERED MESSAGE FOR NO ACTIVE REQUESTS
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No active requests',
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Booking requests will appear here',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            // Results Title with fade-in
            FadeInWidget(
              delay: const Duration(milliseconds: 100),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: isSmallScreen ? 30 : 90,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Active Booking Requests",
                      style: GoogleFonts.quicksand(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$bookingCount requests pending",
                      style: GoogleFonts.quicksand(
                        fontSize: isSmallScreen ? 13 : 14,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Room Cards with staggered animation
            ...List.generate(bookings.length, (index) {
              final bookingDoc = bookings[index];
              final booking = bookingDoc.data() as Map<String, dynamic>;
              final roomDocumentId = booking['roomDocumentId']?.toString() ?? '';

              return StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('room').doc(roomDocumentId).snapshots(),
                builder: (context, roomSnapshot) {
                  if (roomSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildSimpleCardLoading(isSmallScreen, index);
                  }

                  if (!roomSnapshot.hasData || !roomSnapshot.data!.exists) {
                    return FadeInWidget(
                      delay: Duration(milliseconds: 100 + (index * 100)),
                      child: _buildMissingRoomCard(
                        booking: booking,
                        isSmallScreen: isSmallScreen,
                      ),
                    );
                  }

                  final room = roomSnapshot.data!.data() as Map<String, dynamic>;
                  final roomWithBooking = Map<String, dynamic>.from(room);
                  roomWithBooking['bookingId'] = booking['bookingId'];
                  roomWithBooking['userEmail'] = booking['userEmail'];
                  roomWithBooking['bookingDate'] = booking['bookingDate'];
                  roomWithBooking['bookingStatus'] = booking['bookingStatus'];
                  roomWithBooking['userId'] = booking['userId'];

                  return FadeInWidget(
                    delay: Duration(milliseconds: 100 + (index * 100)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
                      child: CompactRoomCardFromFirestore(
                        room: roomWithBooking,
                        roomDocumentId: roomDocumentId,
                        isSmallScreen: isSmallScreen,
                        isOwnerView: true,
                        showBookingInfo: true,
                        isHistoryView: false, // Active requests are NOT history view
                        shouldShowUserInfo: true, // Show user info for active requests
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }
  Widget _buildHistorySection(bool isSmallScreen, String currentUserId, {Key? key}) {
    bool _showMyBookedRooms = false;

    return StatefulBuilder(
      builder: (context, setState) {
        if (_showMyBookedRooms) {
          // Show rooms booked by current user (user as a renter)
          return StreamBuilder<QuerySnapshot>(
            key: key,
            stream: _firestore
                .collection('bookings')
                .where('userId', isEqualTo: currentUserId)
                .where('bookingStatus', whereIn: ['booked', 'rejected', 'requested'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                // Simple loading indicator without shimmer for My Room section
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                );
              }

              final bookings = snapshot.data!.docs;
              final bookingCount = bookings.length;

              return Column(
                children: [
                  // Results Title with filter button
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "My Booked Rooms",
                              style: GoogleFonts.quicksand(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$bookingCount rooms booked",
                              style: GoogleFonts.quicksand(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // SIMPLIFIED TOGGLE BUTTON FOR MY ROOM SECTION - ACTIVE STATE (PINK)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showMyBookedRooms = !_showMyBookedRooms;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899), // PINK COLOR WHEN ACTIVE
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEC4899), // PINK BORDER WHEN ACTIVE
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEC4899).withOpacity(0.3),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.meeting_room_rounded,
                              size: 18,
                              color: Colors.white, // WHITE ICON WHEN ACTIVE
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // If no booked rooms
                  if (bookingCount == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(Icons.bed_rounded, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No Booked Rooms',
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rooms you booked will appear here',
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Booked Room Cards without the "My Booked Room" badge
                  ...List.generate(bookings.length, (index) {
                    final bookingDoc = bookings[index];
                    final booking = bookingDoc.data() as Map<String, dynamic>;
                    final roomDocumentId = booking['roomDocumentId']?.toString() ?? '';

                    return StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('room').doc(roomDocumentId).snapshots(),
                      builder: (context, roomSnapshot) {
                        if (roomSnapshot.connectionState == ConnectionState.waiting) {
                          // Simple loading placeholder without shimmer
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 20,
                              vertical: 8,
                            ),
                            child: Container(
                              height: 150,
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                                color: Colors.white,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          );
                        }

                        if (!roomSnapshot.hasData || !roomSnapshot.data!.exists) {
                          return _buildMissingRoomCard(
                            booking: booking,
                            isSmallScreen: isSmallScreen,
                          );
                        }

                        final room = roomSnapshot.data!.data() as Map<String, dynamic>;
                        final roomWithBooking = Map<String, dynamic>.from(room);
                        roomWithBooking['bookingId'] = booking['bookingId'];
                        roomWithBooking['userEmail'] = booking['userEmail'];
                        roomWithBooking['bookingDate'] = booking['bookingDate'];
                        roomWithBooking['bookingStatus'] = booking['bookingStatus'];
                        roomWithBooking['userId'] = booking['userId'];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
                          child: CompactRoomCardFromFirestore(
                            room: roomWithBooking,
                            roomDocumentId: roomDocumentId,
                            isSmallScreen: isSmallScreen,
                            isOwnerView: true,
                            showBookingInfo: true,
                            isHistoryView: true, // Booked rooms are history view
                            shouldShowUserInfo: false, // Don't show user info for ANY history section items
                            isBookedRoom: true,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ],
              );
            },
          );
        } else {
          // Show rooms uploaded by owner (default view) - WITHOUT SHIMMER ANIMATION
          return StreamBuilder<QuerySnapshot>(
            key: key,
            stream: _firestore
                .collection('room')
                .where('sessionId', isEqualTo: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSimpleLoading();
              }

              final rooms = snapshot.data!.docs;
              final roomCount = rooms.length;

              return Column(
                children: [
                  // Results Title with filter button
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "My Uploaded Rooms",
                              style: GoogleFonts.quicksand(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$roomCount rooms uploaded",
                              style: GoogleFonts.quicksand(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // SIMPLIFIED TOGGLE BUTTON FOR MY ROOM SECTION - INACTIVE STATE
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showMyBookedRooms = !_showMyBookedRooms;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.meeting_room_rounded,
                              size: 18,
                              color: const Color(0xFF64748B), // GREY ICON WHEN INACTIVE
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // If no rooms uploaded
                  if (roomCount == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(Icons.meeting_room_rounded, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No Rooms Uploaded',
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rooms you upload will appear here',
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Room Cards - For uploaded rooms, pass isHistoryView: true
                  ...List.generate(rooms.length, (index) {
                    final roomDoc = rooms[index];
                    final room = roomDoc.data() as Map<String, dynamic>;
                    final roomDocumentId = roomDoc.id;

                    return FadeInWidget(
                      delay: Duration(milliseconds: 100 + (index * 100)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
                        child: CompactRoomCardFromFirestore(
                          room: room,
                          roomDocumentId: roomDocumentId,
                          isSmallScreen: isSmallScreen,
                          isOwnerView: true,
                          showBookingInfo: false,
                          isHistoryView: true, // Uploaded rooms in history section
                          shouldShowUserInfo: false, // Don't show user info for ANY history section items
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // PINK GRADIENT FOR ACTIVE TAB WHEN SELECTED
    final Gradient selectedGradient = const LinearGradient(
      colors: [Color(0xFFEC4899), Color(0xFFF97316)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // BLUE GRADIENT FOR HISTORY TAB WHEN SELECTED
    final Gradient historyGradient = const LinearGradient(
      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: isSelected
              ? (label == 'Active' ? selectedGradient : historyGradient)
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Row(
              key: ValueKey(isSelected ? 'selected_$label' : 'unselected_$label'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: CircularProgressIndicator(
          color: const Color(0xFF3B82F6),
        ),
      ),
    );
  }

  Widget _buildSimpleCardLoading(bool isSmallScreen, int index) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 8,
      ),
      child: Container(
        height: 150,
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          color: Colors.white,
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: const Color(0xFF3B82F6),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingRoomCard({
    required Map<String, dynamic> booking,
    required bool isSmallScreen,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Booking ID: ${booking['bookingId'] ?? 'Unknown'}",
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Room data not found",
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF44336),
                      Color(0xFFD32F2F),
                    ],
                  ),
                ),
                child: Text(
                  "Room Missing",
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade300, height: 1),
          const SizedBox(height: 12),
          Text(
            "User: ${booking['userEmail'] ?? 'Unknown'}",
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Status: ${booking['bookingStatus'] ?? 'Unknown'}",
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "User ID: ${booking['userId'] ?? 'Unknown'}",
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// FADE IN WIDGET FOR STAGGERED ANIMATIONS
// ==============================
class FadeInWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeInWidget({
    Key? key,
    required this.child,
    this.delay = Duration.zero,
  }) : super(key: key);

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _offset = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0.0, _offset.value.dy * 20),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ==============================
// UPDATED ROOM CARD WITH OWNER VIEW
// ==============================
class CompactRoomCardFromFirestore extends StatefulWidget {
  final Map<String, dynamic> room;
  final String roomDocumentId;
  final bool isSmallScreen;
  final bool isOwnerView;
  final bool showBookingInfo;
  final bool isBookedRoom;
  final bool isHistoryView;
  final bool shouldShowUserInfo;

  const CompactRoomCardFromFirestore({
    super.key,
    required this.room,
    required this.roomDocumentId,
    required this.isSmallScreen,
    this.isOwnerView = false,
    this.showBookingInfo = true,
    this.isBookedRoom = false,
    this.isHistoryView = false,
    this.shouldShowUserInfo = true,
  });

  @override
  State<CompactRoomCardFromFirestore> createState() => _CompactRoomCardFromFirestoreState();
}

class _CompactRoomCardFromFirestoreState extends State<CompactRoomCardFromFirestore> {
  bool _imageLoading = true;

  // Check if distance <= 2.0 km for badge display
  bool get _isNearKU {
    final distance = _getFormattedDistance();
    try {
      final match = RegExp(r'([0-9.]+)').firstMatch(distance);
      if (match != null) {
        final km = double.parse(match.group(1)!);
        return km <= 2.0;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  String _getFormattedDistance() {
    final distance = widget.room['distance']?.toString() ?? "0.0";
    if (!distance.toLowerCase().contains('km')) {
      return '$distance km';
    }
    return distance;
  }

  String _getStatus() {
    if (widget.showBookingInfo) {
      return widget.room['bookingStatus']?.toString().toLowerCase() ?? 'requested';
    } else {
      return widget.room['status']?.toString().toLowerCase() ?? 'available';
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return 'Requested';
      case 'booked':
        return 'Booked';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'available':
        return 'Available';
      default:
        return 'Available';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return const Color(0xFFFF9800);
      case 'booked':
        return const Color(0xFF7C3AED);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'rejected':
        return const Color(0xFF6B7280);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'available':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = (widget.room['images'] as List<dynamic>?)?.whereType<String>().toList() ?? [];
    final mainImage = images.isNotEmpty ? images[0] : null;

    final title = widget.room['roomName']?.toString() ?? "Unnamed Room";
    final walkTime = widget.room['walkTime']?.toString() ?? "0 min";
    final location = "$walkTime walk from KU Gate";
    final water = widget.room['water']?.toString() ?? "Available";
    final sunlight = widget.room['sunlight']?.toString() ?? "Good";
    final size = "${widget.room['size']?.toString() ?? '0'} Sq Ft";
    final priceNPR = widget.room['price'] is int ? widget.room['price'] as int : int.tryParse(widget.room['price']?.toString() ?? '0') ?? 0;
    final distance = _getFormattedDistance();
    final internetSpeed = "${widget.room['internet']?.toString() ?? '0'} Mbps";
    final status = _getStatus();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: widget.isSmallScreen ? 16 : 20,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.isSmallScreen ? 16 : 20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2E8F0).withOpacity(0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.isSmallScreen ? 16 : 20),
                  topRight: Radius.circular(widget.isSmallScreen ? 16 : 20),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: widget.isSmallScreen ? 150 : 170,
                  child: mainImage != null
                      ? _buildCachedImageWithShimmer(mainImage)
                      : Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Icon(
                        Icons.photo_library_rounded,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              if (_isNearKU)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      "Near KU Gate",
                      style: GoogleFonts.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: EdgeInsets.all(widget.isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.quicksand(
                              fontSize: widget.isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: widget.isSmallScreen ? 13 : 15,
                                color: Colors.red,
                              ),
                              SizedBox(width: widget.isSmallScreen ? 4 : 6),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.quicksand(
                                    fontSize: widget.isSmallScreen ? 12 : 13,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: widget.isSmallScreen ? 8 : 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _getStatusColor(status),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(status).withOpacity(0.3),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: GoogleFonts.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: widget.isSmallScreen ? 10 : 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "💧 Water: $water",
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "☀️ Sunlight: $sunlight",
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF57C00),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: widget.isSmallScreen ? 12 : 14),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCompactSpecItem(
                        Icons.square_foot_rounded,
                        "Size",
                        size,
                        const Color(0xFF007AFF),
                        widget.isSmallScreen,
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: const Color(0xFFE2E8F0).withOpacity(0.3),
                      ),
                      _buildCompactSpecItem(
                        Icons.wifi_rounded,
                        "Internet",
                        internetSpeed,
                        const Color(0xFF4CAF50),
                        widget.isSmallScreen,
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: const Color(0xFFE2E8F0).withOpacity(0.3),
                      ),
                      _buildCompactSpecItem(
                        Icons.directions_walk_rounded,
                        "Distance",
                        distance,
                        const Color(0xFFFF9800),
                        widget.isSmallScreen,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: widget.isSmallScreen ? 12 : 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Monthly Rent",
                          style: GoogleFonts.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              "NPR",
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: const Color(0xFF64748B).withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              " $priceNPR",
                              style: GoogleFonts.quicksand(
                                fontSize: widget.isSmallScreen ? 20 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B).withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "/month",
                              style: GoogleFonts.quicksand(
                                fontSize: 11,
                                color: const Color(0xFF64748B).withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF0056CC)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => OwnerRoomDetailsDialog(
                              room: widget.room,
                              roomDocumentId: widget.roomDocumentId,
                              bookingId: widget.room['bookingId']?.toString() ?? '',
                              userId: widget.room['userId']?.toString() ?? '',
                              isHistoryView: widget.isHistoryView,
                              shouldShowUserInfo: widget.shouldShowUserInfo,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isSmallScreen ? 14 : 16,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 34),
                          elevation: 0,
                        ),
                        child: Text(
                          "View Details",
                          style: GoogleFonts.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedImageWithShimmer(String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 300),
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade200,
            child: Center(
              child: Icon(
                Icons.image_not_supported_rounded,
                color: Colors.grey.shade400,
                size: 40,
              ),
            ),
          ),
          imageBuilder: (context, imageProvider) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _imageLoading) {
                setState(() {
                  _imageLoading = false;
                });
              }
            });

            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactSpecItem(
      IconData icon,
      String title,
      String value,
      Color color,
      bool isSmallScreen,
      ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 18 : 20,
          color: color,
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.quicksand(
            fontSize: 11,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B).withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}