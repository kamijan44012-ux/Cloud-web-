import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/game_config.dart';
import '../config/palette.dart';
import '../models/player_data.dart';
import '../services/auth_service.dart';
import '../services/cloud_save_service.dart';
import '../services/profile_service.dart';
import '../services/referral_service.dart';
import '../systems/player_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/pvp_lobby_screen.dart';
import 'screens/verify_email_screen.dart';

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
  AppUser? _user;
  String? _syncedUid;

  @override
  void initState() {
    super.initState();
    AuthService.instance.userNotifier.addListener(_onAuthChanged);
    _user = AuthService.instance.currentAppUser;
    _maybeSync(_user);
  }

  @override
  void dispose() {
    AuthService.instance.userNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  String? _referralAppliedUid;

  void _onAuthChanged() {
    final AppUser? user = AuthService.instance.currentAppUser;
    _maybeSync(user);
    _maybeApplyReferral(user);
    if (mounted) setState(() => _user = user);
  }

  /// Once a player is fully signed in and (if needed) email-verified, set up
  /// their invite code and credit any pending referral exactly once.
  Future<void> _maybeApplyReferral(AppUser? user) async {
    if (user == null || user.isLocal) return;
    if (AuthService.instance.needsEmailVerification) return;
    if (_referralAppliedUid == user.uid) return;
    _referralAppliedUid = user.uid;

    final PlayerController player = context.read<PlayerController>();
    await ReferralService.instance.ensureMyCode(user.uid);
    final int bonus =
        await ReferralService.instance.applyPendingReferral(user.uid, player);
    if (bonus > 0) {
      await CloudSaveService.instance.push(player.data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Welcome! +$bonus coins from your friend\'s invite 🎁'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  /// Pulls the cloud save once per signed-in Firebase user. Local-only accounts
  /// have no cloud document, so they just play with their on-device save.
  Future<void> _maybeSync(AppUser? user) async {
    if (user == null || user.isLocal) return;
    if (_syncedUid == user.uid) return;
    _syncedUid = user.uid;

    final PlayerController player = context.read<PlayerController>();
    await CloudSaveService.instance.setUser(
      user.uid,
      email: user.email,
      displayName: user.displayName,
    );
    final PlayerData? cloud = await CloudSaveService.instance.pull();
    if (cloud != null) player.mergeFromCloud(cloud);
    // Pull the avatar chosen on another device.
    await ProfileService.instance.syncFromCloud(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) {
      // Email/password users must confirm their email before entering.
      if (AuthService.instance.needsEmailVerification) {
        return const VerifyEmailScreen();
      }
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
