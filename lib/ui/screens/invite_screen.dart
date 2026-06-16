import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/palette.dart';
import '../../services/referral_service.dart';
import '../widgets/space_background.dart';

/// Shows the player's invite link + reward info so they can share it with
/// friends. Each friend who joins through the link earns coins for both.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Friends'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: ValueListenableBuilder<String?>(
          valueListenable: ReferralService.instance.myCode,
          builder: (BuildContext context, String? code, _) {
            final String link = code == null
                ? 'Sign in to get your invite link'
                : ReferralService.instance.inviteLink(code);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 24),
              children: <Widget>[
                const Center(
                    child: Text('🎁', style: TextStyle(fontSize: 64))),
                const SizedBox(height: 12),
                const Text(
                  'Invite friends, earn coins!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'For every friend who joins with your link:\n'
                  'You get +${ReferralService.inviterBonus} coins  •  '
                  'They get +${ReferralService.newUserBonus} coins',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ValueListenableBuilder<int>(
                  valueListenable: ReferralService.instance.referralCount,
                  builder: (BuildContext c, int count, _) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text('$count',
                            style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Palette.hudGreen)),
                        const Text('friends invited',
                            style: TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (code != null) ...<Widget>[
                  const Text('Your invite link',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Palette.nebulaPurple),
                    ),
                    child: Text(link,
                        style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.hudGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _copy(context, link),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Invite Link',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _copy(
                        context,
                        '🐔🚀 Play Chicken Hunter: Space War with me!\n'
                        'No download — just open & play:\n$link',
                        message: 'Share message copied! Paste it in WhatsApp.',
                      ),
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Copy Share Message',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ] else
                  const Text(
                    'Create an account (email or Google) to get your personal '
                    'invite link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _copy(BuildContext context, String text, {String? message}) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message ?? 'Invite link copied!'),
      backgroundColor: Colors.green,
    ));
  }
}
