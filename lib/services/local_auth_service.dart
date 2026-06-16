import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight account in the on-device fallback store.
class LocalUser {
  const LocalUser({
    required this.email,
    required this.displayName,
  });

  final String email;
  final String displayName;
}

/// On-device account fallback used when Firebase is **not** configured or fails
/// to initialise (e.g. the GitHub Pages demo with no secrets set).
///
/// This lets every player register and sign in with an email + password right
/// away, so the auth wall never blocks them. Accounts live in
/// `shared_preferences` on the device only — they do **not** sync across devices
/// and are **not** a security boundary (passwords are salted-hashed only to
/// avoid storing them in clear text). Real, cross-device cloud accounts and
/// Google sign-in require Firebase to be configured — see FIREBASE_SETUP.md.
class LocalAuthService {
  LocalAuthService._();
  static final LocalAuthService instance = LocalAuthService._();

  static const String _accountsKey = 'local_auth_accounts';
  static const String _sessionKey = 'local_auth_session_email';

  final ValueNotifier<LocalUser?> currentUserNotifier =
      ValueNotifier<LocalUser?>(null);

  SharedPreferences? _prefs;
  Map<String, dynamic> _accounts = <String, dynamic>{};

  bool get isSignedIn => currentUserNotifier.value != null;

  /// Loads stored accounts and restores the previous session, if any.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final String? raw = _prefs!.getString(_accountsKey);
      if (raw != null && raw.isNotEmpty) {
        _accounts = jsonDecode(raw) as Map<String, dynamic>;
      }
      final String? session = _prefs!.getString(_sessionKey);
      if (session != null && _accounts.containsKey(session)) {
        currentUserNotifier.value = _userFrom(session);
      }
    } catch (e) {
      debugPrint('LocalAuthService.load: $e');
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final String e = email.trim().toLowerCase();
    final String name = displayName.trim();
    if (!_isValidEmail(e)) return 'Please enter a valid email address.';
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (name.isEmpty) return 'Please enter your display name.';
    if (_accounts.containsKey(e)) {
      return 'An account already exists with this email.';
    }

    final String salt = _newSalt();
    _accounts[e] = <String, dynamic>{
      'displayName': name,
      'salt': salt,
      'hash': _hash(salt, password),
    };
    await _persistAccounts();
    await _startSession(e);
    return null;
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final String e = email.trim().toLowerCase();
    final Map<String, dynamic>? acct =
        _accounts[e] as Map<String, dynamic>?;
    if (acct == null) return 'No account found with this email.';
    final String salt = acct['salt'] as String? ?? '';
    if (_hash(salt, password) != acct['hash']) {
      return 'Incorrect email or password.';
    }
    await _startSession(e);
    return null;
  }

  /// Starts an instant session with just a display name — no password. Perfect
  /// for jumping straight into the game and sharing with friends.
  Future<String?> signInAsGuest(String displayName) async {
    final String name =
        displayName.trim().isEmpty ? 'Player' : displayName.trim();
    final String id = 'guest_${DateTime.now().millisecondsSinceEpoch}@local';
    _accounts[id] = <String, dynamic>{
      'displayName': name,
      'salt': '',
      'hash': '',
      'guest': true,
    };
    await _persistAccounts();
    await _startSession(id);
    return null;
  }

  Future<void> signOut() async {
    try {
      await _prefs?.remove(_sessionKey);
    } catch (_) {}
    currentUserNotifier.value = null;
  }

  // ---------------------------------------------------------------------------

  Future<void> _startSession(String email) async {
    try {
      await _prefs?.setString(_sessionKey, email);
    } catch (_) {}
    currentUserNotifier.value = _userFrom(email);
  }

  Future<void> _persistAccounts() async {
    try {
      await _prefs?.setString(_accountsKey, jsonEncode(_accounts));
    } catch (e) {
      debugPrint('LocalAuthService._persistAccounts: $e');
    }
  }

  LocalUser _userFrom(String email) {
    final Map<String, dynamic> acct =
        (_accounts[email] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return LocalUser(
      email: email,
      displayName: acct['displayName'] as String? ?? 'Player',
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _newSalt() {
    final Random rnd = Random();
    final List<int> bytes =
        List<int>.generate(12, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// FNV-1a 32-bit hash with a few extra rounds. Kept to 32-bit math so it is
  /// identical on web (JS) and native. Local-only obfuscation, not real crypto.
  String _hash(String salt, String password) {
    final List<int> data = utf8.encode('$salt::$password::chicken-hunter');
    int hash = 0x811c9dc5;
    for (int round = 0; round < 3; round++) {
      for (final int b in data) {
        hash ^= b;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
    }
    return hash.toRadixString(16);
  }
}
