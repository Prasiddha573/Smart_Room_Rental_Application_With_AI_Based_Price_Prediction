import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/show_password_controller.dart';
import '../../../themes/colors.dart';

/// Custom Text Input Field With Icon And Validation
class CustomInputField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final Color iconColor;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool isConfirmPassword;

  const CustomInputField({Key? key, required this.controller, required this.icon, required this.iconColor, required this.hintText, this.validator, this.keyboardType = TextInputType.text, this.isPassword = false, this.isConfirmPassword = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final showPasswordController = Get.find<ShowPasswordController>();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Icon Container
          _buildIconContainer(),
          const SizedBox(width: 12),
          // Text Field
          Expanded(child: isPassword ? _buildPasswordField(showPasswordController, context) : _buildNormalField(context)),
        ],
      ),
    );
  }

  /// Build Icon Container With Consistent Styling
  Widget _buildIconContainer() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  /// Build Normal Text Input Field
  Widget _buildNormalField(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textAlignVertical: TextAlignVertical.center,
      style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textColor),
      cursorColor: AppColors.primaryBlue,
      cursorHeight: 20,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(3),
      decoration: _buildInputDecoration(context),
      validator: validator,
    );
  }

  /// Build Password Input Field With Visibility Toggle
  Widget _buildPasswordField(ShowPasswordController passwordVisibilityController, BuildContext context) {
    return Obx(() {
      final isVisible = isConfirmPassword ? passwordVisibilityController.isConfirmPasswordVisible.value : passwordVisibilityController.isPasswordVisible.value;

      return Stack(
        alignment: Alignment.centerRight,
        children: [
          TextFormField(
            controller: controller, // Use the TextEditingController
            obscureText: isVisible,
            textAlignVertical: TextAlignVertical.center,
            style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textColor),
            cursorColor: AppColors.primaryBlue,
            cursorHeight: 20,
            cursorWidth: 2,
            cursorRadius: const Radius.circular(3),
            decoration: _buildInputDecoration(context).copyWith(contentPadding: const EdgeInsets.only(top: 15, right: 44)),
            validator: validator,
          ),
          // Visibility Toggle Icon
          _buildVisibilityToggle(passwordVisibilityController, isVisible),
        ],
      );
    });
  }

  /// Build Visibility Toggle Button For Password Fields
  Widget _buildVisibilityToggle(ShowPasswordController passwordVisibilityController, bool isVisible) {
    return Positioned(
      right: 0,
      child: GestureDetector(
        onTap: isConfirmPassword ? passwordVisibilityController.toggleConfirmPasswordVisibility : passwordVisibilityController.togglePasswordVisibility,
        child: Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Icon(isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey.shade500, size: 20),
        ),
      ),
    );
  }

  /// Build Common Input Decoration For All Fields
  InputDecoration _buildInputDecoration(BuildContext context) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.quicksand(color: AppColors.getHintTextColor(context), fontSize: 14, fontWeight: FontWeight.w700, height: 1.0),
      border: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      enabledBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      helperText: ' ',
      helperStyle: const TextStyle(height: 0.8, color: Colors.transparent),
      errorStyle: GoogleFonts.quicksand(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.errorRed, height: 1.0),
      contentPadding: const EdgeInsets.only(top: 15),
      isDense: true,
      alignLabelWithHint: true,
    );
  }
}
