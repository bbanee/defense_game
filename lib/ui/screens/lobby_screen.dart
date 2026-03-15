import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tower_defense/data/definition_repository.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/ui/screens/building_management_screen.dart';
import 'package:tower_defense/ui/screens/help_screen.dart';
import 'package:tower_defense/ui/screens/ranking_screen.dart';
import 'package:tower_defense/ui/screens/settings_screen.dart';
import 'package:tower_defense/ui/screens/shop_screen.dart';
import 'package:tower_defense/ui/screens/tower_management_screen.dart';
import 'package:tower_defense/ui/widgets/panel_box.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

typedef GameScreenBuilder = Widget Function({
  required String difficultyId,
  required String stageId,
  required AccountProgress progress,
  required VoidCallback onExit,
});

class LobbyScreen extends StatefulWidget {
  final GameScreenBuilder gameScreenBuilder;

  const LobbyScreen({super.key, required this.gameScreenBuilder});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  static const Duration _energyRegenInterval = Duration(minutes: 5);
  String _gameMode = '스토리 모드';
  String _difficulty = '노멀 모드';
  AccountProgress? _progress;
  final DefinitionRepository _definitionRepo = DefinitionRepository();
  final AccountProgressRepository _progressRepo = AccountProgressRepository();
  Timer? _energyTimer;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _energyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final changed = _applyEnergyRegen(save: false);
      if (changed && _progress != null) {
        _progressRepo.save(_progress!);
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _energyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final data = await _progressRepo.load();
    _initializeEnergyClock(data);
    final changed = _applyEnergyRegenTo(data);
    if (changed) {
      await _progressRepo.save(data);
    }
    if (!mounted) return;
    setState(() => _progress = data);
  }

  void _initializeEnergyClock(AccountProgress progress) {
    if (progress.lastEnergyAtIso.isNotEmpty) return;
    progress.lastEnergyAtIso = DateTime.now().toIso8601String();
  }

  bool _applyEnergyRegen({required bool save}) {
    final progress = _progress;
    if (progress == null) return false;
    final changed = _applyEnergyRegenTo(progress);
    if (changed && save) {
      _progressRepo.save(progress);
    }
    return changed;
  }

  bool _applyEnergyRegenTo(AccountProgress progress) {
    _initializeEnergyClock(progress);
    if (progress.energy >= progress.maxEnergy) {
      progress.lastEnergyAtIso = DateTime.now().toIso8601String();
      return false;
    }

    final last = DateTime.tryParse(progress.lastEnergyAtIso) ?? DateTime.now();
    final now = DateTime.now();
    final elapsed = now.difference(last);
    if (elapsed < _energyRegenInterval) return false;

    final gained = elapsed.inSeconds ~/ _energyRegenInterval.inSeconds;
    if (gained <= 0) return false;

    final newEnergy = (progress.energy + gained).clamp(0, progress.maxEnergy);
    final actualGained = newEnergy - progress.energy;
    progress.energy = newEnergy;
    if (progress.energy >= progress.maxEnergy) {
      progress.lastEnergyAtIso = now.toIso8601String();
    } else {
      progress.lastEnergyAtIso = last
          .add(Duration(seconds: _energyRegenInterval.inSeconds * actualGained))
          .toIso8601String();
    }
    return true;
  }

  String _energyCountdownLabel(AccountProgress? progress) {
    if (progress == null) return '--:--';
    _initializeEnergyClock(progress);
    if (progress.energy >= progress.maxEnergy) return 'MAX';
    final last = DateTime.tryParse(progress.lastEnergyAtIso) ?? DateTime.now();
    final elapsed = DateTime.now().difference(last).inSeconds;
    final remain = (_energyRegenInterval.inSeconds - (elapsed % _energyRegenInterval.inSeconds))
        .clamp(1, _energyRegenInterval.inSeconds);
    final minutes = (remain ~/ 60).toString().padLeft(2, '0');
    final seconds = (remain % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _selectedDifficultyId() {
    return switch (_difficulty) {
      '이지 모드' => 'easy',
      '노멀 모드' => 'normal',
      '하드 모드' => 'hard',
      _ => 'normal',
    };
  }

  String _selectedDifficultyLabel() {
    return switch (_selectedDifficultyId()) {
      'easy' => '이지',
      'normal' => '노말',
      'hard' => '하드',
      'nightmare' => '나이트메어',
      _ => '노말',
    };
  }

  String _bestWaveSummary() {
    final progress = _progress;
    if (progress == null) return '최고 기록: --';
    if (_gameMode == '무한 모드') {
      return '최고 기록: 무한 ${progress.bestInfiniteWave}웨이브';
    }
    final best = progress.bestWaveByDifficulty[_selectedDifficultyId()] ?? 0;
    return '최고 기록: ${_selectedDifficultyLabel()} $best웨이브';
  }

  Future<void> _startGame({String stageId = 'story_01'}) async {
    final progress = _progress;
    if (progress == null) return;
    final isInfiniteMode = _gameMode == '무한 모드';
    final actualStageId = isInfiniteMode ? 'endless_01' : stageId;
    final difficultyId = isInfiniteMode
        ? 'endless'
        : switch (_difficulty) {
            '이지 모드' => 'easy',
            '노멀 모드' => 'normal',
            '하드 모드' => 'hard',
            _ => 'normal',
          };
    final stage = await _definitionRepo.loadStage(actualStageId);
    final energyCost = stage.energyCost;
    if (!mounted) return;

    if (progress.energy < energyCost) {
      await _showStyledNoticeDialog(
        title: '에너지 부족',
        body: '게임 시작에 에너지 $energyCost가 필요합니다.',
      );
      return;
    }

    setState(() {
      progress.energy -= energyCost;
      if (progress.energy < progress.maxEnergy) {
        progress.lastEnergyAtIso = DateTime.now().toIso8601String();
      }
    });
    await _progressRepo.save(progress);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.gameScreenBuilder(
          difficultyId: difficultyId,
          stageId: actualStageId,
          progress: progress.copy(),
          onExit: () => Navigator.of(context).pop(),
        ),
      ),
    );
    final refreshed = await _progressRepo.load();
    _initializeEnergyClock(refreshed);
    _applyEnergyRegenTo(refreshed);
    if (!mounted) return;
    setState(() => _progress = refreshed);
  }

  Future<void> _showStyledNoticeDialog({
    required String title,
    required String body,
  }) async {
    await showDialog<void>(
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
              const Icon(Icons.bolt, color: Color(0xFFFFC857), size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD9E7FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              AppPanelButton(
                label: '확인',
                borderColor: const Color(0xFF83B5FF),
                foregroundColor: const Color(0xFFF3F7FF),
                backgroundColor: const Color(0xCC17304B),
                compact: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyEnergyQuick() async {
    final progress = _progress;
    if (progress == null) return;
    const energyAmount = 5;
    const diamondCost = 50;
    if (progress.diamonds < diamondCost) {
      await _showStyledNoticeDialog(
        title: '다이아 부족',
        body: '에너지 $energyAmount개 구매에는 다이아 $diamondCost개가 필요합니다.',
      );
      return;
    }

    final ok = await showDialog<bool>(
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
              const Icon(Icons.bolt, color: Color(0xFFFFC857), size: 30),
              const SizedBox(height: 10),
              const Text(
                '에너지 구매',
                style: TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '다이아 50개로 에너지 5개를 구매하시겠습니까?',
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
                    child: AppPanelButton(
                      label: '취소',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0x99122336),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppPanelButton(
                      label: '구매',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0xCC17304B),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;
    setState(() {
      progress.diamonds -= diamondCost;
      progress.energy += energyAmount;
    });
    await _progressRepo.save(progress);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = const Color(0xFF8CB8FF);
    final bgColor = const Color(0xFF07111F);
    final textColor = const Color(0xFFF3F7FF);
    final panelFill = const Color(0xB0122136);
    final buttonFill = const Color(0xCC16304D);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/UI/main.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: bgColor),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.12),
                    Colors.black.withOpacity(0.22),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
            Center(
              child: Container(
                width: 360,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xB3121D2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _TopBar(
                      borderColor: borderColor,
                      progress: _progress,
                      energyCountdown: _energyCountdownLabel(_progress),
                      onEnergyPlusTap: _buyEnergyQuick,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SF\n타워 디펜스',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(
                            color: Color(0xFF5EC7FF),
                            blurRadius: 10,
                            offset: Offset(0, 0),
                          ),
                        ],
                        letterSpacing: 1.6,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('게임 모드', style: TextStyle(color: textColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPanelBox(
                            borderColor: borderColor,
                            backgroundColor: panelFill,
                            borderRadius: BorderRadius.circular(14),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _gameMode,
                                dropdownColor: const Color(0xFF12233A),
                                iconEnabledColor: textColor,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                items: const [
                                  DropdownMenuItem(value: '스토리 모드', child: Text('스토리 모드')),
                                  DropdownMenuItem(value: '무한 모드', child: Text('무한 모드')),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _gameMode = value);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_gameMode == '스토리 모드') ...[
                    Row(
                      children: [
                        Text('난이도', style: TextStyle(color: textColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPanelBox(
                            borderColor: borderColor,
                            backgroundColor: panelFill,
                            borderRadius: BorderRadius.circular(14),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 12, color: Color(0xFF27C24C)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _difficulty,
                                      dropdownColor: const Color(0xFF12233A),
                                      iconEnabledColor: textColor,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: '이지 모드', child: Text('이지 모드')),
                                        DropdownMenuItem(value: '노멀 모드', child: Text('노멀 모드')),
                                        DropdownMenuItem(value: '하드 모드', child: Text('하드 모드')),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _difficulty = value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ],
                    AppPanelBox(
                      borderColor: borderColor,
                      backgroundColor: panelFill,
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.flag, size: 14, color: Color(0xFF8FD3FF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _bestWaveSummary(),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: AppPanelButton(
                        label: '게임 시작',
                        borderColor: borderColor,
                        foregroundColor: textColor,
                        backgroundColor: buttonFill,
                        onPressed: _startGame,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: AppPanelButton(
                            label: '타워 관리',
                            icon: Icons.local_fire_department,
                            borderColor: borderColor,
                            foregroundColor: textColor,
                            backgroundColor: buttonFill,
                            onPressed: () async {
                              final progress = _progress;
                              if (progress == null) return;
                              final updated = await Navigator.of(context).push<AccountProgress>(
                                MaterialPageRoute(
                                  builder: (_) => TowerManagementScreen(progress: progress.copy()),
                                ),
                              );
                              if (updated != null) {
                                setState(() => _progress = updated);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPanelButton(
                            label: '건물 관리',
                            icon: Icons.home,
                            borderColor: borderColor,
                            foregroundColor: textColor,
                            backgroundColor: buttonFill,
                            onPressed: () async {
                              final progress = _progress;
                              if (progress == null) return;
                              final updated = await Navigator.of(context).push<AccountProgress>(
                                MaterialPageRoute(
                                  builder: (_) => BuildingManagementScreen(progress: progress.copy()),
                                ),
                              );
                              if (updated != null) {
                                setState(() => _progress = updated);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppPanelButton(
                        label: '테스트맵',
                        icon: Icons.science,
                        borderColor: borderColor,
                        foregroundColor: textColor,
                        backgroundColor: const Color(0xCC183B5C),
                        onPressed: () => _startGame(stageId: 'test_u_stage'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppPanelButton(
                            label: '상점',
                            icon: Icons.shopping_cart,
                            borderColor: borderColor,
                            foregroundColor: textColor,
                            backgroundColor: buttonFill,
                            onPressed: () async {
                              final progress = _progress;
                              if (progress == null) return;
                              final updated = await Navigator.of(context).push<AccountProgress>(
                                MaterialPageRoute(
                                  builder: (_) => ShopScreen(progress: progress.copy()),
                                ),
                              );
                              if (updated != null) {
                                setState(() => _progress = updated);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPanelButton(
                            label: '도움말',
                            icon: Icons.help_outline,
                            borderColor: borderColor,
                            foregroundColor: textColor,
                            backgroundColor: buttonFill,
                            onPressed: () async {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HelpScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppPanelButton(
                            label: '랭킹',
                            icon: Icons.emoji_events,
                            borderColor: borderColor,
                            foregroundColor: textColor,
                            backgroundColor: buttonFill,
                            onPressed: () async {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RankingScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPanelButton(
                            label: '설정',
                            icon: Icons.settings,
                            borderColor: borderColor,
                            foregroundColor: textColor,
                            backgroundColor: buttonFill,
                            onPressed: () async {
                              final progress = _progress;
                              if (progress == null) return;
                              final updated = await Navigator.of(context).push<AccountProgress>(
                                MaterialPageRoute(
                                  builder: (_) => SettingsScreen(
                                    progress: progress.copy(),
                                    debugRankingBuilder: (_) => const DebugRankingSeedScreen(),
                                  ),
                                ),
                              );
                              if (updated != null) {
                                setState(() => _progress = updated);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _TopBar extends StatelessWidget {
  final Color borderColor;
  final AccountProgress? progress;
  final String energyCountdown;
  final VoidCallback onEnergyPlusTap;

  const _TopBar({
    required this.borderColor,
    this.progress,
    required this.energyCountdown,
    required this.onEnergyPlusTap,
  });

  @override
  Widget build(BuildContext context) {
    final gold = progress?.accountGold ?? 0;
    final diamonds = progress?.diamonds ?? 0;
    final energy = progress?.energy ?? 0;
    final maxEnergy = progress?.maxEnergy ?? 20;
    final tickets = progress?.shardDrawTickets ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA0E1930),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(
            icon: Icons.savings,
            label: '$gold',
            accentColor: const Color(0xFFFFC857),
          ),
          _StatItem(
            icon: Icons.diamond,
            label: '$diamonds',
            accentColor: const Color(0xFF58C8FF),
          ),
          Row(
            children: [
              _StatItem(
                icon: Icons.bolt,
                label: '$energy/$maxEnergy',
                subLabel: energyCountdown,
                accentColor: const Color(0xFFFFC857),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onEnergyPlusTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xCC17304B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFC857), width: 1),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 11,
                    color: Color(0xFFFFC857),
                  ),
                ),
              ),
            ],
          ),
          _StatItem(
            icon: Icons.confirmation_number,
            label: '$tickets',
            accentColor: const Color(0xFF8FD3FF),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subLabel;
  final Color? accentColor;

  const _StatItem({
    required this.icon,
    required this.label,
    this.subLabel,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: accentColor ?? const Color(0xFFF3F7FF)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: accentColor ?? const Color(0xFFF3F7FF),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subLabel != null)
              Text(
                subLabel!,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFBFD5FF),
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
