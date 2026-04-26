import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../services/auth_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/modern_app_bar.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = Get.find<AuthService>();
  final ToastService _toastService = ToastService();

  // Get Supabase client instance
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  User? user;
  DocumentSnapshot? userDoc;
  bool _isLoading = true;
  bool _isUploadingImage = false;

  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;

    // Initialize Animation Controller For Smooth Transitions
    _fadeAnimationController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeInOut));

    _loadUser();
  }

  /// Load User Profile Data From Firestore
  Future<void> _loadUser() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('User').doc(user!.uid).get();

      if (!mounted) return;

      setState(() {
        userDoc = doc;
        _isLoading = false;
        _isUploadingImage = false;
      });

      // Start Fade-In Animation immediately
      _fadeAnimationController.forward();
    } catch (e) {
      print("Error loading user: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Change Profile Image From Device Gallery and Upload to Supabase
  Future<void> _changeImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);

    if (picked == null) return;

    setState(() {
      _isLoading = true;
      _isUploadingImage = true;
    });

    try {
      // 1. Create a unique file name for the image
      final file = File(picked.path);
      final fileExtension = picked.path.split('.').last.toLowerCase();
      final fileName = '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}.$fileExtension';

      // 2. Define the storage path in Supabase
      final storagePath = 'profile-pictures/$fileName';

      // 3. Upload the image to Supabase Storage
      await _supabaseClient.storage
          .from('products') // Your bucket name
          .upload(storagePath, file, fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExtension'));

      // 4. Get the public URL from Supabase
      final String publicUrl = _supabaseClient.storage.from('products').getPublicUrl(storagePath);

      print("Image uploaded to Supabase. URL: $publicUrl");

      // 5. Update Firebase with the Supabase URL
      await _authService.updateUserProfile(profilePath: publicUrl);

      if (!mounted) return;

      _toastService.showSuccessMessage("Profile Image Updated Successfully");

      // Reload user data to show the new image
      await _loadUser();
    } catch (e) {
      print("Error uploading image to Supabase: $e");

      if (!mounted) return;

      // Show error message
      _toastService.showErrorMessage("Failed to upload image. Please try again.");

      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  /// Show Dialog For Changing Username
  void _changeName() {
    final controller = TextEditingController(text: userDoc?['Name'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return _iOSStyledDialog(
          dialogContext: dialogContext,
          title: "Change Username",
          content: TextField(
            controller: controller,
            style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: 'Enter New Username',
              hintStyle: GoogleFonts.quicksand(color: Colors.grey[600]),
            ),
          ),
          onSave: () async {
            if (controller.text.trim().isEmpty) {
              _toastService.showErrorMessage("Username cannot be empty");
              return;
            }

            await _authService.updateUserProfile(name: controller.text.trim());
            Navigator.pop(dialogContext);
            if (mounted) {
              _toastService.showSuccessMessage("Username Updated");
              _loadUser();
            }
          },
          onCancel: () {
            Navigator.pop(dialogContext);
          },
        );
      },
    );
  }

  /// Show Dialog For Changing Phone Number
  void _changePhone() {
    final controller = TextEditingController(text: userDoc?['Phone'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return _iOSStyledDialog(
          dialogContext: dialogContext,
          title: "Change Phone Number",
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: 'Enter Phone Number',
              hintStyle: GoogleFonts.quicksand(color: Colors.grey[600]),
            ),
          ),
          onSave: () async {
            if (controller.text.trim().isEmpty) {
              _toastService.showErrorMessage("Phone number cannot be empty");
              return;
            }

            await _authService.updateUserProfile(phone: controller.text.trim());
            Navigator.pop(dialogContext);
            if (mounted) {
              _toastService.showSuccessMessage("Phone Number Updated");
              _loadUser();
            }
          },
          onCancel: () {
            Navigator.pop(dialogContext);
          },
        );
      },
    );
  }

  /// Send Password Reset Email To Registered Email Address
  Future<void> _resetPassword() async {
    final email = user?.email;
    if (email == null) {
      _toastService.showErrorMessage("No email found for this account");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sent = await _authService.sendPasswordResetEmail(email);

      if (!mounted) return;

      if (sent) {
        _toastService.showSuccessMessage("Password reset email sent to $email");
      }
    } catch (e) {
      _toastService.showErrorMessage("Failed to send reset email");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Logout User And Navigate To Login Screen
  Future<void> _logout() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signOut();
      if (!mounted) return;

      Get.offAll(() => LoginScreen());
    } catch (e) {
      print("Logout error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = userDoc?['Name'] ?? 'No Name';
    final email = userDoc?['Email'] ?? user?.email ?? 'No Email';
    final phone = userDoc?['Phone'] ?? 'Not Set';
    final imagePath = userDoc?['Path'];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: const ModernAppBar(title: "My Profile"),
      body: _buildContentLayout(name, email, phone, imagePath),
    );
  }

  /// Build Main Content Layout With Animated Transitions
  Widget _buildContentLayout(String name, String email, String phone, dynamic imagePath) {
    return SingleChildScrollView(
      child: AnimatedBuilder(
        animation: _fadeAnimationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _fadeAnimation.value) * 10),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Profile Card Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Column(
                        children: [
                          // Profile Image With Edit Pencil Button - SHIMMER DURING UPLOAD ONLY
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _isUploadingImage ? Colors.orange : const Color(0xFF7B68EE), width: 2.5),
                                ),
                                child: Stack(
                                  children: [
                                    // Show shimmer when uploading
                                    if (_isUploadingImage)
                                      Shimmer.fromColors(
                                        baseColor: Colors.grey.shade300,
                                        highlightColor: Colors.grey.shade100,
                                        child: Container(
                                          width: 88,
                                          height: 88,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),

                                    // Show actual image when not uploading
                                    if (!_isUploadingImage)
                                      CircleAvatar(
                                        radius: 41,
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage: _getProfileImageProvider(imagePath),
                                        child: (imagePath == null || (imagePath as String).isEmpty) ? Icon(Icons.person, size: 44, color: Colors.grey[400]) : null,
                                      ),
                                  ],
                                ),
                              ),

                              // Edit Profile Image Button
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploadingImage ? null : _changeImage,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: _isUploadingImage ? Colors.grey : Colors.orange.shade400, width: 1.5),
                                      color: Colors.white,
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
                                    ),
                                    child: Center(
                                      child: _isUploadingImage
                                          ? Shimmer.fromColors(
                                        baseColor: Colors.grey.shade300,
                                        highlightColor: Colors.grey.shade100,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                          : Icon(Icons.edit, size: 14, color: Colors.orange.shade700),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // User Information Display - ALWAYS SHOW ACTUAL DATA, NO SHIMMER HERE
                          Column(
                            children: [
                              // Always show actual name (even during upload)
                              Text(
                                name,
                                style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),

                              // Always show actual email (even during upload)
                              Text(
                                email,
                                style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),

                              // Always show actual phone (even during upload)
                              Text(
                                phone,
                                style: GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Settings Section - BUTTONS ARE ENABLED EVEN DURING UPLOAD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Column(
                        children: [
                          _compactSettingsTile(
                            icon: Icons.person_outline,
                            iconColor: Colors.deepPurple,
                            title: "Change Username",
                            onTap: _changeName,
                          ),
                          const Divider(height: 0, thickness: 0.5),
                          _compactSettingsTile(
                            icon: Icons.lock_outline,
                            iconColor: Colors.orange,
                            title: "Change Password",
                            onTap: _resetPassword,
                          ),
                          const Divider(height: 0, thickness: 0.5),
                          _compactSettingsTile(
                            icon: Icons.phone_outlined,
                            iconColor: Colors.green,
                            title: "Change Phone Number",
                            onTap: _changePhone,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Account Management Section - BUTTONS ARE ENABLED EVEN DURING UPLOAD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Column(
                        children: [
                          _compactSettingsTile(
                            icon: Icons.add_circle_outline,
                            iconColor: Colors.blue,
                            title: "Create New Account",
                            onTap: () => Get.to(() => SignUpScreen()),
                          ),
                          const Divider(height: 0, thickness: 0.5),
                          _compactSettingsTile(
                            icon: Icons.logout,
                            iconColor: Colors.red,
                            title: "Log Out",
                            onTap: _logout,
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Helper method to get the correct ImageProvider for profile picture
  ImageProvider? _getProfileImageProvider(dynamic imagePath) {
    if (imagePath != null && (imagePath as String).isNotEmpty) {
      final path = imagePath as String;
      if (path.startsWith('http')) {
        return NetworkImage(path);
      } else if (path.startsWith('gs://') || path.contains('supabase')) {
        return NetworkImage(path);
      } else {
        return FileImage(File(path));
      }
    }
    return null;
  }

  /// Build Compact Settings Tile With Consistent Styling
  Widget _compactSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      minVerticalPadding: 0,
      dense: true,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDestructive ? Colors.red : iconColor,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.quicksand(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: isDestructive ? Colors.red : Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  /// Build iOS-Styled Dialog With Cancel And Save Buttons
  Widget _iOSStyledDialog({required BuildContext dialogContext, required String title, required Widget content, required VoidCallback onSave, required VoidCallback onCancel}) {
    final double screenWidth = MediaQuery.of(dialogContext).size.width;
    final double dialogWidth = (screenWidth - 32);
    const purple = Color(0xFF7B68EE);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 6,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6))],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 48), child: content),
                    ),
                    Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          // Cancel Button With Red Styling
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onCancel,
                              icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                              label: Text(
                                "Cancel",
                                style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Save Button With Purple Styling And Verified Icon
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onSave,
                              icon: const Icon(Icons.verified, size: 16, color: Colors.white),
                              label: Text(
                                "Save",
                                style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: purple,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}