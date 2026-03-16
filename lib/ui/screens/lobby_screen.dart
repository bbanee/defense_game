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
import 'package:url_launcher/url_launcher.dart';

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
  static const bool _showTestMapButton = false;
  static final Uri _officialHomepageUri = Uri.parse('https://www.opentheday.site/');
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
    final attendanceRewards = await _definitionRepo.loadAttendanceRewards();
    final attendanceResult = _applyAttendanceCheck(
      data,
      attendanceRewards,
    );
    if (changed) {
      await _progressRepo.save(data);
    }
    if (attendanceResult != null) {
      await _progressRepo.save(data);
    }
    if (!mounted) return;
    _normalizeSelections(data);
    setState(() => _progress = data);
    if (attendanceResult != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAttendanceDialog(
          day: attendanceResult.day,
          claimedReward: attendanceResult.reward,
          rewards: attendanceRewards,
        );
      });
    }
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

  _AttendanceClaimResult? _applyAttendanceCheck(
    AccountProgress progress,
    List<Map<String, dynamic>> rewards,
  ) {
    if (rewards.isEmpty) return null;
    final today = _todayKey();
    if (progress.lastAttendanceDate == today) {
      return null;
    }

    final nextDay = (progress.attendanceDay % rewards.length) + 1;
    final reward = rewards.firstWhere(
      (entry) => (entry['day'] as int? ?? 0) == nextDay,
      orElse: () => rewards.first,
    );
    _applyAttendanceReward(progress, reward);
    progress.lastAttendanceDate = today;
    progress.attendanceDay = nextDay;
    return _AttendanceClaimResult(day: nextDay, reward: reward);
  }

  void _applyAttendanceReward(
    AccountProgress progress,
    Map<String, dynamic> reward,
  ) {
    final type = reward['type'] as String? ?? '';
    final amount = reward['amount'] as int? ?? 0;
    switch (type) {
      case 'accountGold':
        progress.accountGold += amount;
        break;
      case 'diamonds':
        progress.diamonds += amount;
        break;
      case 'shardDrawTickets':
        progress.shardDrawTickets += amount;
        break;
      case 'energy':
        progress.energy += amount;
        break;
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  String _attendanceRewardLabel(Map<String, dynamic> reward) {
    return reward['label'] as String? ?? '';
  }

  IconData _attendanceRewardIcon(String type) {
    return switch (type) {
      'accountGold' => Icons.savings_rounded,
      'diamonds' => Icons.diamond_rounded,
      'shardDrawTickets' => Icons.confirmation_number_rounded,
      'energy' => Icons.bolt_rounded,
      _ => Icons.card_giftcard_rounded,
    };
  }

  Color _attendanceRewardColor(String type) {
    return switch (type) {
      'accountGold' => const Color(0xFFFFC857),
      'diamonds' => const Color(0xFF5EC7FF),
      'shardDrawTickets' => const Color(0xFF7EF0B8),
      'energy' => const Color(0xFFFF8A65),
      _ => const Color(0xFFD9E7FF),
    };
  }

  Future<void> _showAttendanceDialog({
    required int day,
    required Map<String, dynamic> claimedReward,
    required List<Map<String, dynamic>> rewards,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            height: screenHeight * 0.66,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF102033),
                borderRadius: BorderRadius.circular(22),
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
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF5EC7FF),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '출석체크 완료',
                    style: TextStyle(
                      color: Color(0xFFF3F7FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$day일차 보상: ${_attendanceRewardLabel(claimedReward)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD9E7FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: GridView.builder(
                      itemCount: rewards.length,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1.12,
                      ),
                      itemBuilder: (context, index) {
                        final reward = rewards[index];
                        final rewardDay = reward['day'] as int? ?? index + 1;
                        final claimed = rewardDay <= day;
                        final today = rewardDay == day;
                        final type = reward['type'] as String? ?? '';
                        final accent = _attendanceRewardColor(type);
                        return Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: today
                                ? const Color(0xCC17304B)
                                : const Color(0xCC142238),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: today
                                  ? accent
                                  : claimed
                                      ? const Color(0x667DB7FF)
                                      : const Color(0x33476888),
                              width: today ? 1.4 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$rewardDay일차',
                                style: TextStyle(
                                  color: today
                                      ? const Color(0xFFF3F7FF)
                                      : claimed
                                          ? const Color(0xFFD9E7FF)
                                          : const Color(0xFF8EA5C8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Icon(
                                _attendanceRewardIcon(type),
                                color: accent,
                                size: 15,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _attendanceRewardLabel(reward),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: claimed
                                      ? const Color(0xFFF3F7FF)
                                      : const Color(0xFFA6B9D8),
                                  fontSize: 8.5,
                                  fontWeight: today ? FontWeight.w800 : FontWeight.w700,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
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
      },
    );
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

  bool _isNormalUnlocked(AccountProgress progress) {
    return (progress.bestWaveByDifficulty['easy'] ?? 0) >= 40;
  }

  bool _isHardUnlocked(AccountProgress progress) {
    return (progress.bestWaveByDifficulty['normal'] ?? 0) >= 50;
  }

  bool _isInfiniteUnlocked(AccountProgress progress) {
    return (progress.bestWaveByDifficulty['easy'] ?? 0) >= 30;
  }

  void _normalizeSelections(AccountProgress progress) {
    if (_gameMode == '무한 모드' && !_isInfiniteUnlocked(progress)) {
      _gameMode = '스토리 모드';
    }
    if (_difficulty == '하드 모드' && !_isHardUnlocked(progress)) {
      _difficulty = _isNormalUnlocked(progress) ? '노멀 모드' : '이지 모드';
    }
    if (_difficulty == '노멀 모드' && !_isNormalUnlocked(progress)) {
      _difficulty = '이지 모드';
    }
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

  String _formatCompactAmount(int value) {
    if (value >= 1000000) {
      final compact = value / 1000000;
      return compact >= 10 ? '${compact.toStringAsFixed(0)}M' : '${compact.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final compact = value / 1000;
      return compact >= 10 ? '${compact.toStringAsFixed(0)}K' : '${compact.toStringAsFixed(1)}K';
    }
    return '$value';
  }

  Future<void> _startGame({String stageId = 'story_01'}) async {
    final progress = _progress;
    if (progress == null) return;
    if (_gameMode == '무한 모드' && !_isInfiniteUnlocked(progress)) {
      await _showStyledNoticeDialog(
        title: '무한 모드 잠김',
        body: '무한 모드는 이지모드 30웨이브 클리어 후 오픈됩니다.',
      );
      return;
    }
    if (_gameMode == '스토리 모드') {
      if (_difficulty == '노멀 모드' && !_isNormalUnlocked(progress)) {
        await _showStyledNoticeDialog(
          title: '노멀 모드 잠김',
          body: '노멀 모드는 이지모드 40웨이브 클리어 후 오픈됩니다.',
        );
        return;
      }
      if (_difficulty == '하드 모드' && !_isHardUnlocked(progress)) {
        await _showStyledNoticeDialog(
          title: '하드 모드 잠김',
          body: '하드 모드는 노멀모드 50웨이브 클리어 후 오픈됩니다.',
        );
        return;
      }
    }
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
    _normalizeSelections(refreshed);
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
    final action = await showDialog<String>(
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
                '에너지 5개를 얻는 방법을 선택하세요.',
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
                      label: '닫기',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0x99122336),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppPanelButton(
                      label: '다이아(50)',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0xCC17304B),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop('diamond'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppPanelButton(
                      label: '광고보고 얻기',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0xCC14405C),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop('ad'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;
    if (action == 'diamond') {
      if (progress.diamonds < diamondCost) {
        await _showStyledNoticeDialog(
          title: '다이아 부족',
          body: '에너지 $energyAmount개 구매에는 다이아 $diamondCost개가 필요합니다.',
        );
        return;
      }
      setState(() {
        progress.diamonds -= diamondCost;
        progress.energy += energyAmount;
      });
    } else if (action == 'ad') {
      setState(() {
        progress.energy += energyAmount;
      });
    } else {
      return;
    }
    await _progressRepo.save(progress);
  }

  Future<void> _openOfficialHomepage() async {
    final opened = await launchUrl(
      _officialHomepageUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      await _showStyledNoticeDialog(
        title: '홈페이지 열기 실패',
        body: '공식 홈페이지를 열 수 없습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = const Color(0xFF8CB8FF);
    final bgColor = const Color(0xFF07111F);
    final textColor = const Color(0xFFF3F7FF);
    final panelFill = const Color(0xB0122136);
    final buttonFill = const Color(0xCC16304D);
    final progress = _progress;
    final normalUnlocked = progress != null && _isNormalUnlocked(progress);
    final hardUnlocked = progress != null && _isHardUnlocked(progress);
    final infiniteUnlocked = progress != null && _isInfiniteUnlocked(progress);

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
                              goldLabel: _formatCompactAmount(_progress?.accountGold ?? 0),
                              diamondLabel: _formatCompactAmount(_progress?.diamonds ?? 0),
                              ticketLabel: _formatCompactAmount(_progress?.shardDrawTickets ?? 0),
                              energyLabel: '${_progress?.energy ?? 0}/${_progress?.maxEnergy ?? 20}',
                              energyCountdown: _energyCountdownLabel(_progress),
                              onEnergyPlusTap: _buyEnergyQuick,
                              onAttendanceTap: () async {
                                final rewards = await _definitionRepo.loadAttendanceRewards();
                                if (!mounted) return;
                                await _showAttendanceDialog(
                                  day: _progress?.attendanceDay ?? 0,
                                  claimedReward: rewards[(_progress?.attendanceDay ?? 1).clamp(1, rewards.length) - 1],
                                  rewards: rewards,
                                );
                              },
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
                        SizedBox(
                          width: _LobbyFieldLabelWidth.value,
                          child: Text(
                            '모드',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPanelBox(
                            borderColor: borderColor,
                            backgroundColor: panelFill,
                            borderRadius: BorderRadius.circular(14),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.layers_rounded, size: 14, color: Color(0xFF8FD3FF)),
                                const SizedBox(width: 8),
                                Expanded(
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
                                      items: [
                                        const DropdownMenuItem(
                                          value: '스토리 모드',
                                          child: Text('스토리 모드'),
                                        ),
                                        DropdownMenuItem(
                                          value: '무한 모드',
                                          enabled: infiniteUnlocked,
                                          child: Text(
                                            infiniteUnlocked
                                                ? '무한 모드'
                                                : '무한 모드 (잠김)',
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _gameMode = value);
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
                    if (_gameMode == '스토리 모드') ...[
                    Row(
                      children: [
                        SizedBox(
                          width: _LobbyFieldLabelWidth.value,
                          child: Text(
                            '난이도',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
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
                                      items: [
                                        const DropdownMenuItem(
                                          value: '이지 모드',
                                          child: Text('이지 모드'),
                                        ),
                                        DropdownMenuItem(
                                          value: '노멀 모드',
                                          enabled: normalUnlocked,
                                          child: Text(
                                            normalUnlocked
                                                ? '노멀 모드'
                                                : '노멀 모드 (잠김)',
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: '하드 모드',
                                          enabled: hardUnlocked,
                                          child: Text(
                                            hardUnlocked
                                                ? '하드 모드'
                                                : '하드 모드 (잠김)',
                                          ),
                                        ),
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
                    if (_showTestMapButton) ...[
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
                    ],
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppPanelButton(
                        label: '공식 홈페이지',
                        icon: Icons.language,
                        borderColor: borderColor,
                        foregroundColor: textColor,
                        backgroundColor: const Color(0xCC14405C),
                        onPressed: _openOfficialHomepage,
                      ),
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

class _LobbyFieldLabelWidth {
  static const double value = 58;

  const _LobbyFieldLabelWidth();
}

class _TopBar extends StatelessWidget {
  final Color borderColor;
  final String goldLabel;
  final String diamondLabel;
  final String ticketLabel;
  final String energyLabel;
  final String energyCountdown;
  final VoidCallback onEnergyPlusTap;
  final VoidCallback onAttendanceTap;

  const _TopBar({
    required this.borderColor,
    required this.goldLabel,
    required this.diamondLabel,
    required this.ticketLabel,
    required this.energyLabel,
    required this.energyCountdown,
    required this.onEnergyPlusTap,
    required this.onAttendanceTap,
  });

  @override
  Widget build(BuildContext context) {
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
            label: goldLabel,
            accentColor: const Color(0xFFFFC857),
          ),
          _StatItem(
            icon: Icons.diamond,
            label: diamondLabel,
            accentColor: const Color(0xFF58C8FF),
          ),
          Row(
            children: [
              _StatItem(
                icon: Icons.bolt,
                label: energyLabel,
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
            label: ticketLabel,
            accentColor: const Color(0xFF8FD3FF),
          ),
          InkWell(
            onTap: onAttendanceTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xCC17304B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 13,
                color: Color(0xFF8FD3FF),
              ),
            ),
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

class _AttendanceClaimResult {
  final int day;
  final Map<String, dynamic> reward;

  const _AttendanceClaimResult({
    required this.day,
    required this.reward,
  });
}
