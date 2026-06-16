import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String adminEmail = 'aliuk0018@gmail.com';
  static const int adminInitialCoins = 2000000;
  static const String _adminPanelPassword = '125700';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isSignedIn => _auth.currentUser != null;
  bool get isAdmin =>
      _auth.currentUser?.email?.toLowerCase() == adminEmail.toLowerCase();

  bool checkAdminPanelPassword(String password) =>
      password == _adminPanelPassword;

  Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(displayName.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Registration failed. Please try again.';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Sign in failed. Please try again.';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
        return null;
      }
      return 'Google sign-in is available on web only. Please use email.';
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return 'Google sign-in failed. Please use email instead.';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Failed to send reset email. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication error. Please try again.';
    }
  }
}
