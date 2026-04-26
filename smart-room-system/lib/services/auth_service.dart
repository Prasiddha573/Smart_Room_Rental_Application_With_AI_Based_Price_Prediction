import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';
import 'toast_service.dart';

/// Service Handling All Authentication Related Operations
class AuthService extends GetxService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ToastService _toastService = ToastService();

  /// Create New User Account With Email And Password
  Future<User?> createUserWithEmailAndPassword({required String email, required String password, required String fullName, required String phone}) async {
    try {
      // Check If Email Already Exists In Firestore
      final emailQuery = await _firestore.collection('User').where('Email', isEqualTo: email.trim()).get();

      if (emailQuery.docs.isNotEmpty) {
        _toastService.showErrorMessage("Email Already Exists");
        return null;
      }

      // Create User In Firebase Authentication
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception("User Creation Failed");
      }

      // Create User Document In Firestore
      await _createUserDocument(userId: user.uid, fullName: fullName, phone: phone, email: email);

      // Send Email Verification
      await user.sendEmailVerification();

      _toastService.showSuccessMessage("Account Created Successfully!");
      return user;
    } on FirebaseAuthException catch (error) {
      _handleFirebaseAuthError(error);
      return null;
    } catch (error) {
      _toastService.showErrorMessage("An Unexpected Error Occurred");
      return null;
    }
  }

  /// Sign In Existing User With Email And Password
  Future<User?> signInWithEmailAndPassword({required String email, required String password}) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());

      return userCredential.user;
    } on FirebaseAuthException catch (error) {
      _handleLoginFirebaseAuthError(error);
      return null;
    } catch (error) {
      _toastService.showErrorMessage("An Unexpected Error Occurred");
      return null;
    }
  }

  /// Send Password Reset Email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (error) {
      _handlePasswordResetError(error);
      return false;
    } catch (error) {
      _toastService.showErrorMessage("Failed To Send Reset Email");
      return false;
    }
  }

  /// Create User Document In Firestore Database
  Future<void> _createUserDocument({required String userId, required String fullName, required String phone, required String email}) async {
    final userModel = UserModel(id: DateTime.now().microsecondsSinceEpoch.toString(), name: fullName.trim(), phone: phone.trim(), email: email.trim(), sessionId: userId, profilePath: "https://firebasestorage.googleapis.com/v0/b/online-2cdb1.appspot.com/o/1707049056458970?alt=media&token=2bcfcd4d-c2e1-4795-a064-312d5265eb21");

    await _firestore.collection("User").doc(userId).set(userModel.toFirestoreMap());
  }

  /// Handle Firebase Authentication Errors For Signup
  void _handleFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case "network-request-failed":
        _toastService.showErrorMessage("Please Check Your Connection");
        break;
      case "too-many-requests":
        _toastService.showErrorMessage("Too Many Attempts");
        break;
      case "email-already-in-use":
        _toastService.showErrorMessage("Email Is Already Registered");
        break;
      case "weak-password":
        _toastService.showErrorMessage("Use A Stronger Password");
        break;
      case "invalid-email":
        _toastService.showErrorMessage("Invalid Email Address");
        break;
      case "operation-not-allowed":
        _toastService.showErrorMessage("Email/Password Accounts Not Enabled");
        break;
      default:
        _toastService.showErrorMessage("Registration Failed");
    }
  }

  /// Handle Firebase Authentication Errors For Login
  void _handleLoginFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case "network-request-failed":
        _toastService.showErrorMessage("Please Check Your Connection");
        break;
      case "too-many-requests":
        _toastService.showErrorMessage("Too Many Attempts");
        break;
      case "user-not-found":
        _toastService.showErrorMessage("No Account Found With This Email");
        break;
      case "wrong-password":
        _toastService.showErrorMessage("Incorrect Password");
        break;
      case "invalid-email":
        _toastService.showErrorMessage("Invalid Email Address");
        break;
      case "user-disabled":
        _toastService.showErrorMessage("Account Has Been Disabled");
        break;
      default:
        _toastService.showErrorMessage("Login Failed");
    }
  }

  /// Handle Password Reset Errors
  void _handlePasswordResetError(FirebaseAuthException error) {
    switch (error.code) {
      case "invalid-email":
        _toastService.showErrorMessage("Invalid Email Address");
        break;
      case "user-not-found":
        _toastService.showErrorMessage("No Account Found With This Email");
        break;
      case "too-many-requests":
        _toastService.showErrorMessage("Too Many Attempts. Try Again Later");
        break;
      default:
        _toastService.showErrorMessage("Failed To Send Reset Email");
    }
  }

  /// Sign Out Current User
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Get Current User
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check If User Is Logged In
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  /// Check If User Email Is Verified
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  /// Send Email Verification
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Get User Data From Firestore
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('User').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return UserModel(id: data['id'] ?? '', name: data['Name'] ?? '', phone: data['Phone'] ?? '', email: data['Email'] ?? '', sessionId: data['SessionId'] ?? '', profilePath: data['Path'] ?? '');
      }
      return null;
    } catch (error) {
      return null;
    }
  }

  /// Update User Profile
  Future<void> updateUserProfile({String? name, String? phone, String? profilePath}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return;

      final updateData = <String, dynamic>{};
      if (name != null) updateData['Name'] = name.trim();
      if (phone != null) updateData['Phone'] = phone.trim();
      if (profilePath != null) updateData['Path'] = profilePath;
      updateData['updatedAt'] = DateTime.now();

      await _firestore.collection('User').doc(user.uid).update(updateData);
    } catch (error) {
      _toastService.showErrorMessage("Failed To Update Profile");
    }
  }
}
