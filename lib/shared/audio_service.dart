import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:tower_defense/data/repositories/settings_repository.dart';

enum AudioBgmTrack {
  login('audio/bgm/login_theme.mp3', 0.34),
  lobby('audio/bgm/lobby_theme.mp3', 0.36),
  battle('audio/bgm/battle_theme.mp3', 0.32);

  const AudioBgmTrack(this.assetPath, this.volume);

  final String assetPath;
  final double volume;
}

class AppAudioService {
  AppAudioService._();

  static final AppAudioService instance = AppAudioService._();

  final SettingsRepository _settingsRepo = SettingsRepository();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final Map<String, DateTime> _throttleMap = {};
  final Set<AudioPlayer> _activeSfxPlayers = <AudioPlayer>{};

  bool _initialized = false;
  bool _musicOn = true;
  bool _sfxOn = true;
  String? _currentBgmPath;

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
    await initialize();
    await syncSettings();
    if (!_musicOn) return;
    if (_currentBgmPath == track.assetPath &&
        _bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.setVolume(track.volume);
      return;
    }
    _currentBgmPath = track.assetPath;
    await _bgmPlayer.stop();
    await _bgmPlayer.setVolume(track.volume);
    await _bgmPlayer.play(AssetSource(track.assetPath));
  }

  Future<void> stopBgm() async {
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

  Future<void> playVictoryJingle() => _playSfx(
        'audio/bgm/result_victory.mp3',
        volume: 0.74,
        minGap: const Duration(milliseconds: 400),
      );

  Future<void> playDefeatJingle() => _playSfx(
        'audio/bgm/result_defeat.mp3',
        volume: 0.72,
        minGap: const Duration(milliseconds: 400),
      );

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
    return _playSfx(
      assetPath,
      volume: volume,
      throttleKey: throttleKey,
      minGap: minGap,
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
      'rapid_basic' => 0.12,
      'support_basic' => 0.10,
      'chain_basic' => 0.16,
      'laser_basic' => 0.14,
      'drone_basic' => 0.12,
      'gravity_basic' => 0.15,
      'infection_basic' => 0.14,
      'sniper_basic' => 0.22,
      'shotgun_basic' => 0.24,
      'missile_basic' => 0.22,
      'mortar_basic' => 0.24,
      'singularity_basic' => 0.24,
      _ => 0.18,
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

    final player = AudioPlayer();
    try {
      _activeSfxPlayers.add(player);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
      unawaited(_disposeLater(player, maxDuration: maxDuration));
    } catch (_) {
      _activeSfxPlayers.remove(player);
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
    _activeSfxPlayers.remove(player);
    await player.dispose();
  }
}
