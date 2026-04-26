import 'package:get/get.dart';

/// Controller For Managing Password Visibility States
class ShowPasswordController extends GetxController {
  var isPasswordVisible = true.obs;
  var isConfirmPasswordVisible = true.obs;

  /// Toggle Main Password Visibility
  void togglePasswordVisibility() => isPasswordVisible.value = !isPasswordVisible.value;

  /// Toggle Confirm Password Visibility
  void toggleConfirmPasswordVisibility() => isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
}
