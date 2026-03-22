import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tower_defense/data/repositories/achievement_repository.dart';

class EconomyLogRepository {
  static final Map<String, DateTime> _lastTrimAt = {};
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EconomyLogRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<void> logCurrencyChange({
    required String source,
    required String currency,
    required int amount,
    required int balanceAfter,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final isPremiumCurrency = currency == 'diamonds';
    final delta = <String, int>{};
    if (amount > 0 && currency == 'accountGold') {
      delta['totalGoldEarned'] = amount;
    }
    if (amount < 0 && currency == 'accountGold') {
      delta['totalGoldSpent'] = -amount;
    }
    if (amount > 0 && currency == 'diamonds') {
      delta['totalDiamondsEarned'] = amount;
    }
    if (amount < 0 && currency == 'diamonds') {
      delta['totalDiamondsSpent'] = -amount;
    }
    if (amount > 0 && currency == 'energy') {
      delta['totalEnergyGained'] = amount;
    }
    if (amount > 0 && currency == 'shardDrawTickets') {
      delta['totalTicketsGained'] = amount;
    }
    if (delta.isNotEmpty) {
      AchievementRepository.applyStatsDelta(delta);
    }
    final payload = <String, dynamic>{
      'uid': uid,
      'source': source,
      'currency': currency,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'metadata': metadata ?? const <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('opsStats')
        .doc('main')
        .set({
      if (amount > 0 && currency == 'accountGold')
        'totalGoldEarned': FieldValue.increment(amount),
      if (amount < 0 && currency == 'accountGold')
        'totalGoldSpent': FieldValue.increment(-amount),
      if (amount > 0 && currency == 'diamonds')
        'totalDiamondsEarned': FieldValue.increment(amount),
      if (amount < 0 && currency == 'diamonds')
        'totalDiamondsSpent': FieldValue.increment(-amount),
      if (amount > 0 && currency == 'energy')
        'totalEnergyGained': FieldValue.increment(amount),
      if (amount > 0 && currency == 'shardDrawTickets')
        'totalTicketsGained': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!isPremiumCurrency) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('diamondLogs')
        .add(payload);
    await _trimRecentCollection(
      _firestore.collection('users').doc(uid).collection('diamondLogs'),
      keep: 30,
    );
  }

  Future<void> logUpgrade({
    required String upgradeType,
    required String targetId,
    required int fromLevel,
    required int toLevel,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final delta = <String, int>{
      'totalUpgrades': 1,
      if (upgradeType.startsWith('tower_')) 'towerUpgradeCount': 1,
      if (upgradeType.startsWith('core_')) 'coreUpgradeCount': 1,
    };
    AchievementRepository.applyStatsDelta(delta);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('opsStats')
        .doc('main')
        .set({
      'totalUpgrades': FieldValue.increment(1),
      if (upgradeType.startsWith('tower_'))
        'towerUpgradeCount': FieldValue.increment(1),
      if (upgradeType.startsWith('core_'))
        'coreUpgradeCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logShopAction({
    required String actionType,
    required String itemId,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final rawCount = metadata?['count'];
    final drawCount = rawCount is int ? rawCount : int.tryParse('$rawCount') ?? 1;
    final delta = <String, int>{
      'totalShopActions': 1,
      if (actionType == 'unlock_tower') 'towerPurchaseCount': 1,
      if (actionType.contains('shard_draw')) 'shardDrawCount': drawCount,
    };
    AchievementRepository.applyStatsDelta(delta);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('opsStats')
        .doc('main')
        .set({
      'totalShopActions': FieldValue.increment(1),
      if (actionType == 'unlock_tower')
        'towerPurchaseCount': FieldValue.increment(1),
      if (actionType.contains('shard_draw'))
        'shardDrawCount': FieldValue.increment(drawCount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logTowerPurchase({
    required String towerId,
    required String rarity,
    required String currency,
    required int cost,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final payload = <String, dynamic>{
      'uid': uid,
      'towerId': towerId,
      'rarity': rarity,
      'currency': currency,
      'cost': cost,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('towerPurchaseLogs')
        .add(payload);
    await _trimRecentCollection(
      _firestore.collection('users').doc(uid).collection('towerPurchaseLogs'),
      keep: 30,
    );
  }

  Future<void> logAdReward({
    required String placement,
    required Map<String, dynamic> reward,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    AchievementRepository.applyStatsDelta({'totalAdsRewarded': 1});
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('opsStats')
        .doc('main')
        .set({
      'totalAdsRewarded': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _trimRecentCollection(
    CollectionReference<Map<String, dynamic>> collection, {
    required int keep,
  }) async {
    final trimKey = collection.path;
    final now = DateTime.now();
    final lastTrim = _lastTrimAt[trimKey];
    if (lastTrim != null && now.difference(lastTrim) < const Duration(minutes: 2)) {
      return;
    }
    _lastTrimAt[trimKey] = now;
    final snapshot =
        await collection.orderBy('createdAt', descending: true).get();
    if (snapshot.docs.length <= keep) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs.skip(keep)) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
