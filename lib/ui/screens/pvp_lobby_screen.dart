import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../models/pvp_match.dart';
import '../../services/cloud_save_service.dart';
import '../../services/pvp_service.dart';
import '../../systems/player_controller.dart';
import '../widgets/menu_button.dart';
import '../widgets/space_background.dart';
import 'pvp_game_screen.dart';

/// Lobby for 1v1 PvP. Two tabs:
///  • Create Match — generates a 6-digit room code to share with a friend.
///  • Join Match  — enter the host's code to enter their room.
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
  bool _creating = false;
  StreamSubscription<PvpRoom?>? _waitSub;

  // Join-tab state
  final TextEditingController _codeCtrl = TextEditingController();
  bool _joining = false;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _waitSub?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _myUid() {
    final String? uid = CloudSaveService.instance.uid;
    return uid ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _myName() {
    final String uid = _myUid();
    final String suffix =
        uid.length >= 6 ? uid.substring(uid.length - 6).toUpperCase() : uid.toUpperCase();
    return 'Pilot_$suffix';
  }

  Future<void> _createRoom(PlayerController player) async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _roomCode = null;
    });

    final String code = await PvpService.instance.createRoom(
      uid: _myUid(),
      name: _myName(),
      shipId: player.data.selectedShipId,
    );

    if (!mounted) return;
    setState(() {
      _roomCode = code;
      _creating = false;
    });

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
    });
  }

  void _cancelCreate() {
    _waitSub?.cancel();
    if (_roomCode != null) {
      PvpService.instance.deleteRoom(_roomCode!);
    }
    setState(() {
      _roomCode = null;
      _creating = false;
    });
  }

  Future<void> _joinRoom(PlayerController player) async {
    final String code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _joinError = 'Enter a valid 6-digit code');
      return;
    }
    setState(() {
      _joining = true;
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
        _joining = false;
        _joinError = error;
      });
      return;
    }

    // Fetch host info once before navigating
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
        padding: const EdgeInsets.all(16),
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
                'VS MODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3),
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
    if (_creating) {
      return const Center(
          child: CircularProgressIndicator(color: Palette.hudYellow));
    }

    if (_roomCode != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Share this code with your opponent:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _roomCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 20),
                  decoration: BoxDecoration(
                    color: Palette.spaceBottom.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Palette.hudYellow, width: 2),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: Palette.hudYellow.withOpacity(0.35),
                          blurRadius: 24),
                    ],
                  ),
                  child: Text(
                    _roomCode!,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Palette.hudYellow,
                      letterSpacing: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tap to copy',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Palette.hudGreen),
                  ),
                  SizedBox(width: 12),
                  Text('Waiting for opponent…',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _cancelCreate,
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.sports_esports, size: 72, color: Colors.white30),
            const SizedBox(height: 20),
            const Text(
              'Create a room and share\nthe code with your friend.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),
            MenuButton(
              label: 'Create Match',
              icon: Icons.add_circle_outline,
              color: Palette.hudGreen,
              onTap: () => _createRoom(player),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Join tab
  // ---------------------------------------------------------------------------
  Widget _joinTab(PlayerController player) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.link, size: 72, color: Colors.white30),
              const SizedBox(height: 20),
              const Text(
                'Enter your friend\'s room code',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      letterSpacing: 10,
                      fontSize: 32),
                  filled: true,
                  fillColor: Palette.spaceBottom.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Palette.hudYellow, width: 2),
                  ),
                  errorText: _joinError,
                ),
                onChanged: (_) => setState(() => _joinError = null),
              ),
              const SizedBox(height: 24),
              if (_joining)
                const CircularProgressIndicator(color: Palette.hudYellow)
              else
                MenuButton(
                  label: 'Join Match',
                  icon: Icons.play_arrow,
                  color: Palette.hudBlue,
                  onTap: () => _joinRoom(player),
                ),
            ],
          ),
        ),
      );
}
