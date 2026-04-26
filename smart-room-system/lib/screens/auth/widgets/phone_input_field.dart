import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../themes/colors.dart';

/// Specialized Phone Input Field With Nepal Flag Icon
class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;

  const PhoneInputField({Key? key, required this.controller, required this.hintText, this.validator}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Nepal Flag Icon Container
          _buildNepalFlagIcon(),
          const SizedBox(width: 12),
          // Phone Input Field
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textColor),
              cursorColor: AppColors.primaryBlue,
              cursorHeight: 20,
              cursorWidth: 2,
              cursorRadius: const Radius.circular(3),
              decoration: _buildInputDecoration(context),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Nepal Flag Styled Icon Container
  Widget _buildNepalFlagIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: AppColors.phoneIconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Center(
        child: Container(
          width: 20,
          height: 14,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400, width: 1)),
          child: Row(
            children: [
              Container(width: 6, color: AppColors.phoneIconColor),
              Container(width: 6, color: const Color(0xFF003893)),
              Expanded(child: Container(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Phone Input Field Decoration
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
