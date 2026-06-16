import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/palette.dart';
import '../../services/auth_service.dart';
import '../widgets/space_background.dart';

/// Shown after email/password signup until the player confirms their email.
/// Two modes:
///  - Code mode (EmailJS configured): enter the 6-digit code from the email.
///  - Link mode (fallback): click the verification link; auto-detected.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _code = TextEditingController();
  Timer? _poll;
  bool _busy = false;
  bool _resending = false;
  String? _info;

  bool get _codeMode => AuthService.instance.usesEmailCode;

  @override
  void initState() {
    super.initState();
    // Link mode advances on its own once the player clicks the link.
    if (!_codeMode) {
      _poll = Timer.periodic(
          const Duration(seconds: 4), (_) => _checkLink(silent: true));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _checkLink({bool silent = false}) async {
    if (_busy) return;
    if (!silent) setState(() => _busy = true);
    final bool verified =
        await AuthService.instance.reloadAndCheckVerified();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!verified && !silent) {
      setState(() =>
          _info = 'Not verified yet. Open the email and tap the link first.');
    }
  }

  Future<void> _submitCode() async {
    setState(() {
      _busy = true;
      _info = null;
    });
    final String? err =
        await AuthService.instance.confirmEmailCode(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _info = err;
    });
    // On success the auth gate swaps this screen for the game automatically.
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
      _info = err ??
          (_codeMode
              ? 'New code sent. Check your inbox (and spam).'
              : 'Verification email sent. Check your inbox (and spam).');
    });
  }

  @override
  Widget build(BuildContext context) {
    final String email = AuthService.instance.currentEmail ?? 'your email';
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.mark_email_unread_outlined,
                    color: Palette.hudYellow, size: 72),
                const SizedBox(height: 20),
                Text(
                  _codeMode ? 'Enter your code' : 'Verify your email',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  _codeMode
                      ? 'We emailed a 6-digit code to:\n$email\n\n'
                          'Copy it from the email and type it below.'
                      : 'We sent a verification link to:\n$email\n\n'
                          'Open it, tap the link, then come back — this screen '
                          'continues automatically.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                if (_codeMode)
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        letterSpacing: 12,
                        fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: const TextStyle(
                          color: Colors.white24, letterSpacing: 12),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submitCode(),
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : (_codeMode ? _submitCode : () => _checkLink()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.hudGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_codeMode ? 'Verify' : "I've verified — Continue",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(
                    _resending
                        ? 'Sending…'
                        : (_codeMode ? 'Resend code' : 'Resend email'),
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
