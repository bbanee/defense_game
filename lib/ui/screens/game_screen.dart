import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/game/tower_defense_game.dart';

class GameScreen extends StatelessWidget {
  final VoidCallback? onExit;
  final String difficultyId;
  final String stageId;
  final AccountProgress progress;

  const GameScreen({
    super.key,
    this.onExit,
    required this.difficultyId,
    required this.stageId,
    required this.progress,
  });

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF102033),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF83B5FF), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.exit_to_app, color: Color(0xFF8FD3FF), size: 30),
              const SizedBox(height: 10),
              const Text(
                '전투 종료',
                style: TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '전투를 종료하고 로비로 돌아가시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9E7FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF3F7FF),
                        backgroundColor: const Color(0x99122336),
                        side: const BorderSide(color: Color(0xFF83B5FF), width: 1.2),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF3F7FF),
                        backgroundColor: const Color(0xCC17304B),
                        side: const BorderSide(color: Color(0xFF83B5FF), width: 1.2),
                      ),
                      child: const Text('로비로'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldExit == true) {
      onExit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _confirmExit(context);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: GameWidget(
            game: TowerDefenseGame(
              onExitToLobby: onExit,
              difficultyId: difficultyId,
              stageId: stageId,
              accountProgress: progress,
            ),
            backgroundBuilder: (context) => const ColoredBox(color: Color(0xFF0E0E12)),
          ),
        ),
      ),
    );
  }
}
