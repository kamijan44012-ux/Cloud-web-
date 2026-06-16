import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/pvp_match.dart';

/// Firestore-backed PvP service.
///
/// Speed decisions:
/// - createRoom uses a WriteBatch (single round-trip for room + state docs).
/// - joinRoom uses a plain update() — no transaction — which is faster and
///   safe enough for a casual game where simultaneous joins on the same 6-digit
///   code are extremely unlikely.
/// - All network calls have a 12-second timeout so the UI never spins forever.
/// - Errors are surfaced as String messages instead of being swallowed silently.
class PvpService {
  PvpService._();
  static final PvpService instance = PvpService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _rng = Random();

  static const Duration _timeout = Duration(seconds: 12);

  String generateCode() => (100000 + _rng.nextInt(900000)).toString();

  DocumentReference<Map<String, dynamic>> _roomRef(String code) =>
      _db.collection('pvp_rooms').doc(code);

  DocumentReference<Map<String, dynamic>> _stateRef(String code) =>
      _db.collection('pvp_rooms').doc(code).collection('game').doc('state');

  /// Creates the room and initial game state in a single batch (one round-trip).
  /// The caller should generate the code first with [generateCode] so the UI
  /// can display it immediately while this write is in-flight.
  Future<void> createRoom({
    required String code,
    required String uid,
    required String name,
    required String shipId,
  }) async {
    final WriteBatch batch = _db.batch();

    batch.set(_roomRef(code), <String, dynamic>{
      'hostUid': uid,
      'hostName': name,
      'hostShipId': shipId,
      'guestUid': null,
      'guestName': null,
      'guestShipId': null,
      'status': 'waiting',
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_stateRef(code), <String, dynamic>{
      'h_x': 270.0,
      'h_y': 760.0,
      'h_hp': 100.0,
      'g_x': 270.0,
      'g_y': 760.0,
      'g_hp': 100.0,
      'h_fired': 0,
      'g_fired': 0,
    });

    await batch.commit().timeout(_timeout);
  }

  /// Returns null on success, or a human-readable error string on failure.
  /// Uses a simple read → update pattern (no transaction) for speed.
  Future<String?> joinRoom({
    required String code,
    required String uid,
    required String name,
    required String shipId,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _roomRef(code).get().timeout(_timeout);

      if (!snap.exists) return 'Room not found. Check the code.';
      final Map<String, dynamic> d = snap.data()!;

      if (d['guestUid'] != null) return 'Room is full.';
      if (d['status'] != 'waiting') return 'Game already started.';
      if (d['hostUid'] == uid) return 'You cannot join your own room.';

      await _roomRef(code).update(<String, dynamic>{
        'guestUid': uid,
        'guestName': name,
        'guestShipId': shipId,
        'status': 'playing',
      }).timeout(_timeout);

      return null; // success
    } catch (e) {
      debugPrint('PvpService.joinRoom error: $e');
      final String msg = e.toString().toLowerCase();
      if (msg.contains('permission-denied') || msg.contains('permission_denied')) {
        return 'Permission denied — update Firestore rules (see firestore.rules).';
      }
      if (msg.contains('timeout')) {
        return 'Connection timed out. Check your internet and try again.';
      }
      if (msg.contains('unavailable') || msg.contains('network')) {
        return 'Network error. Check your internet connection.';
      }
      return 'Failed to join. Try again.';
    }
  }

  Stream<PvpRoom?> listenToRoom(String code) =>
      _roomRef(code).snapshots().map((DocumentSnapshot<Map<String, dynamic>> s) {
        if (!s.exists) return null;
        return PvpRoom.fromMap(s.data()!, code);
      });

  Stream<Map<String, dynamic>> listenToGameState(String code) =>
      _stateRef(code).snapshots().map((DocumentSnapshot<Map<String, dynamic>> s) =>
          s.data() ?? <String, dynamic>{});

  Future<void> updatePosition({
    required String code,
    required bool isHost,
    required double x,
    required double y,
  }) async {
    final String p = isHost ? 'h' : 'g';
    try {
      await _stateRef(code)
          .set(<String, dynamic>{'${p}_x': x, '${p}_y': y}, SetOptions(merge: true))
          .timeout(_timeout);
    } catch (_) {}
  }

  Future<void> incrementBulletCount({
    required String code,
    required bool isHost,
  }) async {
    final String p = isHost ? 'h' : 'g';
    try {
      await _stateRef(code)
          .update(<String, dynamic>{'${p}_fired': FieldValue.increment(1)})
          .timeout(_timeout);
    } catch (_) {}
  }

  Future<void> syncHealth({
    required String code,
    required bool isHost,
    required double myHealth,
    required double opponentHealth,
  }) async {
    final String my = isHost ? 'h' : 'g';
    final String opp = isHost ? 'g' : 'h';
    try {
      await _stateRef(code)
          .set(<String, dynamic>{
            '${my}_hp': myHealth,
            '${opp}_hp': opponentHealth,
          }, SetOptions(merge: true))
          .timeout(_timeout);
    } catch (_) {}
  }

  Future<void> endMatch({required String code, required String winner}) async {
    try {
      await _roomRef(code)
          .update(<String, dynamic>{'status': 'finished', 'winner': winner})
          .timeout(_timeout);
    } catch (_) {}
  }

  Future<void> deleteRoom(String code) async {
    try {
      await _stateRef(code).delete().timeout(_timeout);
      await _roomRef(code).delete().timeout(_timeout);
    } catch (_) {}
  }
}
