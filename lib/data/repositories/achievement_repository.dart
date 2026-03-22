import 'dart:async';

import 'package:tower_defense/data/definition_repository.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/data/repositories/analytics_repository.dart';
import 'package:tower_defense/data/repositories/economy_log_repository.dart';
import 'package:tower_defense/domain/models/definitions.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';

class AchievementViewData {
  final AchievementDef definition;
  final int currentValue;
  final bool claimed;

  const AchievementViewData({
    required this.definition,
    required this.currentValue,
    required this.claimed,
  });

  bool get completed => currentValue >= definition.target;
}

class AchievementRepository {
  static List<AchievementDef>? _definitionCache;
  static Map<String, dynamic>? _opsStatsCache;
  static Map<String, List<AchievementViewData>> _viewCacheBySignature = {};
  final DefinitionRepository _definitionRepo;
  final AccountProgressRepository _progressRepo;
  final AnalyticsRepository _analyticsRepo;
  final EconomyLogRepository _economyLogRepo;

  AchievementRepository({
    DefinitionRepository? definitionRepository,
    AccountProgressRepository? progressRepository,
    AnalyticsRepository? analyticsRepository,
    EconomyLogRepository? economyLogRepository,
  })  : _definitionRepo = definitionRepository ?? const DefinitionRepository(),
        _progressRepo = progressRepository ?? AccountProgressRepository(),
        _analyticsRepo = analyticsRepository ?? AnalyticsRepository(),
        _economyLogRepo = economyLogRepository ?? EconomyLogRepository();

  static void invalidateStatsCache() {
    _opsStatsCache = null;
    _viewCacheBySignature.clear();
  }

  static void applyStatsDelta(Map<String, int> delta) {
    final next = Map<String, dynamic>.from(_opsStatsCache ?? const <String, dynamic>{});
    delta.forEach((key, value) {
      final current = next[key];
      final currentInt = current is int ? current : int.tryParse('$current') ?? 0;
      next[key] = currentInt + value;
    });
    _opsStatsCache = next;
    _viewCacheBySignature.clear();
  }

  Future<List<AchievementViewData>> load(AccountProgress progress) async {
    final signature = _signatureFor(progress);
    final memoryCached = _viewCacheBySignature[signature];
    if (memoryCached != null && memoryCached.isNotEmpty) {
      return List<AchievementViewData>.from(memoryCached);
    }
    return refresh(progress);
  }

  Future<List<AchievementViewData>> refresh(AccountProgress progress) async {
    final definitions = _definitionCache ?? await _definitionRepo.loadAchievements();
    _definitionCache = definitions;
    final opsStats = await _loadOpsStatsCached();
    final stats = _buildAchievementStats(progress, opsStats);
    final results = definitions
        .map(
          (definition) => AchievementViewData(
            definition: definition,
            currentValue: stats[definition.statKey] ?? 0,
            claimed: progress.claimedAchievementIds.contains(definition.id),
          ),
        )
        .toList(growable: false);
    _viewCacheBySignature[_signatureFor(progress)] = results;
    return results;
  }

  Future<AccountProgress> claim({
    required AccountProgress progress,
    required AchievementViewData achievement,
  }) async {
    if (achievement.claimed || !achievement.completed) {
      return progress;
    }

    final updated = progress.copy();
    updated.claimedAchievementIds.add(achievement.definition.id);
    updated.accountGold += achievement.definition.reward.accountGold;
    updated.diamonds += achievement.definition.reward.diamonds;
    updated.shardDrawTickets += achievement.definition.reward.shardDrawTickets;
    invalidateStatsCache();
    unawaited(_progressRepo.save(updated));

    if (achievement.definition.reward.accountGold > 0) {
      unawaited(
        _economyLogRepo.logCurrencyChange(
          source: 'achievement_reward',
          currency: 'accountGold',
          amount: achievement.definition.reward.accountGold,
          balanceAfter: updated.accountGold,
          metadata: {'achievementId': achievement.definition.id},
        ),
      );
    }
    if (achievement.definition.reward.diamonds > 0) {
      unawaited(
        _economyLogRepo.logCurrencyChange(
          source: 'achievement_reward',
          currency: 'diamonds',
          amount: achievement.definition.reward.diamonds,
          balanceAfter: updated.diamonds,
          metadata: {'achievementId': achievement.definition.id},
        ),
      );
    }
    if (achievement.definition.reward.shardDrawTickets > 0) {
      unawaited(
        _economyLogRepo.logCurrencyChange(
          source: 'achievement_reward',
          currency: 'shardDrawTickets',
          amount: achievement.definition.reward.shardDrawTickets,
          balanceAfter: updated.shardDrawTickets,
          metadata: {'achievementId': achievement.definition.id},
        ),
      );
    }
    return updated;
  }

  Future<void> warmUp(AccountProgress progress) async {
    await refresh(progress);
  }

  Map<String, int> _buildAchievementStats(
    AccountProgress progress,
    Map<String, dynamic> opsStats,
  ) {
    final unlockedTowerCount =
        progress.towers.values.where((tower) => tower.unlocked).length;
    final totalTowerLevel = progress.towers.values
        .where((tower) => tower.unlocked)
        .fold<int>(0, (sum, tower) => sum + tower.level);

    int stat(String key) {
      final value = opsStats[key];
      if (value is int) return value;
      return int.tryParse('$value') ?? 0;
    }

    return {
      'bestWaveEasy': progress.bestWaveByDifficulty['easy'] ?? 0,
      'bestWaveNormal': progress.bestWaveByDifficulty['normal'] ?? 0,
      'bestWaveHard': progress.bestWaveByDifficulty['hard'] ?? 0,
      'bestInfiniteWave': progress.bestInfiniteWave,
      'unlockedTowerCount': unlockedTowerCount,
      'totalTowerLevel': totalTowerLevel,
      'coreLevel': progress.core.level,
      'totalBattles': stat('totalBattles'),
      'victoryCount': stat('victoryCount'),
      'totalGoldEarned': stat('totalGoldEarned'),
      'totalDiamondsSpent': stat('totalDiamondsSpent'),
      'shardDrawCount': stat('shardDrawCount'),
      'totalAdsRewarded': stat('totalAdsRewarded'),
    };
  }

  Future<Map<String, dynamic>> _loadOpsStatsCached() async {
    final cached = _opsStatsCache;
    if (cached != null) return cached;
    final loaded = await _analyticsRepo.loadOpsStats();
    _opsStatsCache = loaded;
    return loaded;
  }

  String _signatureFor(AccountProgress progress) {
    final unlockedTowerCount =
        progress.towers.values.where((tower) => tower.unlocked).length;
    final totalTowerLevel = progress.towers.values
        .where((tower) => tower.unlocked)
        .fold<int>(0, (sum, tower) => sum + tower.level);
    return [
      progress.bestWaveByDifficulty['easy'] ?? 0,
      progress.bestWaveByDifficulty['normal'] ?? 0,
      progress.bestWaveByDifficulty['hard'] ?? 0,
      progress.bestInfiniteWave,
      unlockedTowerCount,
      totalTowerLevel,
      progress.core.level,
      progress.claimedAchievementIds.join(','),
    ].join('|');
  }
}
