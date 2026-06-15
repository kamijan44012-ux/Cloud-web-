import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_data.dart';

/// Handles local persistence of [PlayerData]. Cloud sync is layered on top in
/// [services/cloud_save_service.dart]; this class is the offline-first base so
/// the game is fully playable with no network.
class SaveSystem {
  static const String _key = 'player_data_v1';

  Future<PlayerData> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) return PlayerData();
    try {
      return PlayerData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt save — start fresh rather than crash on boot.
      return PlayerData();
    }
  }

  Future<void> save(PlayerData data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  Future<void> wipe() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
