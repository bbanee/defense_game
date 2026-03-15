import 'package:flutter/material.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/ui/screens/game_screen.dart';
import 'package:tower_defense/ui/screens/lobby_screen.dart';

void main() {
  runApp(const TowerDefenseApp());
}

class TowerDefenseApp extends StatelessWidget {
  const TowerDefenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tower Defense',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B3B42)),
        fontFamily: 'Roboto',
      ),
      home: LobbyScreen(
        gameScreenBuilder: ({
          required String difficultyId,
          required String stageId,
          required AccountProgress progress,
          required VoidCallback onExit,
        }) {
          return GameScreen(
            difficultyId: difficultyId,
            stageId: stageId,
            progress: progress,
            onExit: onExit,
          );
        },
      ),
    );
  }
}
