import 'package:flutter/material.dart';

import '../../config/palette.dart';
import '../../services/profile_service.dart';
import '../screens/profile_screen.dart';

/// Small circular avatar button that opens the [ProfileScreen]. Reactively
/// updates when the player changes their avatar.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: ProfileService.instance.avatarIndex,
        builder: (_, int __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(color: Palette.nebulaPurple, width: 2),
          ),
          child: Center(
            child: Text(
              ProfileService.instance.currentEmoji,
              style: TextStyle(fontSize: size * 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
