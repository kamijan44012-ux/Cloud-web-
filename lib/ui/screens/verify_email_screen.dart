import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/palette.dart';
import '../../services/auth_service.dart';
import '../widgets/space_background.dart';

/// Shown after email/password signup until the player confirms their email by
/// clicking the verification link Firebase sent them. Polls automatically and
/// also offers manual "I've verified" / "Resend" actions.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _poll;
  bool _checking = false;
  bool _resending = false;
  String? _info;

  @override
  void initState() {
    super.initState();
    // Auto-check every few seconds so the screen advances on its own once the
    // player clicks the link in their inbox.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() => _checking = true);
    final bool verified =
        await AuthService.instance.reloadAndCheckVerified();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!verified && !silent) {
      setState(() =>
          _info = 'Not verified yet. Open the email and tap the link first.');
    }
    // When verified, AuthService notifies listeners and the auth gate swaps
    // this screen for the game automatically.
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _info = null;
    });
    final String? err = await AuthService.instance.resendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _resending = false;
      _info = err ?? 'Verification email sent. Check your inbox (and spam).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final String email = AuthService.instance.currentEmail ?? 'your email';
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.mark_email_unread_outlined,
                    color: Palette.hudYellow, size: 72),
                const SizedBox(height: 20),
                const Text(
                  'Verify your email',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to:\n$email\n\n'
                  'Open it on your phone, tap the link, then come back — '
                  'this screen continues automatically.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (_info != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Palette.hudYellow, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _checking ? null : () => _check(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.hudGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text("I've verified — Continue",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(
                    _resending ? 'Sending…' : 'Resend email',
                    style: const TextStyle(color: Palette.hudYellow),
                  ),
                ),
                TextButton(
                  onPressed: () => AuthService.instance.signOut(),
                  child: const Text('Use a different account',
                      style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
