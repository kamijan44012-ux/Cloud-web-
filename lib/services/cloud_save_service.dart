import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/game_config.dart';
import '../models/player_data.dart';

/// Cloud save + anonymous auth. Signs the player in anonymously (upgradeable to
/// Google later), then reads/writes their PlayerData document in Firestore.
/// Conflict resolution is last-write-wins by `lastSyncedMs`.
class CloudSaveService {
  CloudSaveService._();
  static final CloudSaveService instance = CloudSaveService._();

  String? _uid;
  String? get uid => _uid;

  Future<void> signInAnonymously() async {
    if (!GameConfig.enableFirebase) return;
    try {
      final UserCredential cred = await FirebaseAuth.instance.signInAnonymously();
      _uid = cred.user?.uid;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  DocumentReference<Map<String, dynamic>>? get _doc =>
      _uid == null ? null : FirebaseFirestore.instance.collection('saves').doc(_uid);

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
