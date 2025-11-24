import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { scheduled, ongoing, completed, cancelled }

class TherapySession {
  final String id;
  final String userId;
  final String therapistId;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final SessionStatus status;
  final String? notes;
  final double? rating;
  final String? feedback;
  final double sessionFee;
  final DateTime createdAt;
  final DateTime updatedAt;

  TherapySession({
    required this.id,
    required this.userId,
    required this.therapistId,
    required this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.status = SessionStatus.scheduled,
    this.notes,
    this.rating,
    this.feedback,
    required this.sessionFee,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'therapist_id': therapistId,
        'scheduled_at': Timestamp.fromDate(scheduledAt),
        'started_at': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'ended_at': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'status': status.name,
        'notes': notes,
        'rating': rating,
        'feedback': feedback,
        'session_fee': sessionFee,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  static TherapySession fromJson(Map<String, dynamic> json) => TherapySession(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        therapistId: json['therapist_id'] ?? '',
        scheduledAt: json['scheduled_at'] is Timestamp
            ? (json['scheduled_at'] as Timestamp).toDate()
            : DateTime.now(),
        startedAt: json['started_at'] is Timestamp
            ? (json['started_at'] as Timestamp).toDate()
            : null,
        endedAt: json['ended_at'] is Timestamp
            ? (json['ended_at'] as Timestamp).toDate()
            : null,
        status: SessionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => SessionStatus.scheduled,
        ),
        notes: json['notes'],
        rating: json['rating']?.toDouble(),
        feedback: json['feedback'],
        sessionFee: (json['session_fee'] ?? 0.0).toDouble(),
        createdAt: json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : DateTime.now(),
      );

  TherapySession copyWith({
    String? id,
    String? userId,
    String? therapistId,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
    SessionStatus? status,
    String? notes,
    double? rating,
    String? feedback,
    double? sessionFee,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TherapySession(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        therapistId: therapistId ?? this.therapistId,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        rating: rating ?? this.rating,
        feedback: feedback ?? this.feedback,
        sessionFee: sessionFee ?? this.sessionFee,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Duration get duration {
    if (startedAt != null && endedAt != null) {
      return endedAt!.difference(startedAt!);
    }
    return Duration.zero;
  }
}