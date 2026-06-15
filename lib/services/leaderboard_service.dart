import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/game_config.dart';
import 'cloud_save_service.dart';

class LeaderboardEntry {
  const LeaderboardEntry(this.name, this.score, this.wave);
  final String name;
  final int score;
  final int wave;
}

/// Simple global high-score leaderboard backed by Firestore. For a real launch
/// you'd guard writes with security rules / server validation to stop score
/// injection; this is the client half.
class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('leaderboard');

  Future<void> submit({required String name, required int score, required int wave}) async {
    if (!GameConfig.enableFirebase) return;
    final String? uid = CloudSaveService.instance.uid;
    if (uid == null) return;
    try {
      await _col.doc(uid).set(<String, dynamic>{
        'name': name,
        'score': score,
        'wave': wave,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Leaderboard submit failed: $e');
    }
  }

  Future<List<LeaderboardEntry>> top({int limit = 50}) async {
    if (!GameConfig.enableFirebase) return _mock();
    try {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _col.orderBy('score', descending: true).limit(limit).get();
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => LeaderboardEntry(
                (d.data()['name'] ?? 'Pilot') as String,
                (d.data()['score'] ?? 0) as int,
                (d.data()['wave'] ?? 0) as int,
              ))
          .toList();
    } catch (e) {
      debugPrint('Leaderboard fetch failed: $e');
      return _mock();
    }
  }

  /// Offline / pre-Firebase placeholder so the leaderboard screen still renders.
  List<LeaderboardEntry> _mock() => const <LeaderboardEntry>[
        LeaderboardEntry('AceHunter', 184200, 42),
        LeaderboardEntry('ChickenSlayer', 151000, 38),
        LeaderboardEntry('NovaPilot', 132500, 35),
        LeaderboardEntry('You', 0, 0),
      ];
}
