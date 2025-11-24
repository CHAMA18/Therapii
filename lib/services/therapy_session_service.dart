import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:therapii/models/therapy_session.dart';

class TherapySessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'therapy_sessions';

  // Create a new therapy session
  Future<void> createSession(TherapySession session) async {
    try {
      await _firestore.collection(_collection).doc(session.id).set(session.toJson());
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  // Get session by ID
  Future<TherapySession?> getSession(String sessionId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(sessionId).get();
      if (doc.exists && doc.data() != null) {
        return TherapySession.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get session: $e');
    }
  }

  // Update session
  Future<void> updateSession(TherapySession session) async {
    try {
      final updatedSession = session.copyWith(updatedAt: DateTime.now());
      await _firestore.collection(_collection).doc(session.id).update(updatedSession.toJson());
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  // Delete session
  Future<void> deleteSession(String sessionId) async {
    try {
      await _firestore.collection(_collection).doc(sessionId).delete();
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  // Get user's sessions (sorted by creation date, most recent first)
  Future<List<TherapySession>> getUserSessions(String userId, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .get();

      final list = querySnapshot.docs
          .map((doc) => TherapySession.fromJson(doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get user sessions: $e');
    }
  }

  // Get therapist's sessions
  Future<List<TherapySession>> getTherapistSessions(String therapistId, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('therapist_id', isEqualTo: therapistId)
          .get();

      final list = querySnapshot.docs
          .map((doc) => TherapySession.fromJson(doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get therapist sessions: $e');
    }
  }

  // Get sessions by status
  Future<List<TherapySession>> getSessionsByStatus(
    String userId,
    SessionStatus status, {
    int limit = 20,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .get();

      final list = querySnapshot.docs
          .map((doc) => TherapySession.fromJson(doc.data()))
          .where((s) => s.status == status)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get sessions by status: $e');
    }
  }

  // Get upcoming sessions for a user
  Future<List<TherapySession>> getUpcomingSessions(String userId, {int limit = 10}) async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .get();

      final list = querySnapshot.docs
          .map((doc) => TherapySession.fromJson(doc.data()))
          .where((s) => s.status == SessionStatus.scheduled && s.scheduledAt.isAfter(now))
          .toList();
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get upcoming sessions: $e');
    }
  }

  // Stream session data for real-time updates
  Stream<TherapySession?> streamSession(String sessionId) {
    return _firestore
        .collection(_collection)
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? TherapySession.fromJson(doc.data()!)
            : null);
  }

  // Start a session
  Future<void> startSession(String sessionId) async {
    try {
      await _firestore.collection(_collection).doc(sessionId).update({
        'status': SessionStatus.ongoing.name,
        'started_at': Timestamp.fromDate(DateTime.now()),
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to start session: $e');
    }
  }

  // End a session
  Future<void> endSession(String sessionId, {String? notes}) async {
    try {
      final updates = {
        'status': SessionStatus.completed.name,
        'ended_at': Timestamp.fromDate(DateTime.now()),
        'updated_at': Timestamp.fromDate(DateTime.now()),
      };
      
      if (notes != null) {
        updates['notes'] = notes;
      }
      
      await _firestore.collection(_collection).doc(sessionId).update(updates);
    } catch (e) {
      throw Exception('Failed to end session: $e');
    }
  }

  // Cancel a session
  Future<void> cancelSession(String sessionId) async {
    try {
      await _firestore.collection(_collection).doc(sessionId).update({
        'status': SessionStatus.cancelled.name,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to cancel session: $e');
    }
  }

  // Add session rating and feedback
  Future<void> rateSession(String sessionId, double rating, String? feedback) async {
    try {
      await _firestore.collection(_collection).doc(sessionId).update({
        'rating': rating,
        'feedback': feedback,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to rate session: $e');
    }
  }

  // Schedule a new session
  Future<String> scheduleSession({
    required String userId,
    required String therapistId,
    required DateTime scheduledAt,
    required double sessionFee,
  }) async {
    try {
      final sessionRef = _firestore.collection(_collection).doc();
      final session = TherapySession(
        id: sessionRef.id,
        userId: userId,
        therapistId: therapistId,
        scheduledAt: scheduledAt,
        sessionFee: sessionFee,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await sessionRef.set(session.toJson());
      return sessionRef.id;
    } catch (e) {
      throw Exception('Failed to schedule session: $e');
    }
  }
}