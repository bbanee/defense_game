import 'dart:convert';
import 'package:flutter/services.dart';

class JsonAssetLoader {
  const JsonAssetLoader();

  Future<Map<String, dynamic>> loadObject(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<dynamic>> loadList(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as List<dynamic>;
  }
}
