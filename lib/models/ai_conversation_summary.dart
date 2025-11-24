import 'package:cloud_firestore/cloud_firestore.dart';

class AiConversationSummary {
  final String id;
  final String patientId;
  final String therapistId;
  final String summary;
  final DateTime createdAt;
  final List<AiMessagePart> transcript;

  const AiConversationSummary({
    required this.id,
    required this.patientId,
    required this.therapistId,
    required this.summary,
    required this.createdAt,
    this.transcript = const <AiMessagePart>[],
  });

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'therapist_id': therapistId,
        'summary': summary,
        'created_at': Timestamp.fromDate(createdAt),
        'transcript': transcript.map((m) => m.toJson()).toList(growable: false),
      };

  factory AiConversationSummary.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AiConversationSummary(
      id: doc.id,
      patientId: (data['patient_id'] ?? '').toString(),
      therapistId: (data['therapist_id'] ?? '').toString(),
      summary: (data['summary'] ?? '').toString(),
      createdAt: _toDate(data['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      transcript: _toTranscript(data['transcript']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<AiMessagePart> _toTranscript(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => AiMessagePart(
                role: (e['role'] ?? '').toString(),
                text: (e['text'] ?? '').toString(),
              ))
          .toList(growable: false);
    }
    return const <AiMessagePart>[];
  }
}

class AiMessagePart {
  final String role;
  final String text;

  const AiMessagePart({required this.role, required this.text});

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
      };
}
