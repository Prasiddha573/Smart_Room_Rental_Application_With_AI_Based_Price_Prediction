import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Service For Showing Toast Messages Throughout The Application
class ToastService {
  /// Display Success Message
  void showSuccessMessage(String message) {
    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, backgroundColor: Colors.green, textColor: Colors.white, fontSize: 16.0);
  }

  /// Display Error Message
  void showErrorMessage(String message) {
    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, backgroundColor: Colors.red, textColor: Colors.white, fontSize: 16.0);
  }

  /// Display Warning Message
  void showWarningMessage(String message) {
    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, backgroundColor: Colors.orange, textColor: Colors.white, fontSize: 16.0);
  }

  /// Display Info Message
  void showInfoMessage(String message) {
    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, backgroundColor: Colors.blue, textColor: Colors.white, fontSize: 16.0);
  }

  /// Display Simple Message (Same as your previous code)
  void showMessage(String message) {
    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, backgroundColor: Colors.black87, textColor: Colors.white, fontSize: 16.0);
  }
}
