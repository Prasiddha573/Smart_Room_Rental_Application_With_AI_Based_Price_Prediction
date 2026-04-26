import 'package:get/get.dart';

/// Controller For Managing Loading States Across The Application
class LoaderController extends GetxController {
  var isLoading = false.obs;

  /// Start Loading Indicator
  void startLoading() => isLoading.value = true;

  /// Stop Loading Indicator
  void stopLoading() => isLoading.value = false;

  /// Toggle Loading State
  void toggleLoading() => isLoading.value = !isLoading.value;
}
