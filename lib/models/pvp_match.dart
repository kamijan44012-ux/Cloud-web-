enum PvpStatus { waiting, playing, finished }

class PvpRoom {
  const PvpRoom({
    required this.code,
    required this.hostUid,
    required this.hostName,
    required this.hostShipId,
    this.guestUid,
    this.guestName,
    this.guestShipId,
    required this.status,
    this.winner,
  });

  final String code;
  final String hostUid;
  final String hostName;
  final String hostShipId;
  final String? guestUid;
  final String? guestName;
  final String? guestShipId;
  final PvpStatus status;
  final String? winner; // 'host' or 'guest'

  bool get isFull => guestUid != null;

  factory PvpRoom.fromMap(Map<String, dynamic> data, String code) => PvpRoom(
        code: code,
        hostUid: data['hostUid'] as String? ?? '',
        hostName: data['hostName'] as String? ?? 'Pilot',
        hostShipId: data['hostShipId'] as String? ?? 'falcon',
        guestUid: data['guestUid'] as String?,
        guestName: data['guestName'] as String?,
        guestShipId: data['guestShipId'] as String?,
        status: _statusFrom(data['status'] as String? ?? 'waiting'),
        winner: data['winner'] as String?,
      );

  static PvpStatus _statusFrom(String s) {
    switch (s) {
      case 'playing':
        return PvpStatus.playing;
      case 'finished':
        return PvpStatus.finished;
      default:
        return PvpStatus.waiting;
    }
  }
}
