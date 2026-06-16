import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/pvp_match.dart';

/// Firestore-backed service for PvP room management and real-time game state
/// synchronisation. Both players write their own position/health to a shared
/// state document so neither side owns the other's data.
class PvpService {
  PvpService._();
  static final PvpService instance = PvpService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _rng = Random();

  String _generateCode() => (100000 + _rng.nextInt(900000)).toString();

  DocumentReference<Map<String, dynamic>> _roomRef(String code) =>
      _db.collection('pvp_rooms').doc(code);

  DocumentReference<Map<String, dynamic>> _stateRef(String code) =>
      _db.collection('pvp_rooms').doc(code).collection('game').doc('state');

  Future<String> createRoom({
    required String uid,
    required String name,
    required String shipId,
  }) async {
    final String code = _generateCode();
    await _roomRef(code).set(<String, dynamic>{
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
    await _stateRef(code).set(<String, dynamic>{
      'h_x': 270.0,
      'h_y': 760.0,
      'h_hp': 100.0,
      'g_x': 270.0,
      'g_y': 760.0,
      'g_hp': 100.0,
      'h_fired': 0,
      'g_fired': 0,
    });
    return code;
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> joinRoom({
    required String code,
    required String uid,
    required String name,
    required String shipId,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _roomRef(code);
    try {
      String? error;
      await _db.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        if (!snap.exists) {
          error = 'Room not found';
          return;
        }
        final Map<String, dynamic> d = snap.data()!;
        if (d['guestUid'] != null) {
          error = 'Room is full';
          return;
        }
        if (d['status'] != 'waiting') {
          error = 'Game already started';
          return;
        }
        tx.update(ref, <String, dynamic>{
          'guestUid': uid,
          'guestName': name,
          'guestShipId': shipId,
          'status': 'playing',
        });
      });
      return error;
    } catch (e) {
      debugPrint('PvpService.joinRoom: $e');
      return 'Failed to join. Check your connection.';
    }
  }

  Stream<PvpRoom?> listenToRoom(String code) =>
      _roomRef(code).snapshots().map((DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists) return null;
        return PvpRoom.fromMap(snap.data()!, code);
      });

  Stream<Map<String, dynamic>> listenToGameState(String code) =>
      _stateRef(code).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> snap) =>
              snap.data() ?? <String, dynamic>{});

  Future<void> updatePosition({
    required String code,
    required bool isHost,
    required double x,
    required double y,
  }) async {
    final String p = isHost ? 'h' : 'g';
    try {
      await _stateRef(code)
          .set(<String, dynamic>{'${p}_x': x, '${p}_y': y}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> incrementBulletCount({
    required String code,
    required bool isHost,
  }) async {
    final String p = isHost ? 'h' : 'g';
    try {
      await _stateRef(code).update(<String, dynamic>{'${p}_fired': FieldValue.increment(1)});
    } catch (_) {}
  }

  /// Writes both my health and opponent's health in one call to reduce writes.
  Future<void> syncHealth({
    required String code,
    required bool isHost,
    required double myHealth,
    required double opponentHealth,
  }) async {
    final String my = isHost ? 'h' : 'g';
    final String opp = isHost ? 'g' : 'h';
    try {
      await _stateRef(code).set(<String, dynamic>{
        '${my}_hp': myHealth,
        '${opp}_hp': opponentHealth,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> endMatch({required String code, required String winner}) async {
    try {
      await _roomRef(code).update(<String, dynamic>{
        'status': 'finished',
        'winner': winner,
      });
    } catch (_) {}
  }

  Future<void> deleteRoom(String code) async {
    try {
      await _stateRef(code).delete();
      await _roomRef(code).delete();
    } catch (_) {}
  }
}
