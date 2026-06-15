import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../config/palette.dart';
import 'screens/main_menu_screen.dart';

class ChickenHunterApp extends StatelessWidget {
  const ChickenHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: GameConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Palette.spaceTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.nebulaPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}
