import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tower_defense/data/definition_repository.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/data/repositories/balance_repository.dart';
import 'package:tower_defense/domain/models/definitions.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/domain/progress/lobby_upgrade_progress.dart';
import 'package:tower_defense/shared/tower_visual_fx.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

part 'tower_management_screen_view.part.dart';
part 'tower_management_screen_logic.part.dart';


const List<String> kTowerIds = [
  'cannon_basic',
  'rapid_basic',
  'shotgun_basic',
  'frost_basic',
  'drone_basic',
  'chain_basic',
  'missile_basic',
  'support_basic',
  'laser_basic',
  'sniper_basic',
  'gravity_basic',
  'infection_basic',
  'chrono_basic',
  'singularity_basic',
  'mortar_basic',
];

Color _rarityColor(String? rarity) {
  return switch (rarity) {
    'common' => const Color(0xFF6C63FF),
    'rare' => const Color(0xFF00D2A5),
    'unique' => const Color(0xFFB85BFF),
    'legendary' => const Color(0xFFFFC857),
    _ => const Color(0xFF7A7A7A),
  };
}

String _towerDisplayName(String id) {
  return switch (id) {
    'cannon_basic' => 'Pulse Turret',
    'rapid_basic' => 'Railguard Battery',
    'shotgun_basic' => 'Scatter Blaster',
    'frost_basic' => 'Frost Relay',
    'drone_basic' => 'Drone Dock',
    'chain_basic' => 'Tesla Arc Node',
    'missile_basic' => 'Missile Matrix',
    'support_basic' => 'Nano Support Beacon',
    'laser_basic' => 'Prism Laser Array',
    'sniper_basic' => 'Holo Sniper Spire',
    'gravity_basic' => 'Gravity Well Emitter',
    'infection_basic' => 'Virus Injector',
    'chrono_basic' => 'Chrono Distortion Core',
    'singularity_basic' => 'Singularity Cannon',
    'mortar_basic' => 'Aegis AI Citadel',
    _ => id,
  };
}

String _towerDisplayNameKo(String id) {
  return switch (id) {
    'cannon_basic' => '캐논 터렛',
    'rapid_basic' => '래피드 포탑',
    'shotgun_basic' => '샷건 포탑',
    'frost_basic' => '프로스트 타워',
    'drone_basic' => '드론 기지',
    'chain_basic' => '체인 노드',
    'missile_basic' => '미사일 매트릭스',
    'support_basic' => '서포트 비콘',
    'laser_basic' => '레이저 어레이',
    'sniper_basic' => '스나이퍼 스파이어',
    'gravity_basic' => '그래비티 웰',
    'infection_basic' => '인펙션 인젝터',
    'chrono_basic' => '크로노 코어',
    'singularity_basic' => '싱귤래리티 캐논',
    'mortar_basic' => '모르타 시타델',
    _ => id,
  };
}

class TowerManagementScreen extends StatefulWidget {
  final AccountProgress progress;

  const TowerManagementScreen({super.key, required this.progress});

  @override
  State<TowerManagementScreen> createState() => _TowerManagementScreenState();
}

class _TowerManagementScreenState extends State<TowerManagementScreen> {
  late AccountProgress progress;
  final DefinitionRepository repo = DefinitionRepository();
  final BalanceRepository balanceRepo = BalanceRepository();
  final Map<String, TowerDef> towerDefs = {};
  final AccountProgressRepository progressRepo = AccountProgressRepository();
  Map<String, dynamic>? lobbyConfig;
  Map<String, dynamic>? lobbyPresets;
  BalanceConfig? balanceConfig;

  @override
  void initState() {
    super.initState();
    progress = widget.progress;
    _loadDefs();
  }

  Future<void> _loadDefs() async {
    final defs = <String, TowerDef>{};
    for (final id in kTowerIds) {
      defs[id] = await repo.loadTower(id);
    }
    BalanceConfig? loadedBalance;
    try {
      loadedBalance = await balanceRepo.load();
    } catch (_) {
      loadedBalance = const BalanceConfig(
        defaultPermanentGrowth: PermanentGrowthConfig(
          damagePercentPerLevel: 0.06,
          fireRatePercentPerLevel: 0.03,
          rangeBonusEveryLevels: 4,
          rangeBonusPerStep: 0.15,
        ),
        core: CoreBalanceConfig(
          hp: CoreUpgradeTrack(
            baseCost: 3000,
            costMultiplier: 1.55,
            maxLevel: 15,
            growthMultiplier: 1.02,
          ),
          shield: CoreUpgradeTrack(
            baseCost: 5000,
            costMultiplier: 1.68,
            maxLevel: 15,
            growthMultiplier: 1.03,
          ),
          defense: CoreUpgradeTrack(
            baseCost: 10000,
            costMultiplier: 1.85,
            maxLevel: 15,
            flatIncrease: 0.008,
            cap: 0.45,
          ),
        ),
        towerGrowthOverrides: {},
      );
    }
    Map<String, dynamic>? config;
    Map<String, dynamic>? presets;
    try {
      config = await repo.loadLobbyUpgradeConfig();
      presets = await repo.loadLobbyUpgradePresets();
      final defaultState = await repo.loadLobbyUpgradeDefaultState();
      final rawDefault = defaultState['playerLobbyUpgrades'] as Map<String, dynamic>? ?? {};
      rawDefault.forEach((towerId, value) {
        if (value is Map<String, dynamic> && !progress.lobbyUpgrades.containsKey(towerId)) {
          progress.lobbyUpgrades[towerId] = TowerLobbyUpgradeProgress.fromJson(towerId, value);
        }
      });
      for (final towerId in kTowerIds) {
        final p = progress.towers[towerId] ?? TowerProgress(towerId: towerId, unlocked: false);
        final lp = progress.lobbyUpgrades[towerId] ??
            TowerLobbyUpgradeProgress(towerId: towerId);
        _normalizeLobbyPoints(p, lp, (config['maxTrackLevel'] as int?) ?? 15);
        progress.towers[towerId] = p;
        progress.lobbyUpgrades[towerId] = lp;
      }
    } catch (_) {
      config = {'maxTrackLevel': 15, 'costCurve': {'base': 10, 'growth': 1.22, 'rarityMultiplier': {}}};
      presets = const {'towers': {}};
      for (final towerId in kTowerIds) {
        final p = progress.towers[towerId] ?? TowerProgress(towerId: towerId, unlocked: false);
        final lp = progress.lobbyUpgrades[towerId] ??
            TowerLobbyUpgradeProgress(towerId: towerId);
        _normalizeLobbyPoints(p, lp, 15);
        progress.towers[towerId] = p;
        progress.lobbyUpgrades[towerId] = lp;
      }
    }
    if (!mounted) return;
    setState(() {
      towerDefs.addAll(defs);
      lobbyConfig = config;
      lobbyPresets = presets;
      balanceConfig = loadedBalance;
    });
  }

  Future<void> _exitScreen() async {
    await progressRepo.save(progress);
    if (!mounted) return;
    Navigator.of(context).pop(progress);
  }

  @override
  Widget build(BuildContext context) {
    final orderedIds = _orderedTowerIds();
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _exitScreen();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('타워 관리'),
          backgroundColor: const Color(0xFF0E1A2D),
          foregroundColor: const Color(0xFFF3F7FF),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF091321), Color(0xFF13233B)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: towerDefs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xCC142238),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF83B5FF)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield_moon, color: Color(0xFF83B5FF)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '보유 골드 ${progress.accountGold}  |  타워를 눌러 강화',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF3F7FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF83B5FF), width: 2),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xCC122138), Color(0xCC1A2E4A)],
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: orderedIds.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 0,
                                  crossAxisSpacing: 0,
                                  childAspectRatio: 0.62,
                                ),
                                itemBuilder: (context, index) {
                                  final towerId = orderedIds[index];
                                  final def = towerDefs[towerId];
                                  if (def == null) return const SizedBox.shrink();
                                  return _towerGridTile(def);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: AppPanelButton(
                          label: '로비로 돌아가기',
                          borderColor: const Color(0xFF83B5FF),
                          foregroundColor: const Color(0xFFF3F7FF),
                          backgroundColor: const Color(0x99122336),
                          onPressed: _exitScreen,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

}
