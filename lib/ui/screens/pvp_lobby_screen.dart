import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../models/pvp_match.dart';
import '../../services/cloud_save_service.dart';
import '../../services/pvp_service.dart';
import '../../systems/player_controller.dart';
import '../widgets/space_background.dart';
import 'pvp_game_screen.dart';

class PvpLobbyScreen extends StatefulWidget {
  const PvpLobbyScreen({super.key, this.initialJoinCode, this.mobileMode = false});

  /// When opened via a share link the room code arrives pre-filled.
  final String? initialJoinCode;

  /// Passed through to [PvpGameScreen] so the game uses the same display mode.
  final bool mobileMode;

  @override
  State<PvpLobbyScreen> createState() => _PvpLobbyScreenState();
}

class _PvpLobbyScreenState extends State<PvpLobbyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Create-tab state
  String? _roomCode;
  _CreateState _createState = _CreateState.idle;
  String? _createError;
  StreamSubscription<PvpRoom?>? _waitSub;
  int _wager = 0;

  // Join-tab state
  final TextEditingController _codeCtrl = TextEditingController();
  _JoinState _joinState = _JoinState.idle;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    final int initialTab = widget.initialJoinCode != null ? 1 : 0;
    _tabs = TabController(length: 2, vsync: this, initialIndex: initialTab);
    if (widget.initialJoinCode != null) {
      _codeCtrl.text = widget.initialJoinCode!;
    }
  }

  @override
  void dispose() {
    _waitSub?.cancel();
    _tabs.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Identity helpers
  // ---------------------------------------------------------------------------
  String _myUid() {
    final String? uid = CloudSaveService.instance.uid;
    return uid ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _myName() {
    final String uid = _myUid();
    final String suffix = uid.length >= 6
        ? uid.substring(uid.length - 6).toUpperCase()
        : uid.toUpperCase();
    return 'Pilot_$suffix';
  }

  /// On web: builds a full invite URL with the room code in the URL fragment.
  /// On mobile: returns just the code (recipient opens the web app manually).
  String _inviteLink(String code) {
    if (kIsWeb) {
      final String base = Uri.base.removeFragment().toString();
      return '${base}#pvp=$code';
    }
    return code;
  }

  // ---------------------------------------------------------------------------
  // Create Match
  // ---------------------------------------------------------------------------
  Future<void> _createRoom(PlayerController player) async {
    if (_createState != _CreateState.idle) return;

    final String code = PvpService.instance.generateCode();
    // Show code + invite link IMMEDIATELY — user can copy it right now.
    setState(() {
      _roomCode = code;
      _createState = _CreateState.writing;
      _createError = null;
    });

    // Yield a frame so Flutter renders the code before doing any I/O.
    await Future<void>.delayed(Duration.zero);

    try {
      await PvpService.instance.createRoom(
        code: code,
        uid: _myUid(),
        name: _myName(),
        shipId: player.data.selectedShipId,
        wagerAmount: _wager,
      );
    } catch (e) {
      if (!mounted) return;
      // Keep _roomCode visible so user can still copy the link.
      // Show a snackbar explaining Firebase needs to be configured.
      setState(() => _createState = _CreateState.waiting);
      _snack(
        'Firebase not configured — set up Firestore to enable online play. '
        'You can still copy the invite link.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _createState = _CreateState.waiting);

    _waitSub?.cancel();
    _waitSub =
        PvpService.instance.listenToRoom(code).listen((PvpRoom? room) {
      if (room == null || !mounted) return;
      if (room.status == PvpStatus.playing) {
        _waitSub?.cancel();
        // Deduct host's wager now that match is confirmed
        if (_wager > 0) player.spendCoins(_wager);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PvpGameScreen(
              roomCode: code,
              isHost: true,
              opponentName: room.guestName ?? 'Opponent',
              opponentShipId: room.guestShipId ?? 'falcon',
              wagerAmount: _wager,
              mobileMode: widget.mobileMode,
            ),
          ),
        );
      }
    }, onError: (dynamic e) {
      if (!mounted) return;
      setState(() {
        _createState = _CreateState.idle;
        _roomCode = null;
        _createError = _friendlyError(e.toString());
      });
    });
  }

  void _cancelCreate() {
    _waitSub?.cancel();
    if (_roomCode != null) {
      PvpService.instance.deleteRoom(_roomCode!);
    }
    setState(() {
      _roomCode = null;
      _createState = _CreateState.idle;
      _createError = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Join Match
  // ---------------------------------------------------------------------------
  Future<void> _joinRoom(PlayerController player) async {
    if (_joinState != _JoinState.idle) return;
    final String code = _codeCtrl.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _joinError = 'Enter a valid 6-digit code.');
      return;
    }

    setState(() {
      _joinState = _JoinState.joining;
      _joinError = null;
    });

    // Peek at room details before committing — we need the wager amount.
    PvpRoom? room;
    try {
      room = await PvpService.instance
          .listenToRoom(code)
          .first
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _joinState = _JoinState.idle;
        _joinError = 'Connection timed out. Check your internet.';
      });
      return;
    }

    if (!mounted) return;

    if (room == null) {
      setState(() {
        _joinState = _JoinState.idle;
        _joinError = 'Room not found. Check the code.';
      });
      return;
    }

    final int wager = room.wagerAmount;

    if (wager > 0) {
      if (player.coins < wager) {
        setState(() {
          _joinState = _JoinState.idle;
          _joinError =
              'Not enough coins! You need $wager but have ${player.coins}.';
        });
        return;
      }

      // Show wager confirmation dialog.
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: Palette.spaceBottom,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: <Widget>[
              const Icon(Icons.monetization_on, color: Palette.coin, size: 24),
              const SizedBox(width: 8),
              Text(
                'Bet $wager Coins?',
                style: const TextStyle(
                  color: Palette.hudYellow,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _wagerRow('Host', room!.hostName),
              const SizedBox(height: 6),
              _wagerRow('Prize pool', '${wager * 2} coins'),
              _wagerRow('Your balance', '${player.coins} coins'),
              const SizedBox(height: 12),
              const Text(
                'Winner takes everything!',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.hudYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Accept & Join',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) {
        setState(() => _joinState = _JoinState.idle);
        return;
      }
    }

    final String? error = await PvpService.instance.joinRoom(
      code: code,
      uid: _myUid(),
      name: _myName(),
      shipId: player.data.selectedShipId,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _joinState = _JoinState.idle;
        _joinError = error;
      });
      return;
    }

    // Deduct guest's wager.
    if (wager > 0) player.spendCoins(wager);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PvpGameScreen(
          roomCode: code,
          isHost: false,
          opponentName: room!.hostName,
          opponentShipId: room.hostShipId,
          wagerAmount: wager,
          mobileMode: widget.mobileMode,
        ),
      ),
    );
  }

  Widget _wagerRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Text('$label: ',
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  String _friendlyError(String raw) {
    if (raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED')) {
      return 'Firebase rules error.\nGo to Firebase console → Firestore → Rules\nand paste the rules from firestore.rules file.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timeout')) {
      return 'Connection timed out. Check your internet.';
    }
    if (raw.contains('unavailable') || raw.contains('network')) {
      return 'No internet connection. Try again.';
    }
    return 'Error: $raw';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final PlayerController player = context.watch<PlayerController>();
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _header(player),
              TabBar(
                controller: _tabs,
                indicatorColor: Palette.hudYellow,
                labelColor: Palette.hudYellow,
                unselectedLabelColor: Colors.white60,
                dividerColor: Colors.white12,
                tabs: const <Widget>[
                  Tab(text: 'Create Match'),
                  Tab(text: 'Join Match'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: <Widget>[
                    _createTab(player),
                    _joinTab(player),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(PlayerController player) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                _cancelCreate();
                Navigator.pop(context);
              },
            ),
            const Expanded(
              child: Text(
                '⚔️  VS MODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            // Live coin balance
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.monetization_on, color: Palette.coin, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${player.coins}',
                  style: const TextStyle(
                      color: Palette.coin,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Create tab
  // ---------------------------------------------------------------------------
  Widget _createTab(PlayerController player) {
    if (_createError != null) {
      return _centeredPad(Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _createError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _btn(
            label: 'Try Again',
            icon: Icons.refresh,
            color: Palette.hudYellow,
            onTap: () => setState(() => _createError = null),
          ),
        ],
      ));
    }

    // Room code shown — waiting for opponent
    if (_roomCode != null) {
      final String link = _inviteLink(_roomCode!);
      return _centeredPad(Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Share with your friend:',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 15),
          ),
          const SizedBox(height: 16),
          // Room code card — tap to copy
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _roomCode!));
              _snack('Code copied!');
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: Palette.spaceBottom.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.hudYellow, width: 2.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Palette.hudYellow.withOpacity(0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _roomCode!,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Palette.hudYellow,
                      letterSpacing: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy, color: Palette.hudYellow, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Share link button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Copy Invite Link',
                style: TextStyle(fontSize: 13)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              _snack('Invite link copied! Send via WhatsApp or Messenger.');
            },
          ),
          const SizedBox(height: 10),
          // Wager badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Palette.coin.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.monetization_on,
                    color: Palette.coin, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Wager: $_wager  •  Prize: ${_wager * 2} coins',
                  style: const TextStyle(
                      color: Palette.coin, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_createState == _CreateState.writing)
            _statusRow(Colors.orange,
                const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.orange),
                'Saving room…')
          else
            _statusRow(Palette.hudGreen,
                const CircularProgressIndicator(
                    strokeWidth: 2, color: Palette.hudGreen),
                'Waiting for opponent…'),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _cancelCreate,
            icon: const Icon(Icons.close, color: Colors.redAccent),
            label: const Text('Cancel',
                style: TextStyle(color: Colors.redAccent, fontSize: 15)),
          ),
        ],
      ));
    }

    // Idle — wager picker then create button
    return _centeredPad(Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.sports_esports, size: 56, color: Colors.white24),
        const SizedBox(height: 18),
        const Text(
          'Choose your wager',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Winner takes both wagers',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(height: 20),
        // Wager chips — 0 = FREE
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: <int>[0, 10, 50, 100].map((int w) {
            final bool selected = _wager == w;
            final bool affordable = player.coins >= w;
            return GestureDetector(
              onTap: affordable ? () => setState(() => _wager = w) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? Palette.hudYellow.withOpacity(0.22)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Palette.hudYellow
                        : (affordable ? Colors.white24 : Colors.white10),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      w == 0 ? Icons.lock_open : Icons.monetization_on,
                      color: selected
                          ? Palette.coin
                          : (affordable ? Colors.white38 : Colors.white12),
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      w == 0 ? 'FREE' : '$w',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Palette.hudYellow
                            : (affordable ? Colors.white60 : Colors.white24),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          _wager == 0
              ? 'Free match — winner gets 100 coins'
              : 'Prize pool: ${_wager * 2} coins',
          style: const TextStyle(
              color: Palette.coin,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 28),
        _btn(
          label: 'Create Match',
          icon: Icons.add_circle_outline,
          color: Palette.hudGreen,
          onTap: () => _createRoom(player),
        ),
      ],
    ));
  }

  // ---------------------------------------------------------------------------
  // Join tab
  // ---------------------------------------------------------------------------
  Widget _joinTab(PlayerController player) => _centeredPad(Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.link, size: 56, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Enter your friend\'s room code',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 10,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.2),
                letterSpacing: 10,
                fontSize: 34,
              ),
              filled: true,
              fillColor: Palette.spaceBottom.withOpacity(0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Palette.hudYellow, width: 2),
              ),
              errorText: _joinError,
              errorMaxLines: 4,
            ),
            onChanged: (_) => setState(() => _joinError = null),
          ),
          const SizedBox(height: 20),
          if (_joinState == _JoinState.joining)
            const Column(
              children: <Widget>[
                CircularProgressIndicator(color: Palette.hudYellow),
                SizedBox(height: 12),
                Text('Joining…',
                    style: TextStyle(color: Colors.white60, fontSize: 14)),
              ],
            )
          else
            _btn(
              label: 'Join Match',
              icon: Icons.play_arrow,
              color: Palette.hudBlue,
              onTap: () => _joinRoom(player),
            ),
        ],
      ));

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Widget _centeredPad(Widget child) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: child,
        ),
      );

  Widget _statusRow(Color color, Widget indicator, String label) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(width: 18, height: 18, child: indicator),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 15)),
        ],
      );

  Widget _btn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 6,
          ),
          icon: Icon(icon),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800)),
          onPressed: onTap,
        ),
      );
}

enum _CreateState { idle, writing, waiting }

enum _JoinState { idle, joining }
