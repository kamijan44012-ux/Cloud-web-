import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../systems/player_controller.dart';

/// Friend-invite / referral system. Each player gets a short code and an invite
/// link. When a brand-new player signs up through someone's link, both the
/// inviter and the new player are rewarded with coins (one time per new player).
class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  static const int inviterBonus = 1000;
  static const int newUserBonus = 500;
  static const String baseUrl =
      'https://kamijan44012-ux.github.io/Cloud-web-/';

  /// Captured from the invite link (`#ref=CODE`) when the app opened.
  String? pendingRefCode;

  /// The signed-in player's own code and how many friends they've brought in.
  final ValueNotifier<String?> myCode = ValueNotifier<String?>(null);
  final ValueNotifier<int> referralCount = ValueNotifier<int>(0);

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String inviteLink(String code) => '$baseUrl#ref=$code';

  String _codeForUid(String uid) {
    int h = 0;
    for (final int c in uid.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 6; i++) {
      sb.write(_alphabet[h % _alphabet.length]);
      h = (h ~/ _alphabet.length) + (i + 1) * 17 + uid.length;
    }
    return sb.toString();
  }

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');
  CollectionReference<Map<String, dynamic>> get _codes =>
      FirebaseFirestore.instance.collection('ref_codes');
  CollectionReference<Map<String, dynamic>> get _saves =>
      FirebaseFirestore.instance.collection('saves');

  /// Ensures the signed-in player has a referral code registered, then loads
  /// their current invite stats. Safe to call on every sign-in.
  Future<void> ensureMyCode(String uid) async {
    if (!GameConfig.enableFirebase) return;
    try {
      final DocumentSnapshot<Map<String, dynamic>> prof =
          await _profiles.doc(uid).get();
      String? code = prof.data()?['refCode'] as String?;
      code ??= _codeForUid(uid);
      await _profiles.doc(uid).set(<String, dynamic>{'refCode': code},
          SetOptions(merge: true));
      await _codes.doc(code).set(<String, dynamic>{'uid': uid},
          SetOptions(merge: true));
      myCode.value = code;
      referralCount.value =
          (prof.data()?['referralCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('ReferralService.ensureMyCode: $e');
    }
  }

  /// Applies a pending invite for a newly verified player. Grants coins to both
  /// the new player and the inviter exactly once.
  Future<int> applyPendingReferral(String uid, PlayerController player) async {
    final String? code = pendingRefCode;
    if (!GameConfig.enableFirebase || code == null || code.isEmpty) return 0;
    try {
      final DocumentSnapshot<Map<String, dynamic>> prof =
          await _profiles.doc(uid).get();
      // Already credited, or this player used a link before — don't double pay.
      if ((prof.data()?['referredBy'] as String?)?.isNotEmpty ?? false) {
        pendingRefCode = null;
        return 0;
      }
      final DocumentSnapshot<Map<String, dynamic>> codeDoc =
          await _codes.doc(code).get();
      final String? inviterUid = codeDoc.data()?['uid'] as String?;
      // Invalid code or self-invite — ignore quietly.
      if (inviterUid == null || inviterUid == uid) {
        pendingRefCode = null;
        return 0;
      }

      // Mark this player as referred so the bonus can't be claimed twice.
      await _profiles.doc(uid).set(<String, dynamic>{'referredBy': code},
          SetOptions(merge: true));

      // Reward the inviter (cloud-side; merges into their save next sync).
      await _saves.doc(inviterUid).set(<String, dynamic>{
        'coins': FieldValue.increment(inviterBonus),
        'lastSyncedMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      await _profiles.doc(inviterUid).set(
          <String, dynamic>{'referralCount': FieldValue.increment(1)},
          SetOptions(merge: true));

      // Reward the new player locally so they see it immediately, then push.
      player.addCoins(newUserBonus);
      pendingRefCode = null;
      return newUserBonus;
    } catch (e) {
      debugPrint('ReferralService.applyPendingReferral: $e');
      return 0;
    }
  }
}
