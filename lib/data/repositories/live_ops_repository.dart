import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class LiveOpsConfig {
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final int minBuildNumber;
  final String announcementTitle;
  final String announcementBody;

  const LiveOpsConfig({
    required this.maintenanceEnabled,
    required this.maintenanceMessage,
    required this.minBuildNumber,
    required this.announcementTitle,
    required this.announcementBody,
  });

  factory LiveOpsConfig.fromJson(Map<String, dynamic> json) {
    return LiveOpsConfig(
      maintenanceEnabled: json['maintenanceEnabled'] as bool? ?? false,
      maintenanceMessage: json['maintenanceMessage'] as String? ?? '',
      minBuildNumber: json['minBuildNumber'] as int? ?? 0,
      announcementTitle: json['announcementTitle'] as String? ?? '',
      announcementBody: json['announcementBody'] as String? ?? '',
    );
  }

  static const empty = LiveOpsConfig(
    maintenanceEnabled: false,
    maintenanceMessage: '',
    minBuildNumber: 0,
    announcementTitle: '',
    announcementBody: '',
  );
}

class LiveOpsRepository {
  static LiveOpsConfig? _cache;
  final FirebaseFirestore _firestore;

  LiveOpsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<LiveOpsConfig> loadConfig() async {
    final cached = _cache;
    if (cached != null) return cached;
    final doc = _firestore.collection('appConfig').doc('live');
    try {
      final cachedSnap = await doc.get(const GetOptions(source: Source.cache));
      final cachedData = cachedSnap.data();
      if (cachedData != null) {
        final config = LiveOpsConfig.fromJson(cachedData);
        _cache = config;
        return config;
      }
    } catch (_) {}
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await doc.get().timeout(const Duration(seconds: 2));
    } catch (_) {
      snap = null;
    }
    if (snap == null) {
      _cache = LiveOpsConfig.empty;
      return LiveOpsConfig.empty;
    }
    final data = snap.data();
    if (data == null) {
      _cache = LiveOpsConfig.empty;
      return LiveOpsConfig.empty;
    }
    final config = LiveOpsConfig.fromJson(data);
    _cache = config;
    return config;
  }
}
