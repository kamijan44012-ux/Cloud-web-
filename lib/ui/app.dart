import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../config/palette.dart';
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
          headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: const _HomeBootstrap(),
    );
  }
}

/// Reads the URL fragment on web to detect PvP invite links.
/// If `#pvp=XXXXXX` is present in the URL, pushes [PvpLobbyScreen] immediately
/// with the code pre-filled in the Join tab.
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

/// Parses `#pvp=XXXXXX` from the current web URL.
/// Returns null on mobile or if the fragment is absent/invalid.
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
