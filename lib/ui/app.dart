import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/game_config.dart';
import '../config/palette.dart';
import '../models/player_data.dart';
import '../services/auth_service.dart';
import '../services/cloud_save_service.dart';
import '../systems/player_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/pvp_lobby_screen.dart';

class ChickenHunterApp extends StatelessWidget {
  const ChickenHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: GameConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Palette.spaceTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.nebulaPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge:
              TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Auth gate: shows [AuthScreen] when the user is not signed in.
/// When signed in, pulls cloud save and shows the game.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _initialized = false;
  User? _user;

  @override
  void initState() {
    super.initState();

    // If Firebase isn't ready (stub config, no network), skip auth.
    if (!GameConfig.enableFirebase) {
      _initialized = true;
      return;
    }

    try {
      AuthService.instance.authStateChanges.listen(_onAuthChanged);
    } catch (_) {
      // Firebase not initialized — offline mode
      setState(() => _initialized = true);
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user != null && (_user == null || _user!.uid != user.uid)) {
      final PlayerController player =
          // ignore: use_build_context_synchronously
          context.read<PlayerController>();
      await CloudSaveService.instance.setUser(
        user.uid,
        email: user.email,
        displayName: user.displayName,
      );
      final PlayerData? cloud = await CloudSaveService.instance.pull();
      if (cloud != null) player.mergeFromCloud(cloud);
    }
    if (mounted) {
      setState(() {
        _user = user;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Palette.spaceTop,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Offline mode (Firebase not configured) or signed-in user
    if (!GameConfig.enableFirebase || _user != null) {
      return const _HomeBootstrap();
    }

    return const AuthScreen();
  }
}

/// Reads the URL fragment on web to detect PvP invite links.
/// If `#pvp=XXXXXX` is present, pushes [PvpLobbyScreen] with code pre-filled.
class _HomeBootstrap extends StatefulWidget {
  const _HomeBootstrap();

  @override
  State<_HomeBootstrap> createState() => _HomeBootstrapState();
}

class _HomeBootstrapState extends State<_HomeBootstrap> {
  @override
  void initState() {
    super.initState();
    final String? code = _extractPvpCode();
    if (code != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PvpLobbyScreen(initialJoinCode: code),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => const MainMenuScreen();
}

String? _extractPvpCode() {
  if (!kIsWeb) return null;
  try {
    final String fragment = Uri.base.fragment;
    if (fragment.startsWith('pvp=')) {
      final String code = fragment.substring(4);
      if (code.length == 6 && int.tryParse(code) != null) return code;
    }
  } catch (_) {}
  return null;
}
