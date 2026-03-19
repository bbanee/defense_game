import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NicknameRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  NicknameRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  String normalize(String nickname) => nickname.trim().toLowerCase();

  Future<bool> reserveNickname({
    required String nickname,
    String? previousNickname,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    final normalized = normalize(nickname);
    if (normalized.isEmpty) return false;
    final previousNormalized =
        previousNickname == null ? '' : normalize(previousNickname);

    await _firestore.runTransaction((tx) async {
      final targetRef = _firestore.collection('nicknames').doc(normalized);
      final previousRef = previousNormalized.isNotEmpty
          ? _firestore.collection('nicknames').doc(previousNormalized)
          : null;
      final targetSnap = await tx.get(targetRef);
      final previousSnap = previousRef == null ? null : await tx.get(previousRef);
      final currentOwner = targetSnap.data()?['uid'] as String?;
      if (targetSnap.exists && currentOwner != uid) {
        throw StateError('duplicate');
      }

      tx.set(
          targetRef,
          {
            'uid': uid,
            'nickname': nickname.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (!targetSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (previousRef != null && previousNormalized != normalized) {
        if (previousSnap?.data()?['uid'] == uid) {
          tx.delete(previousRef);
        }
      }
    });
    return true;
  }

  Future<void> releaseCurrentUserNickname(String nickname) async {
    final uid = _uid;
    final normalized = normalize(nickname);
    if (uid == null || normalized.isEmpty) return;
    final ref = _firestore.collection('nicknames').doc(normalized);
    final snap = await ref.get();
    if (!snap.exists) return;
    final owner = snap.data()?['uid'] as String?;
    if (owner != uid) return;
    await ref.delete().catchError((_) {});
  }
}
