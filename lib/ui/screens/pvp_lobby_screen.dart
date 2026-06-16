import 'dart:async';

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
  const PvpLobbyScreen({super.key});

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

  // Join-tab state
  final TextEditingController _codeCtrl = TextEditingController();
  _JoinState _joinState = _JoinState.idle;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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

  // ---------------------------------------------------------------------------
  // Create Match
  // ---------------------------------------------------------------------------
  Future<void> _createRoom(PlayerController player) async {
    if (_createState != _CreateState.idle) return;

    // 1. Generate code instantly and display it — user sees it before any network call.
    final String code = PvpService.instance.generateCode();
    setState(() {
      _roomCode = code;
      _createState = _CreateState.writing;
      _createError = null;
    });

    // 2. Write to Firestore in background.
    try {
      await PvpService.instance.createRoom(
        code: code,
        uid: _myUid(),
        name: _myName(),
        shipId: player.data.selectedShipId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _createState = _CreateState.idle;
        _roomCode = null;
        _createError = _friendlyError(e.toString());
      });
      return;
    }

    if (!mounted) return;
    setState(() => _createState = _CreateState.waiting);

    // 3. Listen for opponent to join.
    _waitSub?.cancel();
    _waitSub =
        PvpService.instance.listenToRoom(code).listen((PvpRoom? room) {
      if (room == null || !mounted) return;
      if (room.status == PvpStatus.playing) {
        _waitSub?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PvpGameScreen(
              roomCode: code,
              isHost: true,
              opponentName: room.guestName ?? 'Opponent',
              opponentShipId: room.guestShipId ?? 'falcon',
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

    // Fetch room to get host details, then navigate.
    PvpService.instance.listenToRoom(code).first.then((PvpRoom? room) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PvpGameScreen(
            roomCode: code,
            isHost: false,
            opponentName: room?.hostName ?? 'Opponent',
            opponentShipId: room?.hostShipId ?? 'falcon',
          ),
        ),
      );
    });
  }

  String _friendlyError(String raw) {
    if (raw.contains('permission-denied') || raw.contains('PERMISSION_DENIED')) {
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
              _header(),
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

  Widget _header() => Padding(
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
            const SizedBox(width: 48),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Create tab
  // ---------------------------------------------------------------------------
  Widget _createTab(PlayerController player) {
    // Error state
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

    // Code displayed (writing or waiting)
    if (_roomCode != null) {
      return _centeredPad(Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Share this code with your friend:',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 15),
          ),
          const SizedBox(height: 20),
          // Room code card — tapping copies it
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _roomCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
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
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Palette.hudYellow,
                      letterSpacing: 10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy, color: Palette.hudYellow, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Status row
          if (_createState == _CreateState.writing)
            _statusRow(
              Colors.orange,
              const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.orange),
              'Saving room…',
            )
          else
            _statusRow(
              Palette.hudGreen,
              const CircularProgressIndicator(
                  strokeWidth: 2, color: Palette.hudGreen),
              'Waiting for opponent…',
            ),
          const SizedBox(height: 28),
          TextButton.icon(
            onPressed: _cancelCreate,
            icon: const Icon(Icons.close, color: Colors.redAccent),
            label: const Text('Cancel',
                style: TextStyle(color: Colors.redAccent, fontSize: 15)),
          ),
        ],
      ));
    }

    // Idle — show Create button
    return _centeredPad(Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.sports_esports, size: 64, color: Colors.white24),
        const SizedBox(height: 20),
        const Text(
          'Create a room and share\nthe code with your friend.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
        const SizedBox(height: 36),
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
          const Icon(Icons.link, size: 64, color: Colors.white24),
          const SizedBox(height: 20),
          const Text(
            'Enter your friend\'s room code',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 24),
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
            Column(
              children: const <Widget>[
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
  Widget _centeredPad(Widget child) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 6,
          ),
          icon: Icon(icon),
          label: Text(label,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          onPressed: onTap,
        ),
      );
}

enum _CreateState { idle, writing, waiting }

enum _JoinState { idle, joining }
