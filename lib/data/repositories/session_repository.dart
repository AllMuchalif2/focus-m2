import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_record.dart';

class SessionRepository {
  final FirebaseFirestore _firestore;

  SessionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('sessions');
  }

  DocumentReference<Map<String, dynamic>> _proofRef(String userId, String sessionId) {
    return _firestore.collection('users').doc(userId).collection('proofs').doc(sessionId);
  }

  Future<String> createSession(String userId, SessionRecord session) async {
    final ref = session.id.isEmpty
        ? _sessionsRef(userId).doc()
        : _sessionsRef(userId).doc(session.id);

    final data = session.toMap()..['userId'] = userId;
    await ref.set(data);
    return ref.id;
  }

  Stream<List<SessionRecord>> watchRecentSessions(String userId, {int limit = 10}) {
    return _sessionsRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionRecord.fromFirestore(doc)).toList());
  }

  Future<List<SessionRecord>> getRecentSessions(
    String userId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _sessionsRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => SessionRecord.fromFirestore(doc)).toList();
  }

  Future<List<SessionRecord>> getSessionsForDateRange(
    String userId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _sessionsRef(userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => SessionRecord.fromFirestore(doc)).toList();
  }

  Future<void> updateReflection(
    String userId,
    String sessionId,
    String reflection,
  ) async {
    await _sessionsRef(userId).doc(sessionId).update({
      'reflection': reflection,
    });
  }

  Future<void> deleteSession(String userId, String sessionId) async {
    final batch = _firestore.batch();
    final sessionDoc = _sessionsRef(userId).doc(sessionId);
    final proofDoc = _proofRef(userId, sessionId);

    batch.delete(sessionDoc);
    batch.delete(proofDoc);
    await batch.commit();
  }
}
