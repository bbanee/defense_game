import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tower_defense/data/repositories/achievement_repository.dart';

class AnalyticsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AnalyticsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<Map<String, dynamic>> loadOpsStats() async {
    final uid = _uid;
    if (uid == null) return const {};
    final doc = _firestore
        .collection('users')
        .doc(uid)
        .collection('opsStats')
        .doc('main');
    try {
      final cached = await doc.get(const GetOptions(source: Source.cache));
      final cachedData = cached.data();
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData;
      }
    } catch (_) {}
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 2));
      return snap.data() ?? const <String, dynamic>{};
    } on TimeoutException {
      return const <String, dynamic>{};
    }
  }

  Future<void> logBattleResult({
    required String playerName,
    required String mode,
    required String difficultyId,
    required String stageId,
    required int reachedWave,
    required bool victory,
    required int accountGoldReward,
    required int ticketReward,
    required int infiniteScore,
    required int highestPlacedTowerCount,
    required bool usedContinue,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    AchievementRepository.applyStatsDelta({
      'totalBattles': 1,
      if (mode == 'story') 'storyBattles': 1,
      if (mode == 'infinite') 'infiniteBattles': 1,
      if (victory) 'victoryCount': 1,
      if (!victory) 'defeatCount': 1,
    });
    final payload = <String, dynamic>{
      'uid': uid,
      'playerName': playerName,
      'mode': mode,
      'difficultyId': difficultyId,
      'stageId': stageId,
      'reachedWave': reachedWave,
      'victory': victory,
      'accountGoldReward': accountGoldReward,
      'ticketReward': ticketReward,
      'infiniteScore': infiniteScore,
      'highestPlacedTowerCount': highestPlacedTowerCount,
      'usedContinue': usedContinue,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('opsStats')
        .doc('main')
        .set({
      'totalBattles': FieldValue.increment(1),
      if (mode == 'story') 'storyBattles': FieldValue.increment(1),
      if (mode == 'infinite') 'infiniteBattles': FieldValue.increment(1),
      if (victory) 'victoryCount': FieldValue.increment(1),
      if (!victory) 'defeatCount': FieldValue.increment(1),
      'maxReachedWave': FieldValue.increment(0),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastBattle': payload,
    }, SetOptions(merge: true));
    AchievementRepository.invalidateStatsCache();
  }

  Future<void> clearCurrentUserBattleHistory() async {
    return;
  }
}
