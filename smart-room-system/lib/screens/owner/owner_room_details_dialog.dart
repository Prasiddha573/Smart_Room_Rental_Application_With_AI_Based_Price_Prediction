// lib/screens/owner/owner_room_details_dialogs.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../services/toast_service.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/models/chat_user.dart';
import '../../chat/models/chat_message.dart';
import '../../../services/auth_service.dart';
import '../../chat/models/conversation.dart';
import '../../chat/screens/chat_home_screen.dart';

class OwnerRoomDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> room;
  final String roomDocumentId;
  final String bookingId;
  final String userId;
  final bool isHistoryView;
  final bool shouldShowUserInfo;

  const OwnerRoomDetailsDialog({
    super.key,
    required this.room,
    required this.roomDocumentId,
    required this.bookingId,
    required this.userId,
    this.isHistoryView = false,
    this.shouldShowUserInfo = true,
  });

  @override
  State<OwnerRoomDetailsDialog> createState() => _OwnerRoomDetailsDialogState();
}

class _OwnerRoomDetailsDialogState extends State<OwnerRoomDetailsDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _selectedImageIndex = 0;
  bool _isViewingFullImage = false;

  // User information
  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;

  // Map related state variables
  final _currentMapType = ValueNotifier<MapType>(MapType.normal);
  final _mapController = Completer<GoogleMapController>();
  final _isLoadingLocation = ValueNotifier<bool>(false);
  final _currentLatLng = ValueNotifier<LatLng?>(null);
  final _polylines = ValueNotifier<Set<Polyline>>({});
  final _walkTime = ValueNotifier<String>("0 min");
  final _distance = ValueNotifier<String>("0.00 km");

  // Toast service
  final ToastService _toastService = ToastService();

  // New polyline approach - direct drawing
  LatLng? _destination;
  bool _polylineDrawn = false;

  List<String> get _images {
    final imagesData = widget.room['images'];
    if (imagesData is List) {
      return imagesData.whereType<String>().toList();
    }
    return [];
  }

  bool get _isNearKU {
    try {
      final distance = widget.room['distance']?.toString() ?? "0.0";
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

  @override
  void initState() {
    super.initState();
    // Add debug print
    print('📱 OwnerRoomDetailsDialog created');
    print('   Booking User ID: ${widget.userId}');
    print('   Room ID: ${widget.roomDocumentId}');
    print('   Booking ID: ${widget.bookingId}');
    print('   Room Owner ID: ${widget.room['sessionId']}');
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Initialize destination
    final hasCoordinates =
        widget.room['latitude'] != null && widget.room['longitude'] != null;
    if (hasCoordinates) {
      final destinationLat = double.tryParse(
        widget.room['latitude'].toString(),
      );
      final destinationLng = double.tryParse(
        widget.room['longitude'].toString(),
      );
      if (destinationLat != null && destinationLng != null) {
        _destination = LatLng(destinationLat, destinationLng);
      }
    }

    // Get location and draw polyline
    _getLocationAndDrawPolyline();

    // Fetch user information - Only if shouldShowUserInfo is true
    if (widget.shouldShowUserInfo) {
      _fetchUserData();
    } else {
      // Don't show user info for "My Room" section
      _isLoadingUser = false;
    }
  }

  // CORRECTED: Fetch booking user (the user who made the booking request)
  Future<void> _fetchUserData() async {
    try {
      if (!widget.shouldShowUserInfo) {
        setState(() {
          _isLoadingUser = false;
        });
        return;
      }

      final firestore = FirebaseFirestore.instance;

      // Get booking user ID (the user who made the booking request)
      final bookingUserId = widget.userId.trim();

      print('🔍 Fetching booking user data for userId: $bookingUserId');

      if (bookingUserId.isNotEmpty) {
        // Query by booking user's SessionId
        final userQuery = await firestore.collection('User')
            .where('SessionId', isEqualTo: bookingUserId)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final doc = userQuery.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          print('✅ Found booking user: ${data['Name']}');

          setState(() {
            _userData = {
              'name': data['Name']?.toString() ?? 'Booking User',
              'email': data['Email']?.toString() ?? '',
              'phone': data['Phone']?.toString() ?? '',
              'profilePath': data['Path']?.toString() ?? '',
              'sessionId': data['SessionId']?.toString() ?? bookingUserId,
            };
            _isLoadingUser = false;
          });
          return;
        }
      }

      // Fallback
      setState(() {
        _userData = {
          'name': 'Booking User',
          'email': 'Not available',
          'phone': 'Not available',
          'profilePath': '',
          'sessionId': bookingUserId,
        };
        _isLoadingUser = false;
      });
    } catch (e) {
      print("❌ Error fetching user data: $e");
      setState(() {
        _userData = {
          'name': 'Booking User',
          'email': 'Not available',
          'phone': 'Not available',
          'profilePath': '',
          'sessionId': widget.userId,
        };
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _getLocationAndDrawPolyline() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get current location
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        _currentLatLng.value = LatLng(position.latitude, position.longitude);

        // Draw polyline immediately if destination exists
        if (_destination != null && !_polylineDrawn) {
          await _drawDirectPolyline();
        }
      }
    } catch (e) {
      debugPrint("Location error in init: $e");
    }
  }

  Future<void> _drawDirectPolyline() async {
    if (_currentLatLng.value == null || _destination == null) return;

    try {
      // Try OSRM API first
      final url =
          'https://router.project-osrm.org/route/v1/foot/'
          '${_currentLatLng.value!.longitude},${_currentLatLng.value!.latitude};'
          '${_destination!.longitude},${_destination!.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;
          List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();

          _polylines.value = {
            Polyline(
              polylineId: const PolylineId("walk_path"),
              points: points,
              color: const Color(0xFF667EEA),
              width: 5,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              patterns: [PatternItem.dash(10), PatternItem.gap(5)],
            ),
          };
          _polylineDrawn = true;
          return;
        }
      }
    } catch (e) {
      debugPrint("OSRM failed, drawing straight line: $e");
    }

    // Fallback: Draw straight line
    _polylines.value = {
      Polyline(
        polylineId: const PolylineId("walk_path"),
        points: [_currentLatLng.value!, _destination!],
        color: const Color(0xFF667EEA),
        width: 3,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
    _polylineDrawn = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeSheet() {
    _controller.reverse().then((_) {
      Navigator.pop(context);
    });
  }

  void _viewFullImage(int index) {
    setState(() {
      _selectedImageIndex = index;
      _isViewingFullImage = true;
    });
  }

  void _closeImageViewer() {
    setState(() {
      _isViewingFullImage = false;
    });
  }

  void _toggleMapType() {
    _currentMapType.value = _currentMapType.value == MapType.normal
        ? MapType.satellite
        : MapType.normal;
  }

  Future<void> _goToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng currentLocation = LatLng(position.latitude, position.longitude);

      _currentLatLng.value = currentLocation;

      // Center map on current location
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation, 16),
      );

      // Redraw polyline
      if (_destination != null) {
        await _drawDirectPolyline();
      }
    } catch (e) {
      debugPrint("Error getting current location: $e");
    }
  }

  Future<void> _openInGoogleMaps() async {
    final latitude = widget.room['latitude'];
    final longitude = widget.room['longitude'];
    if (latitude != null && longitude != null) {
      final lat = double.tryParse(latitude.toString());
      final lng = double.tryParse(longitude.toString());
      if (lat != null && lng != null) {
        final url = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          _toastService.showErrorMessage('Could not launch Google Maps');
        }
      }
    }
  }

  // Booking status update method (only for active requests)
  Future<void> _updateBookingStatus(String newStatus) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Update booking status
      await firestore.collection('bookings').doc(widget.bookingId).update({
        'bookingStatus': newStatus,
        'updatedAt': DateTime.now(),
      });

      // Update room status in room collection
      final roomStatus = newStatus == 'booked' ? 'Booked' : 'Available';
      await firestore.collection('room').doc(widget.roomDocumentId).update({
        'status': roomStatus,
        'updatedAt': DateTime.now(),
      });

      // Show success message using ToastService
      _toastService.showSuccessMessage(
        newStatus == 'booked'
            ? 'Booking accepted successfully! Room marked as Booked.'
            : 'Booking rejected successfully! Room marked as Available.',
      );

      // Close the dialog after update
      _closeSheet();
    } catch (e) {
      debugPrint("Error updating status: $e");
      _toastService.showErrorMessage(
        'Failed to update status. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: GestureDetector(
        onTap: _closeSheet,
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping on content
            child: DraggableScrollableSheet(
              initialChildSize: isTablet ? 0.85 : 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              snap: true,
              snapSizes: [isTablet ? 0.85 : 0.9],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: ModernColors.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      _buildContent(scrollController, isSmallScreen, isTablet),
                      if (_isViewingFullImage)
                        _buildFullImageViewer(isSmallScreen, isTablet),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    ScrollController scrollController,
    bool isSmallScreen,
    bool isTablet,
  ) {
    final room = widget.room;
    final images = _images;

    // Data extraction with fallbacks
    final title = room['roomName']?.toString() ?? "Unnamed Room";
    final walkTime = room['walkTime']?.toString() ?? "0 min";
    final location = "$walkTime walk from KU Gate";
    final water = room['water']?.toString() ?? "Available";
    final sunlight = room['sunlight']?.toString() ?? "Good";
    final hasBathroom =
        room['bathroom']?.toString() == "Yes" || room['bathroom'] == true;
    final size = "${room['size']?.toString() ?? '0'} Sq Ft";
    final priceNPR = room['price'] is int
        ? room['price'] as int
        : int.tryParse(room['price']?.toString() ?? '0') ?? 0;
    final distance = _getFormattedDistance();
    final internetSpeed = "${room['internet']?.toString() ?? '0'} Mbps";
    final fullLocation =
        room['location']?.toString() ?? "Location not specified";
    final latitude = room['latitude'];
    final longitude = room['longitude'];

    // Get booking status
    final bookingStatus =
        room['bookingStatus']?.toString().toLowerCase() ?? 'requested';

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header with drag handle
        SliverToBoxAdapter(child: _buildHeader(isSmallScreen, isTablet)),

        // User Information Section - Only show if shouldShowUserInfo is true
        if (widget.shouldShowUserInfo)
          SliverToBoxAdapter(
            child: _isLoadingUser
                ? _buildUserInfoShimmer(isSmallScreen, isTablet)
                : _buildUserInfoSection(isSmallScreen, isTablet),
          ),

        // Main Image
        SliverToBoxAdapter(
          child: _buildMainImageSection(images, isSmallScreen, isTablet),
        ),

        // Thumbnails Row - Centered
        if (images.length > 1)
          SliverToBoxAdapter(
            child: _buildThumbnailsSection(images, isSmallScreen, isTablet),
          ),

        // Main Room Card with everything
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
              vertical: isTablet ? 20 : 16,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: ModernColors.surface,
                borderRadius: BorderRadius.circular(
                  isTablet ? 18 : (isSmallScreen ? 14 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: ModernColors.outline.withOpacity(0.15),
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  isTablet ? 20 : (isSmallScreen ? 12 : 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room Title and Status Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Room Title
                              Text(
                                title,
                                style: GoogleFonts.quicksand(
                                  fontSize: isTablet
                                      ? 20
                                      : (isSmallScreen ? 15 : 17),
                                  fontWeight: FontWeight.w800,
                                  color: ModernColors.onSurface,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              SizedBox(
                                height: isTablet ? 8 : (isSmallScreen ? 6 : 6),
                              ),

                              // Location with RED icon
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: isTablet
                                        ? 16
                                        : (isSmallScreen ? 13 : 15),
                                    color: Colors.red,
                                  ),
                                  SizedBox(
                                    width: isTablet
                                        ? 8
                                        : (isSmallScreen ? 4 : 6),
                                  ),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: GoogleFonts.quicksand(
                                        fontSize: isTablet
                                            ? 14
                                            : (isSmallScreen ? 12 : 13),
                                        color: ModernColors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                          width: isTablet ? 16 : (isSmallScreen ? 8 : 10),
                        ),

                        // Room Status Button - Shows booking status
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: _getStatusGradient(bookingStatus),
                            boxShadow: [
                              BoxShadow(
                                color: _getStatusColor(
                                  bookingStatus,
                                ).withOpacity(0.3),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _getStatusText(bookingStatus),
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

                    SizedBox(height: isTablet ? 20 : (isSmallScreen ? 12 : 14)),

                    // Room Specifications Grid
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 16 : (isSmallScreen ? 12 : 12),
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ModernColors.background.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(
                          isTablet ? 12 : (isSmallScreen ? 8 : 10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCompactSpecItem(
                            Icons.square_foot_rounded,
                            "Size",
                            size,
                            ModernColors.primary,
                            isSmallScreen,
                            isTablet,
                          ),
                          Container(
                            height: isTablet ? 32 : (isSmallScreen ? 24 : 28),
                            width: 1,
                            color: ModernColors.outline.withOpacity(0.3),
                          ),
                          _buildCompactSpecItem(
                            Icons.wifi_rounded,
                            "Internet",
                            internetSpeed,
                            const Color(0xFF4CAF50),
                            isSmallScreen,
                            isTablet,
                          ),
                          Container(
                            height: isTablet ? 32 : (isSmallScreen ? 24 : 28),
                            width: 1,
                            color: ModernColors.outline.withOpacity(0.3),
                          ),
                          _buildCompactSpecItem(
                            Icons.directions_walk_rounded,
                            "Distance",
                            distance,
                            const Color(0xFFFF9800),
                            isSmallScreen,
                            isTablet,
                          ),
                        ],
                      ),
                    ),

                    // Monthly Rent Section (without Compare button for owner)
                    Padding(
                      padding: EdgeInsets.only(
                        top: isTablet ? 20 : (isSmallScreen ? 16 : 18),
                        bottom: isTablet ? 16 : (isSmallScreen ? 12 : 14),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : (isSmallScreen ? 12 : 14),
                          vertical: isTablet ? 10 : (isSmallScreen ? 8 : 10),
                        ),
                        decoration: BoxDecoration(
                          color: ModernColors.surface,
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : (isSmallScreen ? 10 : 12),
                          ),
                          border: Border.all(
                            color: ModernColors.outline.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Monthly Rent",
                              style: GoogleFonts.quicksand(
                                fontSize: isTablet
                                    ? 13
                                    : (isSmallScreen ? 11 : 12),
                                fontWeight: FontWeight.w700,
                                color: ModernColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(
                              height: isTablet ? 4 : (isSmallScreen ? 2 : 3),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "NPR",
                                  style: GoogleFonts.quicksand(
                                    fontSize: isTablet
                                        ? 13
                                        : (isSmallScreen ? 11 : 12),
                                    color: ModernColors.onSurfaceVariant
                                        .withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(
                                  width: isTablet ? 6 : (isSmallScreen ? 3 : 4),
                                ),
                                Text(
                                  " $priceNPR",
                                  style: GoogleFonts.quicksand(
                                    fontSize: isTablet
                                        ? 22
                                        : (isSmallScreen ? 18 : 20),
                                    fontWeight: FontWeight.w800,
                                    color: ModernColors.onSurface,
                                  ),
                                ),
                                SizedBox(
                                  width: isTablet ? 6 : (isSmallScreen ? 3 : 4),
                                ),
                                Text(
                                  "/month",
                                  style: GoogleFonts.quicksand(
                                    fontSize: isTablet
                                        ? 13
                                        : (isSmallScreen ? 11 : 12),
                                    color: ModernColors.onSurfaceVariant
                                        .withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Divider before Additional Amenities
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 16 : (isSmallScreen ? 12 : 14),
                      ),
                      child: Divider(
                        height: 1,
                        color: ModernColors.outline.withOpacity(0.3),
                      ),
                    ),

                    // Additional Amenities
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Additional Amenities",
                          style: GoogleFonts.quicksand(
                            fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                            fontWeight: FontWeight.w700,
                            color: ModernColors.onSurface,
                          ),
                        ),
                        SizedBox(
                          height: isTablet ? 16 : (isSmallScreen ? 10 : 12),
                        ),

                        // First Row: Water & Sunlight
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Water Pill
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet
                                    ? 14
                                    : (isSmallScreen ? 10 : 10),
                                vertical: isTablet
                                    ? 8
                                    : (isSmallScreen ? 5 : 5),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 18 : 16,
                                ),
                              ),
                              child: Text(
                                "💧 Water: $water",
                                style: GoogleFonts.quicksand(
                                  fontSize: isTablet
                                      ? 14
                                      : (isSmallScreen ? 11 : 11),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ),

                            // Sunlight Pill
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet
                                    ? 14
                                    : (isSmallScreen ? 10 : 10),
                                vertical: isTablet
                                    ? 8
                                    : (isSmallScreen ? 5 : 5),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 18 : 16,
                                ),
                              ),
                              child: Text(
                                "☀️ Sunlight: $sunlight",
                                style: GoogleFonts.quicksand(
                                  fontSize: isTablet
                                      ? 14
                                      : (isSmallScreen ? 11 : 11),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF57C00),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(
                          height: isTablet ? 12 : (isSmallScreen ? 8 : 10),
                        ),

                        // Second Row: Bathroom & Windows
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Bathroom Pill
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet
                                    ? 14
                                    : (isSmallScreen ? 10 : 10),
                                vertical: isTablet
                                    ? 8
                                    : (isSmallScreen ? 5 : 5),
                              ),
                              decoration: BoxDecoration(
                                color: hasBathroom
                                    ? const Color(0xFFE3F2FD)
                                    : // Light blue for attached
                                const Color(
                                  0xFFF5F5F5,
                                ), // Light grey for shared
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 18 : 16,
                                ),
                              ),
                              child: Text(
                                hasBathroom
                                    ? "🚽 Bathroom: Attached"
                                    : "🚽 Bathroom: Shared",
                                style: GoogleFonts.quicksand(
                                  fontSize: isTablet
                                      ? 14
                                      : (isSmallScreen ? 11 : 11),
                                  fontWeight: FontWeight.w700,
                                  color: hasBathroom
                                      ? const Color(0xFF2196F3)
                                      : // Blue for attached
                                  const Color(
                                    0xFF757575,
                                  ), // Grey for shared
                                ),
                              ),
                            ),

                            // Windows Pill
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet
                                    ? 14
                                    : (isSmallScreen ? 10 : 10),
                                vertical: isTablet
                                    ? 8
                                    : (isSmallScreen ? 5 : 5),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E5F5),
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 18 : 16,
                                ),
                              ),
                              child: Text(
                                "🪟 Windows: 5",
                                style: GoogleFonts.quicksand(
                                  fontSize: isTablet
                                      ? 14
                                      : (isSmallScreen ? 11 : 11),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9C27B0),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(
                          height: isTablet ? 20 : (isSmallScreen ? 12 : 16),
                        ),

                        // Amenity Windows (Laundry, Wi-Fi, Parking, Security, Cleaning)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildAmenityWindow(
                              Icons.local_laundry_service_rounded,
                              "Laundry",
                              const Color(0xFF9C27B0),
                              isSmallScreen,
                              isTablet,
                            ),
                            _buildAmenityWindow(
                              Icons.wifi_rounded,
                              "Wi-Fi",
                              const Color(0xFF2196F3),
                              isSmallScreen,
                              isTablet,
                            ),
                            _buildAmenityWindow(
                              Icons.local_parking_rounded,
                              "Parking",
                              const Color(0xFF795548),
                              isSmallScreen,
                              isTablet,
                            ),
                            if (!isSmallScreen) ...[
                              _buildAmenityWindow(
                                Icons.security_rounded,
                                "Security",
                                const Color(0xFFF44336),
                                isSmallScreen,
                                isTablet,
                              ),
                              _buildAmenityWindow(
                                Icons.cleaning_services_rounded,
                                "Cleaning",
                                const Color(0xFFFF9800),
                                isSmallScreen,
                                isTablet,
                              ),
                            ],
                          ],
                        ),

                        // For small screens, show the last 2 windows in a second row
                        if (isSmallScreen) ...[
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildAmenityWindow(
                                Icons.security_rounded,
                                "Security",
                                const Color(0xFFF44336),
                                isSmallScreen,
                                isTablet,
                              ),
                              SizedBox(width: 20),
                              _buildAmenityWindow(
                                Icons.cleaning_services_rounded,
                                "Cleaning",
                                const Color(0xFFFF9800),
                                isSmallScreen,
                                isTablet,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Location Details Section
        SliverToBoxAdapter(
          child: _buildLocationSection(
            fullLocation: fullLocation,
            latitude: latitude,
            longitude: longitude,
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
          ),
        ),

        // Only show action buttons for active requests (not history view and status is requested)
        if (!widget.isHistoryView && bookingStatus == 'requested')
          SliverToBoxAdapter(
            child: _buildActionButtons(isSmallScreen, isTablet),
          ),

        // Bottom spacing - REMOVED the booking status section for history view
        SliverToBoxAdapter(
          child: SizedBox(height: isTablet ? 20 : (isSmallScreen ? 15 : 20)),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isSmallScreen, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
        vertical: isTablet ? 20 : 16,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: isTablet ? 50 : 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: isTablet ? 16 : (isSmallScreen ? 8 : 12)),
          // Center aligned title
          Center(
            child: Text(
              widget.isHistoryView
                  ? "Booking History Details"
                  : "Booking Request Details",
              style: GoogleFonts.quicksand(
                fontSize: isTablet ? 24 : (isSmallScreen ? 18 : 20),
                fontWeight: FontWeight.w800,
                color: ModernColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(bool isSmallScreen, bool isTablet) {
    // Only show if we have user data
    if (_userData == null) {
      return const SizedBox.shrink();
    }

    final userName = _userData!['name']?.toString() ?? 'User';
    final userEmail = _userData!['email']?.toString() ?? 'No email';
    final userPhone = _userData!['phone']?.toString() ?? 'Not available';
    final userPhoto = _userData!['profilePath']?.toString();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
        vertical: isTablet ? 8 : (isSmallScreen ? 8 : 12),
      ),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16 : (isSmallScreen ? 12 : 14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isTablet ? 18 : (isSmallScreen ? 14 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Row(
          children: [
            // User Photo
            Container(
              width: isTablet ? 50 : (isSmallScreen ? 40 : 45),
              height: isTablet ? 50 : (isSmallScreen ? 40 : 45),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: ClipOval(
                child: userPhoto != null && userPhoto.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: userPhoto,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: isTablet ? 20 : 16,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: isTablet ? 20 : 16,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                )
                    : Container(
                  color: const Color(0xFFF1F5F9),
                  child: Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: isTablet ? 20 : 16,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: isTablet ? 14 : (isSmallScreen ? 10 : 12)),

            // User Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: GoogleFonts.quicksand(
                      fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isTablet ? 4 : (isSmallScreen ? 2 : 3)),
                  Row(
                    children: [
                      Icon(
                        Icons.email_rounded,
                        size: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                        color: Colors.deepOrange,
                      ),
                      SizedBox(width: isTablet ? 6 : (isSmallScreen ? 4 : 5)),
                      Expanded(
                        child: Text(
                          userEmail,
                          style: GoogleFonts.quicksand(
                            fontSize: isTablet ? 12 : (isSmallScreen ? 10 : 11),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 2 : (isSmallScreen ? 1 : 2)),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                        color: Colors.blue,
                      ),
                      SizedBox(width: isTablet ? 6 : (isSmallScreen ? 4 : 5)),
                      Text(
                        userPhone,
                        style: GoogleFonts.quicksand(
                          fontSize: isTablet ? 12 : (isSmallScreen ? 10 : 11),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Button - Owner chats with Booking User
            _buildChatButton(isSmallScreen, isTablet),
          ],
        ),
      ),
    );
  }

  // Chat Button Widget - Owner chats with Booking User
  Widget _buildChatButton(bool isSmallScreen, bool isTablet) {
    return Container(
      width: isTablet ? 36 : (isSmallScreen ? 30 : 32),
      height: isTablet ? 36 : (isSmallScreen ? 30 : 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0084FF),
        borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0084FF).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
          onTap: _openChatDirect,
          child: Center(
            child: Icon(
              Icons.messenger_rounded,
              size: isTablet ? 18 : (isSmallScreen ? 16 : 17),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // Chat Button Handler - Owner chats with Booking User
  void _openChatDirect() {
    print('💬 CHAT BUTTON CLICKED');

    // Get booking user ID (the user who requested the booking)
    final bookingUserId = widget.userId.trim();
    print('👤 Booking user ID: $bookingUserId');

    // Get my ID (current user - room owner)
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myId.isEmpty) {
      print('❌ I need to login first');
      _toastService.showErrorMessage('Please login to chat');
      return;
    }

    print('🏠 My ID (Room Owner): $myId');

    // Sort IDs for conversation ID
    final List<String> ids = [myId, bookingUserId]..sort();
    final conversationId = '${ids[0]}_${ids[1]}';
    print('💬 Creating conversation: $conversationId');

    // Create chat in Firestore
    _createChatInFirestore(conversationId, myId, bookingUserId);

    // Close the dialog
    Navigator.pop(context);
  }

  void _createChatInFirestore(String convId, String myId, String bookingUserId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Create conversation
      await firestore.collection('chat_users').doc(convId).set({
        'conversationId': convId,
        'user1Id': myId,
        'user2Id': bookingUserId,
        'users': [myId, bookingUserId],
        'lastMessage': 'Hello! I\'m interested in your room booking.',
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': myId,
        'unreadCount': {myId: 0, bookingUserId: 1},
        'isFavorite': {myId: false, bookingUserId: false},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      print('✅ Conversation created with booking user');

      // 2. Create first message
      final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
      await firestore.collection('chats').doc(messageId).set({
        'messageId': messageId,
        'conversationId': convId,
        'senderId': myId,
        'receiverId': bookingUserId,
        'message': 'Hello! I\'m the room owner. Let\'s discuss your booking.',
        'type': 'text',
        'timestamp': Timestamp.now(),
        'isRead': false,
        'isDeleted': false,
      });

      print('✅ Message created');

      // Show success
      _toastService.showSuccessMessage('Booking user added to chat list!');

    } catch (e) {
      print('⚠️ Error (but continuing): $e');
    }
  }

  Widget _buildUserInfoShimmer(bool isSmallScreen, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
        vertical: isTablet ? 8 : (isSmallScreen ? 8 : 12),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        period: const Duration(milliseconds: 1500),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 16 : (isSmallScreen ? 12 : 14)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              isTablet ? 18 : (isSmallScreen ? 14 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: Row(
            children: [
              // User Photo Shimmer with circle shape
              Container(
                width: isTablet ? 50 : (isSmallScreen ? 40 : 45),
                height: isTablet ? 50 : (isSmallScreen ? 40 : 45),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 14 : (isSmallScreen ? 10 : 12)),

              // User Details Shimmer with better animation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name shimmer
                    Container(
                      width: double.infinity,
                      height: isTablet ? 16 : 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      margin: EdgeInsets.only(bottom: isTablet ? 6 : 4),
                    ),

                    // Email row shimmer
                    Row(
                      children: [
                        Container(
                          width: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                          height: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: isTablet ? 6 : (isSmallScreen ? 4 : 5)),
                        Expanded(
                          child: Container(
                            height: isTablet ? 12 : 11,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 4 : (isSmallScreen ? 3 : 4)),

                    // Phone row shimmer
                    Row(
                      children: [
                        Container(
                          width: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                          height: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: isTablet ? 6 : (isSmallScreen ? 4 : 5)),
                        Container(
                          width: 120,
                          height: isTablet ? 12 : 11,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Messaging icon placeholder
              Container(
                width: isTablet ? 36 : (isSmallScreen ? 30 : 32),
                height: isTablet ? 36 : (isSmallScreen ? 30 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainImageSection(
    List<String> images,
    bool isSmallScreen,
    bool isTablet,
  ) {
    if (images.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
        ),
        child: Container(
          height: isTablet ? 250 : (isSmallScreen ? 180 : 200),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(
              isTablet ? 18 : (isSmallScreen ? 14 : 16),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  size: isTablet ? 50 : 40,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: isTablet ? 12 : 8),
                Text(
                  "No Images Available",
                  style: GoogleFonts.quicksand(
                    fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _viewFullImage(0),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
            ),
            child: Container(
              height: isTablet ? 250 : (isSmallScreen ? 180 : 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  isTablet ? 18 : (isSmallScreen ? 14 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  isTablet ? 18 : (isSmallScreen ? 14 : 16),
                ),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: images[0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade100),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: Icon(
                            Icons.photo_library_rounded,
                            size: isTablet ? 50 : 40,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: isTablet ? 16 : 10,
                      right: isTablet ? 16 : 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 14 : (isSmallScreen ? 10 : 12),
                          vertical: isTablet ? 8 : (isSmallScreen ? 5 : 6),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(
                            isTablet ? 14 : (isSmallScreen ? 10 : 12),
                          ),
                        ),
                        child: Text(
                          "${images.length} photos",
                          style: GoogleFonts.quicksand(
                            fontSize: isTablet ? 14 : (isSmallScreen ? 11 : 12),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Near KU Gate Badge (if applicable)
        if (_isNearKU)
          Positioned(
            top: isTablet ? 16 : 10,
            left: isTablet ? 24 : (isSmallScreen ? 16 : 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ModernColors.primary.withOpacity(0.95),
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
    );
  }

  Widget _buildThumbnailsSection(
    List<String> images,
    bool isSmallScreen,
    bool isTablet,
  ) {
    final itemWidth = isTablet ? 80.0 : (isSmallScreen ? 60.0 : 70.0);
    final itemHeight = isTablet ? 80.0 : (isSmallScreen ? 60.0 : 70.0);
    final borderRadius = isTablet ? 14.0 : (isSmallScreen ? 10.0 : 12.0);

    return Padding(
      padding: EdgeInsets.only(
        top: isTablet ? 20 : (isSmallScreen ? 12 : 16),
        left: isTablet ? 24 : (isSmallScreen ? 16 : 20),
        right: isTablet ? 24 : (isSmallScreen ? 16 : 20),
      ),
      child: SizedBox(
        height: itemHeight,
        child: Center(
          child: images.length <= 3
              ? _buildCenteredThumbnails(
                  images,
                  itemWidth,
                  itemHeight,
                  borderRadius,
                  isSmallScreen,
                  isTablet,
                )
              : _buildScrollableThumbnails(
                  images,
                  itemWidth,
                  itemHeight,
                  borderRadius,
                  isSmallScreen,
                  isTablet,
                ),
        ),
      ),
    );
  }

  Widget _buildCenteredThumbnails(
    List<String> images,
    double itemWidth,
    double itemHeight,
    double borderRadius,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: images.asMap().entries.map((entry) {
        final index = entry.key;
        final imageUrl = entry.value;
        return GestureDetector(
          onTap: () => _viewFullImage(index),
          child: Padding(
            padding: EdgeInsets.only(
              right: index < images.length - 1
                  ? (isTablet ? 12 : (isSmallScreen ? 8 : 10))
                  : 0,
            ),
            child: Container(
              width: itemWidth,
              height: itemHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: ModernColors.outline.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey.shade100),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: isTablet ? 30 : 24,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScrollableThumbnails(
    List<String> images,
    double itemWidth,
    double itemHeight,
    double borderRadius,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _viewFullImage(index),
          child: Padding(
            padding: EdgeInsets.only(
              right: index < images.length - 1
                  ? (isTablet ? 12 : (isSmallScreen ? 8 : 10))
                  : 0,
              left: index == 0 ? (isTablet ? 12 : (isSmallScreen ? 8 : 10)) : 0,
            ),
            child: Container(
              width: itemWidth,
              height: itemHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: ModernColors.outline.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey.shade100),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: isTablet ? 30 : 24,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullImageViewer(bool isSmallScreen, bool isTablet) {
    final images = _images;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: Column(
          children: [
            // Header
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
                  vertical: isTablet ? 20 : 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _closeImageViewer,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      "${_selectedImageIndex + 1}/${images.length}",
                      style: GoogleFonts.quicksand(
                        fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 40), // For symmetry
                  ],
                ),
              ),
            ),

            // Image Viewer
            Expanded(
              child: PageView.builder(
                itemCount: images.length,
                controller: PageController(initialPage: _selectedImageIndex),
                onPageChanged: (index) {
                  setState(() {
                    _selectedImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    maxScale: 3.0,
                    child: Padding(
                      padding: EdgeInsets.all(
                        isTablet ? 24 : (isSmallScreen ? 16 : 20),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey.shade800),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade800,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: isTablet ? 50 : 40,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Thumbnails at bottom
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isTablet ? 24 : 20,
                  left: isTablet ? 24 : (isSmallScreen ? 16 : 20),
                  right: isTablet ? 24 : (isSmallScreen ? 16 : 20),
                ),
                child: SizedBox(
                  height: isTablet ? 70 : (isSmallScreen ? 50 : 60),
                  child: Center(
                    child: images.length <= 3
                        ? _buildCenteredBottomThumbnails(
                            images,
                            isSmallScreen,
                            isTablet,
                          )
                        : _buildScrollableBottomThumbnails(
                            images,
                            isSmallScreen,
                            isTablet,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredBottomThumbnails(
    List<String> images,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: images.asMap().entries.map((entry) {
        final index = entry.key;
        final imageUrl = entry.value;
        final thumbnailSize = isTablet ? 65.0 : (isSmallScreen ? 45.0 : 55.0);

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedImageIndex = index;
            });
          },
          child: Padding(
            padding: EdgeInsets.only(right: index < images.length - 1 ? 10 : 0),
            child: Container(
              width: thumbnailSize,
              height: thumbnailSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedImageIndex == index
                      ? ModernColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey.shade800),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScrollableBottomThumbnails(
    List<String> images,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: images.length,
      itemBuilder: (context, index) {
        final thumbnailSize = isTablet ? 65.0 : (isSmallScreen ? 45.0 : 55.0);
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedImageIndex = index;
            });
          },
          child: Padding(
            padding: EdgeInsets.only(right: index < images.length - 1 ? 10 : 0),
            child: Container(
              width: thumbnailSize,
              height: thumbnailSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedImageIndex == index
                      ? ModernColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey.shade800),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactSpecItem(
    IconData icon,
    String title,
    String value,
    Color color,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: isTablet ? 26 : (isSmallScreen ? 18 : 20),
          color: color,
        ),
        SizedBox(height: isTablet ? 8 : (isSmallScreen ? 4 : 6)),
        Text(
          title,
          style: GoogleFonts.quicksand(
            fontSize: isTablet ? 14 : (isSmallScreen ? 10 : 11),
            color: ModernColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: isTablet ? 4 : (isSmallScreen ? 2 : 3)),
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: isTablet ? 16 : (isSmallScreen ? 11 : 12),
            fontWeight: FontWeight.w800,
            color: ModernColors.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityWindow(
    IconData icon,
    String label,
    Color color,
    bool isSmallScreen,
    bool isTablet,
  ) {
    final size = isTablet ? 60.0 : (isSmallScreen ? 40.0 : 45.0);
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              isTablet ? 14 : (isSmallScreen ? 8 : 10),
            ),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Icon(
            icon,
            size: isTablet ? 28 : (isSmallScreen ? 18 : 20),
            color: color,
          ),
        ),
        SizedBox(height: isTablet ? 8 : (isSmallScreen ? 4 : 6)),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: isTablet ? 13 : (isSmallScreen ? 9 : 10),
            fontWeight: FontWeight.w700,
            color: ModernColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection({
    required String fullLocation,
    required dynamic latitude,
    required dynamic longitude,
    required bool isSmallScreen,
    required bool isTablet,
  }) {
    final hasCoordinates = latitude != null && longitude != null;
    final destinationLat = hasCoordinates
        ? double.tryParse(latitude.toString())
        : null;
    final destinationLng = hasCoordinates
        ? double.tryParse(longitude.toString())
        : null;
    final destination =
        hasCoordinates && destinationLat != null && destinationLng != null
            ? LatLng(destinationLat, destinationLng)
            : null;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : (isSmallScreen ? 8 : 10),
        vertical: isTablet ? 12 : 8,
      ),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 20 : (isSmallScreen ? 12 : 16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isTablet ? 18 : (isSmallScreen ? 14 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Only "Location" header
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: isTablet ? 22 : (isSmallScreen ? 18 : 20),
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : (isSmallScreen ? 8 : 10)),
                  Text(
                    "Location",
                    style: GoogleFonts.quicksand(
                      fontSize: isTablet ? 22 : (isSmallScreen ? 16 : 18),
                      fontWeight: FontWeight.w800,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    ),
                  ),
                ],
              ),
            ),

            if (hasCoordinates && destination != null) ...[
              // LARGER Map Container with minimal margins
              Container(
                height: isTablet ? 380 : (isSmallScreen ? 280 : 320),
                width: double.infinity,
                margin: EdgeInsets.only(
                  left: 0,
                  right: 0,
                  bottom: isTablet ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    isTablet ? 14 : (isSmallScreen ? 10 : 12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    isTablet ? 14 : (isSmallScreen ? 10 : 12),
                  ),
                  child: Stack(
                    children: [
                      // Google Map with full interactivity
                      ValueListenableBuilder<MapType>(
                        valueListenable: _currentMapType,
                        builder: (context, mapType, _) {
                          return GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: destination,
                              zoom: 15,
                            ),
                            onMapCreated: (controller) async {
                              if (!_mapController.isCompleted) {
                                _mapController.complete(controller);
                              }

                              // Draw polyline if not already drawn
                              if (_currentLatLng.value != null &&
                                  !_polylineDrawn &&
                                  destination != null) {
                                _drawDirectPolyline();
                              }

                              // Fit bounds to show both markers
                              if (_currentLatLng.value != null) {
                                final bounds = LatLngBounds(
                                  southwest: LatLng(
                                    min(
                                      destination.latitude,
                                      _currentLatLng.value!.latitude,
                                    ),
                                    min(
                                      destination.longitude,
                                      _currentLatLng.value!.longitude,
                                    ),
                                  ),
                                  northeast: LatLng(
                                    max(
                                      destination.latitude,
                                      _currentLatLng.value!.latitude,
                                    ),
                                    max(
                                      destination.longitude,
                                      _currentLatLng.value!.longitude,
                                    ),
                                  ),
                                );

                                await controller.animateCamera(
                                  CameraUpdate.newLatLngBounds(bounds, 50),
                                );
                              } else {
                                await controller.animateCamera(
                                  CameraUpdate.newLatLngZoom(destination, 15),
                                );
                              }
                            },
                            polylines: _polylines.value,
                            markers: {
                              // Destination marker (Red)
                              Marker(
                                markerId: const MarkerId('destination'),
                                position: destination,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed,
                                ),
                                infoWindow: InfoWindow(
                                  title: 'Room Location',
                                  snippet: fullLocation,
                                ),
                              ),

                              // Current location marker (Green) - if available
                              if (_currentLatLng.value != null)
                                Marker(
                                  markerId: const MarkerId('current_location'),
                                  position: _currentLatLng.value!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueGreen,
                                  ),
                                  infoWindow: const InfoWindow(
                                    title: 'Your Location',
                                  ),
                                ),
                            },
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            mapType: mapType,
                            minMaxZoomPreference: const MinMaxZoomPreference(
                              5,
                              20,
                            ),
                            onTap: (LatLng position) {
                              // Allow tap interactions
                            },
                          );
                        },
                      ),

                      // Map Controls positioned far right
                      Positioned(
                        bottom: 12,
                        right: 8,
                        child: Column(
                          children: [
                            // Satellite Button
                            ValueListenableBuilder<MapType>(
                              valueListenable: _currentMapType,
                              builder: (context, mapType, _) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: _toggleMapType,
                                    icon: Icon(
                                      Icons.satellite_rounded,
                                      color: mapType == MapType.satellite
                                          ? const Color(0xFF667EEA)
                                          : Colors.grey.shade700,
                                      size: 16,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    style: IconButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Current Location Button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _goToCurrentLocation,
                                icon: const Icon(
                                  Icons.my_location,
                                  color: Color(0xFF667EEA),
                                  size: 16,
                                ),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // "Open in Google Maps" Button
            if (hasCoordinates) ...[
              SizedBox(height: isTablet ? 20 : (isSmallScreen ? 12 : 16)),
              Container(
                height: isTablet ? 56 : (isSmallScreen ? 42 : 48),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    isTablet ? 14 : (isSmallScreen ? 10 : 12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3498DB).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  onPressed: _openInGoogleMaps,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        isTablet ? 14 : (isSmallScreen ? 10 : 12),
                      ),
                    ),
                  ),
                  icon: Icon(
                    Icons.directions_rounded,
                    size: isTablet ? 22 : 18,
                  ),
                  label: Text(
                    "Open in Google Maps",
                    style: GoogleFonts.quicksand(
                      fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isSmallScreen, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : (isSmallScreen ? 16 : 20),
        vertical: isTablet ? 16 : (isSmallScreen ? 12 : 16),
      ),
      child: Column(
        children: [
          // Accept/Reject Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              "Booking Decision",
              style: GoogleFonts.quicksand(
                fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),

          Row(
            children: [
              // REJECT Button at LEFT (Red Gradient)
              Expanded(
                child: Container(
                  height: isTablet ? 50 : (isSmallScreen ? 40 : 44),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      isTablet ? 12 : (isSmallScreen ? 10 : 12),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF44336), // Red
                        Color(0xFFD32F2F), // Dark Red
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF44336).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _updateBookingStatus('rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          isTablet ? 12 : (isSmallScreen ? 10 : 12),
                        ),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel_rounded,
                          size: isTablet ? 20 : (isSmallScreen ? 16 : 18),
                        ),
                        SizedBox(width: isTablet ? 8 : (isSmallScreen ? 4 : 6)),
                        Text(
                          "Reject",
                          style: GoogleFonts.quicksand(
                            fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(width: isTablet ? 12 : (isSmallScreen ? 8 : 10)),

              // ACCEPT Button at RIGHT (Green Gradient with Verified Icon)
              Expanded(
                child: Container(
                  height: isTablet ? 50 : (isSmallScreen ? 40 : 44),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      isTablet ? 12 : (isSmallScreen ? 10 : 12),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4CAF50), // Green
                        Color(0xFF2E7D32), // Dark Green
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _updateBookingStatus('booked'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          isTablet ? 12 : (isSmallScreen ? 10 : 12),
                        ),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: isTablet ? 20 : (isSmallScreen ? 16 : 18),
                        ),
                        SizedBox(width: isTablet ? 8 : (isSmallScreen ? 4 : 6)),
                        Text(
                          "Accept",
                          style: GoogleFonts.quicksand(
                            fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods for status display
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
      default:
        return const Color(0xFF4CAF50);
    }
  }

  LinearGradient _getStatusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
        );
      case 'booked':
        return const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
        );
      case 'cancelled':
        return const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        );
      case 'rejected':
        return const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
        );
      case 'pending':
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
        );
    }
  }
}

// Modern Colors Palette (same as your card)
class ModernColors {
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryDark = Color(0xFF0056CC);
  static const Color primaryContainer = Color(0xFFE3F2FD);

  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF2F2F7);

  static const Color onSurface = Color(0xFF1C1C1E);
  static const Color onSurfaceVariant = Color(0xFF8E8E93);

  static const Color outline = Color(0xFFC7C7CC);
}