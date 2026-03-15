import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tower_defense/data/definition_repository.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/domain/models/definitions.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/shared/tower_visual_fx.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

const List<String> kShopTowerIds = [
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

class _ShardDrawReward {
  final TowerDef tower;
  final int shards;

  const _ShardDrawReward({
    required this.tower,
    required this.shards,
  });
}

class _ShardDrawOutcome {
  final String? error;
  final List<_ShardDrawReward> rewards;

  const _ShardDrawOutcome({
    this.error,
    this.rewards = const [],
  });
}

class ShopScreen extends StatefulWidget {
  final AccountProgress progress;

  const ShopScreen({super.key, required this.progress});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late AccountProgress progress;
  final DefinitionRepository repo = DefinitionRepository();
  final AccountProgressRepository progressRepo = AccountProgressRepository();
  GachaBannerDef? banner;
  Map<String, TowerDef> towerDefs = {};
  String? lastResult;
  int _tabIndex = 1;
  Timer? _shardShowcaseTimer;
  int _shardShowcaseIndex = 0;

  @override
  void initState() {
    super.initState();
    progress = widget.progress;
    _ensureStarterTowers();
    _loadData();
  }

  void _ensureStarterTowers() {
    for (final towerId in const ['cannon_basic', 'rapid_basic', 'frost_basic']) {
      final tower = progress.towers[towerId] ?? TowerProgress(towerId: towerId, unlocked: true);
      tower.unlocked = true;
      progress.towers[towerId] = tower;
    }
  }

  Future<void> _loadData() async {
    final loadedBanner = await repo.loadGachaBanner('starter');
    final defs = <String, TowerDef>{};
    for (final id in kShopTowerIds) {
      defs[id] = await repo.loadTower(id);
    }
    if (!mounted) return;
    setState(() {
      banner = loadedBanner;
      towerDefs = defs;
    });
    _startShardShowcase();
  }

  @override
  void dispose() {
    _shardShowcaseTimer?.cancel();
    super.dispose();
  }

  void _startShardShowcase() {
    _shardShowcaseTimer?.cancel();
    if (towerDefs.isEmpty) return;
    _shardShowcaseTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!mounted || towerDefs.isEmpty) return;
      setState(() {
        _shardShowcaseIndex = (_shardShowcaseIndex + 1) % towerDefs.length;
      });
    });
  }

  Future<void> _exitScreen() async {
    await progressRepo.save(progress);
    if (!mounted) return;
    Navigator.of(context).pop(progress);
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('상점'),
          backgroundColor: const Color(0xFF0E1A2D),
          foregroundColor: const Color(0xFFF3F7FF),
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                _currencyHeader(),
                const SizedBox(height: 12),
                _shopTabs(),
                const SizedBox(height: 12),
                _tabContent(panelBorder),
                const SizedBox(height: 12),
                AppPanelButton(
                  label: '로비로 돌아가기',
                  borderColor: panelBorder,
                  foregroundColor: const Color(0xFFF3F7FF),
                  backgroundColor: const Color(0x99122336),
                  onPressed: _exitScreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shopTabs() {
    const labels = ['타워구매', '타워조각', '골드', '에너지', '다이아'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tabIndex = i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tabIndex == i ? const Color(0xCC1F3D63) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: _tabIndex == i
                        ? Border.all(color: const Color(0xFF9AC6FF), width: 1.0)
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _tabIndex == i
                          ? const Color(0xFFF4F8FF)
                          : const Color(0xFFB4C7E8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabContent(Color panelBorder) {
    return switch (_tabIndex) {
      0 => _towerPurchasePanel(panelBorder),
      1 => _shardGachaPanel(panelBorder),
      2 => _goldPanel(panelBorder),
      3 => _energyPanel(panelBorder),
      4 => _diamondPanel(panelBorder),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _currencyHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC142238),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.savings, size: 16, color: Color(0xFFFFC857)),
            const SizedBox(width: 4),
            Text(
              '${progress.accountGold}',
              style: const TextStyle(
                color: Color(0xFFF3F7FF),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.diamond, size: 16, color: Color(0xFF58C8FF)),
            const SizedBox(width: 4),
            Text(
              '${progress.diamonds}',
              style: const TextStyle(
                color: Color(0xFFF3F7FF),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.confirmation_number, size: 16, color: Color(0xFFF3F7FF)),
            const SizedBox(width: 4),
            Text(
              '${progress.shardDrawTickets}',
              style: const TextStyle(
                color: Color(0xFFF3F7FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shardGachaPanel(Color panelBorder) {
    _syncShardDrawDailyLimit();
    _syncAdDailyLimit();
    final singleRemain = (5 - progress.shardDrawSingleDailyCount).clamp(0, 5);
    final tenRemain = (5 - progress.shardDrawTenDailyCount).clamp(0, 5);
    final adTenRemain = (1 - progress.adShardDrawTenDailyCount).clamp(0, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _shardShowcaseCard(panelBorder),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppPanelButton(
                label: '1회 뽑기 (300)\n$singleRemain/5',
                borderColor: panelBorder,
                foregroundColor: const Color(0xFFF3F7FF),
                backgroundColor: const Color(0xCC17304B),
                compact: true,
                onPressed: () => _handleDraw(count: 1, useCost: true, useTicket: false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppPanelButton(
                label: '10회 뽑기 (3,000)\n$tenRemain/5',
                borderColor: panelBorder,
                foregroundColor: const Color(0xFFF3F7FF),
                backgroundColor: const Color(0xCC17304B),
                compact: true,
                onPressed: () => _handleDraw(count: 10, useCost: true, useTicket: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppPanelButton(
                label: '티켓 1회 뽑기',
                borderColor: panelBorder,
                foregroundColor: const Color(0xFFF3F7FF),
                backgroundColor: const Color(0xCC17304B),
                compact: true,
                onPressed: () => _handleDraw(count: 1, useCost: false, useTicket: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppPanelButton(
                label: '티켓 10회 뽑기',
                borderColor: panelBorder,
                foregroundColor: const Color(0xFFF3F7FF),
                backgroundColor: const Color(0xCC17304B),
                compact: true,
                onPressed: () => _handleDraw(count: 10, useCost: false, useTicket: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppPanelButton(
          label: '광고보고 10회 뽑기\n$adTenRemain/1',
          borderColor: panelBorder,
          foregroundColor: const Color(0xFFF3F7FF),
          backgroundColor: const Color(0xCC14405C),
          compact: true,
          onPressed: () => _handleDraw(count: 10, useCost: false, useTicket: false, useAd: true),
        ),
      ],
    );
  }

  Widget _shardShowcaseCard(Color panelBorder) {
    if (towerDefs.isEmpty) {
      return Container(
        height: 210,
        decoration: BoxDecoration(
          color: const Color(0xCC142238),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: panelBorder, width: 1.2),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final orderedDefs = kShopTowerIds.map((id) => towerDefs[id]).whereType<TowerDef>().toList();
    final current = orderedDefs[_shardShowcaseIndex % orderedDefs.length];
    final prev = orderedDefs[(_shardShowcaseIndex - 1 + orderedDefs.length) % orderedDefs.length];
    final next = orderedDefs[(_shardShowcaseIndex + 1) % orderedDefs.length];

    Widget sideCard(TowerDef def, {required Alignment alignment}) {
      return Align(
        alignment: alignment,
        child: Opacity(
          opacity: 0.24,
          child: Transform.scale(
            scale: 0.72,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0x99192B43),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _rarityColor(def.rarity).withOpacity(0.45)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/main_towers/${def.id}.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: panelBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '타워 조각 스캔',
            style: TextStyle(
              color: Color(0xFFF3F7FF),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: Stack(
              children: [
                sideCard(prev, alignment: const Alignment(-0.85, 0.1)),
                sideCard(next, alignment: const Alignment(0.85, 0.1)),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey(current.id),
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1B3553), Color(0xFF12253B)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _rarityColor(current.rarity), width: 1.6),
                        boxShadow: [
                          BoxShadow(
                            color: _rarityColor(current.rarity).withOpacity(0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/images/main_towers/${current.id}.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _towerDisplayNameKo(current.id),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _rarityColor(current.rarity),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_rarityLabelKo(current.rarity)} 타워 조각 출현 가능',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _towerPurchasePanel(Color panelBorder) {
    if (towerDefs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final orderedTowerIds = [...kShopTowerIds]
      ..sort((a, b) {
        final rarityA = _rarityOrder(towerDefs[a]?.rarity);
        final rarityB = _rarityOrder(towerDefs[b]?.rarity);
        if (rarityA != rarityB) return rarityA.compareTo(rarityB);
        return kShopTowerIds.indexOf(a).compareTo(kShopTowerIds.indexOf(b));
      });
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orderedTowerIds.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.6,
      ),
      itemBuilder: (context, index) {
        final towerId = orderedTowerIds[index];
        final def = towerDefs[towerId];
        if (def == null) return const SizedBox.shrink();
        return _towerPurchaseTile(def, panelBorder);
      },
    );
  }

  Widget _towerPurchaseTile(TowerDef def, Color panelBorder) {
    final tower = progress.towers[def.id] ?? TowerProgress(towerId: def.id, unlocked: false);
    progress.towers[def.id] = tower;
    final price = _towerDiamondPrice(def.rarity);
    return InkWell(
      onTap: tower.unlocked ? null : () => _showTowerPurchaseDetail(def),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xCC142238),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: panelBorder, width: 1.1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (tower.unlocked)
                      Image.asset(
                        'assets/images/main_towers/${def.id}.png',
                        fit: BoxFit.cover,
                      )
                    else
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                        child: Image.asset(
                          'assets/images/main_towers/${def.id}.png',
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.85),
                          colorBlendMode: BlendMode.darken,
                        ),
                      ),
                    Positioned.fill(
                      child: TowerVisualFxOverlay(
                        permanentLevel: tower.level,
                        towerId: def.id,
                        rarity: def.rarity,
                        opacity: tower.unlocked ? 0.95 : 0.18,
                      ),
                    ),
                    if (!tower.unlocked)
                      Positioned.fill(
                        child: Container(color: Colors.black.withOpacity(0.32)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _towerDisplayNameKo(def.id),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF3F7FF),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: AppPanelButton(
                label: tower.unlocked ? '구매 완료' : 'D ${_fmtInt(price)}',
                borderColor: tower.unlocked ? const Color(0xFF5AC89D) : panelBorder,
                foregroundColor: tower.unlocked ? const Color(0xFFDDFBF0) : const Color(0xFFF3F7FF),
                backgroundColor: tower.unlocked
                    ? const Color(0xAA174436)
                    : const Color(0xCC17304B),
                compact: true,
                onPressed: tower.unlocked ? null : () => _confirmTowerPurchase(def, price),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTowerPurchaseDetail(TowerDef def) async {
    final price = _towerDiamondPrice(def.rarity);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF13233B), Color(0xFF1A2E4A)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF93AEE8), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/images/main_towers/${def.id}.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                          Positioned.fill(
                            child: TowerVisualFxOverlay(
                              permanentLevel: 1,
                              towerId: def.id,
                              rarity: def.rarity,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _towerDisplayNameKo(def.id),
                            style: const TextStyle(
                              color: Color(0xFFF4F8FF),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _rarityLabelKo(def.rarity),
                            style: TextStyle(
                              color: _rarityColor(def.rarity),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _detailLine('공격력', def.baseDamage.toStringAsFixed(def.baseDamage % 1 == 0 ? 0 : 1)),
                          _detailLine('공격주기', '${def.fireRate.toStringAsFixed(2)}초'),
                          _detailLine('사거리', def.range.toStringAsFixed(0)),
                          _detailLine('공격방식', _attackTypeLabelKo(def.attackType)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailPanel(
                  title: '특수효과',
                  body: _specialEffectSummary(def),
                ),
                const SizedBox(height: 10),
                _detailPanel(
                  title: '궁극기',
                  body:
                      '발동 확률 ${_formatPercent(def.ultimateChance)} / 피해 배율 x${def.ultimateDamageMultiplier.toStringAsFixed(2)} / ${_ultimateAlphaSummary(def.id)}',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppPanelButton(
                        label: '닫기',
                        borderColor: const Color(0xFF83B5FF),
                        foregroundColor: const Color(0xFFF3F7FF),
                        backgroundColor: const Color(0x99122336),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppPanelButton(
                        label: '다이아 ${_fmtInt(price)}',
                        borderColor: const Color(0xFF83B5FF),
                        foregroundColor: const Color(0xFFF3F7FF),
                        backgroundColor: const Color(0xCC17304B),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _confirmTowerPurchase(def, price);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _goldPanel(Color panelBorder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _goldShopPackageCard(
          panelBorder: panelBorder,
          title: '골드 보급 상자',
          goldAmount: 10000,
          diamondCost: 100,
        ),
        const SizedBox(height: 10),
        _goldShopPackageCard(
          panelBorder: panelBorder,
          title: '골드 보급 팩',
          goldAmount: 30000,
          diamondCost: 250,
        ),
        const SizedBox(height: 10),
        _goldShopPackageCard(
          panelBorder: panelBorder,
          title: '골드 보급 크레이트',
          goldAmount: 70000,
          diamondCost: 500,
        ),
        const SizedBox(height: 10),
        _goldShopPackageCard(
          panelBorder: panelBorder,
          title: '골드 대형 보급함',
          goldAmount: 150000,
          diamondCost: 900,
        ),
      ],
    );
  }

  Widget _energyPanel(Color panelBorder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _energyShopPackageCard(
          panelBorder: panelBorder,
          title: '골드 충전 셀',
          energyAmount: 10,
          costLabel: '골드 10,000',
          accentColor: const Color(0xFFFFD36E),
          onBuy: () => _buyEnergyWithGold(
            title: '골드 충전 셀',
            energyAmount: 10,
            goldCost: 10000,
          ),
        ),
        const SizedBox(height: 10),
        _energyShopPackageCard(
          panelBorder: panelBorder,
          title: '골드 충전 코어',
          energyAmount: 25,
          costLabel: '골드 25,000',
          accentColor: const Color(0xFFFFD36E),
          onBuy: () => _buyEnergyWithGold(
            title: '골드 충전 코어',
            energyAmount: 25,
            goldCost: 25000,
          ),
        ),
        const SizedBox(height: 10),
        _energyShopPackageCard(
          panelBorder: panelBorder,
          title: '다이아 충전 셀',
          energyAmount: 20,
          costLabel: '다이아 200',
          accentColor: const Color(0xFF8FD3FF),
          onBuy: () => _buyEnergyWithDiamond(
            title: '다이아 충전 셀',
            energyAmount: 20,
            diamondCost: 200,
          ),
        ),
        const SizedBox(height: 10),
        _energyShopPackageCard(
          panelBorder: panelBorder,
          title: '다이아 충전 코어',
          energyAmount: 50,
          costLabel: '다이아 500',
          accentColor: const Color(0xFF8FD3FF),
          onBuy: () => _buyEnergyWithDiamond(
            title: '다이아 충전 코어',
            energyAmount: 50,
            diamondCost: 500,
          ),
        ),
      ],
    );
  }

  Widget _diamondPanel(Color panelBorder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _diamondShopPackageCard(
          panelBorder: panelBorder,
          title: '다이아 팩 S',
          diamondAmount: 1200,
          cashLabel: '₩1,200',
        ),
        const SizedBox(height: 10),
        _diamondShopPackageCard(
          panelBorder: panelBorder,
          title: '다이아 팩 M',
          diamondAmount: 3500,
          cashLabel: '₩3,300',
        ),
        const SizedBox(height: 10),
        _diamondShopPackageCard(
          panelBorder: panelBorder,
          title: '다이아 팩 L',
          diamondAmount: 8000,
          cashLabel: '₩7,500',
        ),
        const SizedBox(height: 10),
        _diamondShopPackageCard(
          panelBorder: panelBorder,
          title: '다이아 팩 XL',
          diamondAmount: 18000,
          cashLabel: '₩15,000',
        ),
      ],
    );
  }

  Widget _goldShopPackageCard({
    required Color panelBorder,
    required String title,
    required int goldAmount,
    required int diamondCost,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xCC17304B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD36E), width: 1.1),
            ),
            child: const Icon(
              Icons.savings,
              color: Color(0xFFFFD36E),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF3F7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '골드 +${_fmtInt(goldAmount)}',
                  style: const TextStyle(
                    color: Color(0xFFFFD36E),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: AppPanelButton(
              label: '다이아 ${_fmtInt(diamondCost)}',
              borderColor: panelBorder,
              foregroundColor: const Color(0xFFF3F7FF),
              backgroundColor: const Color(0xCC17304B),
              compact: true,
              onPressed: () => _buyGoldPackage(
                title: title,
                goldAmount: goldAmount,
                diamondCost: diamondCost,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _energyShopPackageCard({
    required Color panelBorder,
    required String title,
    required int energyAmount,
    required String costLabel,
    required Color accentColor,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xCC17304B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor, width: 1.1),
            ),
            child: Icon(
              Icons.bolt,
              color: accentColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF3F7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '에너지 +${_fmtInt(energyAmount)}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: AppPanelButton(
              label: costLabel,
              borderColor: panelBorder,
              foregroundColor: const Color(0xFFF3F7FF),
              backgroundColor: const Color(0xCC17304B),
              compact: true,
              onPressed: onBuy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diamondShopPackageCard({
    required Color panelBorder,
    required String title,
    required int diamondAmount,
    required String cashLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xCC17304B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8FD3FF), width: 1.1),
            ),
            child: const Icon(
              Icons.diamond,
              color: Color(0xFF8FD3FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF3F7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '다이아 +${_fmtInt(diamondAmount)}',
                  style: const TextStyle(
                    color: Color(0xFF8FD3FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: AppPanelButton(
              label: cashLabel,
              borderColor: panelBorder,
              foregroundColor: const Color(0xFFF3F7FF),
              backgroundColor: const Color(0xCC17304B),
              compact: true,
              onPressed: () => _showNoticeDialog(
                title: title,
                body: '현금 결제 연동 전 임시 상품 목록입니다.\n실제 결제 기능은 아직 준비 중입니다.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyGoldPackage({
    required String title,
    required int goldAmount,
    required int diamondCost,
  }) async {
    if (progress.diamonds < diamondCost) {
      await _showNoticeDialog(title: '알림', body: '다이아가 부족합니다.');
      return;
    }
    final ok = await _showConfirmDialog(
      title: title,
      body: '다이아 ${_fmtInt(diamondCost)}개로 골드 ${_fmtInt(goldAmount)}을 구매하시겠습니까?',
      confirmLabel: '구매',
    );
    if (ok != true) return;
    setState(() {
      progress.diamonds -= diamondCost;
      progress.accountGold += goldAmount;
    });
    await progressRepo.save(progress);
  }

  Future<void> _buyEnergyWithGold({
    required String title,
    required int energyAmount,
    required int goldCost,
  }) async {
    if (progress.accountGold < goldCost) {
      await _showNoticeDialog(title: '알림', body: '골드가 부족합니다.');
      return;
    }
    final ok = await _showConfirmDialog(
      title: title,
      body: '골드 ${_fmtInt(goldCost)}로 에너지 ${_fmtInt(energyAmount)}를 구매하시겠습니까?',
      confirmLabel: '구매',
    );
    if (ok != true) return;
    setState(() {
      progress.accountGold -= goldCost;
      progress.energy += energyAmount;
    });
    await progressRepo.save(progress);
  }

  Future<void> _buyEnergyWithDiamond({
    required String title,
    required int energyAmount,
    required int diamondCost,
  }) async {
    if (progress.diamonds < diamondCost) {
      await _showNoticeDialog(title: '알림', body: '다이아가 부족합니다.');
      return;
    }
    final ok = await _showConfirmDialog(
      title: title,
      body: '다이아 ${_fmtInt(diamondCost)}로 에너지 ${_fmtInt(energyAmount)}를 구매하시겠습니까?',
      confirmLabel: '구매',
    );
    if (ok != true) return;
    setState(() {
      progress.diamonds -= diamondCost;
      progress.energy += energyAmount;
    });
    await progressRepo.save(progress);
  }

  Widget _comingSoonPanel({
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF3F7FF),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'COMING SOON',
            style: TextStyle(
              color: Color(0xFF8EC7FF),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  int _towerDiamondPrice(String rarity) {
    return switch (rarity) {
      'common' => 2000,
      'rare' => 4000,
      'unique' => 7000,
      'legendary' => 10000,
      _ => 5000,
    };
  }

  int _rarityOrder(String? rarity) {
    return switch (rarity) {
      'common' => 0,
      'rare' => 1,
      'unique' => 2,
      'legendary' => 3,
      _ => 99,
    };
  }

  Future<void> _confirmTowerPurchase(TowerDef def, int price) async {
    final tower = progress.towers[def.id] ?? TowerProgress(towerId: def.id, unlocked: false);
    if (tower.unlocked) {
      await _showNoticeDialog(title: '알림', body: '이미 구매한 타워입니다.');
      return;
    }
    if (progress.diamonds < price) {
      await _showNoticeDialog(title: '알림', body: '다이아가 부족합니다.');
      return;
    }
    final ok = await _showConfirmDialog(
      title: '타워 구매',
      body: '${_towerDisplayNameKo(def.id)}를 다이아 ${_fmtInt(price)}개로 구매하시겠습니까?',
      confirmLabel: '구매',
    );
    if (ok != true) return;
    setState(() {
      progress.diamonds -= price;
      tower.unlocked = true;
      progress.towers[def.id] = tower;
    });
    await progressRepo.save(progress);
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFFD9E7FF)),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFF3F7FF),
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _detailPanel({
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x99122336),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF3F7FF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
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

  Color _rarityColor(String rarity) {
    return switch (rarity) {
      'common' => const Color(0xFF6C63FF),
      'rare' => const Color(0xFF00D2A5),
      'unique' => const Color(0xFFB85BFF),
      'legendary' => const Color(0xFFFFC857),
      _ => const Color(0xFF7A7A7A),
    };
  }

  String _rarityLabelKo(String rarity) {
    return switch (rarity) {
      'common' => '일반',
      'rare' => '레어',
      'unique' => '유니크',
      'legendary' => '전설',
      _ => rarity,
    };
  }

  String _attackTypeLabelKo(String attackType) {
    return switch (attackType) {
      'hitscan' => '히트스캔',
      'projectile' => '투사체',
      _ => attackType,
    };
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(value * 100 >= 10 ? 0 : 1)}%';
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

  String _fmtSec(double? value) {
    final v = value ?? 0;
    return '${v.toStringAsFixed(v >= 1 ? 1 : 2)}초';
  }

  String _specialEffectSummary(TowerDef def) {
    if (def.effects.isEmpty) return '특수효과 없음';
    final base = def.effects.first;
    final boosted = def.effects.length > 1 ? def.effects[1] : null;
    final first = _effectLine(base);
    if (boosted == null) return first;
    return '$first / 강화: ${_effectLine(boosted)}';
  }

  String _effectLine(TowerEffectSpec e) {
    return switch (e.type) {
      'slow' =>
        '감속 ${_formatPercent((e.value ?? 0).clamp(0, 0.95).toDouble())}, 지속 ${_fmtSec(e.durationSec)}',
      'freeze' =>
        '빙결 확률 ${_formatPercent((e.chance ?? 0).clamp(0, 1).toDouble())}, 지속 ${_fmtSec(e.durationSec)}',
      'vulnerability' =>
        '취약 ${_formatPercent((e.value ?? 0).clamp(0, 1.5).toDouble())}, 지속 ${_fmtSec(e.durationSec)}',
      'time_dilate' =>
        '시간왜곡 ${_formatPercent((e.value ?? 0).clamp(0, 0.8).toDouble())}, 지속 ${_fmtSec(e.durationSec)}',
      'pull' =>
        '끌어당김 ${((e.value ?? 1).round())}칸, 확률 ${_formatPercent((e.chance ?? 1).clamp(0, 1).toDouble())}',
      'dot' => '지속피해 ${(e.value ?? 0).toStringAsFixed(1)} / ${_fmtSec(e.durationSec)}',
      'attack_weaken' =>
        '공격약화 ${_formatPercent((e.value ?? 0).clamp(0, 0.8).toDouble())}, 지속 ${_fmtSec(e.durationSec)}',
      'chain_arc' =>
        '연쇄피해 ${_formatPercent((e.value ?? 0).clamp(0, 2).toDouble())}, 연쇄수 ${e.maxStack ?? 1}',
      'max_hp_burst' =>
        '최대체력 비례 ${_formatPercent((e.value ?? 0).clamp(0, 0.3).toDouble())}',
      _ => e.type,
    };
  }

  String _ultimateAlphaSummary(String towerId) {
    return switch (towerId) {
      'cannon_basic' => '주변 폭발+감속',
      'rapid_basic' => '초고속 연사+취약 강화',
      'shotgun_basic' => '근접 산탄 강화',
      'frost_basic' => '추가 빙결',
      'drone_basic' => '공격약화 강화',
      'chain_basic' => '연쇄 수 증가',
      'missile_basic' => '폭발+취약 확산',
      'support_basic' => '강한 취약 부여+실드 회복',
      'laser_basic' => '도트 확산',
      'sniper_basic' => '저체력 처형',
      'gravity_basic' => '끌어당김+감속',
      'infection_basic' => '감염+취약',
      'chrono_basic' => '시간왜곡 확산',
      'singularity_basic' => '붕괴+끌어당김',
      'mortar_basic' => '광역 포격+감속',
      _ => '추가 효과',
    };
  }

  Future<void> _handleDraw({
    required int count,
    required bool useCost,
    required bool useTicket,
    bool useAd = false,
  }) async {
    _syncShardDrawDailyLimit();
    _syncAdDailyLimit();
    final outcome = await _rollMany(
      count: count,
      useCost: useCost,
      useTicket: useTicket,
      useAd: useAd,
    );
    if (!mounted) return;
    if (outcome.error != null) {
      await _showNoticeDialog(title: '알림', body: outcome.error!);
      return;
    }
    final summary = outcome.rewards.map((e) => '${_towerDisplayNameKo(e.tower.id)} 조각 +${e.shards}').join(', ');
    setState(() => lastResult = summary);
    await _showDrawResultDialog(outcome.rewards);
  }

  void _syncShardDrawDailyLimit() {
    final today = _todayKey();
    if (progress.shardDrawDailyDate == today) return;
    progress.shardDrawDailyDate = today;
    progress.shardDrawSingleDailyCount = 0;
    progress.shardDrawTenDailyCount = 0;
  }

  void _syncAdDailyLimit() {
    final today = _todayKey();
    if (progress.adDailyDate == today) return;
    progress.adDailyDate = today;
    progress.adPointResetDailyCount = 0;
    progress.adShardDrawTenDailyCount = 0;
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _showNoticeDialog({
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

  Future<void> _showDrawResultDialog(List<_ShardDrawReward> rewards) async {
    if (rewards.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
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
              const Text(
                '타워 조각 획득',
                style: TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: rewards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: rewards.length == 1 ? 1 : 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: rewards.length == 1 ? 2.4 : 1.15,
                  ),
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xCC17304B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _rarityColor(reward.tower.rarity),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Image.asset(
                              'assets/images/main_towers/${reward.tower.id}.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _towerDisplayNameKo(reward.tower.id),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFF3F7FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '조각 +${reward.shards}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _rarityColor(reward.tower.rarity),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

  Future<_ShardDrawOutcome> _rollMany({
    required int count,
    required bool useCost,
    required bool useTicket,
    required bool useAd,
  }) async {
    final b = banner;
    if (b == null) {
      return const _ShardDrawOutcome(error: '배너 로딩 중');
    }
    if (useAd) {
      if (count != 10) {
        return const _ShardDrawOutcome(error: '광고 뽑기는 10회만 가능합니다.');
      }
      if (progress.adShardDrawTenDailyCount >= 1) {
        return const _ShardDrawOutcome(error: '광고 10회 뽑기는 하루 1회까지만 가능합니다.');
      }
      progress.adShardDrawTenDailyCount += 1;
    } else if (useTicket) {
      if (progress.shardDrawTickets < count) {
        return const _ShardDrawOutcome(error: '티켓 부족');
      }
      progress.shardDrawTickets -= count;
    } else if (useCost) {
      if (count == 1 && progress.shardDrawSingleDailyCount >= 5) {
        return const _ShardDrawOutcome(error: '1회 뽑기는 하루 5회까지만 가능합니다.');
      }
      if (count == 10 && progress.shardDrawTenDailyCount >= 5) {
        return const _ShardDrawOutcome(error: '10회 뽑기는 하루 5회까지만 가능합니다.');
      }
      final totalCost = b.cost.amount * count;
      if (b.cost.currency == 'diamond') {
        if (progress.diamonds < totalCost) {
          return const _ShardDrawOutcome(error: '다이아 부족');
        }
        progress.diamonds -= totalCost;
      } else if (b.cost.currency == 'accountGold') {
        if (progress.accountGold < totalCost) {
          return const _ShardDrawOutcome(error: '골드 부족');
        }
        progress.accountGold -= totalCost;
      }
      if (count == 1) {
        progress.shardDrawSingleDailyCount += 1;
      } else if (count == 10) {
        progress.shardDrawTenDailyCount += 1;
      }
    }
    final rng = math.Random();
    final rewards = <_ShardDrawReward>[];
    for (int i = 0; i < count; i++) {
      final roll = rng.nextDouble() * 100;
      double acc = 0;
      String rarity = b.rates.first.rarity;
      for (final rate in b.rates) {
        acc += rate.percent;
        if (roll <= acc) {
          rarity = rate.rarity;
          break;
        }
      }

      final candidates = towerDefs.values.where((t) => t.rarity == rarity).toList();
      if (candidates.isEmpty) {
        continue;
      }
      final tower = candidates[rng.nextInt(candidates.length)];
      final p = progress.towers[tower.id] ?? TowerProgress(towerId: tower.id, unlocked: false);
      final shardAmount = _rollShardAmount(rng);
      p.shards += shardAmount;
      progress.towers[tower.id] = p;
      rewards.add(_ShardDrawReward(tower: tower, shards: shardAmount));
    }
    await progressRepo.save(progress);
    if (rewards.isEmpty) {
      return const _ShardDrawOutcome(error: '획득 실패');
    }
    return _ShardDrawOutcome(rewards: rewards);
  }

  int _rollShardAmount(math.Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.40) return 1;
    if (roll < 0.68) return 2;
    if (roll < 0.86) return 3;
    if (roll < 0.95) return 4;
    if (roll < 0.99) return 5;
    return 10;
  }

}
