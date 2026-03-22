import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';

class AccountProgressRepository {
  static const String _path = 'assets/data/progress/account.json';
  static final Map<String, AccountProgress> _cache = {};
  static final Map<String, AccountProgress> _pendingSaves = {};
  static final Map<String, Timer> _saveTimers = {};
  static final Map<String, String> _lastSnapshotTrimByUid = {};
  static StreamSubscription<User?>? _authSubscription;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AccountProgressRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      // 로그아웃 또는 계정 전환 시 다른 UID의 타이머/캐시 정리
      final currentUid = user?.uid;
      final staleUids = _saveTimers.keys
          .where((uid) => uid != currentUid)
          .toList(growable: false);
      for (final uid in staleUids) {
        _saveTimers.remove(uid)?.cancel();
        _pendingSaves.remove(uid);
        _cache.remove(uid);
        _lastSnapshotTrimByUid.remove(uid);
      }
    });
  }

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _progressDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('main');
  }

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Future<AccountProgress> load() async {
    final uid = _uid;
    if (uid == null) {
      return _loadDefaultAsset();
    }
    final cached = _cache[uid];
    if (cached != null) {
      return cached.copy();
    }

    try {
      final cachedSnap =
          await _progressDoc(uid).get(const GetOptions(source: Source.cache));
      final cachedData = cachedSnap.data()?['data'];
      if (cachedData is Map<String, dynamic>) {
        final progress = AccountProgress.fromJson(cachedData);
        _cache[uid] = progress.copy();
        return progress;
      }
      if (cachedData is Map) {
        final progress =
            AccountProgress.fromJson(Map<String, dynamic>.from(cachedData));
        _cache[uid] = progress.copy();
        return progress;
      }
    } catch (_) {}

    DocumentSnapshot<Map<String, dynamic>>? progressSnap;
    try {
      progressSnap =
          await _progressDoc(uid).get().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      progressSnap = null;
    }
    if (progressSnap == null) {
      final seeded = await _loadDefaultAsset();
      _cache[uid] = seeded.copy();
      return seeded;
    }
    if (!progressSnap.exists) {
      final seeded = await _loadDefaultAsset();
      _cache[uid] = seeded.copy();
      return seeded;
    }

    final data = progressSnap.data()?['data'];
    if (data is Map<String, dynamic>) {
      final progress = AccountProgress.fromJson(data);
      _cache[uid] = progress.copy();
      return progress;
    }
    if (data is Map) {
      final progress = AccountProgress.fromJson(Map<String, dynamic>.from(data));
      _cache[uid] = progress.copy();
      return progress;
    }

    final seeded = await _loadDefaultAsset();
    _cache[uid] = seeded.copy();
    return seeded;
  }

  Future<void> save(AccountProgress progress) async {
    final uid = _uid;
    if (uid == null) return;
    _saveTimers.remove(uid)?.cancel();
    _pendingSaves.remove(uid);
    await _commitSave(uid, progress.copy());
  }

  void scheduleSave(
    AccountProgress progress, {
    Duration delay = const Duration(milliseconds: 800),
  }) {
    final uid = _uid;
    if (uid == null) return;
    final snapshot = progress.copy();
    _cache[uid] = snapshot.copy();
    _pendingSaves[uid] = snapshot;
    _saveTimers.remove(uid)?.cancel();
    _saveTimers[uid] = Timer(delay, () {
      final pending = _pendingSaves.remove(uid);
      _saveTimers.remove(uid);
      if (pending == null) return;
      unawaited(_commitSave(uid, pending));
    });
  }

  Future<void> flushScheduledSave([AccountProgress? progress]) async {
    final uid = _uid;
    if (uid == null) return;
    _saveTimers.remove(uid)?.cancel();
    final pending =
        progress?.copy() ?? _pendingSaves.remove(uid) ?? _cache[uid]?.copy();
    _pendingSaves.remove(uid);
    if (pending == null) return;
    await _commitSave(uid, pending);
  }

  Future<void> _commitSave(String uid, AccountProgress progress) async {
    final nickname = progress.nickname.trim();
    final profileDoc = _profileDoc(uid);
    final batch = _firestore.batch();
    _cache[uid] = progress.copy();
    batch.set(
      _progressDoc(uid),
      {
        'data': progress.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      profileDoc,
      {
        'nickname': nickname,
        'loginType':
            _auth.currentUser?.isAnonymous == true ? 'guest' : 'google',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    unawaited(_saveDailySnapshot(uid, progress));
  }

  Future<void> resetCurrentUserData() async {
    final uid = _uid;
    if (uid == null) return;
    final fresh = await _loadDefaultAsset();
    fresh.nickname = '';
    _saveTimers.remove(uid)?.cancel();
    _pendingSaves.remove(uid);
    _cache.remove(uid);
    await _commitSave(uid, fresh);
  }

  Future<void> deleteCurrentUserData() async {
    final uid = _uid;
    if (uid == null) return;
    _saveTimers.remove(uid)?.cancel();
    _pendingSaves.remove(uid);
    _cache.remove(uid);

    final userDoc = _firestore.collection('users').doc(uid);
    const subcollections = [
      'progress',
      'settings',
      'battleHistory',
      'opsStats',
      'snapshots',
      'diamondLogs',
      'towerPurchaseLogs',
    ];

    await Future.wait(
      subcollections.map((name) async {
        final snapshot = await userDoc.collection(name).get();
        if (snapshot.docs.isEmpty) return;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }),
    );

    await userDoc.delete().catchError((_) {});
  }

  Future<AccountProgress> _loadDefaultAsset() async {
    final raw = await rootBundle.loadString(_path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AccountProgress.fromJson(json);
  }

  Future<void> _saveDailySnapshot(String uid, AccountProgress progress) async {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final snapshotId = '${now.year}-$month-$day';
    final snapshots = _firestore
        .collection('users')
        .doc(uid)
        .collection('snapshots');
    await snapshots.doc(snapshotId).set({
      'date': snapshotId,
      'data': progress.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (_lastSnapshotTrimByUid[uid] == snapshotId) return;
    _lastSnapshotTrimByUid[uid] = snapshotId;
    final snapshot =
        await snapshots.orderBy('date', descending: true).get();
    if (snapshot.docs.length <= 30) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs.skip(30)) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
