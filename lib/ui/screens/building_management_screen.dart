import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/data/repositories/balance_repository.dart';
import 'package:tower_defense/data/repositories/economy_log_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/domain/progress/core_progress.dart';
import 'package:tower_defense/shared/ad_service.dart';
import 'package:tower_defense/shared/audio_service.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

class BuildingManagementScreen extends StatefulWidget {
  final AccountProgress progress;

  const BuildingManagementScreen({super.key, required this.progress});

  @override
  State<BuildingManagementScreen> createState() =>
      _BuildingManagementScreenState();
}

class _BuildingManagementScreenState extends State<BuildingManagementScreen> {
  late AccountProgress progress;
  final AccountProgressRepository progressRepo = AccountProgressRepository();
  final BalanceRepository balanceRepo = BalanceRepository();
  final EconomyLogRepository economyLogRepo = EconomyLogRepository();
  CoreBalanceConfig? coreBalance;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    unawaited(AppAudioService.instance.playBgm(AudioBgmTrack.lobby));
    progress = widget.progress;
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final config = await balanceRepo.load();
      if (!mounted) return;
      setState(() => coreBalance = config.core);
    } catch (_) {
      if (!mounted) return;
      setState(() => coreBalance = CoreBalanceConfig.fromJson(const {}));
    }
  }

  Future<void> _exitScreen() async {
    if (_isExiting) return;
    _isExiting = true;
    final snapshot = progress.copy();
    final navigator = Navigator.of(context);
    unawaited(AppAudioService.instance.stopAllSfx());
    if (navigator.canPop()) {
      navigator.pop(snapshot);
    }
    unawaited(progressRepo.save(snapshot));
  }

  @override
  void dispose() {
    unawaited(AppAudioService.instance.stopAllSfx());
    super.dispose();
  }

  CoreBalanceConfig get _coreBalance =>
      coreBalance ?? CoreBalanceConfig.fromJson(const {});
  int get _hpCost => _coreBalance.hp.costForLevel(progress.core.hpLevel);
  int get _shieldCost =>
      _coreBalance.shield.costForLevel(progress.core.shieldLevel);
  int get _defenseCost =>
      _coreBalance.defense.costForLevel(progress.core.defenseLevel);
  bool get _isHpMax => progress.core.hpLevel >= _coreBalance.hp.maxLevel;
  bool get _isShieldMax =>
      progress.core.shieldLevel >= _coreBalance.shield.maxLevel;
  bool get _isDefenseMax =>
      progress.core.defenseLevel >= _coreBalance.defense.maxLevel;

  Future<void> _upgradeHp() async {
    if (_isHpMax) return;
    final balance = _coreBalance;
    final core = progress.core;
    final cost = _hpCost;
    if (progress.accountGold < cost) {
      unawaited(AppAudioService.instance.playError());
      await _showNoticeDialog(
        title: '골드 부족',
        body: '내구 보강 강화에는 ${_fmtInt(cost)} 골드가 필요합니다.',
      );
      return;
    }
    final previousLevel = core.hpLevel;
    setState(() {
      progress.accountGold -= cost;
      core.hpLevel += 1;
      core.level += 1;
      core.hp = (core.hp * (balance.hp.growthMultiplier ?? 1.04)).round();
    });
    unawaited(AppAudioService.instance.playTowerUpgrade());
    if (core.hpLevel != previousLevel) {
      economyLogRepo.logCurrencyChange(
        source: 'core_upgrade_hp',
        currency: 'accountGold',
        amount: -cost,
        balanceAfter: progress.accountGold,
        metadata: {'toLevel': core.hpLevel},
      );
      economyLogRepo.logUpgrade(
        upgradeType: 'core_hp',
        targetId: 'core',
        fromLevel: previousLevel,
        toLevel: core.hpLevel,
      );
    }
  }

  Future<void> _upgradeShield() async {
    if (_isShieldMax) return;
    final balance = _coreBalance;
    final core = progress.core;
    final cost = _shieldCost;
    if (progress.accountGold < cost) {
      unawaited(AppAudioService.instance.playError());
      await _showNoticeDialog(
        title: '골드 부족',
        body: '실드 증폭 강화에는 ${_fmtInt(cost)} 골드가 필요합니다.',
      );
      return;
    }
    final previousLevel = core.shieldLevel;
    setState(() {
      progress.accountGold -= cost;
      core.shieldLevel += 1;
      core.level += 1;
      core.shield =
          (core.shield * (balance.shield.growthMultiplier ?? 1.035)).round();
    });
    unawaited(AppAudioService.instance.playTowerUpgrade());
    if (core.shieldLevel != previousLevel) {
      economyLogRepo.logCurrencyChange(
        source: 'core_upgrade_shield',
        currency: 'accountGold',
        amount: -cost,
        balanceAfter: progress.accountGold,
        metadata: {'toLevel': core.shieldLevel},
      );
      economyLogRepo.logUpgrade(
        upgradeType: 'core_shield',
        targetId: 'core',
        fromLevel: previousLevel,
        toLevel: core.shieldLevel,
      );
    }
  }

  Future<void> _upgradeDefense() async {
    if (_isDefenseMax) return;
    final balance = _coreBalance;
    final core = progress.core;
    final cost = _defenseCost;
    if (progress.accountGold < cost) {
      unawaited(AppAudioService.instance.playError());
      await _showNoticeDialog(
        title: '골드 부족',
        body: '방어 계수 강화에는 ${_fmtInt(cost)} 골드가 필요합니다.',
      );
      return;
    }
    final previousLevel = core.defenseLevel;
    setState(() {
      progress.accountGold -= cost;
      core.defenseLevel += 1;
      core.level += 1;
      core.defenseRate =
          (core.defenseRate + (balance.defense.flatIncrease ?? 0.005))
              .clamp(0, balance.defense.cap ?? 0.45);
    });
    unawaited(AppAudioService.instance.playTowerUpgrade());
    if (core.defenseLevel != previousLevel) {
      economyLogRepo.logCurrencyChange(
        source: 'core_upgrade_defense',
        currency: 'accountGold',
        amount: -cost,
        balanceAfter: progress.accountGold,
        metadata: {'toLevel': core.defenseLevel},
      );
      economyLogRepo.logUpgrade(
        upgradeType: 'core_defense',
        targetId: 'core',
        fromLevel: previousLevel,
        toLevel: core.defenseLevel,
      );
    }
  }

  int _spentGoldForTrack(CoreUpgradeTrack track, int currentLevel) {
    if (currentLevel <= 1) return 0;
    int total = 0;
    for (int level = 1; level < currentLevel; level++) {
      total += track.costForLevel(level);
    }
    return total;
  }

  int get _buildingResetRefund {
    final core = progress.core;
    final totalSpent = _spentGoldForTrack(_coreBalance.hp, core.hpLevel) +
        _spentGoldForTrack(_coreBalance.shield, core.shieldLevel) +
        _spentGoldForTrack(_coreBalance.defense, core.defenseLevel);
    return (totalSpent * 0.7).round();
  }

  int get _buildingResetFullRefund {
    final core = progress.core;
    return _spentGoldForTrack(_coreBalance.hp, core.hpLevel) +
        _spentGoldForTrack(_coreBalance.shield, core.shieldLevel) +
        _spentGoldForTrack(_coreBalance.defense, core.defenseLevel);
  }

  Future<void> _resetBuildings() async {
    final core = progress.core;
    if (core.hpLevel == 1 && core.shieldLevel == 1 && core.defenseLevel == 1) {
      await _showNoticeDialog(
        title: '초기화 불가',
        body: '초기화할 건물 강화 내역이 없습니다.',
      );
      return;
    }

    final fullRefund = await _showResetChoiceDialog();
    if (fullRefund == null) return;
    final refund = fullRefund ? _buildingResetFullRefund : _buildingResetRefund;
    final ok = await _showConfirmDialog(
      title: fullRefund ? '광고 초기화' : '건물 초기화',
      body: fullRefund
          ? '광고를 보고 사용한 골드 100%인 ${_fmtInt(refund)} 골드를 반환하고 건물 강화를 초기화합니다.'
          : '사용한 골드의 70%인 ${_fmtInt(refund)} 골드를 반환하고 건물 강화를 초기화합니다.',
      confirmLabel: fullRefund ? '광고 초기화' : '초기화',
    );
    if (ok != true) return;

    if (fullRefund) {
      final watched = await AppAdService.instance.showRewardedAd();
      if (!mounted) return;
      if (!watched) return;
    }

    final previousCoreLevel = core.level;
    setState(() {
      progress.accountGold += refund;
      core.level = 1;
      core.hp = 2600;
      core.shield = 250;
      core.defenseRate = 0.05;
      core.hpLevel = 1;
      core.shieldLevel = 1;
      core.defenseLevel = 1;
    });
    await economyLogRepo.logCurrencyChange(
      source: fullRefund ? 'core_reset_refund_ad' : 'core_reset_refund',
      currency: 'accountGold',
      amount: refund,
      balanceAfter: progress.accountGold,
    );
    if (fullRefund) {
      await economyLogRepo.logAdReward(
        placement: 'building_reset_full_refund',
        reward: {'accountGold': refund},
      );
    }
    await economyLogRepo.logUpgrade(
      upgradeType: 'core_reset',
      targetId: 'core',
      fromLevel: previousCoreLevel,
      toLevel: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final core = progress.core;
    const bgTop = Color(0xFF091321);
    const bgBottom = Color(0xFF13233B);
    const panelBorder = Color(0xFF83B5FF);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _exitScreen();
        }
      },
      child: Scaffold(
        backgroundColor: bgTop,
        appBar: AppBar(
          title: const Text('건물 관리'),
          backgroundColor: const Color(0xFF0E1A2D),
          foregroundColor: const Color(0xFFF3F7FF),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgTop, bgBottom],
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                _coreShowcase(core.level),
                const SizedBox(height: 14),
                _statsGrid(core),
                const SizedBox(height: 14),
                _upgradeCard(
                  title: '내구 보강',
                  subtitle: '코어 체력을 높여 더 오래 버팁니다',
                  accent: const Color(0xFF7FC8FF),
                  value: 'HP ${core.hp}',
                  level: 'Lv${core.hpLevel}',
                  cost: _hpCost,
                  isMax: _isHpMax,
                  onPressed: _upgradeHp,
                ),
                const SizedBox(height: 10),
                _upgradeCard(
                  title: '실드 증폭',
                  subtitle: '전투 시작 시 보호막을 더 두껍게 유지합니다',
                  accent: const Color(0xFF89F0D0),
                  value: '실드 ${core.shield}',
                  level: 'Lv${core.shieldLevel}',
                  cost: _shieldCost,
                  isMax: _isShieldMax,
                  onPressed: _upgradeShield,
                ),
                const SizedBox(height: 10),
                _upgradeCard(
                  title: '방어 계수',
                  subtitle: '받는 피해를 줄이는 코어 방어율을 강화합니다',
                  accent: const Color(0xFFFFD36E),
                  value: '방어율 ${(core.defenseRate * 100).toStringAsFixed(0)}%',
                  level: 'Lv${core.defenseLevel}',
                  cost: _defenseCost,
                  isMax: _isDefenseMax,
                  onPressed: _upgradeDefense,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppPanelButton(
                        label: '초기화',
                        borderColor: panelBorder,
                        foregroundColor: const Color(0xFFF3F7FF),
                        backgroundColor: const Color(0x80502A2A),
                        onPressed: _resetBuildings,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppPanelButton(
                        label: '로비로 돌아가기',
                        borderColor: panelBorder,
                        foregroundColor: const Color(0xFFF3F7FF),
                        backgroundColor: const Color(0x99122336),
                        onPressed: _exitScreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _coreShowcase(int coreLevel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC11233A), Color(0xCC1A2F4B)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF93BFFF), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xCC17304B),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF93BFFF), width: 1.1),
              ),
              child: Text(
                'LV$coreLevel',
                style: const TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF5EC7FF).withOpacity(0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Image.asset(
                'assets/images/core/core.png',
                height: 170,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(CoreProgress core) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.96,
      children: [
        _statTile(
          title: '코어 HP',
          value: '${core.hp}',
          level: 'Lv${core.hpLevel}',
          accent: const Color(0xFF7FC8FF),
        ),
        _statTile(
          title: '실드',
          value: '${core.shield}',
          level: 'Lv${core.shieldLevel}',
          accent: const Color(0xFF89F0D0),
        ),
        _statTile(
          title: '방어율',
          value: '${(core.defenseRate * 100).toStringAsFixed(0)}%',
          level: 'Lv${core.defenseLevel}',
          accent: const Color(0xFFFFD36E),
        ),
      ],
    );
  }

  Widget _statTile({
    required String title,
    required String value,
    required String level,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.85), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFBFD5FF),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            level,
            style: const TextStyle(
              color: Color(0xFFF3F7FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _upgradeCard({
    required String title,
    required String subtitle,
    required Color accent,
    required String value,
    required String level,
    required int cost,
    required bool isMax,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF3F7FF),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFD9E7FF),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.85)),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 154,
                child: AppPanelButton(
                  label: isMax ? 'MAX' : '강화 (${_fmtInt(cost)})',
                  borderColor: const Color(0xFF83B5FF),
                  foregroundColor: const Color(0xFFF3F7FF),
                  backgroundColor:
                      isMax ? const Color(0x80506A7A) : const Color(0xCC17304B),
                  compact: true,
                  onPressed: isMax ? null : onPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtInt(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final indexFromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  Future<void> _showNoticeDialog({
    required String title,
    required String body,
  }) async {
    unawaited(AppAudioService.instance.playPopupOpen());
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

  Future<bool?> _showResetChoiceDialog() async {
    return showDialog<bool>(
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
              const Icon(Icons.refresh_rounded,
                  color: Color(0xFFFFC857), size: 30),
              const SizedBox(height: 10),
              const Text(
                '초기화 방식 선택',
                style: TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '일반 초기화는 70% 환불, 광고 초기화는 100% 환불을 제공합니다.',
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
                      label: '일반 초기화',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0x80502A2A),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppPanelButton(
                      label: '광고 초기화',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0xCC14405C),
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
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
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
                      label: confirmLabel,
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
  }
}
