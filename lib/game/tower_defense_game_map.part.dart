part of 'tower_defense_game.dart';

class MapComponent extends PositionComponent {
  final TowerDefenseGame gameRef;
  final List<GridPoint> path;
  final Sprite? background;
  final bool showPathOverlay;
  final bool showBuildOverlay;

  MapComponent({
    required this.gameRef,
    required this.path,
    this.background,
    this.showPathOverlay = false,
    this.showBuildOverlay = false,
  });

  @override
  void render(Canvas canvas) {
    final tile = gameRef.tileSize;
    final width = gameRef.gridWidth;
    final height = gameRef.gridHeight;

    if (background != null) {
      background!.render(
        canvas,
        position: Vector2.zero(),
        size: Vector2(width * tile, height * tile),
      );
    }

    if (background == null) {
      final bgPaint = Paint()..color = const Color(0xFF1A1D24);
      canvas.drawRect(Rect.fromLTWH(0, 0, width * tile, height * tile), bgPaint);

      final gridPaint = Paint()
        ..color = const Color(0xFF2A2F3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          canvas.drawRect(Rect.fromLTWH(x * tile, y * tile, tile, tile), gridPaint);
        }
      }
    }

    if (showPathOverlay) {
      final pathPaint = Paint()..color = const Color(0x77394253);
      for (final cell in path) {
        canvas.drawRect(Rect.fromLTWH(cell.x * tile, cell.y * tile, tile, tile), pathPaint);
      }
    }

    if (showBuildOverlay) {
      final buildPaint = Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (final cell in gameRef.buildCells) {
        canvas.drawRect(Rect.fromLTWH(cell.x * tile, cell.y * tile, tile, tile), buildPaint);
      }
    }
  }
}

String _towerEffectPath(String towerId, int index) {
  final base = _towerDisplayName(towerId);
  return 'towers_effect/${base}_$index.png';
}

String _towerSpecialEffectPath(String towerId) {
  return 'towers_special_effect/${towerId}_special_hit.png';
}

class StartEndMarkers extends PositionComponent {
  final TowerDefenseGame gameRef;
  final List<GridPoint> path;

  StartEndMarkers({required this.gameRef, required this.path});

  @override
  void render(Canvas canvas) {
    final tile = gameRef.tileSize;
    final start = path.first;
    final end = path.last;

    final startPaint = Paint()..color = const Color(0xFF00BFA5);
    final endPaint = Paint()..color = const Color(0xFFFF5252);

    canvas.drawRect(Rect.fromLTWH(start.x * tile, start.y * tile, tile, tile), startPaint);
    canvas.drawRect(Rect.fromLTWH(end.x * tile, end.y * tile, tile, tile), endPaint);
  }
}

class CoreBuilding extends PositionComponent {
  final TowerDefenseGame gameRef;
  final GridPoint positionCell;

  double hp = 100;
  double maxHp = 100;
  double shield = 0;
  double maxShield = 0;
  SpriteSheet? coreSheet;
  Vector2 visualOffset = Vector2.zero();

  CoreBuilding({required this.gameRef, required this.positionCell}) {
    size = Vector2(24, 24);
    anchor = Anchor.center;
    priority = 50;
  }

  void setStats(double currentHp, double totalHp, double currentShield, double totalShield) {
    hp = currentHp;
    maxHp = totalHp;
    shield = currentShield;
    maxShield = totalShield;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final tile = gameRef.tileSize;
    this.size = Vector2(tile * 1.92, tile * 1.92);
    visualOffset = Vector2(tile * 0.95, tile * 0.95);
    position = positionCell.toWorld(gameRef) + visualOffset;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final image = await gameRef.images.load('core/core_sheet.png');
      coreSheet = SpriteSheet.fromColumnsAndRows(image: image, columns: 4, rows: 3);
    } catch (_) {
      coreSheet = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final hpWidth = size.x;
    final hpHeight = 4.0;
    final ratio = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    final shieldRatio = maxShield <= 0 ? 0.0 : (shield / maxShield).clamp(0.0, 1.0);

    if (coreSheet != null) {
      final idx = ((1.0 - ratio) * 11).round().clamp(0, 11);
      final row = idx ~/ 4;
      final col = idx % 4;
      final sprite = coreSheet!.getSprite(row, col);
      sprite.render(
        canvas,
        position: Vector2(-size.x / 2, -size.y / 2),
        size: size,
      );
    } else {
      final corePaint = Paint()..color = const Color(0xFF2B7FFF);
      final ringPaint = Paint()
        ..color = const Color(0xFF0B1A36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset.zero, size.x * 0.5, corePaint);
      canvas.drawCircle(Offset.zero, size.x * 0.5 + 2, ringPaint);
    }
    final bgPaint = Paint()..color = const Color(0xFF1E1E1E);
    final fgPaint = Paint()..color = const Color(0xFF33B36A);

    canvas.drawRect(Rect.fromLTWH(-hpWidth / 2, -size.y / 2 - 10, hpWidth, hpHeight), bgPaint);
    canvas.drawRect(
      Rect.fromLTWH(-hpWidth / 2, -size.y / 2 - 10, hpWidth * ratio, hpHeight),
      fgPaint,
    );

    if (maxShield > 0) {
      final shieldBg = Paint()..color = const Color(0xFF1B2B3A);
      final shieldFg = Paint()..color = const Color(0xFF4FC3F7);
      canvas.drawRect(
        Rect.fromLTWH(-hpWidth / 2, -size.y / 2 - 16, hpWidth, hpHeight),
        shieldBg,
      );
      canvas.drawRect(
        Rect.fromLTWH(-hpWidth / 2, -size.y / 2 - 16, hpWidth * shieldRatio, hpHeight),
        shieldFg,
      );
    }
  }
}


