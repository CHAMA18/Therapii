import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:therapii/models/chat_conversation.dart';
import 'package:therapii/models/chat_message.dart';

class ChatService {
  ChatService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _conversationCollection = 'conversations';
  static const String _messagesSubcollection = 'messages';

  static String conversationIdFor({required String therapistId, required String patientId}) {
    return '${therapistId}_$patientId';
  }

  DocumentReference<Map<String, dynamic>> _conversationRef({
    required String therapistId,
    required String patientId,
  }) {
    final id = conversationIdFor(therapistId: therapistId, patientId: patientId);
    return _firestore.collection(_conversationCollection).doc(id);
  }

  CollectionReference<Map<String, dynamic>> _messagesRef({
    required String therapistId,
    required String patientId,
  }) {
    return _conversationRef(therapistId: therapistId, patientId: patientId)
        .collection(_messagesSubcollection);
  }

  Future<void> ensureConversation({
    required String therapistId,
    required String patientId,
  }) async {
    final conversationRef =
        _conversationRef(therapistId: therapistId, patientId: patientId);
    final timestamp = Timestamp.fromDate(DateTime.now());

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(conversationRef);
      if (existing.exists) {
        final data = existing.data();
        final updates = <String, dynamic>{};
        if ((data?['therapist_id'] ?? '').toString().isEmpty) {
          updates['therapist_id'] = therapistId;
        }
        if ((data?['patient_id'] ?? '').toString().isEmpty) {
          updates['patient_id'] = patientId;
        }
        if (updates.isNotEmpty) {
          updates['updated_at'] = timestamp;
          transaction.update(conversationRef, updates);
        }
        return;
      }

      transaction.set(conversationRef, {
        'therapist_id': therapistId,
        'patient_id': patientId,
        'created_at': timestamp,
        'updated_at': timestamp,
        'therapist_unread_count': 0,
        'patient_unread_count': 0,
      });
    });
  }

  Future<void> sendMessage({
    required String therapistId,
    required String patientId,
    required String senderId,
    required String text,
    required bool senderIsTherapist,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final conversationRef = _conversationRef(therapistId: therapistId, patientId: patientId);
    final messagesRef = _messagesRef(therapistId: therapistId, patientId: patientId);
    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);
      if (!conversationSnapshot.exists) {
        transaction.set(conversationRef, {
          'therapist_id': therapistId,
          'patient_id': patientId,
          'created_at': timestamp,
          'updated_at': timestamp,
          'therapist_unread_count': 0,
          'patient_unread_count': 0,
        });
      }

      final messageRef = messagesRef.doc();
      transaction.set(messageRef, {
        'sender_id': senderId,
        'receiver_id': senderIsTherapist ? patientId : therapistId,
        'sender_role': senderIsTherapist ? 'therapist' : 'patient',
        'text': trimmed,
        'sent_at': timestamp,
      });

      final unreadUpdates = <String, dynamic>{
        'last_message_text': trimmed,
        'last_message_sender_id': senderId,
        'last_message_sender_role': senderIsTherapist ? 'therapist' : 'patient',
        'last_message_at': timestamp,
        'updated_at': timestamp,
      };

      if (senderIsTherapist) {
        unreadUpdates['therapist_unread_count'] = 0;
        unreadUpdates['patient_unread_count'] = FieldValue.increment(1);
      } else {
        unreadUpdates['patient_unread_count'] = 0;
        unreadUpdates['therapist_unread_count'] = FieldValue.increment(1);
      }

      transaction.update(conversationRef, unreadUpdates);
    });
  }

  Stream<List<ChatMessage>> streamMessages({
    required String therapistId,
    required String patientId,
    int limit = 200,
  }) {
    final conversationId = conversationIdFor(therapistId: therapistId, patientId: patientId);
    return _messagesRef(therapistId: therapistId, patientId: patientId)
        .orderBy('sent_at', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromDoc(doc, conversationId: conversationId))
            .toList());
  }

  Stream<ChatConversation?> streamConversation({
    required String therapistId,
    required String patientId,
  }) {
    return _conversationRef(therapistId: therapistId, patientId: patientId)
        .snapshots()
        .map((snapshot) => snapshot.exists ? ChatConversation.fromDoc(snapshot) : null);
  }

  Stream<List<ChatConversation>> streamTherapistConversations({
    required String therapistId,
    int limit = 50,
  }) {
    return _firestore
        .collection(_conversationCollection)
        .where('therapist_id', isEqualTo: therapistId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .where((doc) => doc.exists && doc.id.isNotEmpty)
              .map(ChatConversation.fromDoc)
              .toList();
          list.sort((a, b) {
            final am = a.lastMessageAt;
            final bm = b.lastMessageAt;
            if (am == null && bm == null) return 0;
            if (am == null) return 1;
            if (bm == null) return -1;
            return bm.compareTo(am);
          });
          return list;
        });
  }

  Stream<List<ChatConversation>> streamPatientConversations({
    required String patientId,
    int limit = 50,
  }) {
    return _firestore
        .collection(_conversationCollection)
        .where('patient_id', isEqualTo: patientId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .where((doc) => doc.exists && doc.id.isNotEmpty)
              .map(ChatConversation.fromDoc)
              .toList();
          list.sort((a, b) {
            final am = a.lastMessageAt;
            final bm = b.lastMessageAt;
            if (am == null && bm == null) return 0;
            if (am == null) return 1;
            if (bm == null) return -1;
            return bm.compareTo(am);
          });
          return list;
        });
  }

  Future<void> markConversationRead({
    required String therapistId,
    required String patientId,
    required bool viewerIsTherapist,
  }) async {
    final conversationRef = _conversationRef(therapistId: therapistId, patientId: patientId);
    final updates = <String, dynamic>{
      viewerIsTherapist ? 'therapist_unread_count' : 'patient_unread_count': 0,
      viewerIsTherapist ? 'therapist_last_read_at' : 'patient_last_read_at': Timestamp.fromDate(DateTime.now()),
    };

    try {
      await conversationRef.update(updates);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        // Conversation not created yet; nothing to mark.
        return;
      }
      rethrow;
    }
  }

  Future<ChatConversation?> getConversation({
    required String therapistId,
    required String patientId,
  }) async {
    final snapshot = await _conversationRef(therapistId: therapistId, patientId: patientId).get();
    if (!snapshot.exists) return null;
    return ChatConversation.fromDoc(snapshot);
  }
}