import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  static final Map<String, SettingsData> _cache = {};
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SettingsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) {
    return _firestore.collection('users').doc(uid).collection('settings').doc('main');
  }

  Future<SettingsData> load() async {
    final uid = _uid;
    if (uid == null) {
      return const SettingsData(musicOn: true, sfxOn: true, showDamage: true);
    }
    final cached = _cache[uid];
    if (cached != null) {
      return cached;
    }
    try {
      final cachedSnap =
          await _settingsDoc(uid).get(const GetOptions(source: Source.cache));
      final cachedData = cachedSnap.data()?['data'];
      final cachedParsed = _parseSettings(cachedData);
      if (cachedParsed != null) {
        _cache[uid] = cachedParsed;
        return cachedParsed;
      }
    } catch (_) {}

    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await _settingsDoc(uid).get().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      snap = null;
    }
    if (snap == null || !snap.exists) {
      const fallback = SettingsData(musicOn: true, sfxOn: true, showDamage: true);
      _cache[uid] = fallback;
      return fallback;
    }
    final data = snap.data()?['data'];
    final parsed = _parseSettings(data);
    if (parsed != null) {
      _cache[uid] = parsed;
      return parsed;
    }
    const fallback = SettingsData(musicOn: true, sfxOn: true, showDamage: true);
    _cache[uid] = fallback;
    return fallback;
  }

  SettingsData? _parseSettings(Object? data) {
    if (data is Map<String, dynamic>) {
      return SettingsData.fromJson(data);
    }
    if (data is Map) {
      return SettingsData.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<void> save(SettingsData data) async {
    final uid = _uid;
    if (uid == null) return;
    _cache[uid] = data;
    await _settingsDoc(uid).set({
      'data': data.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resetCurrentUserSettings() async {
    final uid = _uid;
    if (uid == null) return;
    _cache.remove(uid);
    await _settingsDoc(uid).delete().catchError((_) {});
  }
}
