import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/game_config.dart';
import 'auth_service.dart';

/// Stores the player's chosen avatar (a preset, no photo upload required) and
/// keeps the display name in one place. Persists locally for everyone and
/// mirrors to Firestore `user_profiles` for signed-in cloud accounts so the
/// avatar follows the player across devices.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  /// Space-themed preset avatars. Index into this list is what we persist.
  static const List<String> avatars = <String>[
    '🐔', '🚀', '👾', '🛸', '🤖', '👽', '⭐', '🔥',
    '🐲', '🦅', '🦊', '🐺', '🦁', '🐯', '🦖', '💀',
    '😎', '🥷', '👑', '⚡', '🌟', '🪐', '☄️', '🎯',
  ];

  static const String _avatarKey = 'profile_avatar_index';

  final ValueNotifier<int> avatarIndex = ValueNotifier<int>(0);

  SharedPreferences? _prefs;

  String get currentEmoji => avatars[avatarIndex.value % avatars.length];

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      avatarIndex.value = _prefs!.getInt(_avatarKey) ?? 0;
    } catch (e) {
      debugPrint('ProfileService.load: $e');
    }
  }

  /// Pull the avatar saved in the cloud for this user (call after sign-in).
  Future<void> syncFromCloud(String uid) async {
    if (!GameConfig.enableFirebase) return;
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(uid)
              .get();
      final int? idx = (snap.data()?['avatarIndex'] as num?)?.toInt();
      if (idx != null) {
        avatarIndex.value = idx % avatars.length;
        await _prefs?.setInt(_avatarKey, avatarIndex.value);
      }
    } catch (e) {
      debugPrint('ProfileService.syncFromCloud: $e');
    }
  }

  Future<void> setAvatar(int index) async {
    final int idx = index % avatars.length;
    avatarIndex.value = idx;
    try {
      await _prefs?.setInt(_avatarKey, idx);
    } catch (_) {}
    // Mirror to the cloud profile so it follows the player across devices.
    final String? uid = AuthService.instance.currentUid;
    if (GameConfig.enableFirebase &&
        AuthService.instance.isCloudEnabled &&
        uid != null &&
        !(AuthService.instance.currentAppUser?.isLocal ?? true)) {
      try {
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(uid)
            .set(<String, dynamic>{'avatarIndex': idx},
                SetOptions(merge: true));
      } catch (e) {
        debugPrint('ProfileService.setAvatar cloud: $e');
      }
    }
  }
}
