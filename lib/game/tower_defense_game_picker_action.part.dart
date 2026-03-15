part of 'tower_defense_game.dart';

class TowerPicker extends PositionComponent {
  final TowerDefenseGame gameRef;
  final GridPoint cell;

  late List<_HudButtonData> buttons;

  TowerPicker({required this.gameRef, required this.cell}) {
    priority = 2000;
    buttons = [
      for (final id in kAllTowerIds)
        _HudButtonData(
          id,
          _towerDisplayNameKo(id),
          _rarityColor(gameRef.towerDefs[id]?.rarity),
        ),
    ];
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final button in buttons) {
      try {
        button.sprite = await gameRef.loadSprite('main_towers/${button.towerId}.png');
      } catch (_) {
        button.sprite = null;
      }
    }
  }

  @override
  void onMount() {
    super.onMount();
    updateLayout();
  }

  void updateLayout() {
    final buttonSize = gameRef.tileSize * 1.22;
    final padding = gameRef.tileSize * 0.18;
    final labelHeight = gameRef.tileSize * 0.72;
    const cols = 5;
    final rows = (buttons.length / cols).ceil();
    size.setValues(
      buttonSize * cols + padding * (cols + 1),
      (buttonSize + labelHeight) * rows + padding * (rows + 1),
    );
    final left = (gameRef.size.x - size.x) / 2;
    final top = gameRef.size.y - size.y - gameRef.tileSize * 0.4;
    position.setValues(left, top);
  }

  String? hitTest(Vector2 worldPos) {
    final local = worldPos - position;
    if (local.x < 0 || local.y < 0 || local.x > size.x || local.y > size.y) {
      return null;
    }

    final buttonSize = gameRef.tileSize * 1.22;
    final padding = gameRef.tileSize * 0.18;
    final labelHeight = gameRef.tileSize * 0.72;
    const cols = 5;
    for (int i = 0; i < buttons.length; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final x = padding + col * (buttonSize + padding);
      final y = padding + row * (buttonSize + labelHeight + padding);
      final rect = Rect.fromLTWH(x, y, buttonSize, buttonSize);
      if (rect.contains(Offset(local.x, local.y))) {
        final def = gameRef.towerDefs[buttons[i].towerId];
        if (def == null) return null;
        final unlocked =
            gameRef.debugOpen || (gameRef.accountProgress.towers[def.id]?.unlocked ?? false);
        if (!unlocked) return null;
        return buttons[i].towerId;
      }
    }
    return null;
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xEE1B1B22);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), bgPaint);

    final buttonSize = gameRef.tileSize * 1.22;
    final padding = gameRef.tileSize * 0.18;
    final labelHeight = gameRef.tileSize * 0.72;
    const cols = 5;
    final namePaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
    final costPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFFFD166),
        fontSize: 7,
        fontWeight: FontWeight.w700,
      ),
    );

    for (int i = 0; i < buttons.length; i++) {
      final data = buttons[i];
      final row = i ~/ cols;
      final col = i % cols;
      final x = padding + col * (buttonSize + padding);
      final y = padding + row * (buttonSize + labelHeight + padding);
      final rect = Rect.fromLTWH(x, y, buttonSize, buttonSize);

      final paint = Paint()..color = data.color;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
      final imageRect = Rect.fromLTWH(x + 3, y + 3, buttonSize - 6, buttonSize - 6);
      final def = gameRef.towerDefs[data.towerId];
      final locked = def == null
          ? true
          : !(gameRef.debugOpen ||
              (gameRef.accountProgress.towers[def.id]?.unlocked ?? false));
      if (data.sprite != null) {
        data.sprite!.renderRect(canvas, imageRect);
      }
      final permanentLevel = def == null ? 1 : (gameRef.accountProgress.towers[def.id]?.level ?? 1);
      drawTowerVisualFx(
        canvas,
        imageRect,
        permanentLevel: permanentLevel,
        towerId: data.towerId,
        rarity: def?.rarity,
        phase: gameRef.visualFxTime,
        opacity: locked ? 0.28 : 0.82,
      );
      final estimatedTextWidth = data.name.length * 8.0;
      namePaint.render(
        canvas,
        data.name,
        Vector2(x + (buttonSize - estimatedTextWidth) / 2 + 4, y + buttonSize + 2),
      );
      if (def != null) {
        final buildCost =
            (def.buildCost * gameRef.difficultyDef.buildCostMultiplier).round();
        final costLabel = 'G ${_formatCompactInt(buildCost)}';
        final costWidth = costLabel.length * 6.3;
        costPaint.render(
          canvas,
          costLabel,
          Vector2(x + (buttonSize - costWidth) / 2, y + buttonSize + 12),
        );
      }

      if (locked) {
        final shade = Paint()..color = const Color(0xAA000000);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), shade);
        final lockText = TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
        lockText.render(canvas, 'LOCK', Vector2(x + 12, y + buttonSize / 2 - 6));
      }
    }
  }

  String _formatCompactInt(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

enum TowerAction { upgrade, sell }

class TowerActionPanel extends PositionComponent {
  final TowerDefenseGame gameRef;
  final GridPoint cell;
  Rect? _upgradeRect;
  Rect? _sellRect;

  TowerActionPanel({required this.gameRef, required this.cell}) {
    priority = 2000;
  }

  @override
  void onMount() {
    super.onMount();
    updateLayout();
  }

  void updateLayout() {
    final buttonW = gameRef.tileSize * 2.85;
    final buttonH = gameRef.tileSize * 0.88;
    final padding = gameRef.tileSize * 0.24;
    final headerH = gameRef.tileSize * 0.62;
    size = Vector2(buttonW + padding * 2, headerH + buttonH * 2 + padding * 4);

    final cellPos = cell.toWorld(gameRef);
    final margin = 8.0;
    final gap = gameRef.tileSize * 0.22;
    final minX = margin;
    final maxX = gameRef.size.x - size.x - margin;
    final minY = 52.0;
    final maxY = gameRef.size.y - size.y - margin;
    final clampedCenterX = (cellPos.x - size.x / 2).clamp(minX, maxX);
    final towerRect = Rect.fromCenter(
      center: Offset(cellPos.x, cellPos.y),
      width: gameRef.tileSize,
      height: gameRef.tileSize,
    );
    final avoidMargin = 12.0;
    final infoRect = gameRef.towerInfoPanel == null
        ? null
        : Rect.fromLTWH(
            gameRef.towerInfoPanel!.position.x - avoidMargin,
            gameRef.towerInfoPanel!.position.y - avoidMargin,
            gameRef.towerInfoPanel!.size.x + avoidMargin * 2,
            gameRef.towerInfoPanel!.size.y + avoidMargin * 2,
          );

    Rect candidateRect(double left, double top) =>
        Rect.fromLTWH(left.clamp(minX, maxX), top.clamp(minY, maxY), size.x, size.y);

    bool isValid(Rect rect) {
      if (rect.overlaps(towerRect)) return false;
      if (infoRect != null && rect.overlaps(infoRect)) return false;
      return true;
    }

    final candidates = <Rect>[
      candidateRect(clampedCenterX, cellPos.y - size.y - gap),
      candidateRect(clampedCenterX, cellPos.y + gameRef.tileSize * 0.55 + gap),
      candidateRect(cellPos.x - size.x - gap, cellPos.y - size.y / 2),
      candidateRect(cellPos.x + gameRef.tileSize * 0.55 + gap, cellPos.y - size.y / 2),
      candidateRect(
        math.min(clampedCenterX, (infoRect?.left ?? gameRef.size.x) - size.x - margin),
        minY,
      ),
      candidateRect(clampedCenterX, maxY),
    ];

    final resolvedRect = candidates.firstWhere(
      isValid,
      orElse: () => candidates.last,
    );
    position.setValues(resolvedRect.left, resolvedRect.top);

    _upgradeRect = Rect.fromLTWH(
      padding,
      padding + headerH,
      buttonW,
      buttonH,
    );
    _sellRect = Rect.fromLTWH(
      padding,
      padding * 2 + headerH + buttonH,
      buttonW,
      buttonH,
    );
  }

  Object? hitTest(Vector2 worldPos) {
    final local = worldPos - position;
    if (local.x < 0 || local.y < 0 || local.x > size.x || local.y > size.y) {
      return null;
    }
    if (_upgradeRect?.contains(Offset(local.x, local.y)) ?? false) {
      return TowerAction.upgrade;
    }
    if (_sellRect?.contains(Offset(local.x, local.y)) ?? false) {
      return TowerAction.sell;
    }
    return null;
  }

  @override
  void render(Canvas canvas) {
    final panelRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xF8171B24), Color(0xF02A3140)],
      ).createShader(panelRect);
    final borderPaint = Paint()
      ..color = const Color(0xFF8FA4D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(12)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(12)),
      borderPaint,
    );

    final tower = gameRef.towers[cell];
    final level = tower?.state.level ?? 1;
    final upgradeCost = tower?.nextUpgradeCost ?? 0;
    final refund = tower?.sellRefund ?? 0;
    final towerName = tower == null
        ? '타워'
        : '${_towerDisplayNameKo(tower.towerId)} (${tower.def.attackType == 'hitscan' ? '히트스캔' : '투사체'})';

    final titlePaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
    final subPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFB7C7EA),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
    final label = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
    final valuePaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFEAF1FF),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );

    titlePaint.render(canvas, towerName, Vector2(10, 7));
    subPaint.render(canvas, 'LV.$level', Vector2(10, 21));

    _drawButton(
      canvas,
      _upgradeRect,
      '강화',
      '$upgradeCost G',
      const Color(0xFF4F7DFF),
      const Color(0xFF2749A8),
      label,
      valuePaint,
    );
    _drawButton(
      canvas,
      _sellRect,
      '매각',
      '+$refund G',
      const Color(0xFFD45A64),
      const Color(0xFF8A2636),
      label,
      valuePaint,
    );
  }

  void _drawButton(
    Canvas canvas,
    Rect? rect,
    String title,
    String value,
    Color topColor,
    Color bottomColor,
    TextPaint label,
    TextPaint valuePaint,
  ) {
    if (rect == null) return;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(rect);
    final strokePaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final button = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(button, fillPaint);
    canvas.drawRRect(button, strokePaint);
    label.render(canvas, title, Vector2(rect.left + 10, rect.top + 6));
    valuePaint.render(canvas, value, Vector2(rect.left + 10, rect.top + 22));
  }
}

class TowerInfoPanel extends PositionComponent {
  final TowerDefenseGame gameRef;
  final GridPoint cell;

  TowerInfoPanel({required this.gameRef, required this.cell}) {
    priority = 2000;
  }

  @override
  void onMount() {
    super.onMount();
    updateLayout();
  }

  void updateLayout() {
    final panelW = gameRef.tileSize * 4.5;
    final panelH = gameRef.tileSize * 4.7;
    size = Vector2(panelW, panelH);
    position = Vector2(gameRef.size.x - panelW - 8, 52);
  }

  @override
  void render(Canvas canvas) {
    final tower = gameRef.towers[cell];
    if (tower == null) return;

    final panelRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xF0161B24), Color(0xEE243047)],
      ).createShader(panelRect);
    final borderPaint = Paint()
      ..color = const Color(0xFF93AEE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(12)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(12)),
      borderPaint,
    );

    final def = tower.def;
    final titlePaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
    final subPaint = TextPaint(
      style: TextStyle(
        color: _rarityColor(def.rarity),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    );
    final bodyPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFE5ECFF),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
    final dimPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFB7C7EA),
        fontSize: 8,
        fontWeight: FontWeight.w600,
      ),
    );

    final towerName =
        '${_towerDisplayNameKo(tower.towerId)} (${tower.def.attackType == 'hitscan' ? '히트스캔' : '투사체'})';
    titlePaint.render(canvas, towerName, Vector2(10, 8));
    subPaint.render(
      canvas,
      '${_rarityKo(def.rarity)}  LV.${tower.state.level}',
      Vector2(10, 22),
    );

    bodyPaint.render(
      canvas,
      '공격력 ${tower.damage.toStringAsFixed(tower.damage % 1 == 0 ? 0 : 1)}',
      Vector2(10, 42),
    );
    bodyPaint.render(
      canvas,
      '공격주기 ${tower.fireRate.toStringAsFixed(2)}초',
      Vector2(10, 56),
    );
    bodyPaint.render(
      canvas,
      '사거리 ${tower.range.toStringAsFixed(0)}',
      Vector2(10, 70),
    );

    dimPaint.render(canvas, '궁극기', Vector2(10, 92));
    bodyPaint.render(
      canvas,
      _ultimateSummaryLine(def),
      Vector2(10, 106),
    );

    dimPaint.render(canvas, '활성 특수효과', Vector2(10, 124));
    final effectLines = _towerEffectSummaryLines(def, tower.state.level);
    for (int i = 0; i < effectLines.length && i < 4; i++) {
      bodyPaint.render(canvas, effectLines[i], Vector2(10, 138 + i * 13));
    }
  }

  List<String> _towerEffectSummaryLines(TowerDef def, int level) {
    final activeEffects = def.effects.where((effect) => effect.appliesAtLevel(level)).toList();
    if (activeEffects.isEmpty) {
      return ['고유 특수효과 없음'];
    }
    return activeEffects.map((effect) {
      final chanceText =
          effect.chance != null ? ' / 확률 ${_pct(effect.chance)}' : '';
      return switch (effect.type) {
        'slow' => '감속 ${_pct(effect.value)} / ${_sec(effect.durationSec)}$chanceText',
        'freeze' => '빙결 ${_sec(effect.durationSec ?? effect.freezeDurationSec)}$chanceText',
        'vulnerability' => '취약 ${_pct(effect.value)} / ${_sec(effect.durationSec)}$chanceText',
        'time_dilate' => '시간왜곡 ${_pct(effect.value)} / ${_sec(effect.durationSec)}$chanceText',
        'pull' => '끌어당김 ${effect.value?.round() ?? 1}칸$chanceText',
        'dot' => '지속피해 ${_num(effect.value)} / ${_sec(effect.durationSec)}$chanceText',
        'attack_weaken' => '공격약화 ${_pct(effect.value)} / ${_sec(effect.durationSec)}$chanceText',
        'chain_arc' => '연쇄 ${_pct(effect.value)} / ${effect.maxStack ?? 1}명$chanceText',
        'max_hp_burst' => '최대체력 비례 ${_pct(effect.value)}$chanceText',
        _ => '${effect.type}$chanceText',
      };
    }).toList();
  }

  String _ultimateSummaryLine(TowerDef def) {
    final chance = _pct(def.ultimateChance);
    final damage = '배율 x${def.ultimateDamageMultiplier.toStringAsFixed(2)}';
    final extra = switch (def.id) {
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
    return '확률 $chance / $damage / $extra';
  }

  String _pct(double? value) {
    final v = ((value ?? 0) * 100);
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}%';
  }

  String _sec(double? value) {
    final v = value ?? 0;
    return '${v.toStringAsFixed(v >= 1 ? 1 : 2)}초';
  }

  String _num(double? value) {
    final v = value ?? 0;
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
  }

  String _rarityKo(String rarity) {
    return switch (rarity) {
      'common' => '일반',
      'rare' => '레어',
      'unique' => '유니크',
      'legendary' => '전설',
      _ => rarity,
    };
  }
}

class GridPoint {
  final int x;
  final int y;

  const GridPoint(this.x, this.y);

  Vector2 toWorld(TowerDefenseGame game) =>
      game.mapOrigin + Vector2((x + 0.5) * game.tileSize, (y + 0.5) * game.tileSize);

  @override
  bool operator ==(Object other) => other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class UltimateFxDef {
  final ShockwaveDef? shockwave;
  final GlowDef? glow;

  const UltimateFxDef({this.shockwave, this.glow});

  UltimateFxDef merge(UltimateFxDef other) {
    return UltimateFxDef(
      shockwave: other.shockwave ?? shockwave,
      glow: other.glow ?? glow,
    );
  }

  factory UltimateFxDef.fromJson(Map<String, dynamic> json) {
    return UltimateFxDef(
      shockwave: json['shockwave'] is Map<String, dynamic>
          ? ShockwaveDef.fromJson(json['shockwave'] as Map<String, dynamic>)
          : null,
      glow: json['glow'] is Map<String, dynamic>
          ? GlowDef.fromJson(json['glow'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ShockwaveDef {
  final double radiusTiles;
  final double duration;
  final double width;
  final Color color;

  const ShockwaveDef({
    required this.radiusTiles,
    required this.duration,
    required this.width,
    required this.color,
  });

  factory ShockwaveDef.fromJson(Map<String, dynamic> json) {
    return ShockwaveDef(
      radiusTiles: (json['radius'] as num?)?.toDouble() ?? 1.6,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.35,
      width: (json['width'] as num?)?.toDouble() ?? 6.0,
      color: _parseHexColor(json['color']?.toString() ?? '#8BE9FF'),
    );
  }
}

class GlowDef {
  final Color color;
  final double scale;
  final double opacity;

  const GlowDef({
    required this.color,
    required this.scale,
    required this.opacity,
  });

  factory GlowDef.fromJson(Map<String, dynamic> json) {
    return GlowDef(
      color: _parseHexColor(json['color']?.toString() ?? '#8BE9FF'),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.4,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.55,
    );
  }
}

Color _parseHexColor(String value) {
  var hex = value.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  final intColor = int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
  return Color(intColor);
}


