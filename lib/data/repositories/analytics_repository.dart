import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AnalyticsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

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
  }

  Future<void> clearCurrentUserBattleHistory() async {
    return;
  }
}
