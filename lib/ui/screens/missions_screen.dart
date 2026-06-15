import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../models/achievement.dart';
import '../../models/mission.dart';
import '../../systems/battle_pass.dart';
import '../../systems/mission_system.dart';
import '../../systems/player_controller.dart';
import '../widgets/currency_bar.dart';
import '../widgets/space_background.dart';

/// Three tabs: daily/weekly Missions, the seasonal Battle Pass track, and
/// permanent Achievements. All reactive to their respective systems.
class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Missions'),
          backgroundColor: Colors.transparent,
          bottom: const TabBar(tabs: <Widget>[
            Tab(text: 'Missions'),
            Tab(text: 'Battle Pass'),
            Tab(text: 'Achievements'),
          ]),
        ),
        extendBodyBehindAppBar: true,
        body: SpaceBackground(
          child: Column(
            children: <Widget>[
              const SizedBox(height: kToolbarHeight + 48),
              const CurrencyBar(showLevel: true),
              const Expanded(
                child: TabBarView(children: <Widget>[
                  _MissionsTab(),
                  _BattlePassTab(),
                  _AchievementsTab(),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionsTab extends StatelessWidget {
  const _MissionsTab();
  @override
  Widget build(BuildContext context) {
    final MissionSystem ms = context.watch<MissionSystem>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: ms.missions.map((Mission m) {
        return Card(
          color: Colors.black.withOpacity(0.45),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(m.scope == MissionScope.weekly ? Icons.calendar_month : Icons.today,
                        color: Palette.hudYellow, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: m.fraction,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Palette.hudGreen),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('${m.progress}/${m.target}', style: const TextStyle(color: Colors.white70)),
                    Text('+${m.rewardCoins}🪙 ${m.rewardGems > 0 ? '+${m.rewardGems}💎' : ''}',
                        style: const TextStyle(color: Palette.coin)),
                    if (m.claimed)
                      const Text('Claimed', style: TextStyle(color: Colors.white38))
                    else
                      ElevatedButton(
                        onPressed: m.isComplete ? () => ms.claim(m) : null,
                        child: const Text('Claim'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BattlePassTab extends StatelessWidget {
  const _BattlePassTab();
  @override
  Widget build(BuildContext context) {
    final BattlePassSystem bp = context.watch<BattlePassSystem>();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Text('Season Tier ${bp.tier} / ${BattlePassSystem.maxTier}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: bp.tierFraction,
                minHeight: 10,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Palette.nebulaPink),
              ),
              if (!bp.isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Buy the Battle Pass in the Shop to unlock the premium track.',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: BattlePassSystem.maxTier,
            itemBuilder: (BuildContext context, int i) {
              final int tier = i + 1;
              final BattlePassReward r = bp.rewardForTier(tier);
              final bool reached = bp.tier >= tier;
              return Card(
                color: reached ? Palette.hudGreen.withOpacity(0.25) : Colors.black.withOpacity(0.4),
                child: ListTile(
                  leading: CircleAvatar(child: Text('$tier')),
                  title: Text('Free: ${r.freeCoins}🪙 ${r.freeGems > 0 ? '${r.freeGems}💎' : ''}'),
                  subtitle: Text('Premium: ${r.premiumCoins}🪙 ${r.premiumGems}💎'
                      '${r.premiumShipId != null ? ' + Ship!' : ''}'),
                  trailing: reached ? const Icon(Icons.check_circle, color: Palette.hudGreen) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab();
  @override
  Widget build(BuildContext context) {
    final PlayerController player = context.watch<PlayerController>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: Achievement.all.map((Achievement a) {
        final bool done = player.data.unlockedAchievements.contains(a.id);
        return Card(
          color: done ? Palette.hudYellow.withOpacity(0.2) : Colors.black.withOpacity(0.4),
          child: ListTile(
            leading: Icon(done ? Icons.emoji_events : Icons.lock_outline,
                color: done ? Palette.hudYellow : Colors.white38),
            title: Text(a.title),
            subtitle: Text(a.description),
            trailing: Text('+${a.rewardGems}💎',
                style: const TextStyle(color: Palette.gem, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }
}
