import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RankingEntry {
  final String name;
  final int score;
  final String? detail;
  final String? uid;

  const RankingEntry({
    required this.name,
    required this.score,
    this.detail,
    this.uid,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json, {String? uid}) {
    return RankingEntry(
      name: json['name'] as String,
      score: json['score'] as int,
      detail: json['detail'] as String?,
      uid: uid ?? json['uid'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'score': score,
      'detail': detail,
    };
  }
}

class RankingRepository {
  static List<RankingEntry>? _stageCache;
  static List<RankingEntry>? _infiniteCache;
  static final Map<String, Map<String, int>> _stageScoresByUid = {};
  static final Map<String, int> _infiniteScoresByUid = {};
  static Future<void>? _warmUpFuture;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RankingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _stageCollection =>
      _firestore.collection('stageRankings');
  CollectionReference<Map<String, dynamic>> get _infiniteCollection =>
      _firestore.collection('infiniteRankings');

  static const Map<String, String> _difficultyLabelToKey = {
    '이지': 'easy',
    '노말': 'normal',
    '하드': 'hard',
    '나이트메어': 'nightmare',
  };

  static const Map<String, String> _difficultyKeyToLabel = {
    'easy': '이지',
    'normal': '노말',
    'hard': '하드',
    'nightmare': '나이트메어',
  };

  List<RankingEntry> loadStageCached() {
    return List<RankingEntry>.from(_stageCache ?? const []);
  }

  List<RankingEntry> loadInfiniteCached() {
    return List<RankingEntry>.from(_infiniteCache ?? const []);
  }

  Future<void> warmUp() {
    final existing = _warmUpFuture;
    if (existing != null) {
      return existing;
    }
    final future = _warmUpInternal();
    _warmUpFuture = future;
    return future.whenComplete(() {
      if (identical(_warmUpFuture, future)) {
        _warmUpFuture = null;
      }
    });
  }

  Future<List<RankingEntry>> loadStage() async {
    final memoryCached = _stageCache;
    if (memoryCached != null && memoryCached.isNotEmpty) {
      return List<RankingEntry>.from(memoryCached);
    }
    return refreshStage();
  }

  Future<List<RankingEntry>> refreshStage() async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      final cached = await _stageCollection.get(
        const GetOptions(source: Source.cache),
      );
      if (cached.docs.isNotEmpty) {
        snap = cached;
      } else {
        snap = await _stageCollection.get().timeout(const Duration(seconds: 2));
      }
    } catch (_) {
      try {
        snap = await _stageCollection.get().timeout(const Duration(seconds: 2));
      } catch (_) {
        return List<RankingEntry>.from(_stageCache ?? const []);
      }
    }
    _stageCache = _parseStageSnapshot(snap);
    return List<RankingEntry>.from(_stageCache!);
  }

  Future<List<RankingEntry>> loadInfinite() async {
    final memoryCached = _infiniteCache;
    if (memoryCached != null && memoryCached.isNotEmpty) {
      return List<RankingEntry>.from(memoryCached);
    }
    return refreshInfinite();
  }

  Future<List<RankingEntry>> refreshInfinite() async {
    final query =
        _infiniteCollection.orderBy('score', descending: true).limit(20);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) {
        snap = cached;
      } else {
        snap = await query.get().timeout(const Duration(seconds: 2));
      }
    } catch (_) {
      try {
        snap = await query.get().timeout(const Duration(seconds: 2));
      } catch (_) {
        return List<RankingEntry>.from(_infiniteCache ?? const []);
      }
    }
    _infiniteCache = snap.docs.map((doc) {
      final data = doc.data();
      final uid = (data['uid'] as String?) ?? doc.id;
      final score = data['score'] as int? ?? 0;
      _infiniteScoresByUid[uid] = score;
      return RankingEntry.fromJson(data, uid: uid);
    }).toList();
    return List<RankingEntry>.from(_infiniteCache!);
  }

  Future<List<RankingEntry>> load() async {
    return loadStage();
  }

  Future<void> saveStage(List<RankingEntry> entries) async {
    for (final entry in entries) {
      await addStageScore(entry.name, entry.score, detail: entry.detail);
    }
  }

  Future<void> saveInfinite(List<RankingEntry> entries) async {
    for (final entry in entries) {
      await addInfiniteScore(entry.name, entry.score);
    }
  }

  Future<void> save(List<RankingEntry> entries) async {
    await saveStage(entries);
  }

  Future<void> addStageScore(String name, int score, {String? detail}) async {
    final uid = _uid;
    if (uid == null) return;
    final doc = _stageCollection.doc(uid);
    final difficultyKey = _difficultyLabelToKey[detail] ?? detail;
    if (difficultyKey == null || difficultyKey.isEmpty) return;
    Map<String, dynamic> currentScores;
    final cachedScores = _stageScoresByUid[uid];
    if (cachedScores != null) {
      currentScores = Map<String, dynamic>.from(cachedScores);
    } else {
      Map<String, dynamic> currentData = const <String, dynamic>{};
      try {
        final cached = await doc.get(const GetOptions(source: Source.cache));
        currentData = cached.data() ?? const <String, dynamic>{};
      } catch (_) {}
      if (currentData.isEmpty) {
        final current = await doc.get();
        currentData = current.data() ?? const <String, dynamic>{};
      }
      final currentScoresRaw = currentData['scoresByDifficulty'];
      currentScores = currentScoresRaw is Map
          ? Map<String, dynamic>.from(currentScoresRaw)
          : <String, dynamic>{};
    }
    final currentScore = currentScores[difficultyKey] is int
        ? currentScores[difficultyKey] as int
        : int.tryParse('${currentScores[difficultyKey]}') ?? 0;
    if (currentScore >= score) return;
    currentScores[difficultyKey] = score;
    _stageScoresByUid[uid] = {
      for (final entry in currentScores.entries)
        entry.key: entry.value is int
            ? entry.value as int
            : int.tryParse('${entry.value}') ?? 0,
    };
    await doc.set({
      'name': name,
      'scoresByDifficulty': currentScores,
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final updatedEntries = _buildStageCacheEntryList(name, currentScores, uid: uid);
    final currentEntries = List<RankingEntry>.from(_stageCache ?? const []);
    currentEntries.removeWhere((entry) => entry.uid == uid);
    currentEntries.addAll(updatedEntries);
    currentEntries.sort(_compareStageEntries);
    _stageCache = currentEntries.take(20).toList();
  }

  Future<void> addInfiniteScore(String name, int score) async {
    final uid = _uid;
    if (uid == null) return;
    final doc = _infiniteCollection.doc(uid);
    int? currentScore = _infiniteScoresByUid[uid];
    if (currentScore == null) {
      try {
        final cached = await doc.get(const GetOptions(source: Source.cache));
        currentScore = cached.data()?['score'] as int?;
      } catch (_) {}
      currentScore ??= (await doc.get()).data()?['score'] as int?;
    }
    if (currentScore != null && currentScore >= score) return;
    _infiniteScoresByUid[uid] = score;
    await doc.set({
      'name': name,
      'score': score,
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final updated = RankingEntry(name: name, score: score, uid: uid);
    final currentEntries = List<RankingEntry>.from(_infiniteCache ?? const []);
    final sameUserIndex = currentEntries.indexWhere((entry) => entry.uid == uid);
    if (sameUserIndex >= 0) {
      if (currentEntries[sameUserIndex].score < score) {
        currentEntries[sameUserIndex] = updated;
      }
    } else {
        currentEntries.add(updated);
    }
    currentEntries.sort((a, b) => b.score.compareTo(a.score));
    _infiniteCache = currentEntries.take(20).toList();
  }

  bool get hasAuthenticatedUser => _uid != null;

  Future<void> deleteCurrentUserEntries() async {
    final uid = _uid;
    if (uid == null) return;
    await _stageCollection.doc(uid).delete().catchError((_) {});
    await _infiniteCollection.doc(uid).delete().catchError((_) {});
    _stageScoresByUid.remove(uid);
    _infiniteScoresByUid.remove(uid);
    _stageCache = null;
    _infiniteCache = null;
    _warmUpFuture = null;
  }

  Future<void> _warmUpInternal() async {
    await Future.wait<void>([
      if ((_stageCache ?? const []).isEmpty) refreshStage().then((_) {}),
      if ((_infiniteCache ?? const []).isEmpty) refreshInfinite().then((_) {}),
    ]);
  }

  static List<RankingEntry> _buildStageCacheEntryList(
    String name,
    Map<String, dynamic> scoresByDifficulty, {
    String? uid,
  }) {
    final entries = <RankingEntry>[];
    for (final entry in scoresByDifficulty.entries) {
      final difficultyKey = entry.key.toString();
      final score = entry.value is int
          ? entry.value as int
          : int.tryParse(entry.value.toString()) ?? 0;
      if (score <= 0) continue;
      entries.add(
        RankingEntry(
          name: name,
          score: score,
          detail: _difficultyKeyToLabel[difficultyKey] ?? difficultyKey,
          uid: uid,
        ),
      );
    }
    entries.sort(_compareStageEntries);
    return entries.take(20).toList();
  }

  static List<RankingEntry> _parseStageSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final entries = <RankingEntry>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['name'] as String?) ?? 'PLAYER';
      final scoresByDifficulty = data['scoresByDifficulty'];
      if (scoresByDifficulty is Map) {
        final entryUid = (data['uid'] as String?) ?? doc.id;
        RankingEntry? bestEntry;
        for (final entry in scoresByDifficulty.entries) {
          final difficultyKey = entry.key.toString();
          final score = entry.value is int
              ? entry.value as int
              : int.tryParse(entry.value.toString()) ?? 0;
          if (score <= 0) continue;
          final candidate = RankingEntry(
            name: name,
            score: score,
            detail: _difficultyKeyToLabel[difficultyKey] ?? difficultyKey,
            uid: entryUid,
          );
          if (bestEntry == null ||
              _compareStageEntries(candidate, bestEntry) < 0) {
            bestEntry = candidate;
          }
        }
        if (bestEntry != null) {
          entries.add(bestEntry);
        }
        final uid = entryUid;
        _stageScoresByUid[uid] = {
          for (final entry in scoresByDifficulty.entries)
            entry.key.toString(): entry.value is int
                ? entry.value as int
                : int.tryParse(entry.value.toString()) ?? 0,
        };
        continue;
      }

      final entryUid = (data['uid'] as String?) ?? doc.id;
      final legacy = RankingEntry.fromJson(data, uid: entryUid);
      if (legacy.score > 0) {
        entries.add(legacy);
      }
    }
    entries.sort(_compareStageEntries);
    return entries.take(20).toList();
  }

  static int _difficultyOrder(String? detail) {
    return switch (detail) {
      '하드' => 0,
      '노말' => 1,
      '이지' => 2,
      '나이트메어' => -1,
      _ => 99,
    };
  }

  static int _compareStageEntries(RankingEntry a, RankingEntry b) {
    final difficultyCompare =
        _difficultyOrder(a.detail).compareTo(_difficultyOrder(b.detail));
    if (difficultyCompare != 0) {
      return difficultyCompare;
    }
    return b.score.compareTo(a.score);
  }
}
