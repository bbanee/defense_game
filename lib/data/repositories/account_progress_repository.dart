import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';

class AccountProgressRepository {
  static const String _path = 'assets/data/progress/account.json';
  static const String _prefsKey = 'account_progress_json';

  Future<AccountProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      return AccountProgress.fromJson(json);
    }

    final raw = await rootBundle.loadString(_path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AccountProgress.fromJson(json);
  }

  Future<void> save(AccountProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(progress.toJson());
    await prefs.setString(_prefsKey, json);
  }
}
