// Booking Confirmation Dialog - Complete Solution with Proper Owner ID Fetching
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingConfirmationDialog extends StatefulWidget {
  final Map<String, dynamic> room;
  final String? roomDocumentId; // Accept document ID as parameter

  const BookingConfirmationDialog({
    super.key,
    required this.room,
    this.roomDocumentId,
  });

  @override
  State<BookingConfirmationDialog> createState() => _BookingConfirmationDialogState();
}

class _BookingConfirmationDialogState extends State<BookingConfirmationDialog> {
  bool _isSubmitting = false;
  bool _bookingConfirmed = false;

  Future<void> _submitBooking() async {
    setState(() {
      _isSubmitting = true;
    });

    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showErrorDialog("Please login to book this room");
      return;
    }

    try {
      final room = widget.room;
      final currentUserSessionId = user.uid;

      // CRITICAL PART: Get room owner's sessionId
      String roomOwnerSessionId = '';
      String roomDocumentId = '';

      // Strategy 1: Use passed document ID if available
      roomDocumentId = widget.roomDocumentId ?? room['id']?.toString() ?? '';

      // Strategy 2: Try to get sessionId from room data first
      roomOwnerSessionId = room['sessionId']?.toString() ?? '';

      // Strategy 3: If sessionId is not in room data, fetch complete room document
      if (roomOwnerSessionId.isEmpty) {
        if (roomDocumentId.isNotEmpty) {
          // We have document ID, fetch complete document
          debugPrint("Fetching complete room document with ID: $roomDocumentId");
          final roomDoc = await firestore.collection('room').doc(roomDocumentId).get();

          if (roomDoc.exists) {
            final fullData = roomDoc.data() as Map<String, dynamic>;
            roomOwnerSessionId = fullData['sessionId']?.toString() ?? '';

            // Debug log what we found
            debugPrint("Found room document. Keys: ${fullData.keys.join(', ')}");
            debugPrint("SessionId from Firestore: $roomOwnerSessionId");

            if (roomOwnerSessionId.isEmpty) {
              debugPrint("❌ ERROR: Even after fetching, sessionId is empty!");
              debugPrint("Available fields: ${fullData.keys.join(', ')}");
            }
          } else {
            debugPrint("❌ ERROR: Room document not found with ID: $roomDocumentId");
          }
        } else {
          // No document ID, try to find by unique combination
          debugPrint("No document ID, trying to find room by unique fields...");
          final roomName = room['roomName']?.toString() ?? '';
          final roomLocation = room['location']?.toString() ?? '';
          final roomPrice = room['price'];

          if (roomName.isNotEmpty && roomLocation.isNotEmpty) {
            debugPrint("Searching for room: $roomName at $roomLocation");

            final querySnapshot = await firestore
                .collection('room')
                .where('roomName', isEqualTo: roomName)
                .where('location', isEqualTo: roomLocation)
                .limit(1)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              final doc = querySnapshot.docs.first;
              roomDocumentId = doc.id;
              final fullData = doc.data() as Map<String, dynamic>;
              roomOwnerSessionId = fullData['sessionId']?.toString() ?? '';
              debugPrint("Found by name+location. SessionId: $roomOwnerSessionId");
            } else {
              debugPrint("❌ ERROR: Could not find room by name+location");
            }
          }
        }
      }

      // Final check
      if (roomOwnerSessionId.isEmpty) {
        debugPrint("❌ CRITICAL ERROR: Could not find owner sessionId!");
        debugPrint("Room data keys: ${room.keys.join(', ')}");
        debugPrint("Document ID available: $roomDocumentId");
        _showErrorDialog("Could not find room owner information. Please contact support.");
        return;
      }

      debugPrint("✅ SUCCESS: Owner SessionId: $roomOwnerSessionId");
      debugPrint("✅ SUCCESS: Room DocumentId: $roomDocumentId");
      debugPrint("✅ SUCCESS: User SessionId: $currentUserSessionId");

      // Generate booking ID
      final bookingId = '${DateTime.now().millisecondsSinceEpoch}_${room['roomName']?.toString().replaceAll(' ', '_')}';

      // Prepare booking data - ONLY STORE ESSENTIAL FIELDS
      final Map<String, dynamic> bookingData = {
        'bookingId': bookingId,
        'roomDocumentId': roomDocumentId,

        // ONLY THESE THREE ESSENTIAL FIELDS
        'userId': currentUserSessionId,
        'ownerId': roomOwnerSessionId,

        // User email for reference
        'userEmail': user.email ?? '',

        // Booking status
        'bookingStatus': 'requested',
        'bookingDate': DateTime.now(),

        // Timestamps
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      // Save booking with only essential data
      await firestore.collection('bookings').doc(bookingId).set(bookingData);
      debugPrint("✅ Booking saved successfully with minimal data!");

      // Update room status to 'Requested'
      if (roomDocumentId.isNotEmpty) {
        try {
          await firestore.collection('room').doc(roomDocumentId).update({
            'status': 'Requested',
            'updatedAt': DateTime.now(),
          });
          debugPrint("✅ Room status updated to 'Requested'");
        } catch (e) {
          debugPrint("⚠️ Could not update room status: $e");
        }
      }

      setState(() {
        _isSubmitting = false;
        _bookingConfirmed = true;
      });

      _showSuccessDialog();

    } catch (e, st) {
      debugPrint("❌ EXCEPTION: $e");
      debugPrint("Stack trace: $st");

      setState(() {
        _isSubmitting = false;
      });

      _showErrorDialog("Failed to book room. Please try again.");
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                "Booking Request Sent!",
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your booking request has been sent to the room owner. They will contact you soon.",
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close success dialog
                    Navigator.of(context).pop(); // Close booking dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Continue",
                    style: GoogleFonts.quicksand(
                      fontSize: 15,
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
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Booking Failed",
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "OK",
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade100,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Confirm Booking",
                        style: GoogleFonts.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                            ).createShader(
                              const Rect.fromLTWH(0, 0, 200, 70),
                            ),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Room Summary Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Room Details",
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Room Name
                            _buildDetailRow(
                              icon: Icons.holiday_village_rounded,
                              label: "Room Name",
                              value: room['roomName']?.toString() ?? "Unnamed Room",
                              iconColor: const Color(0xFF4CAF50),
                            ),
                            const SizedBox(height: 8),

                            // Location
                            _buildDetailRow(
                              icon: Icons.location_on_rounded,
                              label: "Location",
                              value: room['location']?.toString() ?? "Location not specified",
                              iconColor: Colors.red,
                            ),
                            const SizedBox(height: 8),

                            // Size
                            _buildDetailRow(
                              icon: Icons.square_foot_rounded,
                              label: "Size",
                              value: "${room['size'] is int ? room['size'] as int : int.tryParse(room['size']?.toString() ?? '0') ?? 0} Sq Ft",
                              iconColor: const Color(0xFF9C27B0),
                            ),
                            const SizedBox(height: 8),

                            // Monthly Rent
                            _buildDetailRow(
                              icon: Icons.attach_money_rounded,
                              label: "Monthly Rent",
                              value: "NPR ${room['price'] is int ? room['price'] as int : int.tryParse(room['price']?.toString() ?? '0') ?? 0}",
                              iconColor: Colors.green,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Booking Terms Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Booking Terms",
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _buildTermItem(
                              "This booking request will be sent to the room owner",
                              Icons.send_rounded,
                              const Color(0xFF2196F3),
                            ),
                            const SizedBox(height: 8),

                            _buildTermItem(
                              "Owner will contact you within 24 hours",
                              Icons.access_time_rounded,
                              const Color(0xFFFF9800),
                            ),
                            const SizedBox(height: 8),

                            _buildTermItem(
                              "You can cancel booking request anytime before confirmation",
                              Icons.cancel_rounded,
                              const Color(0xFFF44336),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Action Buttons
                      if (!_bookingConfirmed)
                        Column(
                          children: [
                            // Confirm Booking Button
                            Container(
                              width: double.infinity,
                              height: 52,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1565C0).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bookmark_add_rounded, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Confirm Booking",
                                      style: GoogleFonts.quicksand(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Cancel Button
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  "Cancel",
                                  style: GoogleFonts.quicksand(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      // COMPLETELY ATTACHED TO BOTTOM
                      const SizedBox(height: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermItem(String text, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}