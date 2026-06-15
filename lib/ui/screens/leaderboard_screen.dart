import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../services/leaderboard_service.dart';
import '../../systems/player_controller.dart';
import '../widgets/space_background.dart';

/// Global high-score leaderboard. Submits the local best on open, then shows
/// the top entries. Falls back to mock data when Firebase isn't configured.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    final PlayerController player = context.read<PlayerController>();
    LeaderboardService.instance.submit(
      name: 'Pilot ${player.level}',
      score: player.data.highScore,
      wave: player.data.highestWave,
    );
    _future = LeaderboardService.instance.top();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Galactic Ranks'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: SafeArea(
          child: FutureBuilder<List<LeaderboardEntry>>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<List<LeaderboardEntry>> snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<LeaderboardEntry> entries = snap.data!;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
                itemCount: entries.length,
                itemBuilder: (BuildContext context, int i) {
                  final LeaderboardEntry e = entries[i];
                  final Color medal = switch (i) {
                    0 => Palette.coin,
                    1 => Colors.grey,
                    2 => const Color(0xFFCD7F32),
                    _ => Colors.white24,
                  };
                  return Card(
                    color: Colors.black.withOpacity(0.45),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: medal,
                        child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(e.name),
                      subtitle: Text('Wave ${e.wave}'),
                      trailing: Text('${e.score}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Palette.hudYellow)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
