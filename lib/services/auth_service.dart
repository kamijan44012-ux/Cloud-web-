import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import 'email_verification_service.dart';
import 'firebase_service.dart';
import 'local_auth_service.dart';

/// A unified, backend-agnostic view of the signed-in player. It is backed by
/// Firebase when configured, otherwise by the on-device [LocalAuthService].
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isLocal,
    this.emailVerified = true,
    this.photoUrl,
    this.isAnonymous = false,
    this.isPasswordProvider = false,
  });

  final String uid;
  final String? email;
  final String? displayName;

  /// True when this account lives only on this device (Firebase not configured).
  final bool isLocal;

  /// Whether the email has been verified. Always true for local/Google/guest.
  final bool emailVerified;

  /// Avatar/photo URL (from Google sign-in), when available.
  final String? photoUrl;

  /// True for instant "Play as Guest" accounts.
  final bool isAnonymous;

  /// True when signed in with email + password (not Google/guest).
  final bool isPasswordProvider;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String adminEmail = 'aliuk0018@gmail.com';
  static const int adminInitialCoins = 2000000;
  static const String _adminPanelPassword = '125700';

  /// Emits the current [AppUser] (or null) whenever auth state changes.
  final ValueNotifier<AppUser?> userNotifier = ValueNotifier<AppUser?>(null);

  User? _firebaseUser;

  /// Set once a password user has confirmed their 6-digit email code (EmailJS
  /// flow). Mirrored to `user_profiles/{uid}.emailCodeVerified`.
  bool _emailCodeVerified = false;

  /// True when Firebase Auth is actually usable (initialised with real config).
  bool get _firebaseReady =>
      GameConfig.enableFirebase && FirebaseService.instance.isReady;

  // -- Unified getters --------------------------------------------------------

  AppUser? get currentAppUser => userNotifier.value;
  bool get isSignedIn => userNotifier.value != null;
  String? get currentUid => userNotifier.value?.uid;
  String? get currentEmail => userNotifier.value?.email;
  String? get currentDisplayName => userNotifier.value?.displayName;
  bool get isAdmin =>
      userNotifier.value?.email?.toLowerCase() == adminEmail.toLowerCase();

  /// The underlying Firebase user, when signed in via Firebase. Cloud features
  /// (Firestore) require this; it is null for local-only accounts.
  User? get firebaseUser => _firebaseUser;

  bool checkAdminPanelPassword(String password) =>
      password == _adminPanelPassword;

  /// True when a real cloud backend (Firebase) is connected. When false the app
  /// uses on-device email accounts and Google sign-in is unavailable.
  bool get isCloudEnabled => _firebaseReady;

  /// True when this build emails a 6-digit code (EmailJS configured) rather
  /// than a Firebase verification link.
  bool get usesEmailCode => EmailVerificationService.instance.usesCode;

  /// True when the signed-in user registered with email/password and has not yet
  /// confirmed their email. Google and guest accounts never need verification.
  bool get needsEmailVerification {
    final AppUser? u = userNotifier.value;
    if (u == null || u.isLocal) return false;
    if (!u.isPasswordProvider) return false;
    if (u.emailVerified) return false; // already verified via Firebase link
    if (usesEmailCode) return !_emailCodeVerified;
    return true; // link flow, not yet clicked
  }

  Future<void> _loadEmailCodeVerified(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(uid)
              .get();
      _emailCodeVerified =
          (snap.data()?['emailCodeVerified'] as bool?) ?? false;
    } catch (e) {
      debugPrint('_loadEmailCodeVerified: $e');
      _emailCodeVerified = false;
    }
  }

  /// Re-sends the verification code (EmailJS) or link (Firebase) to the user.
  Future<String?> resendVerificationEmail() async {
    if (!_firebaseReady) return 'Online server not available.';
    if (usesEmailCode) {
      final String? email = currentEmail;
      if (email == null) return 'No email on file.';
      return EmailVerificationService.instance.sendCode(email);
    }
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Could not send the email. Please try again.';
    }
  }

  /// Checks a 6-digit code the player typed in. On success marks them verified
  /// (locally + in their cloud profile) and refreshes the gate.
  Future<String?> confirmEmailCode(String input) async {
    if (!EmailVerificationService.instance.verify(input)) {
      return 'Incorrect or expired code. Please check and try again.';
    }
    _emailCodeVerified = true;
    try {
      final String? uid = _firebaseUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(uid)
            .set(<String, dynamic>{'emailCodeVerified': true},
                SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('confirmEmailCode persist: $e');
    }
    _recompute();
    return null;
  }

  /// Reloads the Firebase user and refreshes state — call after the player says
  /// they clicked the verification link to flip [needsEmailVerification].
  Future<bool> reloadAndCheckVerified() async {
    if (!_firebaseReady) return false;
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      _firebaseUser = FirebaseAuth.instance.currentUser;
      _recompute();
      return _firebaseUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('reloadAndCheckVerified: $e');
      return false;
    }
  }

  /// Updates the player's display name across Firebase Auth (and refreshes the
  /// unified user). Returns an error message or null on success.
  Future<String?> updateDisplayName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return 'Please enter a name.';
    if (_firebaseReady && _firebaseUser != null) {
      try {
        await _firebaseUser!.updateDisplayName(trimmed);
        await _firebaseUser!.reload();
        _firebaseUser = FirebaseAuth.instance.currentUser;
        _recompute();
        return null;
      } catch (e) {
        debugPrint('updateDisplayName: $e');
        return 'Could not update name. Please try again.';
      }
    }
    // Local accounts: nothing server-side, ProfileService handles persistence.
    return null;
  }

  // -- Lifecycle --------------------------------------------------------------

  /// Wires up auth listeners. Safe to call once at startup, after
  /// [FirebaseService.init]. Works whether or not Firebase is configured.
  Future<void> init() async {
    await LocalAuthService.instance.load();
    LocalAuthService.instance.currentUserNotifier.addListener(_recompute);

    if (_firebaseReady) {
      try {
        final FirebaseAuth auth = FirebaseAuth.instance;
        // Complete a pending web redirect sign-in (Google on mobile browsers).
        if (kIsWeb) {
          try {
            await auth.getRedirectResult();
          } catch (_) {}
        }
        auth.authStateChanges().listen((User? user) async {
          _firebaseUser = user;
          // For unverified email/password accounts, load whether they already
          // confirmed via the 6-digit code on a previous session.
          if (user != null &&
              !user.emailVerified &&
              user.providerData
                  .any((UserInfo p) => p.providerId == 'password')) {
            await _loadEmailCodeVerified(user.uid);
          } else {
            _emailCodeVerified = false;
          }
          _recompute();
        });
      } catch (e) {
        debugPrint('AuthService.init firebase listen failed: $e');
      }
    }
    _recompute();
  }

  void _recompute() {
    if (_firebaseUser != null) {
      final User u = _firebaseUser!;
      final bool isPassword =
          u.providerData.any((UserInfo p) => p.providerId == 'password');
      userNotifier.value = AppUser(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        isLocal: false,
        emailVerified: u.emailVerified,
        photoUrl: u.photoURL,
        isAnonymous: u.isAnonymous,
        isPasswordProvider: isPassword,
      );
      return;
    }
    final LocalUser? local =
        LocalAuthService.instance.currentUserNotifier.value;
    userNotifier.value = local == null
        ? null
        : AppUser(
            uid: 'local:${local.email}',
            email: local.email,
            displayName: local.displayName,
            isLocal: true,
          );
  }

  // -- Email auth -------------------------------------------------------------

  Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_firebaseReady) {
      try {
        final UserCredential cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user?.updateDisplayName(displayName.trim());
        _emailCodeVerified = false;
        // First-time users confirm ownership: a 6-digit code (EmailJS) when
        // configured, otherwise Firebase's verification link.
        try {
          if (usesEmailCode) {
            await EmailVerificationService.instance.sendCode(email.trim());
          } else {
            await cred.user?.sendEmailVerification();
          }
        } catch (e) {
          debugPrint('send verification on signup: $e');
        }
        await cred.user?.reload();
        _firebaseUser = FirebaseAuth.instance.currentUser;
        _recompute();
        return null;
      } on FirebaseAuthException catch (e) {
        return _authError(e);
      } catch (e) {
        debugPrint('signUp error: $e');
        return 'Registration failed. Please try again.';
      }
    }
    // No backend configured — register on this device so the player isn't stuck.
    return LocalAuthService.instance.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (_firebaseReady) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return null;
      } on FirebaseAuthException catch (e) {
        return _authError(e);
      } catch (e) {
        debugPrint('signIn error: $e');
        return 'Sign in failed. Please try again.';
      }
    }
    return LocalAuthService.instance.signIn(
      email: email,
      password: password,
    );
  }

  Future<String?> signInWithGoogle() async {
    if (!_firebaseReady) {
      return 'Google sign-in needs the online server, which isn\'t set up yet. '
          'Please register with your email for now.';
    }
    if (!kIsWeb) {
      return 'Google sign-in is available on web only. Please use email.';
    }
    try {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      try {
        // Fast path on desktop browsers.
        await FirebaseAuth.instance.signInWithPopup(provider);
        return null;
      } catch (_) {
        // Popups are commonly blocked on mobile browsers; redirect is reliable.
        // This navigates away; the result is picked up by init() on return.
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return null;
      }
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return 'Google sign-in failed. Please use email instead.';
    }
  }

  /// Instant play: signs in with just a display name (anonymous on Firebase
  /// when available, on-device guest otherwise). No password, no friction.
  Future<String?> signInAsGuest(String displayName) async {
    if (_firebaseReady) {
      try {
        final UserCredential cred =
            await FirebaseAuth.instance.signInAnonymously();
        await cred.user?.updateDisplayName(
            displayName.trim().isEmpty ? 'Player' : displayName.trim());
        await cred.user?.reload();
        _firebaseUser = FirebaseAuth.instance.currentUser;
        _recompute();
        return null;
      } catch (e) {
        debugPrint('Anonymous sign-in failed, using local guest: $e');
      }
    }
    return LocalAuthService.instance.signInAsGuest(displayName);
  }

  Future<String?> resetPassword(String email) async {
    if (!_firebaseReady) {
      return 'Password reset needs the online server, which isn\'t set up yet.';
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Failed to send reset email. Please try again.';
    }
  }

  Future<void> signOut() async {
    if (_firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Firebase signOut: $e');
      }
    }
    await LocalAuthService.instance.signOut();
    _firebaseUser = null;
    _emailCodeVerified = false;
    EmailVerificationService.instance.clear();
    _recompute();
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
      case 'operation-not-allowed':
        return 'Email sign-in is turned off on the server. '
            'Enable Email/Password in the Firebase console.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'unauthorized-domain':
        return 'This site isn\'t authorised for sign-in. Add the domain in '
            'Firebase Authentication settings.';
      default:
        return e.message ?? 'Authentication error. Please try again.';
    }
  }
}
