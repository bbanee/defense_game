import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RankingEntry {
  final String name;
  final int score;

  const RankingEntry({required this.name, required this.score});

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      name: json['name'] as String,
      score: json['score'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'score': score,
    };
  }
}

class RankingRepository {
  static const String _stagePrefsKey = 'local_stage_ranking_json';
  static const String _infinitePrefsKey = 'local_infinite_ranking_json';

  Future<List<RankingEntry>> loadStage() async {
    return _loadFromKey(_stagePrefsKey);
  }

  Future<List<RankingEntry>> loadInfinite() async {
    return _loadFromKey(_infinitePrefsKey);
  }

  Future<List<RankingEntry>> load() async {
    return loadStage();
  }

  Future<List<RankingEntry>> _loadFromKey(String prefsKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => RankingEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveStage(List<RankingEntry> entries) async {
    await _saveToKey(_stagePrefsKey, entries);
  }

  Future<void> saveInfinite(List<RankingEntry> entries) async {
    await _saveToKey(_infinitePrefsKey, entries);
  }

  Future<void> save(List<RankingEntry> entries) async {
    await saveStage(entries);
  }

  Future<void> _saveToKey(String prefsKey, List<RankingEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(prefsKey, raw);
  }

  Future<void> addStageScore(String name, int score) async {
    await _addScoreToKey(_stagePrefsKey, name, score);
  }

  Future<void> addInfiniteScore(String name, int score) async {
    await _addScoreToKey(_infinitePrefsKey, name, score);
  }

  Future<void> addScore(String name, int score) async {
    await addStageScore(name, score);
  }

  Future<void> _addScoreToKey(String prefsKey, String name, int score) async {
    final entries = await _loadFromKey(prefsKey);
    final updated = [...entries, RankingEntry(name: name, score: score)];
    updated.sort((a, b) => b.score.compareTo(a.score));
    await _saveToKey(prefsKey, updated.take(20).toList());
  }
}
