import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsData {
  final bool musicOn;
  final bool sfxOn;
  final bool showDamage;

  const SettingsData({
    required this.musicOn,
    required this.sfxOn,
    required this.showDamage,
  });

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    return SettingsData(
      musicOn: json['musicOn'] as bool? ?? true,
      sfxOn: json['sfxOn'] as bool? ?? true,
      showDamage: json['showDamage'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'musicOn': musicOn,
      'sfxOn': sfxOn,
      'showDamage': showDamage,
    };
  }

  SettingsData copyWith({bool? musicOn, bool? sfxOn, bool? showDamage}) {
    return SettingsData(
      musicOn: musicOn ?? this.musicOn,
      sfxOn: sfxOn ?? this.sfxOn,
      showDamage: showDamage ?? this.showDamage,
    );
  }
}

class SettingsRepository {
  static const String _prefsKey = 'settings_json';

  Future<SettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return const SettingsData(musicOn: true, sfxOn: true, showDamage: true);
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SettingsData.fromJson(json);
  }

  Future<void> save(SettingsData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(data.toJson()));
  }
}
