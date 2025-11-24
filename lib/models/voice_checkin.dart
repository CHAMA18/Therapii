import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceCheckin {
  final String id;
  final String patientId;
  final String therapistId;
  final DateTime createdAt;
  final int durationSeconds;
  final String audioUrl;
  final String storagePath;

  const VoiceCheckin({
    required this.id,
    required this.patientId,
    required this.therapistId,
    required this.createdAt,
    required this.durationSeconds,
    required this.audioUrl,
    required this.storagePath,
  });

  factory VoiceCheckin.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return VoiceCheckin(
      id: doc.id,
      patientId: (data['patient_id'] ?? '').toString(),
      therapistId: (data['therapist_id'] ?? '').toString(),
      createdAt: _toDate(data['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      durationSeconds: (data['duration_seconds'] ?? 0) is int
          ? (data['duration_seconds'] as int)
          : int.tryParse('${data['duration_seconds']}') ?? 0,
      audioUrl: (data['audio_url'] ?? '').toString(),
      storagePath: (data['storage_path'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'therapist_id': therapistId,
        'created_at': Timestamp.fromDate(createdAt),
        'duration_seconds': durationSeconds,
        'audio_url': audioUrl,
        'storage_path': storagePath,
        'share_with_therapist': true,
      };

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
