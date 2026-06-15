import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../services/audio_service.dart';
import '../../services/cloud_save_service.dart';
import '../../services/iap_service.dart';
import '../../systems/player_controller.dart';
import '../widgets/space_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final PlayerController player = context.read<PlayerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 90, 16, 16),
          children: <Widget>[
            SwitchListTile(
              title: const Text('Sound Effects'),
              value: AudioService.instance.sfxEnabled,
              onChanged: (bool v) => setState(() => AudioService.instance.sfxEnabled = v),
            ),
            SwitchListTile(
              title: const Text('Music'),
              value: AudioService.instance.musicEnabled,
              onChanged: (bool v) {
                setState(() => AudioService.instance.musicEnabled = v);
                if (!v) AudioService.instance.stopMusic();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Cloud Save Now'),
              subtitle: Text(CloudSaveService.instance.uid == null
                  ? 'Not signed in (offline mode)'
                  : 'Synced as ${CloudSaveService.instance.uid}'),
              onTap: () async {
                await CloudSaveService.instance.push(player.data);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Progress uploaded.')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore Purchases'),
              onTap: () => IapService.instance.restorePurchases(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: Text('${GameConfig.appName}\nVersion ${GameConfig.version}'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Reset Progress'),
              onTap: () => _confirmReset(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text('This permanently deletes your local save. This cannot be undone.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restart the app to apply a full reset.')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
