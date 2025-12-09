import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:therapii/models/ai_conversation_summary.dart';

class AiConversationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'ai_conversation_summaries';

  CollectionReference<Map<String, dynamic>> _col() =>
      _firestore.collection(_collection);

  Future<String> saveSummary({
    required String patientId,
    required String therapistId,
    required String summary,
    List<AiMessagePart> transcript = const <AiMessagePart>[],
  }) async {
    // Try server-side save first; gracefully fall back to client write on errors
    // Debug context
    // ignore: avoid_print
    print('[AI-SUMMARY] saveSummary start patient=$patientId therapist=$therapistId transcriptLen=${transcript.length}');
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('saveAiConversationSummary');
      // ignore: avoid_print
      print('[AI-SUMMARY] invoking cloud function saveAiConversationSummary');
      final result = await callable.call({
        'therapistId': therapistId,
        'summary': summary,
        'transcript': transcript.map((e) => e.toJson()).toList(growable: false),
      });
      final data = result.data;
      if (data is Map && data['id'] is String && (data['id'] as String).isNotEmpty) {
        // ignore: avoid_print
        print('[AI-SUMMARY] function saved id=${data['id']}');
        return data['id'] as String;
      }
    } catch (_) {
      // proceed to client fallback
      // ignore: avoid_print
      print('[AI-SUMMARY] function call failed or returned unexpected payload; falling back to client write');
    }
    // Fallback: if function fails or returns unexpected payload, attempt client write
    final ref = _col().doc();
    // ignore: avoid_print
    print('[AI-SUMMARY] writing directly to Firestore collection=$_collection id=${ref.id}');
    await ref.set({
      'patient_id': patientId,
      'therapist_id': therapistId,
      'summary': summary,
      'created_at': Timestamp.fromDate(DateTime.now()),
      'transcript': transcript.map((e) => e.toJson()).toList(growable: false),
      'share_with_therapist': true,
    });
    // ignore: avoid_print
    print('[AI-SUMMARY] client write success id=${ref.id}');
    return ref.id;
  }

  Stream<List<AiConversationSummary>> streamTherapistSummaries({
    required String therapistId,
    int limit = 20,
  }) {
    return _col()
        .where('therapist_id', isEqualTo: therapistId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(AiConversationSummary.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<AiConversationSummary>> streamPatientSummaries({
    required String patientId,
    int limit = 20,
  }) {
    return _col()
        .where('patient_id', isEqualTo: patientId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(AiConversationSummary.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<List<AiConversationSummary>> getTherapistSummaries({
    required String therapistId,
    int limit = 50,
  }) async {
    final snapshot = await _col()
        .where('therapist_id', isEqualTo: therapistId)
        .get();
    final list = snapshot.docs.map(AiConversationSummary.fromDoc).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  Future<List<AiConversationSummary>> getPatientSummaries({
    required String patientId,
    int limit = 50,
  }) async {
    final snapshot = await _col().where('patient_id', isEqualTo: patientId).get();
    final list = snapshot.docs.map(AiConversationSummary.fromDoc).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  Future<AiConversationSummary?> getById(String id) async {
    final doc = await _col().doc(id).get();
    if (!doc.exists) return null;
    return AiConversationSummary.fromDoc(doc);
  }

  Future<void> saveTherapistFeedback({
    required String summaryId,
    required String feedback,
  }) async {
    await _col().doc(summaryId).update({
      'therapist_feedback': feedback,
      'feedback_updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }
}
