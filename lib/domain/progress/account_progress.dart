import 'package:tower_defense/domain/progress/core_progress.dart';
import 'package:tower_defense/domain/progress/lobby_upgrade_progress.dart';

class TowerProgress {
  final String towerId;
  int level;
  int shards;
  bool unlocked;

  TowerProgress({
    required this.towerId,
    this.level = 1,
    this.shards = 0,
    this.unlocked = true,
  });

  factory TowerProgress.fromJson(Map<String, dynamic> json) {
    return TowerProgress(
      towerId: json['towerId'] as String,
      level: json['level'] as int? ?? 1,
      shards: json['shards'] as int? ?? 0,
      unlocked: json['unlocked'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'towerId': towerId,
      'level': level,
      'shards': shards,
      'unlocked': unlocked,
    };
  }

  TowerProgress copy() {
    return TowerProgress(
      towerId: towerId,
      level: level,
      shards: shards,
      unlocked: unlocked,
    );
  }
}

class AccountProgress {
  String nickname;
  int accountGold;
  int diamonds;
  int energy;
  int maxEnergy;
  int bestInfiniteWave;
  String? _lastEnergyAtIso;
  String? _lastAttendanceDate;
  int? _attendanceDay;
  int? _shardDrawTickets;
  String? _shardDrawDailyDate;
  int? _shardDrawSingleDailyCount;
  int? _shardDrawTenDailyCount;
  String? _adDailyDate;
  int? _adPointResetDailyCount;
  int? _adShardDrawTenDailyCount;
  final List<String> claimedAchievementIds;
  final Map<String, int> bestWaveByDifficulty;
  final Map<String, TowerProgress> towers;
  final Map<String, TowerLobbyUpgradeProgress> lobbyUpgrades;
  final CoreProgress core;

  int get shardDrawTickets => _shardDrawTickets ?? 0;
  set shardDrawTickets(int value) => _shardDrawTickets = value;
  String get lastEnergyAtIso => _lastEnergyAtIso ?? '';
  set lastEnergyAtIso(String value) => _lastEnergyAtIso = value;
  String get lastAttendanceDate => _lastAttendanceDate ?? '';
  set lastAttendanceDate(String value) => _lastAttendanceDate = value;
  int get attendanceDay => _attendanceDay ?? 0;
  set attendanceDay(int value) => _attendanceDay = value;
  String get shardDrawDailyDate => _shardDrawDailyDate ?? '';
  set shardDrawDailyDate(String value) => _shardDrawDailyDate = value;
  int get shardDrawSingleDailyCount => _shardDrawSingleDailyCount ?? 0;
  set shardDrawSingleDailyCount(int value) => _shardDrawSingleDailyCount = value;
  int get shardDrawTenDailyCount => _shardDrawTenDailyCount ?? 0;
  set shardDrawTenDailyCount(int value) => _shardDrawTenDailyCount = value;
  String get adDailyDate => _adDailyDate ?? '';
  set adDailyDate(String value) => _adDailyDate = value;
  int get adPointResetDailyCount => _adPointResetDailyCount ?? 0;
  set adPointResetDailyCount(int value) => _adPointResetDailyCount = value;
  int get adShardDrawTenDailyCount => _adShardDrawTenDailyCount ?? 0;
  set adShardDrawTenDailyCount(int value) => _adShardDrawTenDailyCount = value;

  AccountProgress({
    this.nickname = '',
    this.accountGold = 10000,
    this.diamonds = 1500,
    this.energy = 30,
    this.maxEnergy = 30,
    this.bestInfiniteWave = 0,
    String? lastEnergyAtIso = '',
    String? lastAttendanceDate = '',
    int? attendanceDay = 0,
    int? shardDrawTickets = 20,
    String? shardDrawDailyDate = '',
    int? shardDrawSingleDailyCount = 0,
    int? shardDrawTenDailyCount = 0,
    String? adDailyDate = '',
    int? adPointResetDailyCount = 0,
    int? adShardDrawTenDailyCount = 0,
    List<String>? claimedAchievementIds,
    Map<String, int>? bestWaveByDifficulty,
    Map<String, TowerProgress>? towers,
    Map<String, TowerLobbyUpgradeProgress>? lobbyUpgrades,
    CoreProgress? core,
  })  : _shardDrawTickets = shardDrawTickets ?? 0,
        _lastEnergyAtIso = lastEnergyAtIso ?? '',
        _lastAttendanceDate = lastAttendanceDate ?? '',
        _attendanceDay = attendanceDay ?? 0,
        _shardDrawDailyDate = shardDrawDailyDate ?? '',
        _shardDrawSingleDailyCount = shardDrawSingleDailyCount ?? 0,
        _shardDrawTenDailyCount = shardDrawTenDailyCount ?? 0,
        _adDailyDate = adDailyDate ?? '',
        _adPointResetDailyCount = adPointResetDailyCount ?? 0,
        _adShardDrawTenDailyCount = adShardDrawTenDailyCount ?? 0,
        claimedAchievementIds = claimedAchievementIds ?? <String>[],
        bestWaveByDifficulty = bestWaveByDifficulty ?? {},
        towers = towers ?? {},
        lobbyUpgrades = lobbyUpgrades ?? {},
        core = core ?? CoreProgress();

  factory AccountProgress.fromJson(Map<String, dynamic> json) {
    final towerMap = <String, TowerProgress>{};
    final rawTowers = (json['towers'] as List<dynamic>? ?? []);
    for (final item in rawTowers) {
      final progress = TowerProgress.fromJson(item as Map<String, dynamic>);
      towerMap[progress.towerId] = progress;
    }

    final lobbyMap = <String, TowerLobbyUpgradeProgress>{};
    final rawLobby = json['lobbyUpgrades'] as Map<String, dynamic>? ?? {};
    rawLobby.forEach((towerId, value) {
      if (value is Map<String, dynamic>) {
        lobbyMap[towerId] = TowerLobbyUpgradeProgress.fromJson(towerId, value);
      }
    });
    final bestWaveByDifficulty = <String, int>{};
    final rawBest = json['bestWaveByDifficulty'] as Map<String, dynamic>? ?? {};
    rawBest.forEach((difficultyId, value) {
      if (value is int) {
        bestWaveByDifficulty[difficultyId] = value;
      }
    });

    return AccountProgress(
      nickname: json['nickname'] as String? ?? '',
      accountGold: json['accountGold'] as int? ?? 0,
      diamonds: json['diamonds'] as int? ?? 0,
      energy: json['energy'] as int? ?? 30,
      maxEnergy: json['maxEnergy'] as int? ?? 30,
      bestInfiniteWave: json['bestInfiniteWave'] as int? ?? 0,
      lastEnergyAtIso: json['lastEnergyAtIso'] as String? ?? '',
      lastAttendanceDate: json['lastAttendanceDate'] as String? ?? '',
      attendanceDay: json['attendanceDay'] as int? ?? 0,
      shardDrawTickets: json['shardDrawTickets'] as int? ?? 0,
      shardDrawDailyDate: json['shardDrawDailyDate'] as String? ?? '',
      shardDrawSingleDailyCount: json['shardDrawSingleDailyCount'] as int? ?? 0,
      shardDrawTenDailyCount: json['shardDrawTenDailyCount'] as int? ?? 0,
      adDailyDate: json['adDailyDate'] as String? ?? '',
      adPointResetDailyCount: json['adPointResetDailyCount'] as int? ?? 0,
      adShardDrawTenDailyCount: json['adShardDrawTenDailyCount'] as int? ?? 0,
      claimedAchievementIds:
          (json['claimedAchievementIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      bestWaveByDifficulty: bestWaveByDifficulty,
      towers: towerMap,
      lobbyUpgrades: lobbyMap,
      core: CoreProgress.fromJson(json['core'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'accountGold': accountGold,
      'diamonds': diamonds,
      'energy': energy,
      'maxEnergy': maxEnergy,
      'bestInfiniteWave': bestInfiniteWave,
      'lastEnergyAtIso': lastEnergyAtIso,
      'lastAttendanceDate': lastAttendanceDate,
      'attendanceDay': attendanceDay,
      'shardDrawTickets': shardDrawTickets,
      'shardDrawDailyDate': shardDrawDailyDate,
      'shardDrawSingleDailyCount': shardDrawSingleDailyCount,
      'shardDrawTenDailyCount': shardDrawTenDailyCount,
      'adDailyDate': adDailyDate,
      'adPointResetDailyCount': adPointResetDailyCount,
      'adShardDrawTenDailyCount': adShardDrawTenDailyCount,
      'claimedAchievementIds': claimedAchievementIds,
      'bestWaveByDifficulty': bestWaveByDifficulty,
      'towers': towers.values.map((e) => e.toJson()).toList(),
      'lobbyUpgrades': {
        for (final entry in lobbyUpgrades.entries) entry.key: entry.value.toJson(),
      },
      'core': core.toJson(),
    };
  }

  AccountProgress copy() {
    final copyTowers = <String, TowerProgress>{};
    for (final entry in towers.entries) {
      copyTowers[entry.key] = entry.value.copy();
    }

    final copyLobby = <String, TowerLobbyUpgradeProgress>{};
    for (final entry in lobbyUpgrades.entries) {
      copyLobby[entry.key] = entry.value.copy();
    }

    return AccountProgress(
      nickname: nickname,
      accountGold: accountGold,
      diamonds: diamonds,
      energy: energy,
      maxEnergy: maxEnergy,
      bestInfiniteWave: bestInfiniteWave,
      lastEnergyAtIso: lastEnergyAtIso,
      lastAttendanceDate: lastAttendanceDate,
      attendanceDay: attendanceDay,
      shardDrawTickets: shardDrawTickets,
      shardDrawDailyDate: shardDrawDailyDate,
      shardDrawSingleDailyCount: shardDrawSingleDailyCount,
      shardDrawTenDailyCount: shardDrawTenDailyCount,
      adDailyDate: adDailyDate,
      adPointResetDailyCount: adPointResetDailyCount,
      adShardDrawTenDailyCount: adShardDrawTenDailyCount,
      claimedAchievementIds: List<String>.from(claimedAchievementIds),
      bestWaveByDifficulty: Map<String, int>.from(bestWaveByDifficulty),
      towers: copyTowers,
      lobbyUpgrades: copyLobby,
      core: core.copy(),
    );
  }
}
