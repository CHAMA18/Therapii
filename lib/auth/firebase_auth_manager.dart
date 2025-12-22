import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:therapii/auth/auth_manager.dart';
import 'package:therapii/models/user.dart' as AppUser;
import 'package:therapii/services/user_service.dart';

class FirebaseAuthManager extends AuthManager with EmailSignInManager {
  final FirebaseAuth.FirebaseAuth _auth = FirebaseAuth.FirebaseAuth.instance;
  final UserService _userService = UserService();
  
  FirebaseAuth.User? get currentUser => _auth.currentUser;
  Stream<FirebaseAuth.User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<AppUser.User?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final appUser = await _userService.getUser(credential.user!.uid);
        return appUser;
      }
      return null;
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
      return null;
    } catch (e) {
      _showErrorMessage(context, 'An unexpected error occurred. Please try again.');
      return null;
    }
  }

  @override
  Future<AppUser.User?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password, {
    required bool isTherapist,
  }
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Create user profile in Firestore
        final appUser = AppUser.User(
          id: credential.user!.uid,
          email: email,
          firstName: '',
          lastName: '',
          isTherapist: isTherapist,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _userService.createUser(appUser);
        return appUser;
      }
      return null;
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
      return null;
    } catch (e) {
      _showErrorMessage(context, 'An unexpected error occurred. Please try again.');
      return null;
    }
  }

  @override
  Future signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  @override
  Future deleteUser(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await _userService.deleteUser(user.uid);
        // Delete Firebase auth user
        await user.delete();
      }
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
    } catch (e) {
      _showErrorMessage(context, 'Failed to delete account. Please try again.');
    }
  }

  @override
  Future updateEmail({required String email, required BuildContext context}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(email);
        _showSuccessMessage(context, 'Verification email sent to $email');
      }
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
    } catch (e) {
      _showErrorMessage(context, 'Failed to update email. Please try again.');
    }
  }

  // Reauthenticate current user with password (for sensitive operations)
  Future<bool> reauthenticateWithPassword({
    required BuildContext context,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null) {
        _showErrorMessage(context, 'No authenticated user.');
        return false;
      }
      final credential = FirebaseAuth.EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
      return false;
    } catch (_) {
      _showErrorMessage(context, 'Reauthentication failed. Please try again.');
      return false;
    }
  }

  // Update password after reauthentication
  Future<void> updatePassword({
    required BuildContext context,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorMessage(context, 'No authenticated user.');
        return;
      }
      await user.updatePassword(newPassword);
      _showSuccessMessage(context, 'Password updated successfully.');
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
    } catch (_) {
      _showErrorMessage(context, 'Failed to update password. Please try again.');
    }
  }

  // Refresh and, if changed, sync the auth email to the Firestore user profile
  Future<void> refreshAndSyncEmailToFirestore(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorMessage(context, 'No authenticated user.');
        return;
      }
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null) return;
      final uid = refreshed.uid;
      final email = refreshed.email;
      if (email == null) return;
      final existing = await _userService.getUser(uid);
      if (existing == null) return;
      if (existing.email != email) {
        await _userService.updateUser(existing.copyWith(email: email));
        _showSuccessMessage(context, 'Email synced to profile.');
      }
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
    } catch (_) {
      _showErrorMessage(context, 'Failed to refresh account.');
    }
  }

  @override
  Future resetPassword({required String email, required BuildContext context}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSuccessMessage(context, 'Password reset email sent to $email');
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      _showErrorMessage(context, _getErrorMessage(e.code));
    } catch (e) {
      _showErrorMessage(context, 'Failed to send password reset email. Please try again.');
    }
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters long.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'requires-recent-login':
        return 'Please sign in again to perform this action.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}