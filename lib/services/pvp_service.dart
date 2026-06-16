import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/pvp_match.dart';

/// Real-time PvP service backed by PubNub's free demo tier.
///
/// No Firebase / API key required — works out of the box on web and mobile.
/// PubNub demo keys are shared globally; 6-digit room codes keep collisions
/// extremely unlikely for casual games.
///
/// Channels used:
///   pvp_r_{code} — room lifecycle (heartbeat, join, start, end)
///   pvp_s_{code} — game state (position, health, bullets)
class PvpService {
  PvpService._();
  static final PvpService instance = PvpService._();

  static const String _pk = 'demo';
  static const String _sk = 'demo';
  static const String _base = 'https://ps.pndsn.com';

  final Random _rng = Random();

  // Unique ID for this client session
  final String _uuid = List<String>.generate(
    6,
    (_) => Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'),
  ).join();

  String generateCode() => (100000 + _rng.nextInt(900000)).toString();

  String _roomCh(String code) => 'pvp_r_$code';
  String _stateCh(String code) => 'pvp_s_$code';

  // ---------------------------------------------------------------------------
  // Low-level PubNub REST helpers
  // ---------------------------------------------------------------------------

  Future<void> _publish(String channel, Map<String, dynamic> data) async {
    try {
      final String encoded = Uri.encodeComponent(jsonEncode(data));
      await http
          .get(Uri.parse(
              '$_base/publish/$_pk/$_sk/0/$channel/0/$encoded?uuid=$_uuid'))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('PvP publish error: $e');
    }
  }

  /// Long-poll subscribe — yields messages as they arrive, reconnects on error.
  Stream<Map<String, dynamic>> _subscribe(String channel) async* {
    String tt = '0';
    while (true) {
      try {
        final response = await http
            .get(Uri.parse(
                '$_base/v2/subscribe/$_sk/$channel/0?tt=$tt&uuid=$_uuid'))
            .timeout(const Duration(seconds: 310));

        if (response.statusCode == 200) {
          final body =
              jsonDecode(response.body) as Map<String, dynamic>;
          tt = (body['t'] as Map<String, dynamic>)['t'].toString();
          final List<dynamic> msgs =
              (body['m'] as List<dynamic>?) ?? <dynamic>[];
          for (final m in msgs) {
            final dynamic d = (m as Map<String, dynamic>)['d'];
            if (d is Map<String, dynamic>) yield d;
          }
        }
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // In-memory state (survives the browser session)
  // ---------------------------------------------------------------------------

  final Map<String, Map<String, dynamic>> _rooms = <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> _gameStates = <String, Map<String, dynamic>>{};
  final Map<String, Timer?> _heartbeats = <String, Timer?>{};

  // ---------------------------------------------------------------------------
  // Room lifecycle
  // ---------------------------------------------------------------------------

  /// Creates the room and starts broadcasting a heartbeat so the guest can
  /// discover it without Firebase.
  Future<void> createRoom({
    required String code,
    required String uid,
    required String name,
    required String shipId,
    required int wagerAmount,
  }) async {
    final Map<String, dynamic> room = <String, dynamic>{
      'hostUid': uid,
      'hostName': name,
      'hostShipId': shipId,
      'guestUid': null,
      'guestName': null,
      'guestShipId': null,
      'status': 'waiting',
      'winner': null,
      'wagerAmount': wagerAmount,
    };
    _rooms[code] = room;

    // Publish once immediately, then every 2 s so the guest can find it.
    await _publish(_roomCh(code), <String, dynamic>{'t': 'room', ...room});
    _heartbeats[code]?.cancel();
    _heartbeats[code] = Timer.periodic(const Duration(seconds: 2), (_) {
      final Map<String, dynamic>? current = _rooms[code];
      if (current != null) {
        _publish(_roomCh(code), <String, dynamic>{'t': 'room', ...current});
      }
    });
  }

  /// Publishes a join request.  Returns null on success or an error string.
  Future<String?> joinRoom({
    required String code,
    required String uid,
    required String name,
    required String shipId,
  }) async {
    final Map<String, dynamic>? room = _rooms[code];
    if (room != null) {
      if (room['guestUid'] != null) return 'Room is full.';
      if (room['status'] != 'waiting') return 'Game already started.';
      if (room['hostUid'] == uid) return 'You cannot join your own room.';
    }
    await _publish(_roomCh(code), <String, dynamic>{
      't': 'join',
      'guestUid': uid,
      'guestName': name,
      'guestShipId': shipId,
    });
    return null;
  }

  Stream<PvpRoom?> listenToRoom(String code) {
    // ignore: close_sinks
    late StreamController<PvpRoom?> ctrl;
    StreamSubscription<Map<String, dynamic>>? sub;

    ctrl = StreamController<PvpRoom?>(
      onListen: () {
        sub = _subscribe(_roomCh(code)).listen((Map<String, dynamic> msg) {
          final String t = msg['t'] as String? ?? '';
          Map<String, dynamic> room =
              _rooms[code] ?? <String, dynamic>{};

          if (t == 'room') {
            // Heartbeat from host — update local cache
            room = Map<String, dynamic>.from(msg)..remove('t');
            _rooms[code] = room;
            ctrl.add(PvpRoom.fromMap(room, code));
          } else if (t == 'join') {
            // Host side: guest requests to join
            if (room['hostUid'] != null &&
                room['status'] == 'waiting') {
              room['guestUid'] = msg['guestUid'];
              room['guestName'] = msg['guestName'];
              room['guestShipId'] = msg['guestShipId'];
              room['status'] = 'playing';
              _rooms[code] = room;
              // Confirm start to both players
              _publish(_roomCh(code),
                  <String, dynamic>{'t': 'start', ...room});
              ctrl.add(PvpRoom.fromMap(room, code));
            }
          } else if (t == 'start') {
            // Guest side: host confirmed the match
            final Map<String, dynamic> started =
                Map<String, dynamic>.from(msg)..remove('t');
            started['status'] = 'playing';
            _rooms[code] = started;
            ctrl.add(PvpRoom.fromMap(started, code));
          } else if (t == 'end') {
            final Map<String, dynamic> ended =
                Map<String, dynamic>.from(_rooms[code] ?? <String, dynamic>{});
            ended['status'] = 'finished';
            ended['winner'] = msg['winner'] as String?;
            _rooms[code] = ended;
            ctrl.add(PvpRoom.fromMap(ended, code));
          }
        });

        // Emit current state immediately if already known
        final Map<String, dynamic>? cached = _rooms[code];
        if (cached != null) {
          ctrl.add(PvpRoom.fromMap(cached, code));
        }
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return ctrl.stream;
  }

  // ---------------------------------------------------------------------------
  // Game state
  // ---------------------------------------------------------------------------

  Stream<Map<String, dynamic>> listenToGameState(String code) {
    // Accumulate partial updates into a running state map.
    _gameStates[code] = _gameStates[code] ??
        <String, dynamic>{
          'h_x': 270.0,
          'h_y': 760.0,
          'h_hp': 100.0,
          'g_x': 270.0,
          'g_y': 760.0,
          'g_hp': 100.0,
          'h_fired': 0,
          'g_fired': 0,
        };

    // ignore: close_sinks
    late StreamController<Map<String, dynamic>> ctrl;
    StreamSubscription<Map<String, dynamic>>? sub;

    ctrl = StreamController<Map<String, dynamic>>(
      onListen: () {
        sub = _subscribe(_stateCh(code)).listen((Map<String, dynamic> msg) {
          final String t = msg['t'] as String? ?? '';
          final Map<String, dynamic> state =
              _gameStates[code] ?? <String, dynamic>{};

          if (t == 'state') {
            // Merge partial update
            msg.forEach((String k, dynamic v) {
              if (k != 't') state[k] = v;
            });
            _gameStates[code] = state;
            ctrl.add(Map<String, dynamic>.from(state));
          } else if (t == 'fire') {
            final String? who = msg['who'] as String?;
            if (who != null) {
              final int prev =
                  (state['${who}_fired'] as int?) ?? 0;
              state['${who}_fired'] = prev + 1;
            }
            _gameStates[code] = state;
            ctrl.add(Map<String, dynamic>.from(state));
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return ctrl.stream;
  }

  Future<void> updatePosition({
    required String code,
    required bool isHost,
    required double x,
    required double y,
  }) async {
    final String p = isHost ? 'h' : 'g';
    await _publish(_stateCh(code), <String, dynamic>{
      't': 'state',
      '${p}_x': x,
      '${p}_y': y,
    });
  }

  Future<void> incrementBulletCount({
    required String code,
    required bool isHost,
  }) async {
    final String p = isHost ? 'h' : 'g';
    await _publish(_stateCh(code), <String, dynamic>{'t': 'fire', 'who': p});
  }

  Future<void> syncHealth({
    required String code,
    required bool isHost,
    required double myHealth,
    required double opponentHealth,
  }) async {
    final String my = isHost ? 'h' : 'g';
    final String opp = isHost ? 'g' : 'h';
    await _publish(_stateCh(code), <String, dynamic>{
      't': 'state',
      '${my}_hp': myHealth,
      '${opp}_hp': opponentHealth,
    });
  }

  Future<void> endMatch({
    required String code,
    required String winner,
  }) async {
    _heartbeats[code]?.cancel();
    _heartbeats.remove(code);
    await _publish(_roomCh(code), <String, dynamic>{'t': 'end', 'winner': winner});
  }

  Future<void> deleteRoom(String code) async {
    _heartbeats[code]?.cancel();
    _heartbeats.remove(code);
    _rooms.remove(code);
    _gameStates.remove(code);
  }
}
