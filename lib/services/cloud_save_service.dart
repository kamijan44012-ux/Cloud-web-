import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../models/player_data.dart';
import 'auth_service.dart';

/// Cloud save backed by Firestore. Auth is handled by [AuthService]; this
/// service just reads/writes the player's save doc and user profile.
/// Conflict resolution is last-write-wins by `lastSyncedMs`.
class CloudSaveService {
  CloudSaveService._();
  static final CloudSaveService instance = CloudSaveService._();

  String? _uid;
  String? get uid => _uid;

  DocumentReference<Map<String, dynamic>>? get _doc =>
      _uid == null
          ? null
          : FirebaseFirestore.instance.collection('saves').doc(_uid);

  /// Called after a successful Firebase Auth sign-in.
  Future<void> setUser(
    String uid, {
    String? email,
    String? displayName,
  }) async {
    if (!GameConfig.enableFirebase) return;
    _uid = uid;
    try {
      // Store/update the user profile so admin can look up by email.
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(uid)
          .set(
        <String, dynamic>{
          'uid': uid,
          'email': (email ?? '').toLowerCase(),
          'displayName': displayName ?? 'Player',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Ensure admin account has the initial 2 M coins on first login.
      if (email?.toLowerCase() == AuthService.adminEmail.toLowerCase()) {
        final DocumentSnapshot<Map<String, dynamic>> snap =
            await FirebaseFirestore.instance
                .collection('saves')
                .doc(uid)
                .get();
        final int existing =
            (snap.data()?['coins'] as num?)?.toInt() ?? 0;
        if (!snap.exists || existing < AuthService.adminInitialCoins) {
          await FirebaseFirestore.instance
              .collection('saves')
              .doc(uid)
              .set(
            <String, dynamic>{
              'coins': AuthService.adminInitialCoins,
              'lastSyncedMs': DateTime.now().millisecondsSinceEpoch,
            },
            SetOptions(merge: true),
          );
        }
      }
    } catch (e) {
      debugPrint('CloudSaveService.setUser: $e');
    }
  }

  Future<PlayerData?> pull() async {
    if (_doc == null) return null;
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _doc!.get();
      if (!snap.exists) return null;
      return PlayerData.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('Cloud pull failed: $e');
      return null;
    }
  }

  Future<void> push(PlayerData data) async {
    if (_doc == null) return;
    try {
      data.lastSyncedMs = DateTime.now().millisecondsSinceEpoch;
      await _doc!.set(data.toJson());
    } catch (e) {
      debugPrint('Cloud push failed: $e');
    }
  }
}
