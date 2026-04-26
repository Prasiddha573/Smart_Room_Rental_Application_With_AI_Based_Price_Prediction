// Owner Section Dialog For Posting Rooms. Handles Image Uploads To Supabase, Persists Room Data To Firestore, Uses FirebaseAuth SessionId, And Provides An Ios-Inspired Quicksand UI.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import 'location_picker_dialog.dart'; // Import the new location picker dialog

class OwnerSectionDialog extends StatefulWidget {
  const OwnerSectionDialog({super.key});

  @override
  _OwnerSectionDialogState createState() => _OwnerSectionDialogState();
}

class _OwnerSectionDialogState extends State<OwnerSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _internetController = TextEditingController();
  final _windowsController = TextEditingController();
  final _sizeController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedWater = "Available";
  String _selectedSunlight = "Good";
  String _selectedBathroom = "Yes";

  List<File> _selectedImages = [];
  String? _imageError;
  bool _isUploading = false;
  bool _isEstimating = false;
  int? _aiPrice;

  // Location data from picker
  String _selectedLocation = "";
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _walkTime = "0 min";
  String _distance = "0.00 km";

  final ImagePicker _picker = ImagePicker();

  // Function to open location picker dialog
  void _openLocationPicker() async {
    final locationData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const LocationPickerDialog(),
    );

    if (locationData != null && locationData.isNotEmpty) {
      setState(() {
        _selectedLocation = locationData['address'] ?? "";
        _selectedLatitude = locationData['latitude'];
        _selectedLongitude = locationData['longitude'];
        _distance = locationData['distance'] ?? "0.00 km";
        _walkTime = locationData['walkTime'] ?? "0 min";

        // Update the location controller with selected address
        _locationController.text = _selectedLocation;
      });
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _internetController.dispose();
    _windowsController.dispose();
    _sizeController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _uploadImages() async {
    final List<XFile>? images = await _picker.pickMultiImage(imageQuality: 75);
    if (images == null) return;

    if (_selectedImages.length + images.length > 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Maximum 6 images allowed",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() {
      _selectedImages.addAll(images.map((img) => File(img.path)));
      _imageError = null;
    });
  }

  /// Parse the numeric distance value from a string like "1.07 km"
  double _parseDistance(String distanceStr) {
    final cleaned = distanceStr.toLowerCase().replaceAll('km', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Map Flutter app water value to model-expected value
  String _mapWaterValue(String water) {
    switch (water) {
      case "Available":
        return "available";
      case "Limited":
        return "limited";
      case "Always":
        return "always";
      default:
        return "limited";
    }
  }

  /// Map Flutter app sunlight value to model-expected value
  String _mapSunlightValue(String sunlight) {
    switch (sunlight) {
      case "Good":
        return "good";
      case "Moderate":
        return "moderate";
      case "Poor":
        return "poor";
      default:
        return "poor";
    }
  }

  /// Map Flutter app bathroom value to model-expected value
  String _mapBathroomValue(String bathroom) {
    switch (bathroom) {
      case "Yes":
        return "yes";
      case "No":
        return "no";
      case "Shared":
        return "shared";
      default:
        return "no";
    }
  }

  Future<void> _estimatePrice() async {
    // Validate the form fields (except price which doesn't exist anymore)
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    if (_selectedLocation.isEmpty || _selectedLatitude == null || _selectedLongitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please select a location on map first",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() {
      _isEstimating = true;
    });

    try {
      final body = jsonEncode({
        'distance': _parseDistance(_distance),
        'internet': int.tryParse(_internetController.text.trim()) ?? 0,
        'windows': int.tryParse(_windowsController.text.trim()) ?? 0,
        'bathroom': _mapBathroomValue(_selectedBathroom),
        'size': int.tryParse(_sizeController.text.trim()) ?? 0,
        'water': _mapWaterValue(_selectedWater),
        'sunlight': _mapSunlightValue(_selectedSunlight),
      });

      final response = await http.post(
        Uri.parse(AppConfig.priceEstimationApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictedPrice = data['predicted_price'] as int;

        setState(() {
          _aiPrice = predictedPrice;
          _priceController.text = predictedPrice.toString();
          _isEstimating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "AI Estimated Price: NPR $predictedPrice /month",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _isEstimating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Estimation failed: ${data['error'] ?? 'Unknown error'}",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEstimating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Could not connect to estimation server: $e",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    // Ensure AI estimation has been done
    if (_aiPrice == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please press Estimate first to get AI predicted price",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    if (_selectedImages.isEmpty) {
      setState(() {
        _imageError = 'Please Add At Least One Image';
      });
      return;
    }

    if (_selectedLocation.isEmpty || _selectedLatitude == null || _selectedLongitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please select a location on map",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final firestore = FirebaseFirestore.instance;
    final supabase = Supabase.instance.client;
    final user = FirebaseAuth.instance.currentUser;
    final sessionId = user?.uid ?? 'anonymous_${DateTime.now().millisecondsSinceEpoch}';

    List<String?> uploadedUrls = List<String?>.filled(6, null);

    try {
      for (var i = 0; i < _selectedImages.length && i < 6; i++) {
        final File img = _selectedImages[i];
        final fileName = 'room_images/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}.jpg';
        final bytes = await img.readAsBytes();

        await supabase.storage.from('room_images').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600'),
        );

        final publicUrl = supabase.storage.from('room_images').getPublicUrl(fileName);
        uploadedUrls[i] = publicUrl;
      }

      // price = user-edited value (or same as aiPrice if unedited)
      final int price = int.tryParse(_priceController.text.trim()) ?? _aiPrice!;
      // aiPrice = the original AI prediction (never changed)
      final int aiPrice = _aiPrice!;

      final Map<String, dynamic> roomDoc = {
        'roomName': _roomNameController.text.trim(),
        'internet': int.tryParse(_internetController.text.trim()),
        'windows': int.tryParse(_windowsController.text.trim()),
        'size': int.tryParse(_sizeController.text.trim()),
        'location': _selectedLocation,
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'distance': _distance,
        'walkTime': _walkTime,
        'water': _selectedWater,
        'sunlight': _selectedSunlight,
        'bathroom': _selectedBathroom,
        'price': price,
        'aiPrice': aiPrice,
        'images': uploadedUrls.where((e) => e != null).toList(),
        'createdAt': DateTime.now(),
        'sessionId': sessionId,
        'status': "Available"
      };

      await firestore.collection('room').add(roomDoc);

      setState(() {
        _isUploading = false;
      });

      if (mounted) _showSuccessDialog();
    } catch (e, st) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error: $e",
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      debugPrint('Upload error: $e\n$st');
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withOpacity(0.25), blurRadius: 12)],
              ),
              child: Icon(Icons.verified, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              "Successfully Listed",
              style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              "Your Room Has Been Successfully Listed And Is Now Available To Others.",
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Continue", style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
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
              child: Icon(Icons.arrow_back_rounded, size: 20, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                "Post Your Room",
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  foreground: Paint()
                    ..shader = const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _selectedImages.isEmpty ? Center(child: _buildAddImageTile(centered: true)) : _buildImageStrip(),
            ),
          ),
          if (_imageError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  _imageError!,
                  style: GoogleFonts.quicksand(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageStrip() {
    final count = _selectedImages.length < 6 ? _selectedImages.length + 1 : 6;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, idx) {
        if (idx == _selectedImages.length && _selectedImages.length < 6) return _buildAddImageTile();
        final imgFile = _selectedImages[idx];
        return SizedBox(
          width: 130,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  imgFile,
                  width: 130,
                  height: 86,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedImages.removeAt(idx);
                    if (_selectedImages.isEmpty) _imageError = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddImageTile({bool centered = false}) {
    return GestureDetector(
      onTap: _uploadImages,
      child: Container(
        width: centered ? 160 : 130,
        height: centered ? 90 : 86,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              "Add Images",
              style: GoogleFonts.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFieldsContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildRowInput(
            controller: _roomNameController,
            label: "Name Your Room",
            icon: Icons.holiday_village_rounded, // Changed from Icons.room
            iconColor: const Color(0xFF4CAF50),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Room Name Is Required';
              if (value.trim().length < 3) return 'Room Name Must Be At Least 3 Characters';
              if (value.trim().length > 50) return 'Room Name Is Too Long (Max 50 Characters)';
              return null;
            },
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildRowInput(
            controller: _internetController,
            label: "Internet Speed (Mbps)",
            hintSuffix: " Mbps",
            icon: Icons.wifi_rounded,
            iconColor: const Color(0xFFFF9800),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Internet Speed Is Required';
              if (int.tryParse(value.trim()) == null) return 'Enter A Valid Number';
              if (int.parse(value.trim()) < 0) return 'Speed Cannot Be Negative';
              return null;
            },
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildRowInput(
            controller: _windowsController,
            label: "Number Of Windows",
            hintSuffix: " Windows",
            icon: Icons.window_rounded,
            iconColor: const Color(0xFF2196F3),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Number Of Windows Is Required';
              if (int.tryParse(value.trim()) == null) return 'Enter A Valid Number';
              final n = int.parse(value.trim());
              if (n < 0) return 'Number Cannot Be Negative';
              if (n > 50) return 'Max 50 Windows Allowed';
              return null;
            },
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildRowInput(
            controller: _sizeController,
            label: "Room Size (Sq Ft)",
            hintSuffix: " Sq Ft",
            icon: Icons.square_foot_rounded,
            iconColor: const Color(0xFF9C27B0),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Room Size Is Required';
              if (int.tryParse(value.trim()) == null) return 'Enter A Valid Number';
              final s = int.parse(value.trim());
              if (s <= 0) return 'Size Must Be Greater Than 0';
              if (s > 5000) return 'Maximum Allowed Is 5000';
              return null;
            },
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          // Location Input with Map Picker
          _buildLocationInput(),
        ],
      ),
    );
  }

  Widget _buildLocationInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 12 / 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.location_pin, size: 18, color: const Color(0xFFFF5722)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _openLocationPicker,
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: _locationController,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        hintText: "Location",
                        hintStyle: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorStyle: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade600,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Location Is Required';
                        if (value.trim().length < 5) return 'Please select a location on map';
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    String? hintSuffix,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 12 / 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final showSuffix = hintSuffix != null && value.text.trim().isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        hintText: label,
                        hintStyle: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                        suffixText: showSuffix ? hintSuffix : null,
                        suffixStyle: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorStyle: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade600,
                        ),
                      ),
                      validator: validator,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContainerWithButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildToggleContainer(),
          Divider(height: 1, color: Colors.grey.shade100),
          // AI Price display section (appears after estimation)
          if (_aiPrice != null) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.smart_toy_rounded, size: 18, color: Colors.green.shade600),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Predicted Price",
                        style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                      Text(
                        "NPR $_aiPrice /month",
                        style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(top: 12 / 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_rounded, size: 18, color: const Color(0xFFFF9800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        hintText: "Edit Price (NPR)",
                        hintStyle: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                        suffixText: " /Month",
                        suffixStyle: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorStyle: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade600,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please Enter Room Price';
                        if (int.tryParse(value.trim()) == null) return 'Please Enter A Valid Number';
                        final price = int.parse(value.trim());
                        if (price <= 0) return 'Price Must Be Greater Than 0';
                        if (price > 1000000) return 'Price Seems Too High';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isEstimating ? null : _estimatePrice,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFFA726)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isEstimating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.analytics_outlined, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                "Estimate",
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: (_isUploading || _aiPrice == null) ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _aiPrice == null
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : [const Color(0xFF2C3E50), const Color(0xFF3498DB)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isUploading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rocket_launch_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                "Publish",
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleContainer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.water_drop, size: 18, color: Color(0xFF00BCD4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Water Availability",
                  style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildIosStyleToggle(
            options: const ["Available", "Limited", "Always"],
            current: _selectedWater,
            color: const Color(0xFF00BCD4),
            onChanged: (v) => setState(() => _selectedWater = v),
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, size: 18, color: Color(0xFFFFC107)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Sunlight",
                  style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildIosStyleToggle(
            options: const ["Good", "Moderate", "Poor"],
            current: _selectedSunlight,
            color: const Color(0xFFFFC107),
            onChanged: (v) => setState(() => _selectedSunlight = v),
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.bathtub_outlined, size: 18, color: Color(0xFF795548)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Attached Bathroom",
                  style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildIosStyleToggle(
            options: const ["Yes", "No", "Shared"],
            current: _selectedBathroom,
            color: const Color(0xFF795548),
            onChanged: (v) => setState(() => _selectedBathroom = v),
          ),
        ),
      ],
    );
  }

  Widget _buildIosStyleToggle({required List<String> options, required String current, required Color color, required ValueChanged<String> onChanged}) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final opt = options[i];
          final selected = current == opt;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 4, right: i == options.length - 1 ? 0 : 4),
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  child: Text(
                    opt,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        width: screenWidth,
        margin: EdgeInsets.only(top: screenWidth < 600 ? 30 : 40),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    children: [
                      _buildImageSection(),
                      _buildInputFieldsContainer(),
                      _buildMainContainerWithButtons(),
                      const SizedBox(height: 20),
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
}