/// Collection Of Validation Functions For Form Input Fields
class AuthValidators {
  /// Validate Full Name Input
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return "Please Enter Your Full Name";
    }
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
      return "Name Should Contain Only Letters And Spaces";
    }
    if (value.length < 2) {
      return "Name Must Be At Least 2 Characters";
    }
    return null;
  }

  /// Validate Nepali Phone Number Format
  static String? validateNepaliPhone(String? value) {
    if (value == null || value.isEmpty) {
      return "Please Enter Your Phone Number";
    }
    if (value.length != 10 || (!value.startsWith('98') && !value.startsWith('97'))) {
      return "Please Enter A Valid Phone Number";
    }
    return null;
  }

  /// Validate Email Address Format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Please Enter Your Email Address";
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
      return "Please Enter A Valid Email Address";
    }
    return null;
  }

  /// Validate Password Strength And Requirements
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Please Enter A Password";
    }
    if (value.length < 8) {
      return "Password Must Be At Least 8 Characters";
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]+$').hasMatch(value)) {
      return "Use Both Letters And Numbers";
    }
    return null;
  }

  /// Validate Confirm Password Matches Original Password
  static String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return "Please Confirm Your Password";
    }
    if (value != originalPassword) {
      return "Passwords Do Not Match";
    }
    return null;
  }
}
