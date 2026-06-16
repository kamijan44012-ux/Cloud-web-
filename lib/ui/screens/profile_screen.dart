import 'package:flutter/material.dart';

import '../../config/palette.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../widgets/space_background.dart';
import 'settings_screen.dart';

/// Player profile: change avatar, edit display name, see account info, open
/// settings and sign out. Reachable from the avatar button on the main menu.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _savingName = false;

  Future<void> _editName() async {
    final TextEditingController ctrl = TextEditingController(
        text: AuthService.instance.currentDisplayName ?? '');
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Palette.spaceBottom,
        title: const Text('Change name',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: Colors.white38),
          ),
          onSubmitted: (String v) => Navigator.pop(ctx, v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Palette.nebulaPurple),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _savingName = true);
    final String? err = await AuthService.instance.updateDisplayName(name);
    if (!mounted) return;
    setState(() => _savingName = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Name updated.'),
      backgroundColor: err == null ? Colors.green : Colors.redAccent,
    ));
  }

  Future<void> _pickAvatar() async {
    final int? choice = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Palette.spaceBottom,
        title: const Text('Choose your avatar',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: ProfileService.avatars.length,
            itemBuilder: (BuildContext c, int i) {
              final bool selected =
                  i == ProfileService.instance.avatarIndex.value;
              return InkWell(
                onTap: () => Navigator.pop(ctx, i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? Palette.nebulaPurple.withOpacity(0.4)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? Palette.nebulaPurple
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(ProfileService.avatars[i],
                        style: const TextStyle(fontSize: 26)),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (choice != null) {
      await ProfileService.instance.setAvatar(choice);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = AuthService.instance.currentAppUser;
    final String name = user?.displayName ?? 'Player';
    final String email = user?.email ?? '';
    final bool isGuest = user?.isAnonymous ?? (email.isEmpty);
    final bool verified = user?.emailVerified ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 24),
          children: <Widget>[
            Center(
              child: Stack(
                children: <Widget>[
                  ValueListenableBuilder<int>(
                    valueListenable: ProfileService.instance.avatarIndex,
                    builder: (_, int __, ___) => Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                            color: Palette.nebulaPurple, width: 2),
                      ),
                      child: Center(
                        child: Text(ProfileService.instance.currentEmoji,
                            style: const TextStyle(fontSize: 52)),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Palette.nebulaPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: _savingName ? null : _editName,
                    icon: _savingName
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.edit,
                            size: 18, color: Colors.white60),
                  ),
                ],
              ),
            ),
            if (email.isNotEmpty)
              Center(
                child: Text(email,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Center(
              child: _Badge(
                isGuest: isGuest,
                verified: verified,
                isLocal: user?.isLocal ?? true,
              ),
            ),
            const SizedBox(height: 28),
            _Tile(
              icon: Icons.face_retouching_natural,
              label: 'Change Avatar',
              onTap: _pickAvatar,
            ),
            _Tile(
              icon: Icons.badge_outlined,
              label: 'Change Name',
              onTap: _savingName ? null : _editName,
            ),
            _Tile(
              icon: Icons.settings,
              label: 'Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _Tile(
              icon: Icons.logout,
              label: 'Sign Out',
              color: Colors.redAccent,
              onTap: () async {
                await AuthService.instance.signOut();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.isGuest, required this.verified, required this.isLocal});
  final bool isGuest;
  final bool verified;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String text;
    late final Color color;
    if (isGuest) {
      icon = Icons.person_outline;
      text = 'Guest account';
      color = Colors.white54;
    } else if (isLocal) {
      icon = Icons.smartphone;
      text = 'On-device account';
      color = Colors.white54;
    } else if (verified) {
      icon = Icons.verified;
      text = 'Verified';
      color = Palette.hudGreen;
    } else {
      icon = Icons.error_outline;
      text = 'Email not verified';
      color = Palette.hudYellow;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.06),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color)),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white30),
        onTap: onTap,
      ),
    );
  }
}
