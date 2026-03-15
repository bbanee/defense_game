// ┌─────────────────────────────────────────────────────┐
// │         Flutter + Flame  Tower Defense              │
// │                                                     │
// │  몹: 고블린(빠름) / 오크(보통) / 트롤(느림·강함)      │
// │  타워: 화살탑(빠름) / 대포탑(광역) / 얼음탑(슬로우)   │
// │  맵: 상단→하단 S자 꺾이는 길, 빈 타일 클릭→타워 건설 │
// └─────────────────────────────────────────────────────┘

import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TowerDefenseApp());
}

class TowerDefenseApp extends StatelessWidget {
  const TowerDefenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tower Defense',
      theme: ThemeData.dark(),
      home: const _GameScreen(),
    );
  }
}

class _GameScreen extends StatefulWidget {
  const _GameScreen();

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  late TowerDefenseGame _game;

  @override
  void initState() {
    super.initState();
    _game = TowerDefenseGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: GameWidget(game: _game)),
    );
  }
}

// ══════════════════════════════════════════════
//  CONSTANTS
// ══════════════════════════════════════════════

const int kCols = 11;
const int kRows = 18;
const double kHudH = 55.0;
const double kPanelH = 90.0;

const List<List<int>> kPath = [
  [5, 0], [5, 1], [5, 2],
  [4, 2], [3, 2], [2, 2], [1, 2],
  [1, 3], [1, 4], [1, 5],
  [2, 5], [3, 5], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [9, 5],
  [9, 6], [9, 7], [9, 8],
  [8, 8], [7, 8], [6, 8], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8],
  [1, 9], [1, 10], [1, 11],
  [2, 11], [3, 11], [4, 11], [5, 11], [6, 11], [7, 11], [8, 11], [9, 11],
  [9, 12], [9, 13], [9, 14],
  [8, 14], [7, 14], [6, 14], [5, 14],
  [5, 15], [5, 16], [5, 17],
];

// ══════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════

enum EnemyType { goblin, orc, troll }

enum TowerType { arrow, cannon, ice }

// ══════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════

class TowerDefenseGame extends FlameGame with TapCallbacks {
  int gold = 150;
  int lives = 20;
  int wave = 0;
  bool gameOver = false;
  bool gameWon = false;
  TowerType selectedTower = TowerType.arrow;

  double tileSize = 34.0;
  double gridOffX = 0.0;
  double gridOffY = kHudH;

  final Set<String> pathSet = {};
  final Map<String, TowerComponent> towers = {};
  final List<EnemyComponent> enemies = [];
  final List<EnemyComponent> _removeQueue = [];

  int waveEnemyCount = 0;
  int waveSpawned = 0;
  bool waveActive = false;
  double spawnTimer = 0;
  final _rng = math.Random();

  static const List<int> towerCosts = [50, 120, 80];

  @override
  Color backgroundColor() => const Color(0xFF0a1628);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _computeLayout();
    for (final p in kPath) {
      pathSet.add('${p[0]},${p[1]}');
    }
    await add(GridMapComponent());
    await add(HUDComponent());
    await add(TowerPanelComponent());
  }

  void _computeLayout() {
    final double availH = size.y - kHudH - kPanelH;
    final double ts1 = availH / kRows;
    final double ts2 = size.x / kCols;
    double ts = ts1 < ts2 ? ts1 : ts2;
    ts = ts.floorToDouble();
    if (ts < 10) ts = 10;
    if (ts > 60) ts = 60;
    tileSize = ts;
    gridOffX = (size.x - tileSize * kCols) / 2;
    gridOffY = kHudH + (availH - tileSize * kRows) / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver || gameWon) return;

    for (final e in _removeQueue) {
      enemies.remove(e);
      e.removeFromParent();
    }
    _removeQueue.clear();

    if (waveActive) {
      if (waveSpawned < waveEnemyCount) {
        spawnTimer -= dt;
        if (spawnTimer <= 0) {
          _spawnEnemy();
          spawnTimer = 0.75;
        }
      } else if (enemies.isEmpty) {
        waveActive = false;
        if (wave >= 10) {
          gameWon = true;
        } else {
          gold += 40;
        }
      }
    }
  }

  void startWave() {
    if (waveActive || gameOver || gameWon || wave >= 10) return;
    wave++;
    waveActive = true;
    waveSpawned = 0;
    spawnTimer = 0.4;
    waveEnemyCount = 5 + wave * 3;
  }

  void _spawnEnemy() {
    waveSpawned++;
    final double r = _rng.nextDouble();
    EnemyType type;
    if (wave <= 2) {
      type = EnemyType.goblin;
    } else if (wave <= 5) {
      type = r < 0.55 ? EnemyType.goblin : EnemyType.orc;
    } else {
      if (r < 0.30) {
        type = EnemyType.troll;
      } else if (r < 0.60) {
        type = EnemyType.orc;
      } else {
        type = EnemyType.goblin;
      }
    }
    final EnemyComponent e = EnemyComponent(type: type, wave: wave);
    enemies.add(e);
    add(e);
  }

  void scheduleRemove(EnemyComponent e) {
    if (!_removeQueue.contains(e)) _removeQueue.add(e);
  }

  void enemyReachedEnd(EnemyComponent e) {
    lives = (lives - 1).clamp(0, 999);
    scheduleRemove(e);
    if (lives <= 0) gameOver = true;
  }

  void enemyKilled(EnemyComponent e) {
    gold += e.reward;
    scheduleRemove(e);
  }

  Vector2 tileCenter(int col, int row) {
    return Vector2(
      gridOffX + col * tileSize + tileSize / 2,
      gridOffY + row * tileSize + tileSize / 2,
    );
  }

  bool isPath(int col, int row) => pathSet.contains('$col,$row');

  @override
  void onTapDown(TapDownEvent event) {
    final Vector2 p = event.canvasPosition;

    if (p.y >= size.y - kPanelH) {
      final int i = (p.x / (size.x / 3)).floor().clamp(0, 2);
      selectedTower = TowerType.values[i];
      return;
    }

    if (p.y < kHudH) {
      if (gameOver || gameWon) {
        _restart();
      } else if (!waveActive && p.x > size.x - 115) {
        startWave();
      }
      return;
    }

    if (gameOver || gameWon) return;
    final int col = ((p.x - gridOffX) / tileSize).floor();
    final int row = ((p.y - gridOffY) / tileSize).floor();

    if (col < 0 || col >= kCols || row < 0 || row >= kRows) return;
    if (isPath(col, row)) return;
    final String key = '$col,$row';
    if (towers.containsKey(key)) return;

    final int cost = towerCosts[selectedTower.index];
    if (gold < cost) return;

    gold -= cost;
    final TowerComponent t =
        TowerComponent(col: col, row: row, type: selectedTower);
    towers[key] = t;
    add(t);
  }

  void _restart() {
    for (final Component c in List.of(children)) {
      if (c is EnemyComponent || c is TowerComponent || c is BulletComponent) {
        c.removeFromParent();
      }
    }
    enemies.clear();
    _removeQueue.clear();
    towers.clear();

    gold = 150;
    lives = 20;
    wave = 0;
    gameOver = false;
    gameWon = false;
    waveActive = false;
    waveSpawned = 0;
    waveEnemyCount = 0;
    spawnTimer = 0;
    selectedTower = TowerType.arrow;
  }
}

// ══════════════════════════════════════════════
//  GRID MAP COMPONENT
// ══════════════════════════════════════════════

class GridMapComponent extends Component with HasGameRef<TowerDefenseGame> {
  @override
  void render(Canvas canvas) {
    final TowerDefenseGame g = gameRef;
    final double ts = g.tileSize;
    final double ox = g.gridOffX;
    final double oy = g.gridOffY;

    final Paint grassA = Paint()..color = const Color(0xFF3a7030);
    final Paint grassB = Paint()..color = const Color(0xFF437838);
    final Paint pathPaint = Paint()..color = const Color(0xFFb89040);
    final Paint pathBorder = Paint()
      ..color = const Color(0xFF956c20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final Paint gridLine = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int r = 0; r < kRows; r++) {
      for (int c = 0; c < kCols; c++) {
        final Rect rect = Rect.fromLTWH(ox + c * ts, oy + r * ts, ts, ts);
        if (g.isPath(c, r)) {
          canvas.drawRect(rect, pathPaint);
          canvas.drawRect(rect, pathBorder);
        } else {
          canvas.drawRect(rect, (c + r).isEven ? grassA : grassB);
        }
        canvas.drawRect(rect, gridLine);
      }
    }

    _drawMarker(canvas, kPath.first[0], kPath.first[1], 'S',
        const Color(0xFF00ee44), g);
    _drawMarker(canvas, kPath.last[0], kPath.last[1], 'E',
        const Color(0xFFff2244), g);
  }

  void _drawMarker(Canvas canvas, int col, int row, String label, Color color,
      TowerDefenseGame g) {
    final double ts = g.tileSize;
    final Vector2 c = g.tileCenter(col, row);
    canvas.drawCircle(
        Offset(c.x, c.y), ts * 0.36, Paint()..color = color.withOpacity(0.85));
    canvas.drawCircle(
        Offset(c.x, c.y),
        ts * 0.36,
        Paint()
          ..color = Colors.white38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    _centeredText(canvas, label, c.x, c.y, 12, Colors.white);
  }

  void _centeredText(
      Canvas canvas, String t, double x, double y, double fs, Color c) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              color: c, fontSize: fs, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }
}

// ══════════════════════════════════════════════
//  ENEMY COMPONENT
// ══════════════════════════════════════════════

class EnemyComponent extends PositionComponent
    with HasGameRef<TowerDefenseGame> {
  final EnemyType type;
  final int wave;

  late double maxHp;
  late double hp;
  late double speedTiles;
  late int reward;

  int pathIdx = 0;
  double slowTimer = 0;
  bool isDead = false;

  static const Map<EnemyType, Map<String, double>> _stats = {
    EnemyType.goblin: {'hp': 80, 'speed': 2.1, 'reward': 10, 'r': 0.33},
    EnemyType.orc: {'hp': 260, 'speed': 1.2, 'reward': 28, 'r': 0.41},
    EnemyType.troll: {'hp': 750, 'speed': 0.7, 'reward': 65, 'r': 0.48},
  };

  static const Map<EnemyType, Color> _colors = {
    EnemyType.goblin: Color(0xFF22dd55),
    EnemyType.orc: Color(0xFFaa44dd),
    EnemyType.troll: Color(0xFF994422),
  };

  static const Map<EnemyType, String> _labels = {
    EnemyType.goblin: 'G',
    EnemyType.orc: 'O',
    EnemyType.troll: 'T',
  };

  EnemyComponent({required this.type, required this.wave}) {
    final Map<String, double> s = _stats[type]!;
    maxHp = s['hp']! * (1.0 + wave * 0.2);
    hp = maxHp;
    speedTiles = s['speed']!;
    reward = s['reward']!.toInt();
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    position = gameRef.tileCenter(kPath[0][0], kPath[0][1]);
    size = Vector2.all(gameRef.tileSize);
  }

  @override
  void update(double dt) {
    if (isDead) return;
    if (pathIdx >= kPath.length - 1) {
      isDead = true;
      gameRef.enemyReachedEnd(this);
      return;
    }

    if (slowTimer > 0) slowTimer -= dt;
    final double spd =
        speedTiles * gameRef.tileSize * (slowTimer > 0 ? 0.38 : 1.0);
    final Vector2 target =
        gameRef.tileCenter(kPath[pathIdx + 1][0], kPath[pathIdx + 1][1]);
    final Vector2 diff = target - position;
    final double dist = diff.length;
    final double step = spd * dt;

    if (step >= dist) {
      position = target.clone();
      pathIdx++;
    } else {
      position += diff.normalized() * step;
    }
  }

  @override
  void render(Canvas canvas) {
    final double ts = gameRef.tileSize;
    final double r = ts * _stats[type]!['r']!;
    final Color color = _colors[type]!;

    canvas.drawCircle(
        const Offset(1.5, 2), r * 0.92, Paint()..color = Colors.black38);
    canvas.drawCircle(Offset.zero, r, Paint()..color = color);
    canvas.drawCircle(Offset(-r * 0.3, -r * 0.3), r * 0.35,
        Paint()..color = Colors.white.withOpacity(0.22));
    canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    if (slowTimer > 0) {
      canvas.drawCircle(
          Offset.zero,
          r + 3,
          Paint()
            ..color = Colors.lightBlue.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }

    final double bw = ts * 0.85;
    const double bh = 4.5;
    final double bx = -bw / 2;
    final double by = -r - bh - 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(2)),
      Paint()..color = const Color(0xFF770000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, bw * (hp / maxHp).clamp(0.0, 1.0), bh),
          const Radius.circular(2)),
      Paint()..color = const Color(0xFF00ee44),
    );

    _centeredText(canvas, _labels[type]!, 0, 0, ts * 0.28, Colors.white);
  }

  void _centeredText(
      Canvas canvas, String t, double x, double y, double fs, Color c) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              color: c,
              fontSize: fs.clamp(8.0, 18.0),
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }
}

// ══════════════════════════════════════════════
//  TOWER COMPONENT
// ══════════════════════════════════════════════

class TowerComponent extends PositionComponent
    with HasGameRef<TowerDefenseGame> {
  final int col, row;
  final TowerType type;

  double attackCooldown = 0;

  static const List<double> kRange = [3.0, 2.3, 2.8];
  static const List<double> kCooldown = [0.6, 1.8, 1.2];
  static const List<double> kDamage = [22.0, 70.0, 30.0];

  TowerComponent({required this.col, required this.row, required this.type}) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    position = gameRef.tileCenter(col, row);
    size = Vector2.all(gameRef.tileSize);
  }

  @override
  void update(double dt) {
    attackCooldown -= dt;
    if (attackCooldown <= 0) {
      final bool attacked = _tryAttack();
      attackCooldown = attacked ? kCooldown[type.index] : 0.1;
    }
  }

  bool _tryAttack() {
    final TowerDefenseGame g = gameRef;
    final double range = kRange[type.index] * g.tileSize;
    final double dmg = kDamage[type.index];

    EnemyComponent? target;
    int bestIdx = -1;
    for (final EnemyComponent e in g.enemies) {
      if (e.isDead) continue;
      if ((e.position - position).length <= range && e.pathIdx > bestIdx) {
        target = e;
        bestIdx = e.pathIdx;
      }
    }
    if (target == null) return false;

    if (type == TowerType.cannon) {
      final double splashPx = g.tileSize * 1.4;
      for (final EnemyComponent e in List.of(g.enemies)) {
        if (e.isDead) continue;
        if ((e.position - target.position).length <= splashPx) {
          e.hp -= dmg;
          if (e.hp <= 0) {
            e.isDead = true;
            g.enemyKilled(e);
          }
        }
      }
    } else {
      target.hp -= dmg;
      if (type == TowerType.ice) target.slowTimer = 2.8;
      if (target.hp <= 0) {
        target.isDead = true;
        g.enemyKilled(target);
      }
    }

    g.add(BulletComponent(
      from: position.clone(),
      to: target.position.clone(),
      towerType: type,
    ));
    return true;
  }

  @override
  void render(Canvas canvas) {
    final double ts = gameRef.tileSize;
    final double h = ts / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero, width: ts * 0.9, height: ts * 0.9),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3a3a4a),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero, width: ts * 0.9, height: ts * 0.9),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.black38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    switch (type) {
      case TowerType.arrow:
        _renderArrow(canvas, h);
        break;
      case TowerType.cannon:
        _renderCannon(canvas, h);
        break;
      case TowerType.ice:
        _renderIce(canvas, h);
        break;
    }
  }

  void _renderArrow(Canvas canvas, double h) {
    canvas.drawRect(
      Rect.fromLTWH(-5, -h * 0.2, 10, h * 0.8),
      Paint()..color = const Color(0xFF9B6E3E),
    );
    canvas.drawRect(
      Rect.fromLTWH(-8, -h * 0.62, 16, 11),
      Paint()..color = const Color(0xFFb08050),
    );
    final Path arrow = Path()
      ..moveTo(0, -h * 0.95)
      ..lineTo(-4, -h * 0.52)
      ..lineTo(-1.5, -h * 0.58)
      ..lineTo(-1.5, -h * 0.25)
      ..lineTo(1.5, -h * 0.25)
      ..lineTo(1.5, -h * 0.58)
      ..lineTo(4, -h * 0.52)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFFddddcc));
  }

  void _renderCannon(Canvas canvas, double h) {
    canvas.drawCircle(
        Offset(0, h * 0.1), h * 0.52, Paint()..color = const Color(0xFF555568));
    canvas.drawCircle(
        Offset(0, h * 0.1),
        h * 0.52,
        Paint()
          ..color = Colors.black38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-3.5, -h * 0.92, 7, h * 0.85),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF333344),
    );
    canvas.drawCircle(Offset(0, h * 0.15), h * 0.2,
        Paint()..color = const Color(0xFFbbbb00));
  }

  void _renderIce(Canvas canvas, double h) {
    final Path crystal = Path()
      ..moveTo(0, -h * 0.9)
      ..lineTo(h * 0.42, -h * 0.08)
      ..lineTo(h * 0.28, h * 0.62)
      ..lineTo(-h * 0.28, h * 0.62)
      ..lineTo(-h * 0.42, -h * 0.08)
      ..close();
    canvas.drawPath(crystal, Paint()..color = const Color(0xFF44aaff));
    canvas.drawPath(
        crystal,
        Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawLine(
      Offset(-h * 0.12, -h * 0.7),
      Offset(-h * 0.06, h * 0.5),
      Paint()
        ..color = Colors.white38
        ..strokeWidth = 2,
    );
  }
}

// ══════════════════════════════════════════════
//  BULLET COMPONENT
// ══════════════════════════════════════════════

class BulletComponent extends PositionComponent
    with HasGameRef<TowerDefenseGame> {
  final Vector2 from;
  final Vector2 to;
  final TowerType towerType;
  double _t = 0;

  static const double _duration = 0.16;

  BulletComponent(
      {required this.from, required this.to, required this.towerType}) {
    position = from.clone();
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    _t += dt / _duration;
    if (_t >= 1) {
      removeFromParent();
      return;
    }
    position = from + (to - from) * _t;
  }

  @override
  void render(Canvas canvas) {
    switch (towerType) {
      case TowerType.arrow:
        canvas.drawCircle(
            Offset.zero, 3, Paint()..color = const Color(0xFFffee44));
        canvas.drawCircle(
            Offset.zero,
            5,
            Paint()..color = const Color(0xFFffee44).withOpacity(0.3));
        break;
      case TowerType.cannon:
        canvas.drawCircle(
            Offset.zero, 6, Paint()..color = const Color(0xFF222233));
        canvas.drawCircle(
            Offset.zero,
            6,
            Paint()
              ..color = Colors.black45
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        canvas.drawCircle(Offset.zero, 9,
            Paint()..color = Colors.orangeAccent.withOpacity(0.35));
        break;
      case TowerType.ice:
        canvas.drawCircle(
            Offset.zero, 4, Paint()..color = const Color(0xFF88ddff));
        canvas.drawCircle(
            Offset.zero,
            7,
            Paint()..color = const Color(0xFF88ddff).withOpacity(0.3));
        break;
    }
  }
}

// ══════════════════════════════════════════════
//  HUD COMPONENT
// ══════════════════════════════════════════════

class HUDComponent extends Component with HasGameRef<TowerDefenseGame> {
  @override
  void render(Canvas canvas) {
    final TowerDefenseGame g = gameRef;
    final double w = g.size.x;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, kHudH),
      Paint()..color = const Color(0xFF0d1b2a),
    );
    canvas.drawLine(
      Offset(0, kHudH),
      Offset(w, kHudH),
      Paint()
        ..color = Colors.white12
        ..strokeWidth = 1,
    );

    _txt(canvas, 'GOLD ${g.gold}', 12, 9, Colors.amber, 13, bold: true);
    _txt(canvas, 'LIFE ${g.lives}', 12, 30, const Color(0xFFff4444), 13,
        bold: true);
    _txt(canvas, 'WAVE ${g.wave}/10', w / 2, 9, Colors.white70, 13,
        center: true);

    if (g.gameOver) {
      _txt(canvas, 'GAME OVER', w / 2, 28, const Color(0xFFff3333), 17,
          center: true, bold: true);
      _button(canvas, 'RESTART', w - 110, 8, 100, 38,
          const Color(0xFF554444));
    } else if (g.gameWon) {
      _txt(canvas, 'VICTORY!', w / 2, 28, const Color(0xFFffdd00), 17,
          center: true, bold: true);
      _button(canvas, 'RESTART', w - 110, 8, 100, 38,
          const Color(0xFF334455));
    } else if (!g.waveActive) {
      final String lbl = g.wave == 0 ? 'START' : 'NEXT';
      _button(canvas, lbl, w - 110, 8, 100, 38, const Color(0xFF1a7a3a));
    } else {
      _txt(canvas, 'WAVE ${g.wave}', w - 90, 14, Colors.orange, 11);
      _txt(canvas, 'ACTIVE', w - 74, 30, Colors.orange, 10);
    }
  }

  void _button(Canvas canvas, String lbl, double x, double y, double w,
      double h, Color c) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(7)),
      Paint()..color = c,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(7)),
      Paint()
        ..color = Colors.white30
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _txt(canvas, lbl, x + w / 2, y + h / 2, Colors.white, 13,
        center: true, vCenter: true, bold: true);
  }

  void _txt(Canvas canvas, String text, double x, double y, Color color,
      double fs,
      {bool center = false, bool vCenter = false, bool bold = false}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fs,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas,
        Offset(
          center ? x - tp.width / 2 : x,
          vCenter ? y - tp.height / 2 : y,
        ));
  }
}

// ══════════════════════════════════════════════
//  TOWER PANEL COMPONENT
// ══════════════════════════════════════════════

class TowerPanelComponent extends Component with HasGameRef<TowerDefenseGame> {
  static const List<String> _line1 = ['화살탑', '대포탑', '얼음탑'];
  static const List<String> _line2 = ['50G / 빠름', '120G / 광역', '80G / 슬로우'];
  static const List<Color> _colors = [
    Color(0xFF8B5E2E),
    Color(0xFF444466),
    Color(0xFF3388EE),
  ];

  @override
  void render(Canvas canvas) {
    final TowerDefenseGame g = gameRef;
    final double w = g.size.x;
    final double panelY = g.size.y - kPanelH;
    final double btnW = w / 3;

    canvas.drawRect(
      Rect.fromLTWH(0, panelY, w, kPanelH),
      Paint()..color = const Color(0xFF0d1b2a),
    );
    canvas.drawLine(
      Offset(0, panelY),
      Offset(w, panelY),
      Paint()
        ..color = Colors.white12
        ..strokeWidth = 1,
    );

    for (int i = 0; i < 3; i++) {
      final double bx = i * btnW + 5;
      final double by = panelY + 5;
      final double bw = btnW - 10;
      final double bh = kPanelH - 10;
      final bool selected = g.selectedTower.index == i;
      final bool canAfford = g.gold >= TowerDefenseGame.towerCosts[i];
      final Color color = _colors[i];

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(7)),
        Paint()
          ..color =
              selected ? color.withOpacity(0.30) : const Color(0xFF162230),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(7)),
        Paint()
          ..color = selected ? color : Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.2 : 1.0,
      );

      final double cx = bx + bw / 2;
      final double iy = by + bh * 0.4;
      _drawIcon(canvas, TowerType.values[i], cx, iy, color);

      _textC(canvas, _line1[i], cx, by + bh * 0.68,
          canAfford ? Colors.white : Colors.grey, 11, bold: true);
      _textC(canvas, _line2[i], cx, by + bh * 0.83,
          canAfford ? Colors.white60 : Colors.grey.shade700, 9);
    }
  }

  void _drawIcon(
      Canvas canvas, TowerType type, double cx, double cy, Color color) {
    switch (type) {
      case TowerType.arrow:
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy + 3), width: 10, height: 14),
          Paint()..color = color,
        );
        final Path path = Path()
          ..moveTo(cx, cy - 12)
          ..lineTo(cx - 5, cy - 4)
          ..lineTo(cx + 5, cy - 4)
          ..close();
        canvas.drawPath(path, Paint()..color = Colors.grey[300]!);
        break;
      case TowerType.cannon:
        canvas.drawCircle(Offset(cx, cy + 2), 9, Paint()..color = color);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 3, cy - 14, 6, 12),
              const Radius.circular(2)),
          Paint()..color = const Color(0xFF222233),
        );
        break;
      case TowerType.ice:
        final Path crystal = Path()
          ..moveTo(cx, cy - 13)
          ..lineTo(cx + 8, cy - 1)
          ..lineTo(cx + 6, cy + 10)
          ..lineTo(cx - 6, cy + 10)
          ..lineTo(cx - 8, cy - 1)
          ..close();
        canvas.drawPath(crystal, Paint()..color = color);
        canvas.drawPath(
            crystal,
            Paint()
              ..color = Colors.white54
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
        break;
    }
  }

  void _textC(Canvas canvas, String t, double cx, double cy, Color c,
      double fs,
      {bool bold = false}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: c,
          fontSize: fs,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}
