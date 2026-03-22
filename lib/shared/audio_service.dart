import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:tower_defense/data/repositories/settings_repository.dart';

enum AudioBgmTrack {
  login('audio/bgm/login_theme.mp3', 0.34),
  lobby('audio/bgm/lobby_theme.mp3', 0.36),
  battle('audio/bgm/battle_theme.mp3', 0.24);

  const AudioBgmTrack(this.assetPath, this.volume);

  final String assetPath;
  final double volume;
}

class AppAudioService {
  AppAudioService._();

  static final AppAudioService instance = AppAudioService._();

  final SettingsRepository _settingsRepo = SettingsRepository();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _jinglePlayer = AudioPlayer();
  final Map<String, DateTime> _throttleMap = {};
  final Queue<AudioPlayer> _activeSfxPlayers = Queue<AudioPlayer>();
  DateTime _lastThrottleCleanup = DateTime.fromMillisecondsSinceEpoch(0);

  // Android 동시 오디오 플레이어 한계(~32)를 고려한 상한
  // 궁극기·시스템음은 이 제한을 받지 않도록 _playSfx에서 파라미터로 제어
  static const int _maxConcurrentSfxPlayers = 20;

  bool _initialized = false;
  bool _musicOn = true;
  bool _sfxOn = true;
  String? _currentBgmPath;
  int _bgmRequestVersion = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(
        route: AudioContextConfigRoute.system,
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build(),
    );
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _jinglePlayer.setReleaseMode(ReleaseMode.stop);
    await _jinglePlayer.setPlayerMode(PlayerMode.mediaPlayer);
  }

  Future<void> syncSettings() async {
    final settings = await _settingsRepo.load();
    applySettings(settings);
  }

  void applySettings(SettingsData settings) {
    _musicOn = settings.musicOn;
    _sfxOn = settings.sfxOn;
    if (!_musicOn) {
      unawaited(_bgmPlayer.stop());
    }
  }

  Future<void> playBgm(AudioBgmTrack track) async {
    final requestVersion = ++_bgmRequestVersion;
    await initialize();
    if (requestVersion != _bgmRequestVersion) return;
    await syncSettings();
    if (requestVersion != _bgmRequestVersion) return;
    if (!_musicOn) return;
    if (_currentBgmPath == track.assetPath &&
        _bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.setVolume(track.volume);
      return;
    }
    _currentBgmPath = track.assetPath;
    await _bgmPlayer.stop();
    if (requestVersion != _bgmRequestVersion) return;
    await _bgmPlayer.setVolume(track.volume);
    if (requestVersion != _bgmRequestVersion) return;
    await _bgmPlayer.play(AssetSource(track.assetPath));
  }

  Future<void> stopBgm() async {
    _bgmRequestVersion++;
    _currentBgmPath = null;
    await initialize();
    await _bgmPlayer.stop();
  }

  Future<void> stopAllSfx() async {
    final players = _activeSfxPlayers.toList(growable: false);
    _activeSfxPlayers.clear();
    for (final player in players) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  Future<void> playUiClick() =>
      _playSfx(
        'audio/sfx/ui/button_click.mp3',
        volume: 0.55,
        maxDuration: const Duration(seconds: 1),
      );

  Future<void> playTabSwitch() =>
      _playSfx('audio/sfx/ui/tab_switch.mp3', volume: 0.50);

  Future<void> playPopupOpen() =>
      _playSfx('audio/sfx/ui/popup_open.mp3', volume: 0.46);

  Future<void> playPopupClose() =>
      _playSfx('audio/sfx/ui/popup_close.mp3', volume: 0.42);

  Future<void> playConfirm() =>
      _playSfx('audio/sfx/ui/confirm.mp3', volume: 0.56);

  Future<void> playError() => _playSfx('audio/sfx/ui/error.mp3',
      volume: 0.52, minGap: const Duration(milliseconds: 120));

  Future<void> playTowerPlace() => _playSfx(
        'audio/sfx/system/tower_place.mp3',
        volume: 0.62,
        minGap: const Duration(milliseconds: 80),
      );

  Future<void> playTowerPlaceFail() => _playSfx(
        'audio/sfx/system/tower_place_fail.mp3',
        volume: 0.56,
        minGap: const Duration(milliseconds: 120),
      );

  Future<void> playTowerUpgrade() => _playSfx(
        'audio/sfx/system/tower_upgrade.mp3',
        volume: 0.64,
        minGap: const Duration(milliseconds: 100),
      );

  Future<void> playCoreHit() => _playSfx(
        'audio/sfx/system/core_hit.mp3',
        volume: 0.60,
        throttleKey: 'core_hit',
        minGap: const Duration(milliseconds: 420),
        maxDuration: const Duration(milliseconds: 220),
      );

  Future<void> playBossAlert() => _playSfx(
        'audio/sfx/system/boss_alert.mp3',
        volume: 0.82,
        minGap: const Duration(milliseconds: 600),
      );

  Future<void> playBossAlertStinger() => _playSfx(
        'audio/bgm/boss_alert_stinger.mp3',
        volume: 0.68,
        minGap: const Duration(milliseconds: 600),
      );

  Future<void> playGachaOpen() => _playSfx(
        'audio/sfx/system/gacha_open.mp3',
        volume: 0.62,
        minGap: const Duration(milliseconds: 150),
      );

  Future<void> playVictoryJingle() =>
      _playJingle('audio/bgm/result_victory.mp3', volume: 0.74);

  Future<void> playDefeatJingle() =>
      _playJingle('audio/bgm/result_defeat.mp3', volume: 0.72);

  /// BGM/SFX를 먼저 정지한 뒤 _jinglePlayer로 징글을 재생한다.
  /// _activeSfxPlayers에 등록하지 않으므로 stopAllSfx()에 의해 kill되지 않는다.
  Future<void> _playJingle(String assetPath, {required double volume}) async {
    await initialize();
    // BGM과 SFX를 먼저 멈추고 나서 징글 시작 (순서 보장)
    await stopBgm();
    await stopAllSfx();
    if (!_sfxOn) return;
    try {
      await _jinglePlayer.stop();
      await _jinglePlayer.setVolume(volume);
      await _jinglePlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> playTowerAttack(
    String towerId, {
    required bool isUltimate,
    required double attackIntervalSec,
    required String sourceKey,
  }) {
    final assetPath =
        'audio/sfx/towers/${towerId}_${isUltimate ? 2 : 1}.${_towerAudioExtension(towerId, isUltimate)}';
    final throttleKey = 'tower:$towerId:${isUltimate ? 2 : 1}:$sourceKey';
    final minGap = Duration(
      milliseconds: isUltimate
          ? 220
          : math.max(90, math.min(260, (attackIntervalSec * 650).round())),
    );
    final volume = isUltimate
        ? _ultimateVolumeForTower(towerId)
        : _basicVolumeForTower(towerId, attackIntervalSec);
    final maxDuration = _towerMaxDurationForSfx(
      towerId,
      isUltimate: isUltimate,
    );
    return _playSfx(
      assetPath,
      volume: volume,
      throttleKey: throttleKey,
      minGap: minGap,
      maxDuration: maxDuration,
    );
  }

  String _towerAudioExtension(String towerId, bool isUltimate) {
    if (!isUltimate) return 'mp3';
    return switch (towerId) {
      'chrono_basic' || 'mortar_basic' => 'ogg',
      _ => 'mp3',
    };
  }

  double _basicVolumeForTower(String towerId, double attackIntervalSec) {
    final base = switch (towerId) {
      'rapid_basic' => 0.15,
      'support_basic' => 0.13,
      'chain_basic' => 0.19,
      'laser_basic' => 0.17,
      'drone_basic' => 0.15,
      'gravity_basic' => 0.18,
      'infection_basic' => 0.17,
      'sniper_basic' => 0.25,
      'shotgun_basic' => 0.27,
      'missile_basic' => 0.25,
      'mortar_basic' => 0.27,
      'singularity_basic' => 0.27,
      _ => 0.21,
    };
    final speedComp = attackIntervalSec <= 0
        ? 1.0
        : (attackIntervalSec / 1.1).clamp(0.72, 1.15);
    return (base * speedComp).clamp(0.08, 0.28);
  }

  double _ultimateVolumeForTower(String towerId) {
    return switch (towerId) {
      'support_basic' || 'drone_basic' => 0.28,
      'rapid_basic' || 'laser_basic' || 'infection_basic' => 0.32,
      'frost_basic' ||
      'chain_basic' ||
      'gravity_basic' ||
      'chrono_basic' =>
        0.36,
      'sniper_basic' || 'shotgun_basic' || 'missile_basic' => 0.40,
      'cannon_basic' || 'mortar_basic' || 'singularity_basic' => 0.46,
      _ => 0.34,
    };
  }

  Duration? _towerMaxDurationForSfx(
    String towerId, {
    required bool isUltimate,
  }) {
    return switch ((towerId, isUltimate)) {
      ('drone_basic', false) => const Duration(milliseconds: 180),
      ('drone_basic', true) => const Duration(milliseconds: 280),
      ('frost_basic', false) => const Duration(milliseconds: 190),
      ('frost_basic', true) => const Duration(milliseconds: 340),
      ('gravity_basic', false) => const Duration(milliseconds: 180),
      ('gravity_basic', true) => const Duration(milliseconds: 320),
      ('infection_basic', false) => const Duration(milliseconds: 170),
      ('infection_basic', true) => const Duration(milliseconds: 300),
      ('laser_basic', false) => const Duration(milliseconds: 160),
      ('laser_basic', true) => const Duration(milliseconds: 240),
      ('singularity_basic', true) => const Duration(milliseconds: 360),
      _ => null,
    };
  }

  Future<void> _playSfx(
    String assetPath, {
    required double volume,
    String? throttleKey,
    Duration? minGap,
    Duration? maxDuration,
  }) async {
    await initialize();
    if (!_sfxOn) return;

    final key = throttleKey ?? assetPath;
    final gap = minGap ?? const Duration(milliseconds: 80);
    final now = DateTime.now();
    final lastPlayedAt = _throttleMap[key];
    if (lastPlayedAt != null && now.difference(lastPlayedAt) < gap) {
      return;
    }
    _throttleMap[key] = now;

    // 30초마다 5초 이상 지난 throttleMap 항목 제거 (배틀 중 누적 방지)
    if (now.difference(_lastThrottleCleanup).inSeconds >= 30) {
      _lastThrottleCleanup = now;
      _throttleMap.removeWhere(
        (_, t) => now.difference(t).inSeconds >= 5,
      );
    }

    // 동시 플레이어 상한 초과 시 가장 오래된 것을 종료하고 새 소리 재생
    if (_activeSfxPlayers.length >= _maxConcurrentSfxPlayers) {
      final oldest = _activeSfxPlayers.removeFirst();
      unawaited(
        oldest.stop().then((_) => oldest.dispose()).catchError((_) {}),
      );
    }

    final player = AudioPlayer();
    try {
      _activeSfxPlayers.addLast(player);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
      unawaited(_disposeLater(player, maxDuration: maxDuration));
    } catch (_) {
      _activeSfxPlayers.remove(player); // Queue.remove() is O(n), fine for ≤20
      unawaited(player.dispose());
    }
  }

  Future<void> _disposeLater(
    AudioPlayer player, {
    Duration? maxDuration,
  }) async {
    try {
      if (maxDuration != null) {
        await Future.any([
          player.onPlayerComplete.first,
          Future<void>.delayed(maxDuration, () async {
            await player.stop();
          }),
        ]).timeout(const Duration(seconds: 4));
      } else {
        await player.onPlayerComplete.first.timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
    final shouldDispose = _activeSfxPlayers.remove(player);
    if (!shouldDispose) {
      return;
    }
    try {
      await player.dispose();
    } catch (_) {}
  }
}
