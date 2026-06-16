import 'package:flutter/material.dart';

import '../../config/palette.dart';
import '../../services/auth_service.dart';
import '../widgets/space_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 32),
              const Text('🐔', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text(
                'CHICKEN HUNTER',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'SPACE WAR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Palette.hudYellow,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tab,
                  tabs: const <Tab>[
                    Tab(text: 'Login'),
                    Tab(text: 'Register'),
                  ],
                  indicatorColor: Palette.nebulaPurple,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  dividerColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: const <Widget>[
                    _LoginTab(),
                    _RegisterTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Login tab
// ---------------------------------------------------------------------------

class _LoginTab extends StatefulWidget {
  const _LoginTab();

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _forgotMode = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final String? err = await AuthService.instance.signIn(
      email: _email.text,
      password: _pass.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final String? err = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  Future<void> _sendReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final String? err =
        await AuthService.instance.resetPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _forgotMode = false);
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        children: <Widget>[
          _AuthField(
            controller: _email,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
          ),
          if (!_forgotMode) ...<Widget>[
            const SizedBox(height: 14),
            _AuthField(
              controller: _pass,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: _obscure,
              suffix: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _forgotMode = !_forgotMode;
                _error = null;
              }),
              child: Text(
                _forgotMode ? 'Back to Login' : 'Forgot Password?',
                style: const TextStyle(
                    color: Palette.hudYellow, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading
                  ? null
                  : (_forgotMode ? _sendReset : _login),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.nebulaPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _forgotMode ? 'Send Reset Email' : 'Login',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          if (!_forgotMode) ...<Widget>[
            const SizedBox(height: 16),
            const _OrDivider(),
            const SizedBox(height: 16),
            _GoogleButton(onPressed: _loading ? null : _google),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Register tab
// ---------------------------------------------------------------------------

class _RegisterTab extends StatefulWidget {
  const _RegisterTab();

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your display name.');
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final String? err = await AuthService.instance.signUp(
      email: _email.text,
      password: _pass.text,
      displayName: _name.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final String? err = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        children: <Widget>[
          _AuthField(
            controller: _name,
            label: 'Display Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: _email,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: _pass,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: _confirm,
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            obscure: _obscure,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _register,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.hudGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 16),
          _GoogleButton(onPressed: _loading ? null : _google),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.obscure = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Palette.nebulaPurple, width: 1.5),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12)),
        ),
        const Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Text('G',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        label: const Text('Continue with Google',
            style: TextStyle(color: Colors.white)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white30),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
