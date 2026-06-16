import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CoinRequest {
  const CoinRequest({
    required this.id,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.requestedAmount,
    required this.message,
    required this.status,
    required this.createdAt,
    this.adminNote,
    this.approvedAmount,
  });

  final String id;
  final String uid;
  final String email;
  final String displayName;
  final int requestedAmount;
  final String message;
  final String status; // pending | approved | rejected
  final DateTime createdAt;
  final String? adminNote;
  final int? approvedAmount;

  factory CoinRequest.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data()!;
    return CoinRequest(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Player',
      requestedAmount: (data['requestedAmount'] as num?)?.toInt() ?? 0,
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminNote: data['adminNote'] as String?,
      approvedAmount: (data['approvedAmount'] as num?)?.toInt(),
    );
  }
}

class CoinRequestService {
  CoinRequestService._();
  static final CoinRequestService instance = CoinRequestService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('coin_requests');

  Future<String?> submitRequest({
    required String uid,
    required String email,
    required String displayName,
    required int amount,
    String message = '',
  }) async {
    try {
      // Only one pending request at a time per user.
      final QuerySnapshot<Map<String, dynamic>> existing = await _col
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return 'You already have a pending request. '
            'Please wait for the admin to process it.';
      }

      await _col.add(<String, dynamic>{
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'requestedAmount': amount,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'adminNote': null,
        'approvedAmount': null,
      });
      return null;
    } catch (e) {
      debugPrint('CoinRequestService.submitRequest: $e');
      return 'Failed to submit request. Please try again.';
    }
  }

  Stream<List<CoinRequest>> listenPendingRequests() {
    // Sort client-side (oldest first) to avoid needing a Firestore composite
    // index on (status, createdAt).
    return _col
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<CoinRequest> list =
          snap.docs.map(CoinRequest.fromDoc).toList();
      list.sort((CoinRequest a, CoinRequest b) =>
          a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Stream<List<CoinRequest>> listenMyRequests(String uid) {
    // Sort client-side (newest first) to avoid needing a Firestore composite
    // index on (uid, createdAt).
    return _col
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<CoinRequest> list =
          snap.docs.map(CoinRequest.fromDoc).toList();
      list.sort((CoinRequest a, CoinRequest b) =>
          b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String?> approveRequest({
    required String requestId,
    required String targetUid,
    required int coinsToSend,
    required String adminUid,
  }) async {
    try {
      final WriteBatch batch = _db.batch();

      batch.update(_col.doc(requestId), <String, dynamic>{
        'status': 'approved',
        'approvedAmount': coinsToSend,
        'processedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        _db.collection('saves').doc(targetUid),
        <String, dynamic>{
          'coins': FieldValue.increment(coinsToSend),
          'lastSyncedMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );

      batch.set(
        _db.collection('saves').doc(adminUid),
        <String, dynamic>{
          'coins': FieldValue.increment(-coinsToSend),
          'lastSyncedMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('CoinRequestService.approveRequest: $e');
      return 'Failed to send coins. Please try again.';
    }
  }

  Future<String?> rejectRequest({
    required String requestId,
    String adminNote = '',
  }) async {
    try {
      await _col.doc(requestId).update(<String, dynamic>{
        'status': 'rejected',
        'adminNote': adminNote,
        'processedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('CoinRequestService.rejectRequest: $e');
      return 'Failed to reject request.';
    }
  }

  /// Send coins directly to a user by UID (admin-initiated, no request needed).
  Future<String?> sendCoinsToUser({
    required String targetUid,
    required int amount,
    required String adminUid,
  }) async {
    try {
      final WriteBatch batch = _db.batch();

      batch.set(
        _db.collection('saves').doc(targetUid),
        <String, dynamic>{
          'coins': FieldValue.increment(amount),
          'lastSyncedMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );

      batch.set(
        _db.collection('saves').doc(adminUid),
        <String, dynamic>{
          'coins': FieldValue.increment(-amount),
          'lastSyncedMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('CoinRequestService.sendCoinsToUser: $e');
      return 'Failed to send coins.';
    }
  }

  /// Find a user's UID by email via the user_profiles collection.
  Future<String?> findUidByEmail(String email) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> q = await _db
          .collection('user_profiles')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return q.docs.first.id;
    } catch (e) {
      debugPrint('CoinRequestService.findUidByEmail: $e');
      return null;
    }
  }
}
