part of 'tower_defense_game.dart';

enum ResultOverlayAction { doubleReward, close }
enum ContinueOverlayAction { continueAd, giveUp }
enum SpeedAdOverlayAction { unlockAd, close }

class ContinueOverlay extends PositionComponent {
  final TowerDefenseGame gameRef;
  Rect? _continueButtonRect;
  Rect? _giveUpButtonRect;

  ContinueOverlay({required this.gameRef}) {
    priority = 4900;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
    final center = size / 2;
    final buttonY = center.y + 58;
    _continueButtonRect = Rect.fromCenter(
      center: Offset(center.x - 58, buttonY),
      width: 108,
      height: 34,
    );
    _giveUpButtonRect = Rect.fromCenter(
      center: Offset(center.x + 58, buttonY),
      width: 108,
      height: 34,
    );
  }

  @override
  void render(Canvas canvas) {
    _ensureRects();
    final bgPaint = Paint()..color = const Color(0xCC000000);
    canvas.drawRect(size.toRect(), bgPaint);

    final panelRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: 312,
      height: 188,
    );
    final panelPaint = Paint()..color = const Color(0xFF111827);
    final panelBorder = Paint()
      ..color = const Color(0xFF39A7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(10)),
      panelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(10)),
      panelBorder,
    );

    _renderCenteredText(
      canvas,
      '컨티뉴',
      Offset(panelRect.center.dx, panelRect.top + 22),
      const TextStyle(
        color: Color(0xFFF7FBFF),
        fontSize: 28,
        fontWeight: FontWeight.w900,
      ),
    );
    _renderCenteredText(
      canvas,
      '광고를 보고 현재 웨이브를 다시 시작합니다.',
      Offset(panelRect.center.dx, panelRect.top + 68),
      const TextStyle(
        color: Color(0xFFD5E6FF),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
    _renderCenteredText(
      canvas,
      '현재 화면의 적은 제거되고 코어가 회복됩니다.',
      Offset(panelRect.center.dx, panelRect.top + 90),
      const TextStyle(
        color: Color(0xFFA8C8F5),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );

    _renderButton(
      canvas,
      Vector2(panelRect.center.dx - 58, panelRect.top + 150),
      '광고보고 계속',
      fillColor: const Color(0xFF12324A),
      borderColor: const Color(0xFF49C2FF),
      width: 108,
      height: 34,
    );
    _renderButton(
      canvas,
      Vector2(panelRect.center.dx + 58, panelRect.top + 150),
      '포기하기',
      fillColor: const Color(0xFF1B1F2A),
      borderColor: Colors.white,
      width: 108,
      height: 34,
    );
  }

  void _renderCenteredText(
    Canvas canvas,
    String text,
    Offset topCenter,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 240);
    painter.paint(
      canvas,
      Offset(topCenter.dx - painter.width / 2, topCenter.dy),
    );
  }

  void _renderButton(
    Canvas canvas,
    Vector2 center,
    String label, {
    required Color fillColor,
    required Color borderColor,
    required double width,
    required double height,
  }) {
    final rect = Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: width,
      height: height,
    );
    final paint = Paint()..color = fillColor;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      border,
    );
    _renderCenteredTextInRect(
      canvas,
      label,
      rect,
      const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _renderCenteredTextInRect(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width - 8);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  ContinueOverlayAction? hitTest(Vector2 worldPos) {
    _ensureRects();
    final offset = Offset(worldPos.x, worldPos.y);
    if (_continueButtonRect?.contains(offset) ?? false) {
      return ContinueOverlayAction.continueAd;
    }
    if (_giveUpButtonRect?.contains(offset) ?? false) {
      return ContinueOverlayAction.giveUp;
    }
    return null;
  }

  void _ensureRects() {
    if (_continueButtonRect != null && _giveUpButtonRect != null) {
      return;
    }
    final currentSize = gameRef.size;
    if (currentSize.x <= 0 || currentSize.y <= 0) {
      return;
    }
    onGameResize(currentSize);
  }
}

class SpeedAdOverlay extends PositionComponent {
  final TowerDefenseGame gameRef;
  Rect? _unlockButtonRect;
  Rect? _closeButtonRect;

  SpeedAdOverlay({required this.gameRef}) {
    priority = 4850;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
    final center = size / 2;
    final buttonY = center.y + 54;
    _unlockButtonRect = Rect.fromCenter(
      center: Offset(center.x - 58, buttonY),
      width: 108,
      height: 34,
    );
    _closeButtonRect = Rect.fromCenter(
      center: Offset(center.x + 58, buttonY),
      width: 108,
      height: 34,
    );
  }

  @override
  void render(Canvas canvas) {
    _ensureRects();
    final bgPaint = Paint()..color = const Color(0xCC000000);
    canvas.drawRect(size.toRect(), bgPaint);

    final panelRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: 312,
      height: 180,
    );
    final panelPaint = Paint()..color = const Color(0xFF111827);
    final panelBorder = Paint()
      ..color = const Color(0xFF39A7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(10)),
      panelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(10)),
      panelBorder,
    );

    _renderCenteredText(
      canvas,
      '2배속',
      Offset(panelRect.center.dx, panelRect.top + 22),
      const TextStyle(
        color: Color(0xFFF7FBFF),
        fontSize: 28,
        fontWeight: FontWeight.w900,
      ),
    );
    _renderCenteredText(
      canvas,
      '광고를 보고 이번 전투에서 2배속을 사용합니다.',
      Offset(panelRect.center.dx, panelRect.top + 68),
      const TextStyle(
        color: Color(0xFFD5E6FF),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
    _renderCenteredText(
      canvas,
      '광고를 보면 이번 판 동안 1x / 2x 전환이 가능합니다.',
      Offset(panelRect.center.dx, panelRect.top + 90),
      const TextStyle(
        color: Color(0xFFA8C8F5),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );

    _renderButton(
      canvas,
      Vector2(panelRect.center.dx - 58, panelRect.top + 146),
      '광고보고 사용',
      fillColor: const Color(0xFF12324A),
      borderColor: const Color(0xFF49C2FF),
      width: 108,
      height: 34,
    );
    _renderButton(
      canvas,
      Vector2(panelRect.center.dx + 58, panelRect.top + 146),
      '닫기',
      fillColor: const Color(0xFF1B1F2A),
      borderColor: Colors.white,
      width: 108,
      height: 34,
    );
  }

  void _renderCenteredText(
    Canvas canvas,
    String text,
    Offset topCenter,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 250);
    painter.paint(
      canvas,
      Offset(topCenter.dx - painter.width / 2, topCenter.dy),
    );
  }

  void _renderButton(
    Canvas canvas,
    Vector2 center,
    String label, {
    required Color fillColor,
    required Color borderColor,
    required double width,
    required double height,
  }) {
    final rect = Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: width,
      height: height,
    );
    final paint = Paint()..color = fillColor;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      border,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width - 8);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  SpeedAdOverlayAction? hitTest(Vector2 worldPos) {
    _ensureRects();
    final offset = Offset(worldPos.x, worldPos.y);
    if (_unlockButtonRect?.contains(offset) ?? false) {
      return SpeedAdOverlayAction.unlockAd;
    }
    if (_closeButtonRect?.contains(offset) ?? false) {
      return SpeedAdOverlayAction.close;
    }
    return null;
  }

  void _ensureRects() {
    if (_unlockButtonRect != null && _closeButtonRect != null) {
      return;
    }
    final currentSize = gameRef.size;
    if (currentSize.x <= 0 || currentSize.y <= 0) {
      return;
    }
    onGameResize(currentSize);
  }
}

class ResultOverlay extends PositionComponent {
  final TowerDefenseGame gameRef;
  final VoidCallback? onExit;
  final String title;
  final String subtitle;
  Rect? _doubleButtonRect;
  Rect? _closeButtonRect;

  ResultOverlay({
    required this.gameRef,
    required this.title,
    required this.subtitle,
    this.onExit,
  }) {
    priority = 5000;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
    final center = size / 2;
    final panelTop = center.y - 126;
    _doubleButtonRect = gameRef.isInfiniteMode
        ? null
        : Rect.fromCenter(
            center: Offset(center.x - 52, panelTop + 212),
            width: 96,
            height: 30,
          );
    _closeButtonRect = Rect.fromCenter(
      center: Offset(center.x + (gameRef.isInfiniteMode ? 0 : 52), panelTop + 212),
      width: 96,
      height: 30,
    );
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xCC000000);
    canvas.drawRect(size.toRect(), bgPaint);

    final panelRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: 304,
      height: 252,
    );
    final panelPaint = Paint()..color = const Color(0xFF121622);
    final panelBorder = Paint()
      ..color = const Color(0xFF2B7FFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(panelRect, const Radius.circular(10)), panelPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(panelRect, const Radius.circular(10)), panelBorder);

    final headerRect = Rect.fromLTWH(
      panelRect.left + 16,
      panelRect.top + 16,
      panelRect.width - 32,
      48,
    );
    final rewardRect = Rect.fromLTWH(
      panelRect.left + 16,
      panelRect.top + 78,
      panelRect.width - 32,
      84,
    );
    final sectionFill = Paint()..color = const Color(0xFF0F1824);
    final sectionBorder = Paint()
      ..color = const Color(0x663FA7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(headerRect, const Radius.circular(8)),
      sectionFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(headerRect, const Radius.circular(8)),
      sectionBorder,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rewardRect, const Radius.circular(8)),
      sectionFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rewardRect, const Radius.circular(8)),
      sectionBorder,
    );

    final text = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
    final center = size / 2;
    _renderCenteredText(
      canvas,
      title,
      Offset(headerRect.center.dx - 6, headerRect.top + 3),
      const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );

    if (gameRef.isInfiniteMode) {
      _renderCenteredText(
        canvas,
        'SCORE',
        Offset(rewardRect.center.dx, rewardRect.top + 10),
        const TextStyle(
          color: Color(0xFF9FC1FF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
      _renderCenteredText(
        canvas,
        _formatAmount(gameRef.finalInfiniteScore),
        Offset(rewardRect.center.dx, rewardRect.top + 28),
        const TextStyle(
          color: Color(0xFFF8FBFF),
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      );
      _renderCenteredText(
        canvas,
        '도달 웨이브 ${gameRef.displayedWaveNumber}',
        Offset(rewardRect.center.dx, rewardRect.top + 60),
        const TextStyle(
          color: Color(0xFFD7E7FF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      final rewardValuePaint = TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      );

      final goldText = '골드 ${_formatAmount(gameRef.endRewardGold)}';
      final ticketText = '티켓 ${gameRef.endRewardTickets}';
      _renderRewardIcon(
        canvas,
        center: Vector2(rewardRect.left + 34, rewardRect.top + 27),
        type: _RewardIconType.gold,
      );
      rewardValuePaint.render(
        canvas,
        goldText,
        Vector2(rewardRect.left + 58, rewardRect.top + 10),
      );
      _renderRewardIcon(
        canvas,
        center: Vector2(rewardRect.left + 34, rewardRect.top + 61),
        type: _RewardIconType.ticket,
      );
      rewardValuePaint.render(
        canvas,
        ticketText,
        Vector2(rewardRect.left + 58, rewardRect.top + 48),
      );

      _renderButton(
        canvas,
        Vector2(center.x - 52, panelRect.top + 212),
        '보상 2배',
        fillColor: const Color(0xFF12324A),
        borderColor: const Color(0xFF49C2FF),
      );
    }

    _renderButton(
      canvas,
      Vector2(center.x + (gameRef.isInfiniteMode ? 0 : 52), panelRect.top + 212),
      '닫기',
      fillColor: const Color(0xFF1B1F2A),
      borderColor: Colors.white,
    );
  }

  void _renderCenteredText(
    Canvas canvas,
    String text,
    Offset topCenter,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      Offset(topCenter.dx - painter.width / 2, topCenter.dy),
    );
  }

  void _renderRewardIcon(
    Canvas canvas, {
    required Vector2 center,
    required _RewardIconType type,
  }) {
    if (type == _RewardIconType.gold) {
      final bodyRect = Rect.fromCenter(
        center: Offset(center.x, center.y),
        width: 18,
        height: 13,
      );
      final fill = Paint()..color = const Color(0xFFFFC857);
      final border = Paint()
        ..color = const Color(0xFFFFF3B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(6)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(6)),
        border,
      );
      final earPaint = Paint()..color = const Color(0xFFFFD97A);
      canvas.drawCircle(Offset(center.x - 4.5, center.y - 5.0), 2.2, earPaint);
      canvas.drawCircle(Offset(center.x + 2.5, center.y - 5.0), 2.2, earPaint);
      final snoutRect = Rect.fromCenter(
        center: Offset(center.x + 4.3, center.y + 0.5),
        width: 5,
        height: 4,
      );
      final snout = Paint()..color = const Color(0xFFFFE7A6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(snoutRect, const Radius.circular(2)),
        snout,
      );
      final legPaint = Paint()
        ..color = const Color(0xFFFFF1B2)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(center.x - 4.0, center.y + 6.5),
        Offset(center.x - 4.0, center.y + 8.5),
        legPaint,
      );
      canvas.drawLine(
        Offset(center.x + 2.0, center.y + 6.5),
        Offset(center.x + 2.0, center.y + 8.5),
        legPaint,
      );
      return;
    }

    final rect = Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: 18,
      height: 12,
    );
    final fill = Paint()..color = const Color(0xFF56C8FF);
    final border = Paint()
      ..color = const Color(0xFFC5F0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      border,
    );
    final notch = Paint()..color = const Color(0xFF0F1824);
    canvas.drawCircle(Offset(center.x - 4, center.y), 1.5, notch);
  }

  void _renderButton(
    Canvas canvas,
    Vector2 center,
    String label, {
    required Color fillColor,
    required Color borderColor,
    double width = 96.0,
    double height = 30.0,
  }) {
    final rect = Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: width,
      height: height,
    );
    final paint = Paint()..color = fillColor;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), border);

    final text = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    _renderCenteredTextInRect(
      canvas,
      label,
      rect,
      const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _renderCenteredTextInRect(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  String _formatAmount(int value) {
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

  ResultOverlayAction? hitTest(Vector2 worldPos) {
    final offset = Offset(worldPos.x, worldPos.y);
    if (_doubleButtonRect?.contains(offset) ?? false) {
      return ResultOverlayAction.doubleReward;
    }
    if (_closeButtonRect?.contains(offset) ?? false) {
      return ResultOverlayAction.close;
    }
    return null;
  }
}

enum _RewardIconType { gold, ticket }

class BattleHud extends PositionComponent {
  final TowerDefenseGame gameRef;
  Rect? _debugButtonRect;
  Rect? _debugPanelRect;
  Rect? _speedButtonRect;

  BattleHud({required this.gameRef}) {
    priority = 1200;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
    _debugButtonRect = Rect.fromLTWH(size.x - 34, 50, 26, 22);
    _debugPanelRect = Rect.fromLTWH(size.x - 200, 72, 190, 17 * 24 + 8);
    _speedButtonRect = Rect.fromLTWH(size.x - 52, 6, 44, 32);
  }

  @override
  void render(Canvas canvas) {
    const barHeight = 46.0;
    const speedButtonWidth = 44.0;
    final bg = Paint()..color = const Color(0xCC08111B);
    final edgeGlow = Paint()..color = const Color(0x6618D2FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, barHeight), bg);
    canvas.drawRect(Rect.fromLTWH(0, barHeight - 1.2, size.x, 1.2), edgeGlow);

    const gap = 8.0;
    final cardWidth = (size.x - speedButtonWidth - (gap * 5)) / 3;
    final top = 6.0;
    _renderHudCard(
      canvas,
      rect: Rect.fromLTWH(gap, top, cardWidth, 32),
      label: '배틀 골드',
      value: _formatBattleGold(gameRef.battleGold),
      accent: const Color(0xFFFFC94A),
    );
    _renderHudCard(
      canvas,
      rect: Rect.fromLTWH(gap * 2 + cardWidth, top, cardWidth, 32),
      label: '웨이브',
      value: gameRef.isInfiniteMode
          ? '${gameRef.displayedWaveNumber}'
          : '${gameRef.currentWaveIndex + 1}/${gameRef.waves.length}',
      accent: const Color(0xFF37E3A5),
    );
    _renderHudCard(
      canvas,
      rect: Rect.fromLTWH(gap * 3 + cardWidth * 2, top, cardWidth, 32),
      label: '남은시간',
      value: _remainingWaveTimeLabel(),
      accent: const Color(0xFF60A5FA),
      trailing: '${gameRef.towers.length}/${TowerDefenseGame.maxPlacedTowers}',
    );

    final speedRect =
        _speedButtonRect ?? Rect.fromLTWH(size.x - 52, 6, 44, 32);
    final speedFill = Paint()
      ..color = gameRef.adSpeedUnlocked
          ? const Color(0xCC12324A)
          : const Color(0xCC1B1F2A);
    final speedBorder = Paint()
      ..color = gameRef.adSpeedUnlocked
          ? const Color(0xFF49C2FF)
          : const Color(0xFF8AA4C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    canvas.drawRRect(
      RRect.fromRectAndRadius(speedRect, const Radius.circular(8)),
      speedFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(speedRect, const Radius.circular(8)),
      speedBorder,
    );
    _renderCenteredTextInRect(
      canvas,
      gameRef.adSpeedUnlocked
          ? (gameRef.timeScale >= 1.5 ? '2x' : '1x')
          : 'x2',
      speedRect,
      TextStyle(
        color: gameRef.adSpeedUnlocked
            ? const Color(0xFFF8FBFF)
            : const Color(0xFFD7E7FF),
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );

    if (TowerDefenseGame.showDebugUi) {
      final ruleBg = Paint()..color = const Color(0xFF1B1F2A);
      final ruleBorder = Paint()
        ..color = const Color(0xFF2B7FFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final ruleText = TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      final dbg = _debugButtonRect ?? Rect.fromLTWH(size.x - 34, 32, 26, 22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(dbg, const Radius.circular(6)),
        ruleBg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(dbg, const Radius.circular(6)),
        ruleBorder,
      );
      ruleText.render(canvas, 'DBG', Vector2(dbg.left + 2, dbg.top + 4));

      if (gameRef.debugOpen) {
        _renderDebugPanel(canvas);
      }
    }
  }

  void _renderHudCard(
    Canvas canvas, {
    required Rect rect,
    required String label,
    required String value,
    required Color accent,
    String? trailing,
  }) {
    final fill = Paint()..color = const Color(0xEE111A27);
    final border = Paint()
      ..color = accent.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    final glow = Paint()..color = accent.withOpacity(0.14);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      border,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, 4, rect.height),
        const Radius.circular(8),
      ),
      glow,
    );

    final labelPaint = TextPaint(
      style: TextStyle(
        color: const Color(0xFF9FB3C8),
        fontSize: rect.width < 110 ? 8.8 : 9.4,
        fontWeight: FontWeight.w600,
      ),
    );
    final valuePaint = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontSize: rect.width < 110 ? 11.5 : 12.5,
        fontWeight: FontWeight.w800,
        shadows: [
          Shadow(color: accent.withOpacity(0.35), blurRadius: 4),
        ],
      ),
    );
    final trailingPaint = TextPaint(
      style: TextStyle(
        color: const Color(0xFFE5EEF8),
        fontSize: rect.width < 110 ? 9.0 : 9.5,
        fontWeight: FontWeight.w700,
      ),
    );

    labelPaint.render(canvas, label, Vector2(rect.left + 10, rect.top + 4));
    valuePaint.render(canvas, value, Vector2(rect.left + 10, rect.top + 16));
    if (trailing != null) {
      final trailingWidth = trailing.length * (rect.width < 110 ? 5.4 : 5.8);
      trailingPaint.render(
        canvas,
        trailing,
        Vector2(rect.right - trailingWidth - 8, rect.top + 17),
      );
    }
  }

  String _remainingWaveTimeLabel() {
    final remaining = gameRef.spawner.isFinished
        ? (15 - gameRef.waveAdvanceDelayTimer).clamp(0.0, 9999.0)
        : ((gameRef.spawner.totalDurationSec - gameRef.spawner.timer) + 15)
            .clamp(0.0, 9999.0);
    final seconds = remaining.ceil();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String _formatBattleGold(int amount) {
    final raw = amount.toString();
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

  void _renderCenteredTextInRect(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width - 8);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  bool hitDebugButton(Vector2 worldPos) {
    if (!TowerDefenseGame.showDebugUi) return false;
    if (_debugButtonRect == null) return false;
    return _debugButtonRect!.contains(Offset(worldPos.x, worldPos.y));
  }

  bool hitSpeedButton(Vector2 worldPos) {
    if (_speedButtonRect == null) return false;
    return _speedButtonRect!.contains(Offset(worldPos.x, worldPos.y));
  }

  bool hitDebugPanel(Vector2 worldPos, TowerDefenseGame game) {
    if (!TowerDefenseGame.showDebugUi) return false;
    if (_debugPanelRect == null) return false;
    if (!_debugPanelRect!.contains(Offset(worldPos.x, worldPos.y))) return false;
    final local = Offset(worldPos.x - _debugPanelRect!.left, worldPos.y - _debugPanelRect!.top);
    final itemH = 24.0;
    final index = (local.dy / itemH).floor();
    switch (index) {
      case 0:
        game.debugInfiniteGold = !game.debugInfiniteGold;
        return true;
      case 1:
        game.debugSpawn('grunt_basic');
        return true;
      case 2:
        game.debugSpawn('sprinter_basic');
        return true;
      case 3:
        game.debugSpawn('tank_basic');
        return true;
      case 4:
        game.debugSpawn('brute_basic');
        return true;
      case 5:
        game.debugSpawn('scout_basic');
        return true;
      case 6:
        game.debugSpawn('spitter_basic');
        return true;
      case 7:
        game.debugSpawn('armored_basic');
        return true;
      case 8:
        game.debugSpawn('swarm_basic');
        return true;
      case 9:
        game.debugSpawn('elite_basic');
        return true;
      case 10:
        game.debugSpawn('boss_basic');
        return true;
      case 11:
        game.debugLevelUpTowers();
        return true;
      case 12:
        game.debugInfiniteEnemyHp = !game.debugInfiniteEnemyHp;
        return true;
      case 13:
        game._setSpeed(1.0);
        return true;
      case 14:
        game._setSpeed(2.0);
        return true;
      case 15:
        game._setSpeed(4.0);
        return true;
      case 16:
        game._setSpeed(8.0);
        return true;
      default:
        return true;
    }
  }

  void _renderDebugPanel(Canvas canvas) {
    final rect = _debugPanelRect ?? Rect.fromLTWH(size.x - 200, 60, 190, 17 * 24 + 8);
    final bg = Paint()..color = const Color(0xCC0B0B12);
    final border = Paint()
      ..color = const Color(0xFF2B7FFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bg);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), border);

    final items = [
      '무한 골드: ${gameRef.debugInfiniteGold ? 'ON' : 'OFF'}',
      '적 소환: Grunt',
      '적 소환: Sprinter',
      '적 소환: Tank',
      '적 소환: Brute',
      '적 소환: Scout',
      '적 소환: Spitter',
      '적 소환: Armored',
      '적 소환: Swarm',
      '적 소환: Elite',
      '적 소환: Boss',
      '타워 즉시 레벨업',
      '몹 HP 무한: ${gameRef.debugInfiniteEnemyHp ? 'ON' : 'OFF'}',
      '속도 1x',
      '속도 2x',
      '속도 4x',
      '속도 8x',
    ];

    final text = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
      ),
    );
    for (int i = 0; i < items.length; i++) {
      text.render(canvas, items[i], Vector2(rect.left + 8, rect.top + 4 + i * 24));
    }
  }

}


