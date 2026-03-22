import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tower_defense/data/repositories/achievement_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/shared/audio_service.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

class AchievementScreen extends StatefulWidget {
  final AccountProgress progress;

  const AchievementScreen({
    super.key,
    required this.progress,
  });

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  static const List<String> _categoryOrder = [
    'all',
    'story',
    'endless',
    'growth',
    'activity',
    'economy',
  ];

  final AchievementRepository _achievementRepo = AchievementRepository();
  late AccountProgress _progress;
  List<AchievementViewData> _achievements = const [];
  bool _loading = true;
  bool _claiming = false;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _progress = widget.progress.copy();
    unawaited(AppAudioService.instance.playBgm(AudioBgmTrack.lobby));
    unawaited(_loadAchievements());
  }

  Future<void> _loadAchievements() async {
    final achievements = await _achievementRepo.load(_progress);
    if (!mounted) return;
    setState(() {
      _achievements = achievements;
      _loading = false;
    });
  }

  Future<void> _claimAchievement(AchievementViewData achievement) async {
    if (_claiming || achievement.claimed || !achievement.completed) return;
    setState(() => _claiming = true);
    final updated = await _achievementRepo.claim(
      progress: _progress,
      achievement: achievement,
    );
    if (!mounted) return;
    _progress = updated;
    _showRewardDialog([achievement]);
    setState(() {
      _achievements = _achievements
          .map(
            (item) => item.definition.id == achievement.definition.id
                ? AchievementViewData(
                    definition: item.definition,
                    currentValue: item.currentValue,
                    claimed: true,
                  )
                : item,
          )
          .toList(growable: false);
      _claiming = false;
    });
    unawaited(AppAudioService.instance.playConfirm());
  }

  Future<void> _claimAllInCategory(List<AchievementViewData> achievements) async {
    final claimable = achievements
        .where((achievement) => achievement.completed && !achievement.claimed)
        .toList(growable: false);
    if (_claiming || claimable.isEmpty) return;

    setState(() => _claiming = true);
    var updatedProgress = _progress;
    for (final achievement in claimable) {
      updatedProgress = await _achievementRepo.claim(
        progress: updatedProgress,
        achievement: achievement,
      );
    }
    if (!mounted) return;
    _progress = updatedProgress;
    _showRewardDialog(claimable);
    final claimableIds = claimable
        .map((achievement) => achievement.definition.id)
        .toSet();
    setState(() {
      _achievements = _achievements
          .map(
            (item) => claimableIds.contains(item.definition.id)
                ? AchievementViewData(
                    definition: item.definition,
                    currentValue: item.currentValue,
                    claimed: true,
                  )
                : item,
          )
          .toList(growable: false);
      _claiming = false;
    });
    unawaited(AppAudioService.instance.playConfirm());
  }

  void _showRewardDialog(List<AchievementViewData> claimedAchievements) {
    if (claimedAchievements.isEmpty) return;
    var gainedGold = 0;
    var gainedDiamonds = 0;
    var gainedTickets = 0;
    for (final achievement in claimedAchievements) {
      gainedGold += achievement.definition.reward.accountGold;
      gainedDiamonds += achievement.definition.reward.diamonds;
      gainedTickets += achievement.definition.reward.shardDrawTickets;
    }

    final rewards = <String>[];
    if (gainedGold > 0) rewards.add('골드 ${_fmtInt(gainedGold)}');
    if (gainedDiamonds > 0) rewards.add('다이아 ${_fmtInt(gainedDiamonds)}');
    if (gainedTickets > 0) rewards.add('티켓 ${_fmtInt(gainedTickets)}');

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF13233B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF83B5FF), width: 1.2),
            ),
            title: const Text(
              '업적 보상 획득',
              style: TextStyle(
                color: Color(0xFFF3F7FF),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              rewards.join('\n'),
              style: const TextStyle(
                color: Color(0xFFD9E7FF),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Color(0xFF8FD3FF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _completedCount(List<AchievementViewData> achievements) {
    return achievements
        .where((achievement) => achievement.completed || achievement.claimed)
        .length;
  }

  String _fmtInt(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final reverseIndex = text.length - i;
      buffer.write(text[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'all' => '전체',
      'story' => '스토리',
      'endless' => '무한',
      'growth' => '성장',
      'activity' => '활동',
      'economy' => '경제',
      _ => '기타',
    };
  }

  String _rewardLabel(AchievementViewData achievement) {
    final reward = achievement.definition.reward;
    final parts = <String>[];
    if (reward.accountGold > 0) parts.add('골드 ${reward.accountGold}');
    if (reward.diamonds > 0) parts.add('다이아 ${reward.diamonds}');
    if (reward.shardDrawTickets > 0) parts.add('티켓 ${reward.shardDrawTickets}');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final filteredAchievements = _selectedCategory == 'all'
        ? _achievements
        : _achievements
            .where(
              (achievement) =>
                  achievement.definition.category == _selectedCategory,
            )
            .toList(growable: false);
    final claimableCount = filteredAchievements
        .where((achievement) => achievement.completed && !achievement.claimed)
        .length;
    final completedCount = _completedCount(filteredAchievements);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pop(_progress);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF091321),
        body: SafeArea(
          child: Column(
            children: [
              AppBar(
                title:
                    Text('업적${claimableCount > 0 ? ' ($claimableCount)' : ''}'),
                backgroundColor: const Color(0xFF0E1A2D),
                foregroundColor: const Color(0xFFF3F7FF),
                elevation: 0,
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF091321), Color(0xFF13233B)],
                    ),
                  ),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8FD3FF),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categoryOrder.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final category = _categoryOrder[index];
                                  final selected =
                                      _selectedCategory == category;
                                  return InkWell(
                                    onTap: () {
                                      setState(
                                        () => _selectedCategory = category,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xCC17304B)
                                            : const Color(0x99223349),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFFFFC857)
                                              : const Color(0xFF83B5FF),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Text(
                                        _categoryLabel(category),
                                        style: TextStyle(
                                          color: selected
                                              ? const Color(0xFFFFE6A6)
                                              : const Color(0xFFD9E7FF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xCC142238),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF83B5FF),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                claimableCount > 0
                                    ? '${_categoryLabel(_selectedCategory)} 탭에서 수령 가능한 업적이 $claimableCount개 있습니다.'
                                    : '${_categoryLabel(_selectedCategory)} 업적을 달성하고 보상을 받아보세요.',
                                style: const TextStyle(
                                  color: Color(0xFFD9E7FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_categoryLabel(_selectedCategory)} 업적 ${completedCount}/${filteredAchievements.length}',
                                    style: const TextStyle(
                                      color: Color(0xFFD9E7FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 116,
                                  child: AppPanelButton(
                                    label: '모두 수령',
                                    borderColor: claimableCount > 0
                                        ? const Color(0xFFFFC857)
                                        : const Color(0xFF5B6D86),
                                    foregroundColor: const Color(0xFFF3F7FF),
                                    backgroundColor: claimableCount > 0
                                        ? const Color(0xCC17304B)
                                        : const Color(0x55304055),
                                    compact: true,
                                    onPressed: claimableCount > 0
                                        ? () => _claimAllInCategory(
                                              filteredAchievements,
                                            )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...filteredAchievements.map((achievement) {
                              final progressRatio =
                                  achievement.definition.target <= 0
                                      ? 0.0
                                      : (achievement.currentValue /
                                              achievement.definition.target)
                                          .clamp(0.0, 1.0);
                              final accent = achievement.claimed
                                  ? const Color(0xFF7EF0B8)
                                  : achievement.completed
                                      ? const Color(0xFFFFC857)
                                      : const Color(0xFF8FD3FF);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC142238),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: accent, width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            achievement.definition.title,
                                            style: const TextStyle(
                                              color: Color(0xFFF3F7FF),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          achievement.claimed
                                              ? '수령 완료'
                                              : achievement.completed
                                                  ? '달성'
                                                  : '${achievement.currentValue}/${achievement.definition.target}',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      achievement.definition.description,
                                      style: const TextStyle(
                                        color: Color(0xFFD9E7FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progressRatio,
                                        minHeight: 8,
                                        backgroundColor:
                                            const Color(0xFF21344F),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _rewardLabel(achievement),
                                            style: const TextStyle(
                                              color: Color(0xFFF3F7FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 108,
                                          child: AppPanelButton(
                                            label: achievement.claimed
                                                ? '완료'
                                                : achievement.completed
                                                    ? '수령'
                                                    : '진행중',
                                            borderColor: accent,
                                            foregroundColor:
                                                const Color(0xFFF3F7FF),
                                            backgroundColor:
                                                achievement.completed
                                                    ? const Color(0xCC17304B)
                                                    : const Color(0x55304055),
                                            compact: true,
                                            onPressed:
                                                (achievement.completed &&
                                                        !achievement.claimed)
                                                    ? () => _claimAchievement(
                                                        achievement,
                                                      )
                                                    : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (filteredAchievements.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC142238),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF83B5FF),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Text(
                                  '해당 탭의 업적이 없습니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFD9E7FF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
